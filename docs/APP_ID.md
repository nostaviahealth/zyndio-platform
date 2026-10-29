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
| watchOS app (`ios/Watch.xcconfig`) | `com.zyndio.app.watchapp`, companion `com.zyndio.app` |
| watchOS target script (`ios/add_watch_target.rb`) | `com.zyndio.app.watchkitapp` |
| Runner `Info.plist` `CFBundleIdentifier` | `$(PRODUCT_BUNDLE_IDENTIFIER)` (follows the build setting) |
| App Group (Runner and BrandLiveActivity entitlements, pinned together) | `group.com.zyndio.app` |

Unchanged on purpose (not tied to the app ID; Apple team IDs and deep-link schemes are TC-021):

- Deep-link / auth callback schemes `com.zyndio.health://login-callback` (Android)
  and `zyndiohealth://callback` (Android and iOS).
- `packages/platform_wearables` keeps `com.zyndio.wearables`.
- macOS / Linux / Windows desktop placeholders (`com.example.*`) are not store targets.

Outside the repo, set by hand (not done in code):

1. Google Play Console: create the app with package `com.zyndio.app`.
2. Apple Developer: register App IDs `com.zyndio.app` and
   `com.zyndio.app.BrandLiveActivity` (plus the watch ID if the watch app ships),
   with the capabilities in the entitlements (Push, Sign in with Apple, HealthKit,
   App Groups), register App Group `group.com.zyndio.app` and attach it to both.
3. Firebase (if/when used): register the Android app `com.zyndio.app` and the iOS
   app `com.zyndio.app`, then add `google-services.json` /
   `GoogleService-Info.plist` through the secure build path (none are in the repo).
4. Google / Facebook sign-in consoles: the OAuth clients must list package
   `com.zyndio.app` (plus the release SHA-1 on Android) and bundle `com.zyndio.app`.
5. Hosted Supabase Auth: the redirect allow-list must include the mobile callback
   URLs above. Local `supabase/config.toml` has no mobile redirects today.
