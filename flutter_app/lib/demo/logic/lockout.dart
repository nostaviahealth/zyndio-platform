/// Default (Henry, 23 Oct 2026; changeable if the client asks): 5 wrong
/// codes lock the account for 15 minutes.
class LockoutPolicy {
  LockoutPolicy({
    this.maxAttempts = 5,
    this.lockDuration = const Duration(minutes: 15),
  });

  final int maxAttempts;
  final Duration lockDuration;

  int _wrongAttempts = 0;
  DateTime? _lockedAt;

  /// Records a wrong code. Locks the account once [maxAttempts] is reached.
  void registerWrong(DateTime now) {
    if (isLocked(now)) return;
    _wrongAttempts += 1;
    if (_wrongAttempts >= maxAttempts) {
      _lockedAt = now;
    }
  }

  /// Whether the account is currently locked. Clears the lock (and resets
  /// the attempt count) once [lockDuration] has elapsed.
  bool isLocked(DateTime now) {
    final lockedAt = _lockedAt;
    if (lockedAt == null) return false;
    if (now.difference(lockedAt) >= lockDuration) {
      _lockedAt = null;
      _wrongAttempts = 0;
      return false;
    }
    return true;
  }

  /// Time remaining on the current lock, or [Duration.zero] if not locked.
  Duration remaining(DateTime now) {
    if (!isLocked(now)) return Duration.zero;
    final elapsed = now.difference(_lockedAt!);
    final remaining = lockDuration - elapsed;
    return remaining.isNegative ? Duration.zero : remaining;
  }

  void reset() {
    _wrongAttempts = 0;
    _lockedAt = null;
  }
}
