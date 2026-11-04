/// <reference lib="deno.ns" />
import { assertEquals } from 'https://deno.land/std@0.168.0/testing/asserts.ts'
import {
  handleTreatmentEventsRequest,
  PatientRecord,
  TreatmentCourseRecord,
  TreatmentEventRecord,
  TreatmentStore,
} from './handler.ts'

const ORG_A = '00000000-0000-0000-0000-00000000000a'
const PATIENT_A1 = '00000000-0000-0000-0000-0000000a1001'
const PATIENT_A2 = '00000000-0000-0000-0000-0000000a1002'
const TOKEN = 'partner-secret-token-int04'

function createInMemoryStore(nowFn: () => Date): TreatmentStore & {
  courses: TreatmentCourseRecord[]
  events: TreatmentEventRecord[]
  audits: Array<Record<string, unknown>>
} {
  const patients = new Map<string, PatientRecord>([
    [PATIENT_A1, { id: PATIENT_A1, org_id: ORG_A }],
    [PATIENT_A2, { id: PATIENT_A2, org_id: ORG_A }],
  ])
  const courses: TreatmentCourseRecord[] = []
  const events: TreatmentEventRecord[] = []
  const audits: Array<Record<string, unknown>> = []
  let seq = 1

  return {
    courses,
    events,
    audits,
    findPatient(patientId: string) {
      return Promise.resolve(patients.get(patientId) ?? null)
    },
    findEventByIdempotencyKey(orgId: string, idempotencyKey: string) {
      const found = events.find(
        (e) => e.org_id === orgId && e.idempotency_key === idempotencyKey,
      )
      return Promise.resolve(found ?? null)
    },
    findLatestCourse(orgId: string, patientId: string) {
      const matching = courses.filter(
        (c) => c.org_id === orgId && c.patient_id === patientId,
      )
      return Promise.resolve(matching[matching.length - 1] ?? null)
    },
    findCourseById(courseId: string) {
      return Promise.resolve(courses.find((c) => c.id === courseId) ?? null)
    },
    createCourse(input) {
      const ts = nowFn().toISOString()
      const record: TreatmentCourseRecord = {
        ...input,
        id: `course-${seq++}`,
        created_at: ts,
        updated_at: ts,
      }
      courses.push(record)
      return Promise.resolve(record)
    },
    updateCourse(courseId, patch) {
      const idx = courses.findIndex((c) => c.id === courseId)
      if (idx < 0) throw new Error('course not found')
      const updated: TreatmentCourseRecord = {
        ...courses[idx],
        ...patch,
        updated_at: nowFn().toISOString(),
      }
      courses[idx] = updated
      return Promise.resolve(updated)
    },
    createEvent(input) {
      const record: TreatmentEventRecord = {
        ...input,
        id: `event-${seq++}`,
        created_at: nowFn().toISOString(),
      }
      events.push(record)
      return Promise.resolve(record)
    },
    listEvents(orgId, patientId) {
      const list = events
        .filter((e) => e.org_id === orgId && e.patient_id === patientId)
        .sort((a, b) => b.effective_at.localeCompare(a.effective_at))
      return Promise.resolve(list)
    },
    writeAuditLog(entry) {
      audits.push(entry)
      return Promise.resolve()
    },
  }
}

Deno.test('INT-04: rejects missing or invalid bearer token with standard error shape', async () => {
  const now = () => new Date('2026-11-05T10:00:00Z')
  const store = createInMemoryStore(now)
  const req = new Request(
    `https://example.test/v1/patients/${PATIENT_A1}/treatment-events`,
    {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Idempotency-Key': 'idem-1',
        'X-Request-Id': 'req-unauth-1',
      },
      body: JSON.stringify({ event_type: 'medication_start', medication: 'Semaglutide' }),
    },
  )

  const res = await handleTreatmentEventsRequest(req, {
    store,
    expectedBearerToken: TOKEN,
    now,
  })
  assertEquals(res.status, 401)
  const payload = await res.json()
  assertEquals(payload, {
    error: {
      code: 'unauthorized',
      message: 'Valid bearer token is required.',
      request_id: 'req-unauth-1',
    },
  })
})

Deno.test('INT-04: requires Idempotency-Key header on POST /treatment-events', async () => {
  const now = () => new Date('2026-11-05T10:00:00Z')
  const store = createInMemoryStore(now)
  const req = new Request(
    `https://example.test/v1/patients/${PATIENT_A1}/treatment-events`,
    {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${TOKEN}`,
        'Content-Type': 'application/json',
        'X-Request-Id': 'req-no-idem',
      },
      body: JSON.stringify({ event_type: 'medication_start', medication: 'Semaglutide' }),
    },
  )

  const res = await handleTreatmentEventsRequest(req, {
    store,
    expectedBearerToken: TOKEN,
    now,
  })
  assertEquals(res.status, 400)
  const payload = await res.json()
  assertEquals(payload.error.code, 'missing_idempotency_key')
  assertEquals(payload.error.request_id, 'req-no-idem')
})

Deno.test('INT-04: records medication_start, replays idempotently within 7 days, and rejects cross-patient key reuse', async () => {
  let currentNow = new Date('2026-11-05T10:00:00Z')
  const store = createInMemoryStore(() => currentNow)

  const makeReq = (patientId: string, idemKey: string, body: unknown) =>
    new Request(`https://example.test/v1/patients/${patientId}/treatment-events`, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${TOKEN}`,
        'Content-Type': 'application/json',
        'Idempotency-Key': idemKey,
        'X-Request-Id': 'req-idem-test',
      },
      body: JSON.stringify(body),
    })

  // 1. First POST creates course + event (201)
  const firstRes = await handleTreatmentEventsRequest(
    makeReq(PATIENT_A1, 'idem-start-100', {
      event_type: 'medication_start',
      medication: 'Tirzepatide',
      formulation: 'Auto-injector pen',
      dose: { value: 2.5, unit: 'mg weekly' },
      status: 'active',
      tolerability_note: 'Baseline start tolerated well',
      effective_at: '2026-11-01T08:00:00Z',
    }),
    { store, expectedBearerToken: TOKEN, now: () => currentNow },
  )
  assertEquals(firstRes.status, 201)
  const firstBody = await firstRes.json()
  assertEquals(firstBody.replayed, false)
  assertEquals(firstBody.course.medication, 'Tirzepatide')
  assertEquals(firstBody.course.current_dose_value, 2.5)
  assertEquals(firstBody.event.event_type, 'medication_start')
  assertEquals(store.events.length, 1)

  // 2. Replay 3 days later (< 7 days) returns 200 with replayed: true and does not duplicate
  currentNow = new Date('2026-11-08T10:00:00Z')
  const replayRes = await handleTreatmentEventsRequest(
    makeReq(PATIENT_A1, 'idem-start-100', {
      event_type: 'medication_start',
      medication: 'Tirzepatide',
    }),
    { store, expectedBearerToken: TOKEN, now: () => currentNow },
  )
  assertEquals(replayRes.status, 200)
  const replayBody = await replayRes.json()
  assertEquals(replayBody.replayed, true)
  assertEquals(replayBody.event.id, firstBody.event.id)
  assertEquals(store.events.length, 1)

  // 3. Reusing the same Idempotency-Key for a DIFFERENT patient returns 409
  const conflictRes = await handleTreatmentEventsRequest(
    makeReq(PATIENT_A2, 'idem-start-100', {
      event_type: 'medication_start',
      medication: 'Tirzepatide',
    }),
    { store, expectedBearerToken: TOKEN, now: () => currentNow },
  )
  assertEquals(conflictRes.status, 409)
  const conflictBody = await conflictRes.json()
  assertEquals(conflictBody.error.code, 'idempotency_key_conflict')

  // 4. Replaying after 8 days (> 7-day window) returns 409
  currentNow = new Date('2026-11-14T10:00:00Z')
  const expiredReplayRes = await handleTreatmentEventsRequest(
    makeReq(PATIENT_A1, 'idem-start-100', {
      event_type: 'medication_start',
      medication: 'Tirzepatide',
    }),
    { store, expectedBearerToken: TOKEN, now: () => currentNow },
  )
  assertEquals(expiredReplayRes.status, 409)
})

Deno.test('INT-04: validates event_type, dose, status, and tolerability_note and serves GET /treatment', async () => {
  const now = () => new Date('2026-11-05T10:00:00Z')
  const store = createInMemoryStore(now)

  const post = (idem: string, body: unknown) =>
    handleTreatmentEventsRequest(
      new Request(`https://example.test/v1/patients/${PATIENT_A1}/treatment-events`, {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${TOKEN}`,
          'Content-Type': 'application/json',
          'Idempotency-Key': idem,
        },
        body: JSON.stringify(body),
      }),
      { store, expectedBearerToken: TOKEN, now },
    )

  // Invalid event_type -> 400
  const badType = await post('k1', { event_type: 'suggest_dose' })
  assertEquals(badType.status, 400)
  assertEquals((await badType.json()).error.code, 'invalid_event_type')

  // Negative dose -> 400
  const badDose = await post('k2', {
    event_type: 'medication_start',
    medication: 'Semaglutide',
    dose: { value: -0.5, unit: 'mg' },
  })
  assertEquals(badDose.status, 400)
  assertEquals((await badDose.json()).error.code, 'invalid_dose')

  // Invalid status -> 400
  const badStatus = await post('k3', {
    event_type: 'medication_start',
    medication: 'Semaglutide',
    status: 'invalid_state',
  })
  assertEquals(badStatus.status, 400)
  assertEquals((await badStatus.json()).error.code, 'invalid_status')

  // Start course, then dose_change, then GET /treatment
  const startRes = await post('k4', {
    event_type: 'medication_start',
    medication: 'Semaglutide',
    dose: { value: 0.25, unit: 'mg weekly' },
    effective_at: '2026-10-01T00:00:00Z',
  })
  assertEquals(startRes.status, 201)

  const doseRes = await post('k5', {
    event_type: 'dose_change',
    dose: { value: 0.5, unit: 'mg weekly' },
    tolerability_note: 'Titrated to 0.5 mg weekly',
    effective_at: '2026-10-29T00:00:00Z',
  })
  assertEquals(doseRes.status, 201)

  const getRes = await handleTreatmentEventsRequest(
    new Request(`https://example.test/v1/patients/${PATIENT_A1}/treatment`, {
      method: 'GET',
      headers: { Authorization: `Bearer ${TOKEN}`, 'X-Request-Id': 'req-get-1' },
    }),
    { store, expectedBearerToken: TOKEN, now },
  )
  assertEquals(getRes.status, 200)
  const getBody = await getRes.json()
  assertEquals(getBody.patient_id, PATIENT_A1)
  assertEquals(getBody.course.medication, 'Semaglutide')
  assertEquals(getBody.course.current_dose_value, 0.5)
  assertEquals(getBody.events.length, 2)
  assertEquals(getBody.events[0].event_type, 'dose_change')
  assertEquals(getBody.events[1].event_type, 'medication_start')
})
