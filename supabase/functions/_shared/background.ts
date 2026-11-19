// Runs work after the HTTP response is sent. On the hosted Edge Runtime,
// EdgeRuntime.waitUntil keeps the worker alive until the promise settles;
// elsewhere (local serve, tests) the promise simply runs detached. Errors are
// logged by class only, so a failed side task never surfaces to the caller.
declare const EdgeRuntime: { waitUntil(p: Promise<unknown>): void } | undefined

export function runInBackground(task: Promise<unknown>, label: string): void {
  const guarded = task.catch((err) => {
    console.error(`${label}: background task failed`, err instanceof Error ? err.name : 'unknown')
  })
  if (typeof EdgeRuntime !== 'undefined' && EdgeRuntime?.waitUntil) {
    EdgeRuntime.waitUntil(guarded)
  }
}
