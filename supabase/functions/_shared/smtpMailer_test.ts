import { assert, assertEquals, assertRejects, assertStringIncludes } from 'https://deno.land/std@0.168.0/testing/asserts.ts'
import { type SmtpConfig, SmtpError, buildMimeMessage, isSafeAddress, sendMail, smtpConfigFromEnv } from './smtpMailer.ts'

const env = (vars: Record<string, string>) => ({ get: (k: string) => vars[k] })
const base = {
  SMTP_HOST: 'smtp.example.test',
  SMTP_USERNAME: 'mailer@example.test',
  SMTP_PASSWORD: 'app-password',
  SMTP_FROM: 'care@example.test',
}
const cfg: SmtpConfig = {
  host: 'smtp.example.test',
  port: 465,
  username: 'mailer@example.test',
  password: 'app-password',
  from: 'care@example.test',
  fromName: 'Zyndio',
}
const msg = { to: 'jordan.rivera@example.test', subject: '123456 is your Zyndio sign-in code', text: 'Code 123 456\n.dot line', html: '<p>Code</p>' }

Deno.test('smtpConfigFromEnv: null until every required secret is set', () => {
  assertEquals(smtpConfigFromEnv(env({})), null)
  assertEquals(smtpConfigFromEnv(env({ ...base, SMTP_PASSWORD: '' })), null)
  assertEquals(smtpConfigFromEnv(env(base)), { ...cfg })
})

Deno.test('smtpConfigFromEnv: only implicit-TLS port 465 is accepted (25/587 are blocked on Edge Functions)', () => {
  assertEquals(smtpConfigFromEnv(env({ ...base, SMTP_PORT: '465' }))?.port, 465)
  assertEquals(smtpConfigFromEnv(env({ ...base, SMTP_PORT: '587' })), null)
  assertEquals(smtpConfigFromEnv(env({ ...base, SMTP_PORT: '25' })), null)
})

Deno.test('smtpConfigFromEnv: refuses header-injection in configured values', () => {
  assertEquals(smtpConfigFromEnv(env({ ...base, SMTP_FROM_NAME: 'Zyndio\r\nBcc: x@example.test' })), null)
})

Deno.test('isSafeAddress: plain mailboxes only', () => {
  assert(isSafeAddress('jordan.rivera@example.test'))
  assert(!isSafeAddress('Jordan <jordan@example.test>'))
  assert(!isSafeAddress('a@example.test\r\nRCPT TO:<b@example.test>'))
  assert(!isSafeAddress('no-at-sign'))
})

Deno.test('buildMimeMessage: multipart text+html, base64 bodies, encoded non-ASCII subject', () => {
  const mime = buildMimeMessage(cfg, { ...msg, subject: 'Votre code – 123456' }, {
    date: new Date('2026-11-17T10:00:00Z'),
    messageId: 'm1',
    boundary: 'b1',
  })
  assertStringIncludes(mime, 'From: Zyndio <care@example.test>')
  assertStringIncludes(mime, 'To: <jordan.rivera@example.test>')
  assertStringIncludes(mime, 'Subject: =?UTF-8?B?')
  assertStringIncludes(mime, 'Content-Type: multipart/alternative; boundary="b1"')
  assertStringIncludes(mime, 'Content-Type: text/plain; charset=UTF-8')
  assertStringIncludes(mime, 'Content-Type: text/html; charset=UTF-8')
  assertStringIncludes(mime, '--b1--')
  assert(mime.split('\r\n').every((l) => l.length <= 998), 'no line over the SMTP limit')
})

/** Scripted fake SMTPS server: replies per command, records what the client sent. */
function fakeServer(replies: Record<string, string>) {
  const written: string[] = []
  const queue: string[] = ['220 smtp.example.test ESMTP\r\n']
  let inData = false
  let closed = false
  const enc = new TextEncoder()
  const dec = new TextDecoder()
  const conn = {
    read(p: Uint8Array): Promise<number | null> {
      const next = queue.shift()
      if (next === undefined) return Promise.resolve(null)
      const bytes = enc.encode(next)
      p.set(bytes)
      return Promise.resolve(bytes.length)
    },
    write(p: Uint8Array): Promise<number> {
      const text = dec.decode(p)
      written.push(text)
      if (inData) {
        if (text.endsWith('\r\n.\r\n')) {
          inData = false
          queue.push(replies['.'] ?? '250 2.0.0 queued\r\n')
        }
      } else {
        const verb = text.split(/[ :\r]/)[0].toUpperCase()
        if (verb === 'DATA') inData = true
        queue.push(replies[verb] ?? ({
          EHLO: '250-smtp.example.test\r\n250-AUTH PLAIN LOGIN\r\n250 8BITMIME\r\n',
          AUTH: '235 2.7.0 Accepted\r\n',
          MAIL: '250 OK\r\n',
          RCPT: '250 OK\r\n',
          DATA: '354 Go ahead\r\n',
          QUIT: '221 Bye\r\n',
        } as Record<string, string>)[verb] ?? '500 unknown\r\n')
      }
      return Promise.resolve(p.length)
    },
    close() {
      closed = true
    },
  }
  return { conn, written, isClosed: () => closed }
}

Deno.test('sendMail: full SMTPS conversation, dot-stuffed body, connection closed', async () => {
  const server = fakeServer({})
  let target = ''
  await sendMail(cfg, msg, (host, port) => {
    target = `${host}:${port}`
    return Promise.resolve(server.conn)
  })
  assertEquals(target, 'smtp.example.test:465')
  const sent = server.written.join('')
  assertStringIncludes(sent, 'EHLO example.test\r\n')
  assertStringIncludes(sent, `AUTH PLAIN ${btoa('\u0000mailer@example.test\u0000app-password')}\r\n`)
  assertStringIncludes(sent, 'MAIL FROM:<care@example.test>\r\n')
  assertStringIncludes(sent, 'RCPT TO:<jordan.rivera@example.test>\r\n')
  assert(sent.includes('\r\n.\r\n'), 'message terminated with CRLF.CRLF')
  assert(server.isClosed())
})

Deno.test('sendMail: a refused login raises SmtpError with stage and code, never the password', async () => {
  const server = fakeServer({ AUTH: '535 5.7.8 Bad credentials\r\n' })
  const err = await assertRejects(() => sendMail(cfg, msg, () => Promise.resolve(server.conn)), SmtpError)
  assertEquals(err.message, 'SMTP AUTH refused')
  assertEquals(err.code, 535)
  assert(!err.message.includes('app-password'))
  assert(server.isClosed())
})

Deno.test('sendMail: a refused recipient fails before any message data is sent', async () => {
  const server = fakeServer({ RCPT: '550 5.1.1 No such user\r\n' })
  await assertRejects(() => sendMail(cfg, msg, () => Promise.resolve(server.conn)), SmtpError, 'SMTP RCPT TO refused')
  assert(!server.written.some((w) => w.startsWith('DATA')))
})

Deno.test('sendMail: refuses an unsafe recipient without connecting', async () => {
  let connected = false
  await assertRejects(
    () => sendMail(cfg, { ...msg, to: 'x@example.test\r\nRCPT TO:<y@example.test>' }, () => {
      connected = true
      return Promise.reject(new Error('should not connect'))
    }),
    SmtpError,
    'unsafe address',
  )
  assert(!connected)
})
