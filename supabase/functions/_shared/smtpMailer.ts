// TC-006: real email delivery over SMTP, with no third-party dependency.
//
// Supabase Edge Functions block outbound ports 25 and 587, so this client
// speaks SMTP over implicit TLS only (port 465, "SMTPS"). Google Workspace,
// Zoho, Amazon SES, Brevo, Postmark, Resend and most providers offer 465;
// Microsoft 365 does not (587 only) and so cannot be used from a function.
//
// Configuration comes from function secrets, never from code:
//   SMTP_HOST      e.g. smtp.gmail.com
//   SMTP_PORT      465 (the default; anything else is refused)
//   SMTP_USERNAME  the SMTP login
//   SMTP_PASSWORD  the SMTP password / app password
//   SMTP_FROM      the From address, e.g. care@yourdomain.com
//   SMTP_FROM_NAME optional display name (default "Zyndio")
//
// When any required secret is missing, smtpConfigFromEnv() returns null and
// callers fall back to the logged stub, so local stacks and CI never try to
// reach a real mail server.

export interface SmtpConfig {
  host: string
  port: number
  username: string
  password: string
  from: string
  fromName: string
}

export interface MailMessage {
  to: string
  subject: string
  text: string
  html: string
}

/** A byte stream: Deno.TlsConn in production, a fake in tests. */
export interface SmtpConn {
  read(p: Uint8Array): Promise<number | null>
  write(p: Uint8Array): Promise<number>
  close(): void
}

export type SmtpConnect = (host: string, port: number) => Promise<SmtpConn>

interface EnvLike {
  get(key: string): string | undefined
}

export const SMTPS_PORT = 465
const SMTP_TIMEOUT_MS = 15_000

export class SmtpError extends Error {
  constructor(message: string, readonly code?: number) {
    super(message)
    this.name = 'SmtpError'
  }
}

const HEADER_UNSAFE = /[\r\n]/

/** Reads SMTP settings from secrets; null when unset or unusable. */
export function smtpConfigFromEnv(env: EnvLike): SmtpConfig | null {
  const host = env.get('SMTP_HOST')?.trim()
  const username = env.get('SMTP_USERNAME')?.trim()
  const password = env.get('SMTP_PASSWORD')
  const from = env.get('SMTP_FROM')?.trim()
  if (!host || !username || !password || !from) return null
  const portText = env.get('SMTP_PORT')?.trim()
  const port = portText ? Number(portText) : SMTPS_PORT
  if (port !== SMTPS_PORT) {
    // 25 and 587 are blocked from Edge Functions; plaintext ports would leak
    // sign-in codes. Refuse rather than silently fail every send.
    console.error('smtp: unsupported SMTP_PORT, only 465 (implicit TLS) is allowed')
    return null
  }
  const fromName = env.get('SMTP_FROM_NAME')?.trim() || 'Zyndio'
  if ([host, username, from, fromName].some((v) => HEADER_UNSAFE.test(v))) return null
  return { host, port, username, password, from, fromName }
}

/** Address must be a single plain mailbox: no display name, no CR/LF. */
export function isSafeAddress(address: string): boolean {
  return /^[^\s<>()",;:@]+@[^\s<>()",;:@]+\.[^\s<>()",;:@]+$/.test(address)
}

const textEncoder = new TextEncoder()
const textDecoder = new TextDecoder()

function base64(text: string): string {
  const bytes = textEncoder.encode(text)
  let binary = ''
  for (const b of bytes) binary += String.fromCharCode(b)
  return btoa(binary)
}

/** RFC 2047 encoded-word, only when the value is not plain ASCII. */
function encodeHeader(value: string): string {
  return /^[\x20-\x7e]*$/.test(value) ? value : `=?UTF-8?B?${base64(value)}?=`
}

/** Base64 body wrapped at 76 columns (RFC 2045). */
function base64Body(text: string): string {
  return base64(text).replace(/.{1,76}/g, '$&\r\n').trimEnd()
}

/**
 * Builds the full RFC 5322 message: multipart/alternative with a plain-text
 * and an HTML part, both base64 so long lines and non-ASCII are always safe.
 */
export function buildMimeMessage(
  cfg: SmtpConfig,
  msg: MailMessage,
  opts: { date: Date; messageId: string; boundary: string },
): string {
  const domain = cfg.from.split('@')[1] ?? 'localhost'
  const headers = [
    `From: ${encodeHeader(cfg.fromName)} <${cfg.from}>`,
    `To: <${msg.to}>`,
    `Subject: ${encodeHeader(msg.subject)}`,
    `Date: ${opts.date.toUTCString().replace('GMT', '+0000')}`,
    `Message-ID: <${opts.messageId}@${domain}>`,
    'MIME-Version: 1.0',
    `Content-Type: multipart/alternative; boundary="${opts.boundary}"`,
  ]
  const part = (type: string, body: string) =>
    [
      `--${opts.boundary}`,
      `Content-Type: ${type}; charset=UTF-8`,
      'Content-Transfer-Encoding: base64',
      '',
      base64Body(body),
    ].join('\r\n')
  return [
    headers.join('\r\n'),
    '',
    part('text/plain', msg.text),
    part('text/html', msg.html),
    `--${opts.boundary}--`,
    '',
  ].join('\r\n')
}

/** Line-buffered reader for multi-line SMTP replies ("250-..." then "250 ..."). */
class ReplyReader {
  private buffer = ''
  constructor(private readonly conn: SmtpConn) {}

  async read(): Promise<{ code: number; text: string }> {
    const lines: string[] = []
    while (true) {
      const newline = this.buffer.indexOf('\r\n')
      if (newline >= 0) {
        const line = this.buffer.slice(0, newline)
        this.buffer = this.buffer.slice(newline + 2)
        lines.push(line)
        if (/^\d{3} /.test(line) || /^\d{3}$/.test(line)) {
          return { code: Number(line.slice(0, 3)), text: lines.join('\n') }
        }
        if (!/^\d{3}-/.test(line)) throw new SmtpError('malformed SMTP reply')
        continue
      }
      const chunk = new Uint8Array(4096)
      const n = await this.conn.read(chunk)
      if (n === null) throw new SmtpError('SMTP connection closed')
      this.buffer += textDecoder.decode(chunk.subarray(0, n))
    }
  }
}

async function withTimeout<T>(promise: Promise<T>, ms: number): Promise<T> {
  let timer: ReturnType<typeof setTimeout> | undefined
  const timeout = new Promise<never>((_, reject) => {
    timer = setTimeout(() => reject(new SmtpError('SMTP timed out')), ms)
  })
  try {
    return await Promise.race([promise, timeout])
  } finally {
    clearTimeout(timer)
  }
}

const defaultConnect: SmtpConnect = (host, port) => Deno.connectTls({ hostname: host, port })

/**
 * Sends one message. Throws [SmtpError] on any refusal; the error message
 * carries the SMTP stage and code only, never the recipient or the body.
 */
export async function sendMail(
  cfg: SmtpConfig,
  msg: MailMessage,
  connect: SmtpConnect = defaultConnect,
  now: () => Date = () => new Date(),
): Promise<void> {
  if (!isSafeAddress(msg.to) || !isSafeAddress(cfg.from)) {
    throw new SmtpError('unsafe address')
  }
  const id = crypto.randomUUID()
  const message = buildMimeMessage(cfg, msg, {
    date: now(),
    messageId: id,
    boundary: `zyndio-${id}`,
  })

  const conn = await withTimeout(connect(cfg.host, cfg.port), SMTP_TIMEOUT_MS)
  const reader = new ReplyReader(conn)
  const send = async (line: string) => {
    await conn.write(textEncoder.encode(`${line}\r\n`))
  }
  const expect = async (stage: string, ok: number[]) => {
    const reply = await withTimeout(reader.read(), SMTP_TIMEOUT_MS)
    if (!ok.includes(reply.code)) throw new SmtpError(`SMTP ${stage} refused`, reply.code)
    return reply
  }

  try {
    await expect('greeting', [220])
    await send(`EHLO ${cfg.from.split('@')[1] ?? 'localhost'}`)
    await expect('EHLO', [250])
    await send(`AUTH PLAIN ${base64(`\u0000${cfg.username}\u0000${cfg.password}`)}`)
    await expect('AUTH', [235])
    await send(`MAIL FROM:<${cfg.from}>`)
    await expect('MAIL FROM', [250])
    await send(`RCPT TO:<${msg.to}>`)
    await expect('RCPT TO', [250, 251])
    await send('DATA')
    await expect('DATA', [354])
    // Dot-stuffing (RFC 5321 4.5.2): a line starting with "." gets one more.
    const body = message.replace(/\r\n\./g, '\r\n..')
    await conn.write(textEncoder.encode(`${body}\r\n.\r\n`))
    await expect('message', [250])
    await send('QUIT').catch(() => {})
  } finally {
    try {
      conn.close()
    } catch {
      // already closed
    }
  }
}
