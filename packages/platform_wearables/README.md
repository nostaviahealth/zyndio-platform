# Zyndio Wearables SDK

[![pub package](https://img.shields.io/pub/v/platform_wearables.svg)](https://pub.dev/packages/platform_wearables)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

A unified Flutter SDK for aggregating health and fitness data from multiple wearable devices and platforms. Connect users to Apple HealthKit, Google Health Connect, Oura, Whoop, Fitbit, Withings, Polar, Garmin, Dexcom, and Ultrahuman with a single API.

## Features
- **Unified API**: Get sleep, workouts, heart rate, and HRV using the exact same Dart models, regardless of the underlying provider.
- **Secure OAuth**: Built-in support for securely authenticating users with cloud providers (Oura, Whoop) without leaking secrets.
- **On-Device Data**: Native integrations for Apple HealthKit (iOS) and Google Health Connect (Android).
- **Fully Typed**: Strong Dart types for all health data (`SleepSession`, `WorkoutSession`, `HeartRateSample`, etc.).

## Setup

### 1. Zyndio Backend Configuration
This SDK requires a Zyndio backend (running on Supabase) to securely manage API credentials and token exchanges for cloud providers like WHOOP and Oura. 
You must obtain an API key from your Zyndio provider dashboard.

### 2. Installation
Add `platform_wearables` to your `pubspec.yaml`:
```yaml
dependencies:
  platform_wearables: ^0.1.0
```

### 3. iOS Setup (HealthKit)
If you plan to use Apple HealthKit (`BrandProvider.healthkit`), you must update your iOS app's `Info.plist`:
```xml
<key>NSHealthShareUsageDescription</key>
<string>We need access to your health data to provide personalized insights.</string>
<key>NSHealthUpdateUsageDescription</key>
<string>We need permission to save health data to Apple Health.</string>
```
You must also enable the "HealthKit" capability in Xcode.

### 4. Deep Linking Setup (Cloud Providers)
For cloud providers (Oura, Whoop) to redirect back to your app after authentication, you must register a custom URL scheme (e.g., `zyndiohealth://callback`).

## Usage

### Initialization
Initialize the SDK when your app starts:

```dart
import 'package:platform_wearables/platform_wearables.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Zyndio.init(
    apiKey: '<your-api-key>', // Your Zyndio API Key
    userId: 'user_123',          // Your app's internal user ID
    baseUrl: 'https://your-zyndio-backend.supabase.co/functions/v1'
  );

  runApp(MyApp());
}
```

### Connecting a Provider
To authenticate a user with a specific provider, call `connect`. This will automatically open a secure browser window for OAuth providers, or request native permissions for on-device providers.

```dart
try {
  await Zyndio.connect(
    BrandProvider.whoop, 
    redirectUri: 'zyndiohealth://callback'
  );
  print('Successfully connected to WHOOP!');
} catch (e) {
  print('Failed to connect: $e');
}
```

### Fetching Data
Once connected, you can fetch unified data using the same API regardless of the provider:

```dart
// Fetch the last 7 days of sleep data
final sleepSessions = await Zyndio.getSleep(
  startDate: DateTime.now().subtract(const Duration(days: 7)),
  endDate: DateTime.now(),
);

for (var session in sleepSessions) {
  print('Sleep Duration: ${session.durationSeconds} seconds');
  print('Sleep Score: ${session.score}');
}
```

## Available Data Types
- `getSleep()` returns `List<SleepSession>`
- `getHeartRate()` returns `List<HeartRateSample>`
- `getActivity()` returns `List<ActivitySummary>`
- `getWorkouts()` returns `List<WorkoutSession>`
- `getHrv()` returns `List<HrvReading>`

## Support
For enterprise support or access to the Zyndio unified backend infrastructure, please visit [zyndio.example](https://www.zyndio.example).
