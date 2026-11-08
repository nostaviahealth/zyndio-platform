import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/health_repository.dart';
import 'wearable_daily_sync.dart';

enum DeviceHealthConnectResult {
  connected,
  denied,
  healthConnectNotInstalled,
  healthConnectNeedsUpdate,
  failed,
}

/// APP-07: connects the phone's own health store - Apple Health on iOS,
/// Health Connect on Android - entirely on the device (OS permission
/// prompts), then starts the 90-day backfill upload. There is no server-side
/// "connect" step for these: the old Connections screen called
/// `functions/v1/connect`, which does not exist.
abstract class DeviceHealthConnector {
  Future<DeviceHealthConnectResult> connect();
}

class HealthStoreConnector implements DeviceHealthConnector {
  HealthStoreConnector({HealthRepository? repository, WearableDailySync? sync})
      : _repository = repository ?? HealthRepository(),
        _sync = sync;

  final HealthRepository _repository;
  final WearableDailySync? _sync;

  @override
  Future<DeviceHealthConnectResult> connect() async {
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        final status = await _repository.getHealthConnectStatus();
        if (status == 'not_installed') {
          return DeviceHealthConnectResult.healthConnectNotInstalled;
        }
        if (status == 'needs_update') {
          return DeviceHealthConnectResult.healthConnectNeedsUpdate;
        }
      }
      final granted = await _repository.requestUnifiedPermissions();
      if (!granted) return DeviceHealthConnectResult.denied;
      await _repository.setLinked(true);
      // Backfill runs in the background; the screen doesn't wait for it.
      unawaited((_sync ?? WearableDailySync.instance).onConnected());
      return DeviceHealthConnectResult.connected;
    } catch (_) {
      return DeviceHealthConnectResult.failed;
    }
  }
}
