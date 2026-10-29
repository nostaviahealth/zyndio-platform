# App ID (TC-020)

The store app ID is **`com.zyndio.app`** on both stores. Google Play never lets a
package name change after the first upload, so this is pinned by
`scripts/check-app-id.sh`, which runs in CI (`secrets` job, every PR).

| Where | ID |
|---|---|
| Android `applicationId` and `namespace` (`flutter_app/android/app/build.gradle`) | `com.zyndio.app` |
| Android `MainActivity` (`kotlin/com/zyndio/app/`) | package `com.zyndio.app` |
| iOS Runner app (Debug, Release, Profile) | `com.zyndio.app` |
| iOS RunnerTests | `com.zyndio.app.RunnerTests` |
| iOS Live Activity extension | `com.zyndio.app.BrandLiveActivity` |
| watchOS app (`ios/Watch.xcconfig` and `ios/add_watch_target.rb`, one value, TC-021) | `com.zyndio.app.watchkitapp`, companion `com.zyndio.app` |
| Runner `Info.plist` `CFBundleIdentifier` | `$(PRODUCT_BUNDLE_IDENTIFIER)` (follows the build setting) |

Unchanged on purpose (not tied to the app ID):

- App Group `group.com.zyndio.health` (Runner and BrandLiveActivity entitlements).
- Deep-link / auth callback schemes `com.zyndio.health://login-callback` and
  `zyndiohealth://callback`, declared on both Android and iOS (TC-021; the check
  fails if the two platforms' scheme sets differ, ignoring the Google / Facebook
  sign-in SDK schemes).
- `packages/platform_wearables` keeps `com.zyndio.wearables`.
- macOS / Linux / Windows desktop placeholders (`com.example.*`) are not store targets.

## Apple team ID (TC-021)

`DEVELOPMENT_TEAM` is set in one place, `flutter_app/ios/Flutter/Team.xcconfig`,
which is the project-level base configuration (all targets inherit it) and is
included by `ios/Watch.xcconfig`. It stays empty until the Zyndio Apple team ID
is confirmed. `scripts/check-app-id.sh` fails on any team ID hard-coded anywhere
else (project file, xcconfig, Ruby script); `scripts/test-check-app-id.sh` proves
the check catches each regression.

Outside the repo, set by hand (not done in code):

1. Google Play Console: create the app with package `com.zyndio.app`.
2. Apple Developer: register App IDs `com.zyndio.app` and
   `com.zyndio.app.BrandLiveActivity` (plus the watch ID if the watch app ships),
   with the capabilities in the entitlements (Push, Sign in with Apple, HealthKit,
   App Groups), and attach App Group `group.com.zyndio.health` to both.
3. Firebase (if/when used): register the Android app `com.zyndio.app` and the iOS
   app `com.zyndio.app`, then add `google-services.json` /
   `GoogleService-Info.plist` through the secure build path (none are in the repo).
4. Google / Facebook sign-in consoles: the OAuth clients must list package
   `com.zyndio.app` (plus the release SHA-1 on Android) and bundle `com.zyndio.app`.
5. Hosted Supabase Auth: the redirect allow-list must include the mobile callback
   URLs above. Local `supabase/config.toml` has no mobile redirects today.
