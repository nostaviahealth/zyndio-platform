// INT-04: Partner & Clinical Treatment Events API
// Supports:
//   POST /v1/patients/{zyndio_patient_id}/treatment-events
//   GET  /v1/patients/{zyndio_patient_id}/treatment
//
// Enforces:
//   - Clause 9.1 (No-Dose-Suggestion Rule): records partner/clinician-reported
//     GLP-1 treatment context only; never computes or recommends a dose.
//   - Idempotency-Key header on POST with 7-day replay window per (org_id, key).
//   - Standard error envelope: { "error": { "code", "message", "request_id" } }

export type TreatmentEventType =
  | 'medication_start'
  | 'dose_change'
  | 'status_change'
  | 'tolerability_note'
  | 'clinician_change'

export type TreatmentStatus = 'active' | 'paused' | 'discontinued' | 'completed'

export interface TreatmentCourseRecord {
  id: string
  org_id: string
  patient_id: string
  medication: string
  formulation: string
  current_dose_value: number | null
  current_dose_unit: string | null
  start_date: string
  status: TreatmentStatus
  created_by: string | null
  created_at: string
  updated_at: string
}

export interface TreatmentEventRecord {
  id: string
  org_id: string
  patient_id: string
  course_id: string
  event_type: TreatmentEventType
  dose_value: number | null
  dose_unit: string | null
  status_value: TreatmentStatus | null
  note: string | null
  effective_at: string
  entered_by: string | null
  source: 'portal' | 'api'
  idempotency_key: string | null
  created_at: string
}

export interface PatientRecord {
  id: string
  org_id: string
}

export interface PartnerWriteInput {
  orgId: string
  patientId: string
  eventType: TreatmentEventType
  medication: string | null
  formulation: string
  doseValue: number | null
  doseUnit: string | null
  status: TreatmentStatus | null
  note: string | null
  effectiveAt: string
  idempotencyKey: string
  requestId: string
}

export interface PartnerWriteResult {
  replayed: boolean
  course: TreatmentCourseRecord
  event: TreatmentEventRecord
}

export interface TreatmentStore {
  findPatient(patientId: string): Promise<PatientRecord | null>
  isPartnerAuthorised(patientId: string): Promise<boolean>
  findEventByIdempotencyKey(orgId: string, idempotencyKey: string): Promise<TreatmentEventRecord | null>
  findLatestCourse(orgId: string, patientId: string): Promise<TreatmentCourseRecord | null>
  findCourseById(courseId: string): Promise<TreatmentCourseRecord | null>
  createCourse(input: Omit<TreatmentCourseRecord, 'id' | 'created_at' | 'updated_at'>): Promise<TreatmentCourseRecord>
  updateCourse(
    courseId: string,
    patch: Partial<Pick<TreatmentCourseRecord, 'medication' | 'formulation' | 'current_dose_value' | 'current_dose_unit' | 'status'>>,
  ): Promise<TreatmentCourseRecord>
  createEvent(input: Omit<TreatmentEventRecord, 'id' | 'created_at'>): Promise<TreatmentEventRecord>
  listEvents(orgId: string, patientId: string): Promise<TreatmentEventRecord[]>
  writeAuditLog(entry: {
    event_type: string
    actor_user_id: string | null
    target_user_id: string
    org_id: string
    metadata: Record<string, unknown>
  }): Promise<void>
  applyPartnerWrite(input: PartnerWriteInput): Promise<PartnerWriteResult>
}

export interface TreatmentHandlerDeps {
  store: TreatmentStore
  expectedBearerToken?: string
  /** Clinic bound to the bearer token. The header is never authority. */
  boundOrgId?: string
  now?: () => Date
  generateRequestId?: () => string
}

const VALID_EVENT_TYPES: ReadonlySet<string> = new Set<TreatmentEventType>([
  'medication_start',
  'dose_change',
  'status_change',
  'tolerability_note',
  'clinician_change',
])

const VALID_STATUSES: ReadonlySet<string> = new Set<TreatmentStatus>([
  'active',
  'paused',
  'discontinued',
  'completed',
])

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i
const SEVEN_DAYS_MS = 7 * 24 * 60 * 60 * 1000
const MAX_BODY_BYTES = 16384

function errorResponse(
  status: number,
  code: string,
  message: string,
  requestId: string,
): Response {
  return new Response(
    JSON.stringify({
      error: {
        code,
        message,
        request_id: requestId,
      },
    }),
    {
      status,
      headers: {
        'Content-Type': 'application/json',
        'X-Request-Id': requestId,
      },
    },
  )
}

function jsonOk(body: unknown, status: number, requestId: string): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      'Content-Type': 'application/json',
      'X-Request-Id': requestId,
    },
  })
}

function extractBearer(authHeader: string | null): string | null {
  if (!authHeader) return null
  const m = authHeader.match(/^Bearer\s+(\S+)$/i)
  return m ? m[1] : null
}

function constantTimeEquals(a: string, b: string): boolean {
  const enc = new TextEncoder()
  const ab = enc.encode(a)
  const bb = enc.encode(b)
  const len = Math.max(ab.length, bb.length)
  let diff = ab.length ^ bb.length
  for (let i = 0; i < len; i++) {
    diff |= (ab[i] ?? 0) ^ (bb[i] ?? 0)
  }
  return diff === 0
}

function matchRoute(pathname: string): {
  patientId: string
  kind: 'events' | 'treatment'
} | null {
  // Matches both `/v1/patients/{id}/treatment-events` and
  // `/treatment-events/v1/patients/{id}/treatment-events`
  const eventsMatch = pathname.match(
    /(?:^|\/)v1\/patients\/([^/]+)\/treatment-events\/?$/,
  )
  if (eventsMatch) {
    return { patientId: decodeURIComponent(eventsMatch[1]), kind: 'events' }
  }
  const getMatch = pathname.match(
    /(?:^|\/)v1\/patients\/([^/]+)\/treatment\/?$/,
  )
  if (getMatch) {
    return { patientId: decodeURIComponent(getMatch[1]), kind: 'treatment' }
  }
  return null
}

export async function handleTreatmentEventsRequest(
  req: Request,
  deps: TreatmentHandlerDeps,
): Promise<Response> {
  const nowFn = deps.now ?? (() => new Date())
  const requestId =
    req.headers.get('X-Request-Id')?.trim() ||
    (deps.generateRequestId ? deps.generateRequestId() : crypto.randomUUID())

  if (req.method === 'OPTIONS') {
    return new Response('ok', {
      status: 200,
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': 'authorization, content-type, idempotency-key, x-request-id',
        'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
      },
    })
  }

  // Authenticate bearer token (fail closed if expectedBearerToken is missing or empty)
  const token = extractBearer(req.headers.get('Authorization'))
  const expected = deps.expectedBearerToken?.trim() ?? ''
  const boundOrgId = deps.boundOrgId?.trim() ?? ''
  if (!token || !expected || !boundOrgId || !constantTimeEquals(token, expected)) {
    return errorResponse(401, 'unauthorized', 'Valid bearer token is required.', requestId)
  }

  const headerOrg = req.headers.get('X-Partner-Org-Id')?.trim()
  if (headerOrg && headerOrg !== boundOrgId) {
    return errorResponse(403, 'org_not_authorized', 'Partner token is not authorised for that clinic.', requestId)
  }

  const url = new URL(req.url)
  const route = matchRoute(url.pathname)
  if (!route) {
    return errorResponse(404, 'not_found', 'Endpoint not found.', requestId)
  }

  const { patientId, kind } = route
  if (!UUID_RE.test(patientId)) {
    return errorResponse(400, 'invalid_patient_id', 'zyndio_patient_id must be a valid UUID.', requestId)
  }

  const patient = await deps.store.findPatient(patientId)
  if (!patient || patient.org_id !== boundOrgId) {
    return errorResponse(404, 'patient_not_found', 'Patient not found.', requestId)
  }

  if (!(await deps.store.isPartnerAuthorised(patient.id))) {
    return errorResponse(403, 'consent_required', 'Current partner outcome authorisation is required.', requestId)
  }

  // GET /v1/patients/{zyndio_patient_id}/treatment
  if (kind === 'treatment') {
    if (req.method !== 'GET') {
      return errorResponse(405, 'method_not_allowed', 'Only GET is supported on /treatment.', requestId)
    }

    const course = await deps.store.findLatestCourse(patient.org_id, patient.id)
    const events = (await deps.store.listEvents(patient.org_id, patient.id))
      .filter((event) => !course || event.course_id === course.id)

    try {
      await deps.store.writeAuditLog({
        event_type: 'treatment_context_viewed',
        actor_user_id: null,
        target_user_id: patient.id,
        org_id: patient.org_id,
        metadata: { source: 'api', request_id: requestId },
      })
    } catch {
      return errorResponse(500, 'audit_failed', 'Treatment history was not returned because the audit record failed.', requestId)
    }

    return jsonOk(
      {
        patient_id: patient.id,
        course,
        events,
        request_id: requestId,
      },
      200,
      requestId,
    )
  }

  // POST /v1/patients/{zyndio_patient_id}/treatment-events
  if (req.method !== 'POST') {
    return errorResponse(405, 'method_not_allowed', 'Only POST is supported on /treatment-events.', requestId)
  }

  const idempotencyKey = req.headers.get('Idempotency-Key')?.trim() ?? ''
  if (!idempotencyKey || idempotencyKey.length > 255) {
    return errorResponse(
      400,
      'missing_idempotency_key',
      'Idempotency-Key header (1..255 chars) is required.',
      requestId,
    )
  }

  const rawText = await req.text()
  if (new TextEncoder().encode(rawText).byteLength > MAX_BODY_BYTES) {
    return errorResponse(413, 'payload_too_large', 'Request body exceeds maximum size.', requestId)
  }

  let body: Record<string, unknown>
  try {
    const parsed = JSON.parse(rawText)
    if (!parsed || typeof parsed !== 'object' || Array.isArray(parsed)) {
      return errorResponse(400, 'invalid_json', 'Request body must be a JSON object.', requestId)
    }
    body = parsed as Record<string, unknown>
  } catch {
    return errorResponse(400, 'invalid_json', 'Request body is not valid JSON.', requestId)
  }

  // Validate event_type
  const eventType = typeof body.event_type === 'string' ? body.event_type.trim() : ''
  if (!VALID_EVENT_TYPES.has(eventType)) {
    return errorResponse(
      400,
      'invalid_event_type',
      'event_type must be one of medication_start, dose_change, status_change, tolerability_note, clinician_change.',
      requestId,
    )
  }

  // Validate medication & formulation
  const rawMedication = typeof body.medication === 'string' ? body.medication.trim() : null
  if (rawMedication !== null && (rawMedication.length < 1 || rawMedication.length > 120)) {
    return errorResponse(
      400,
      'invalid_medication',
      'medication must be between 1 and 120 characters.',
      requestId,
    )
  }
  const rawFormulation = typeof body.formulation === 'string' ? body.formulation.trim() : ''
  if (rawFormulation.length > 120) {
    return errorResponse(
      400,
      'invalid_formulation',
      'formulation must be at most 120 characters.',
      requestId,
    )
  }

  // Validate dose (accepts either `dose: { value, unit }` or `dose_value` / `dose_unit`)
  let doseValue: number | null = null
  let doseUnit: string | null = null
  if (body.dose !== undefined && body.dose !== null) {
    if (typeof body.dose !== 'object' || Array.isArray(body.dose)) {
      return errorResponse(400, 'invalid_dose', 'dose must be an object with positive value and unit.', requestId)
    }
    const d = body.dose as Record<string, unknown>
    const val = typeof d.value === 'number' ? d.value : Number.NaN
    const unit = typeof d.unit === 'string' ? d.unit.trim() : ''
    if (!Number.isFinite(val) || val <= 0 || !unit || unit.length > 32) {
      return errorResponse(
        400,
        'invalid_dose',
        'dose.value must be a positive number and dose.unit must be 1..32 characters.',
        requestId,
      )
    }
    doseValue = val
    doseUnit = unit
  } else if (body.dose_value !== undefined && body.dose_value !== null) {
    const val = typeof body.dose_value === 'number' ? body.dose_value : Number.NaN
    const unit = typeof body.dose_unit === 'string' ? body.dose_unit.trim() : ''
    if (!Number.isFinite(val) || val <= 0 || !unit || unit.length > 32) {
      return errorResponse(
        400,
        'invalid_dose',
        'dose_value must be a positive number and dose_unit must be 1..32 characters.',
        requestId,
      )
    }
    doseValue = val
    doseUnit = unit
  }

  if (eventType === 'dose_change' && (doseValue === null || doseUnit === null)) {
    return errorResponse(
      400,
      'invalid_dose',
      'dose is required when event_type is dose_change.',
      requestId,
    )
  }

  // Validate status
  const rawStatus =
    typeof body.status === 'string'
      ? body.status.trim()
      : typeof body.status_value === 'string'
        ? body.status_value.trim()
        : null
  if (rawStatus !== null && !VALID_STATUSES.has(rawStatus)) {
    return errorResponse(
      400,
      'invalid_status',
      'status must be one of active, paused, discontinued, completed.',
      requestId,
    )
  }
  if (eventType === 'status_change' && rawStatus === null) {
    return errorResponse(
      400,
      'invalid_status',
      'status is required when event_type is status_change.',
      requestId,
    )
  }

  // Validate tolerability_note / note
  const rawNote =
    typeof body.tolerability_note === 'string'
      ? body.tolerability_note.trim()
      : typeof body.note === 'string'
        ? body.note.trim()
        : null
  if (rawNote !== null && (rawNote.length < 1 || rawNote.length > 500)) {
    return errorResponse(
      400,
      'invalid_tolerability_note',
      'tolerability_note must be between 1 and 500 characters.',
      requestId,
    )
  }
  if (eventType === 'tolerability_note' && !rawNote) {
    return errorResponse(
      400,
      'invalid_tolerability_note',
      'tolerability_note is required when event_type is tolerability_note.',
      requestId,
    )
  }

  // Effective timestamp
  const now = nowFn()
  let effectiveAt = now.toISOString()
  if (typeof body.effective_at === 'string' && body.effective_at.trim()) {
    const parsedDate = new Date(body.effective_at.trim())
    if (Number.isNaN(parsedDate.getTime())) {
      return errorResponse(400, 'invalid_effective_at', 'effective_at must be a valid ISO-8601 timestamp.', requestId)
    }
    effectiveAt = parsedDate.toISOString()
  }

  // Check idempotency key within 7-day replay window
  const existingEvent = await deps.store.findEventByIdempotencyKey(patient.org_id, idempotencyKey)
  if (existingEvent) {
    const createdAgeMs = now.getTime() - new Date(existingEvent.created_at).getTime()
    if (existingEvent.patient_id !== patient.id || createdAgeMs > SEVEN_DAYS_MS) {
      return errorResponse(
        409,
        'idempotency_key_conflict',
        'Idempotency-Key was already used for another patient or outside the 7-day replay window.',
        requestId,
      )
    }
    const existingCourse = await deps.store.findCourseById(existingEvent.course_id)
    return jsonOk(
      {
        replayed: true,
        course: existingCourse,
        event: existingEvent,
        request_id: requestId,
      },
      200,
      requestId,
    )
  }

  if (eventType === 'medication_start' && !rawMedication) {
    return errorResponse(
      400,
      'invalid_medication',
      'medication is required to start a treatment course.',
      requestId,
    )
  }

  let applied: PartnerWriteResult
  try {
    applied = await deps.store.applyPartnerWrite({
      orgId: patient.org_id,
      patientId: patient.id,
      eventType: eventType as TreatmentEventType,
      medication: rawMedication,
      formulation: rawFormulation,
      doseValue,
      doseUnit,
      status: rawStatus as TreatmentStatus | null,
      note: rawNote,
      effectiveAt,
      idempotencyKey,
      requestId,
    })
  } catch {
    return errorResponse(500, 'audit_failed', 'The treatment event was not stored because the audit record failed.', requestId)
  }

  return jsonOk(
    {
      replayed: applied.replayed,
      course: applied.course,
      event: applied.event,
      request_id: requestId,
    },
    applied.replayed ? 200 : 201,
    requestId,
  )
}
