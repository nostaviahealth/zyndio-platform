// TC-006: the emails Zyndio actually sends. Each renderer returns null for a
// payload it can't use, so the caller falls back to the logged stub instead
// of sending a broken email.
//
// APP-10 rule applies to email too: no health information, ever. A sign-in
// email carries the code, its expiry and a safety line; nothing about care,
// results or the clinic.

export interface RenderedEmail {
  subject: string
  text: string
  html: string
}

const BRAND = 'Zyndio'

function escapeHtml(s: string): string {
  return s.replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]!))
}

/** The 6-digit patient sign-in code (APP-01). */
export function renderLoginCodeEmail(params: { code: string; expiresInMinutes: number }): RenderedEmail | null {
  const { code, expiresInMinutes } = params
  if (!/^\d{6}$/.test(code) || !Number.isFinite(expiresInMinutes) || expiresInMinutes <= 0) return null
  const minutes = Math.round(expiresInMinutes)
  const spaced = `${code.slice(0, 3)} ${code.slice(3)}`
  const subject = `${code} is your ${BRAND} sign-in code`
  const text = [
    `Your ${BRAND} sign-in code is ${spaced}.`,
    '',
    `Enter it in the ${BRAND} app to sign in. It expires in ${minutes} minutes and works once.`,
    '',
    `If you didn't ask to sign in, you can ignore this email. Your account stays safe, and no one can sign in without this code.`,
    '',
    `${BRAND} will never ask you for this code by phone, text or email.`,
  ].join('\n')

  const html = `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="color-scheme" content="light only">
<title>${escapeHtml(subject)}</title>
</head>
<body style="margin:0;padding:0;background:#F6F7F9;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Inter,Roboto,Helvetica,Arial,sans-serif;color:#0B1220;">
<div style="display:none;max-height:0;overflow:hidden;">Your code expires in ${minutes} minutes.</div>
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background:#F6F7F9;padding:32px 16px;">
<tr><td align="center">
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="max-width:480px;background:#FFFFFF;border-radius:24px;padding:36px 32px;">
<tr><td style="font-size:14px;font-weight:700;letter-spacing:1.6px;color:#0B1220;">ZYNDIO</td></tr>
<tr><td style="padding-top:28px;font-size:24px;line-height:30px;font-weight:700;letter-spacing:-0.4px;">Your sign-in code</td></tr>
<tr><td style="padding-top:8px;font-size:15px;line-height:22px;color:#4A5365;">Enter this code in the ${BRAND} app to sign in.</td></tr>
<tr><td style="padding-top:24px;">
<div style="background:#F0F2F5;border-radius:16px;padding:20px 0;text-align:center;font-size:36px;line-height:40px;font-weight:700;letter-spacing:10px;color:#0B1220;font-variant-numeric:tabular-nums;">${escapeHtml(spaced)}</div>
</td></tr>
<tr><td style="padding-top:16px;font-size:14px;line-height:20px;color:#4A5365;">It expires in ${minutes} minutes and works once.</td></tr>
<tr><td style="padding-top:24px;border-bottom:1px solid #E6E9EE;"></td></tr>
<tr><td style="padding-top:20px;font-size:13px;line-height:19px;color:#626B7C;">If you didn't ask to sign in, you can ignore this email. No one can sign in without this code. ${BRAND} will never ask you for it by phone, text or email.</td></tr>
</table>
</td></tr>
</table>
</body>
</html>`
  return { subject, text, html }
}

/**
 * The email for a notification_outbox row, or null when this type has no
 * real template yet (those rows keep going to the logged stub).
 */
export function renderNotificationEmail(type: string, payload: Record<string, unknown>): RenderedEmail | null {
  switch (type) {
    case 'patient_login_code': {
      const code = typeof payload.token === 'string' ? payload.token : ''
      const minutes = typeof payload.expires_in_minutes === 'number' ? payload.expires_in_minutes : NaN
      return renderLoginCodeEmail({ code, expiresInMinutes: minutes })
    }
    default:
      return null
  }
}
