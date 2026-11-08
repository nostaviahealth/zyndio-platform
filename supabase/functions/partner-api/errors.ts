// INT-01 conventions: one error shape for every failure,
//   {"error": {"code": "<stable code>", "message": "<human text>", "request_id": "req_..."}}
// Codes are part of the API contract (docs/PARTNER_API.md): add new ones,
// never rename or reuse one.
export const ERROR_STATUS = {
  invalid_request: 400,
  invalid_webhook_url: 400,
  idempotency_key_required: 400,
  unsupported_grant_type: 400,
  invalid_scope: 400,
  unauthorized: 401,
  invalid_client: 401,
  insufficient_scope: 403,
  not_found: 404,
  method_not_allowed: 405,
  patient_already_exists: 409,
  email_unavailable: 409,
  email_change_not_allowed: 409,
  patient_deactivated: 409,
  patient_already_active: 409,
  idempotency_key_in_use: 409,
  limit_reached: 409,
  payload_too_large: 413,
  unsupported_media_type: 415,
  idempotency_key_reused: 422,
  rate_limited: 429,
  internal_error: 500,
} as const

export type ErrorCode = keyof typeof ERROR_STATUS

export class ApiError extends Error {
  code: ErrorCode
  headers: Record<string, string>
  constructor(code: ErrorCode, message: string, headers: Record<string, string> = {}) {
    super(message)
    this.code = code
    this.headers = headers
  }
  get status(): number {
    return ERROR_STATUS[this.code]
  }
}

export function errorBody(code: ErrorCode, message: string, requestId: string) {
  return { error: { code, message, request_id: requestId } }
}
