# Proactive Intelligence & Zero-Friction Engine
## Detailed Feature Documentation

Zyndio has been upgraded from a passive tracker to a proactive longevity partner. This document details the high-fidelity features implemented in the current release cycle.

---

### 1. Predictive Readiness Alerts (Adaptive Timing)
**The Problem**: Health apps usually fire morning alerts at a static time, which often misses the user's actual wake-up window.
**The Solution**: Zyndio now analyzes your 7-day rolling wake-up history from Apple Health/Health Connect. 
- **How it works**: The `NotificationScheduler` calculates your median wake-up time.
- **The Magic**: Instead of a generic 8:00 AM alarm, the app schedules your "Ready to Start" coaching insight to arrive precisely **15 minutes after you actually wake up**.
- **Benefit**: High engagement at the moment of highest intent.

### 2. AI-Personalized Coaching Anchors
**The Problem**: "One size fits all" notifications are ignored.
**The Solution**: Every anchor notification (Morning, Lunch, Evening) is the result of deep biometric analysis.
- **Implementation**: The AI engine looks at your current recovery score, cardiovascular strain, and sleep quality before generating the notification text.
- **The Experience**: If your HRV is low, your morning alert might focus on "Active Recovery"; if your strain is healthy, it might push you toward "Peak Performance."

### 3. Zero-Friction Task Auto-Completion
**The Problem**: "Protocol Fatigue" caused by manually checking off recurring healthy habits.
**The Solution**: An observational completion engine that marks tasks as done based on real-world actions.
- **Diet Trigger**: Scanning a meal with the AI Lens automatically identifies the meal type and marks all "Diet" tasks for that window as **Completed**.
- **Fitness Trigger**: Syncing a workout (>15 min) from a wearable immediately marks all "Fitness" tasks as **Completed**.
- **Feedback**: A high-fidelity in-app banner with haptic feedback confirms the autonomous completion: *"Diet Tasks Completed ✨ — Meal logged automatically."*

### 4. Deep Notification Sync & Persistence
**The Problem**: OS push notifications are ephemeral and easily dismissed.
**The Solution**: A unified sync architecture that bridges the gap between the OS lock screen and the app database.
- **Persistence**: Every AI-generated coaching insight is simultaneously persisted to the Supabase `notifications` table.
- **Inbox Integration**: Dismissed push notifications remain available in the in-app **Inbox** tab.
- **Activity History**: High-value events (post-workout recovery tips, snoozed actions) are logged to a narrative **Activity History** feed, creating a "story of your health day."

### 5. Interactive Lock-Screen Actions
**The Problem**: Opening the app to mark a task as done is too much friction.
**The Solution**: Apple-native and Android-native interactive action buttons.
- **✅ Done**: Instantly marks the associated protocol task as completed without leaving the lock screen.
- **⏰ Snooze**: Postpones the alert by 15 minutes, re-triggering the AI coaching text later.
- **Implementation**: Handled via `DarwinNotificationCategory` (iOS) and `AndroidNotificationAction` (Android).

### 6. Full Android Functional Parity
**The Optimization**: Ensuring the "insanely great" experience is consistent across platforms.
- **Android 13/14+ Compatibility**: Implemented `POST_NOTIFICATIONS` and `SCHEDULE_EXACT_ALARM` permissions.
- **Predictive Exercise Algorithm**: A dedicated Android engine that synthesizes "Workout" data from Heart Rate and Calories even if the Android wearable doesn't natively support training sessions.
- **Infrastructure**: Full Firebase Messaging setup with high-priority channels for Doze-mode delivery.

---

## Technical Stack Summary
- **State Management**: Riverpod (Reactive Progress Rings & Alert State)
- **Backend**: Supabase (Notification Persistence)
- **Local Engine**: Flutter Local Notifications (Exact Scheduled Alarms)
- **Biometric Source**: Apple Health (iOS) / Health Connect (Android)
- **Intelligence**: Custom AI Post-Processing for Adaptive Timing
