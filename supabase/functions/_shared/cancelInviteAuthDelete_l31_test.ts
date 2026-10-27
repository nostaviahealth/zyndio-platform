import {
  assertEquals,
  assert,
} from 'https://deno.land/std@0.224.0/assert/mod.ts'
import {
  decideCancelAuthDelete,
  AUTH_DELETE_SKIP_LOOKUP_EVENT,
} from './cancelInviteAuthDelete.ts'

function chain(result: { data: unknown; error: unknown }) {
  const self: Record<string, unknown> = {}
  self.select = () => self
  self.eq = () => self
  self.maybeSingle = () => Promise.resolve(result)
  self.limit = () => Promise.resolve(result)
  self.not = () => self
  return self
}

Deno.test('Clara L31: patient lookup error skips delete and audits', async () => {
  const rpcCalls: Array<{ name: string; args: Record<string, unknown> }> = []
  let deleted = false
  const admin = {
    from: (table: string) => {
      if (table === 'patients') {
        return chain({ data: null, error: { message: 'patients boom' } })
      }
      return chain({ data: null, error: null })
    },
    rpc: (name: string, args: Record<string, unknown>) => {
      rpcCalls.push({ name, args })
      return Promise.resolve({ data: null, error: null })
    },
    auth: {
      admin: {
        deleteUser: () => {
          deleted = true
          return Promise.resolve({ data: null, error: null })
        },
      },
    },
  }

  const decision = await decideCancelAuthDelete(admin as never, {
    targetUserId: '00000000-0000-0000-0000-0000000a00f4',
    actorUserId: '00000000-0000-0000-0000-0000000a0001',
    orgId: '00000000-0000-0000-0000-00000000000a',
  })

  assertEquals(decision.kind, 'skip_lookup_error')
  assertEquals(deleted, false)
  assertEquals(rpcCalls.length, 1)
  assertEquals(rpcCalls[0].name, 'write_audit_log')
  assertEquals(rpcCalls[0].args.p_event_type, AUTH_DELETE_SKIP_LOOKUP_EVENT)
  assertEquals(AUTH_DELETE_SKIP_LOOKUP_EVENT, 'invite_cancel_auth_delete_skipped_lookup_error')
  assert((rpcCalls[0].args.p_metadata as { table?: string }).table === 'patients')
})

Deno.test('Clara L31: clear lookups still delete the auth user', async () => {
  let deleted = false
  const admin = {
    from: () => chain({ data: null, error: null }),
    rpc: () => Promise.resolve({ data: null, error: null }),
    auth: {
      admin: {
        deleteUser: () => {
          deleted = true
          return Promise.resolve({ data: null, error: null })
        },
      },
    },
  }
  const decision = await decideCancelAuthDelete(admin as never, {
    targetUserId: '00000000-0000-0000-0000-0000000a00f4',
    actorUserId: '00000000-0000-0000-0000-0000000a0001',
    orgId: '00000000-0000-0000-0000-00000000000a',
  })
  assertEquals(decision.kind, 'deleted')
  assert(deleted)
})
