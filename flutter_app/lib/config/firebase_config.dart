import 'package:firebase_core/firebase_core.dart';

/// Whether Firebase has been initialised in this process.
///
/// Dev/CI builds have no `google-services.json` / `GoogleService-Info.plist`,
/// so `Firebase.initializeApp()` in main.dart never succeeds and `Firebase.apps`
/// stays empty. Code that touches `FirebaseMessaging.instance`
/// must check this first — those singletons throw if accessed before init.
bool get firebaseConfigured => Firebase.apps.isNotEmpty;
