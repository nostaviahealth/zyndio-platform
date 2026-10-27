// TC-012: telehealth connector interface + fake adapter (test fixtures only).
// Matching redeem/bind RPCs live in SQL (20261027181000). Clara APPROVED
// docs/RECORD_MATCHING.md. This module locates fixtures for the code-request
// path and records patient-message / notice outbox rows.
// Live vendor API is phase 2 (TELEHEALTH_ADAPTER=live refuses without allow).

export type LocateResult =
  | { kind: 'none' }
  | { kind: 'one'; telehealthPatientId: string }
  | { kind: 'ambiguous' }

export type LinkedSummary = {
  telehealthPatientId: string
  displayName: string
  clinicLabel: string
}

export type TelehealthMessage = {
  telehealthPatientId: string
  body: string
  at: string
}

export interface TelehealthConnector {
  locateForCodeRequest(input: {
    appUserId: string
    normalisedEmail: string
  }): Promise<LocateResult>

  sendPatientMessage(input: {
    telehealthPatientId: string
    body: string
  }): Promise<void>

  fetchLinkedSummary?(telehealthPatientId: string): Promise<LinkedSummary | null>
}

/** Seeded fictional fixtures (Clara TEST_PLAN_PATIENT_SIGNUP §0.3). */
export const FAKE_TELEHEALTH_FIXTURES: ReadonlyArray<{
  telehealthPatientId: string
  normalisedEmail: string
  displayName: string
  clinicLabel: string
}> = [
  {
    telehealthPatientId: 'th_test_jr_001',
    normalisedEmail: 'jordan.rivera@example.com',
    displayName: 'Jordan Rivera',
    clinicLabel: 'Brightway Weight Care',
  },
  {
    telehealthPatientId: 'th_test_ac_002',
    normalisedEmail: 'avery.chen@example.com',
    displayName: 'Avery Chen',
    clinicLabel: 'Brightway Weight Care',
  },
]

export class FakeTelehealthAdapter implements TelehealthConnector {
  readonly messages: TelehealthMessage[] = []
  private readonly byEmail: Map<string, typeof FAKE_TELEHEALTH_FIXTURES[number][]>

  constructor(
    fixtures: ReadonlyArray<typeof FAKE_TELEHEALTH_FIXTURES[number]> = FAKE_TELEHEALTH_FIXTURES,
  ) {
    this.byEmail = new Map()
    for (const f of fixtures) {
      const list = this.byEmail.get(f.normalisedEmail) ?? []
      list.push(f)
      this.byEmail.set(f.normalisedEmail, list)
    }
  }

  async locateForCodeRequest(input: {
    appUserId: string
    normalisedEmail: string
  }): Promise<LocateResult> {
    const hits = this.byEmail.get(input.normalisedEmail) ?? []
    if (hits.length === 0) return { kind: 'none' }
    if (hits.length === 1) {
      return { kind: 'one', telehealthPatientId: hits[0].telehealthPatientId }
    }
    return { kind: 'ambiguous' }
  }

  async sendPatientMessage(input: {
    telehealthPatientId: string
    body: string
  }): Promise<void> {
    this.messages.push({
      telehealthPatientId: input.telehealthPatientId,
      body: input.body,
      at: new Date().toISOString(),
    })
  }

  async fetchLinkedSummary(telehealthPatientId: string): Promise<LinkedSummary | null> {
    const hit = FAKE_TELEHEALTH_FIXTURES.find((f) => f.telehealthPatientId === telehealthPatientId)
    if (!hit) return null
    return {
      telehealthPatientId: hit.telehealthPatientId,
      displayName: hit.displayName,
      clinicLabel: hit.clinicLabel,
    }
  }
}

/** Factory: launch default is fake. Live refuses without explicit allow. */
export function createTelehealthConnector(env: {
  get(name: string): string | undefined
} = Deno.env): TelehealthConnector {
  const mode = (env.get('TELEHEALTH_ADAPTER') ?? 'fake').toLowerCase()
  if (mode === 'fake' || mode === '' || mode === 'test') {
    return new FakeTelehealthAdapter()
  }
  if (mode === 'live') {
    const allow = env.get('TELEHEALTH_LIVE_ALLOW')
    if (allow !== '1') {
      throw new Error('TELEHEALTH_ADAPTER=live refused: set TELEHEALTH_LIVE_ALLOW=1 only with Brett credentials (phase 2)')
    }
    throw new Error('LiveTelehealthAdapter not implemented (phase 2)')
  }
  throw new Error(`Unknown TELEHEALTH_ADAPTER=${mode}`)
}
