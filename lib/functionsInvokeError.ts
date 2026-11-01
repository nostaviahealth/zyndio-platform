import { FunctionsHttpError } from '@supabase/supabase-js';

// TC-018 item 1 (L33, round 2): supabase.functions.invoke() returns
// { data: null, error } for any non-2xx response - the response body (where
// Edge Functions put { error, field? }, see supabase/functions/_shared/cors.ts
// jsonResponse) is never read unless callers go looking for it themselves.
// FunctionsHttpError wraps the raw Response in `.context` (see
// node_modules/@supabase/functions-js FunctionsClient.js); network/relay
// failures (FunctionsFetchError/FunctionsRelayError) have no such body and
// stay internal_error, same as a malformed or non-JSON body.
export async function mapFunctionsInvokeError(error: unknown): Promise<{ error: string; field?: string }> {
  if (error instanceof FunctionsHttpError && error.context instanceof Response) {
    try {
      const body = await error.context.json();
      if (body && typeof body === 'object' && typeof body.error === 'string') {
        return { error: body.error, field: typeof body.field === 'string' ? body.field : undefined };
      }
    } catch {
      // non-JSON body (e.g. a relay/gateway HTML error page) - fall through
    }
  }
  return { error: 'internal_error' };
}
