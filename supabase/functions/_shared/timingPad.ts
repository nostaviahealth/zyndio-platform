// PSU-ENUM: pads every branch of an enumeration-sensitive handler up to the
// same floor so a client measuring wall-clock time can't use latency to tell
// "email exists" from "email doesn't exist" apart, even though one branch
// does real work (createUser + token issue) and the other does much less
// (one notification insert). Not a substitute for identical response
// shape/status - both still have to match - this only closes the timing
// side channel.
export async function padTimingTo(startMs: number, floorMs = 250): Promise<void> {
  const elapsed = Date.now() - startMs
  const remaining = floorMs - elapsed
  if (remaining > 0) {
    await new Promise((resolve) => setTimeout(resolve, remaining))
  }
}
