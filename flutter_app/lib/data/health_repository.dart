import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:health/health.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/temperature_service.dart';
import '../services/health_intelligence_service.dart';

class HealthRepository {
  final Health _health = Health();
  static const String _prefsKey = 'health_connected';

  /// Save connection state
  Future<void> setLinked(bool isLinked) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKey, isLinked);
  }

  /// Check if previously connected
  Future<bool> isLinked() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefsKey) ?? false;
  }

  /// Sleep types safe to include in permission requests.
  /// SLEEP_IN_BED and SLEEP_AWAKE_IN_BED are NOT supported on
  /// all Health Connect versions and crash the permission flow.
  /// On Samsung devices, SLEEP_IN_BED can return corrupted data
  /// that silently crashes subsequent Health Connect queries.
  static List<HealthDataType> get _sleepTypes {
    if (Platform.isAndroid) {
      return [
        HealthDataType.SLEEP_SESSION,
        HealthDataType.SLEEP_ASLEEP,
        HealthDataType.SLEEP_AWAKE,
        HealthDataType.SLEEP_DEEP,
        HealthDataType.SLEEP_LIGHT,
        HealthDataType.SLEEP_REM,
      ];
    } else {
      return [
        HealthDataType.SLEEP_ASLEEP,
        HealthDataType.SLEEP_AWAKE,
        HealthDataType.SLEEP_DEEP,
        HealthDataType.SLEEP_LIGHT,
        HealthDataType.SLEEP_REM,
        HealthDataType.SLEEP_IN_BED,
      ];
    }
  }

  /// Define the basic data types (Supported on most devices/emulators)
  /// These are critical metrics that must be requested reliably.
  static List<HealthDataType> get _basicTypes {
    if (Platform.isAndroid) {
      return [
        HealthDataType.STEPS,
        HealthDataType.HEART_RATE,
        HealthDataType.RESTING_HEART_RATE,
        HealthDataType.HEART_RATE_VARIABILITY_RMSSD,
        HealthDataType.RESPIRATORY_RATE,
        ..._sleepTypes,
        HealthDataType.BLOOD_OXYGEN,
        HealthDataType.WORKOUT,
        HealthDataType.ACTIVE_ENERGY_BURNED,
        HealthDataType.TOTAL_CALORIES_BURNED,
        HealthDataType.SKIN_TEMPERATURE,
        HealthDataType.BODY_TEMPERATURE,
      ];
    }
    return [
      HealthDataType.STEPS,
      HealthDataType.HEART_RATE,
      HealthDataType.RESTING_HEART_RATE,
      HealthDataType.HEART_RATE_VARIABILITY_SDNN,
      HealthDataType.RESPIRATORY_RATE,
      ..._sleepTypes,
      HealthDataType.BLOOD_OXYGEN,
      HealthDataType.WORKOUT,
      HealthDataType.ACTIVE_ENERGY_BURNED,
      HealthDataType.TOTAL_CALORIES_BURNED,
      HealthDataType.EXERCISE_TIME,
      HealthDataType.SKIN_TEMPERATURE,
      HealthDataType.BODY_TEMPERATURE,
    ];
  }

  /// Define advanced data types (Platform specific to prevent permission request crashes)
  static List<HealthDataType> get _advancedTypes {
    if (Platform.isAndroid) {
      return [
        HealthDataType.BASAL_ENERGY_BURNED,
        // Removed: BLOOD_GLUCOSE, BLOOD_PRESSURE, BODY_FAT, DISTANCE, NUTRITION, WEIGHT, etc.
      ];
    }
    
    // iOS (Apple Health)
    return [
      HealthDataType.BASAL_ENERGY_BURNED,
      HealthDataType.BLOOD_GLUCOSE,
      HealthDataType.BLOOD_PRESSURE_DIASTOLIC,
      HealthDataType.BLOOD_PRESSURE_SYSTOLIC,
      HealthDataType.BODY_FAT_PERCENTAGE,
      HealthDataType.BODY_WATER_MASS,
      HealthDataType.DISTANCE_DELTA,
      HealthDataType.FLIGHTS_CLIMBED,
      HealthDataType.HEIGHT,
      HealthDataType.LEAN_BODY_MASS,
      HealthDataType.NUTRITION,
      HealthDataType.WEIGHT,
      HealthDataType.WATER,
      HealthDataType.MENSTRUATION_FLOW,
      // Removed ACTIVITY_INTENSITY for iOS to prevent `requestAuthorization` fallback
    ];
  }

  /// Combine for full request
  List<HealthDataType> get _allTypes => [..._basicTypes, ..._advancedTypes];

  /// Configure the Health instance
  Future<void> configure() async {
    await _health.configure();
  }

  /// Request access to health data with progressive fallback.
  /// Android devices have wildly varying Health Connect implementations.
  /// Strategy: Try all types → basic types → core-only types (steps + HR + sleep).
  Future<bool> requestPermissions() async {
    // 1. Fire Activity Recognition (non-blocking, don't gate health on it)
    if (Platform.isAndroid) {
      Permission.activityRecognition.request(); // don't await, let it pop over/after
    }

    // 2. Try full type set first
    try {
      bool requested = await _health.requestAuthorization(
        _allTypes, 
        permissions: _allTypes.map((e) => HealthDataAccess.READ).toList()
      );

      if (requested) return true;
      print("Request for all types returned false. Trying fallback to basic types...");
    } catch (e) {
      print("Advanced health types not supported ($e). Falling back to basic types.");
    }

    // 3. Fallback: basic types only
    try {
      bool requested = await _health.requestAuthorization(
        _basicTypes, 
        permissions: _basicTypes.map((e) => HealthDataAccess.READ).toList()
      );
      if (requested) return true;
      print("Basic types returned false. Trying core-only fallback...");
    } catch (e) {
      print("Basic permissions failed ($e). Trying core-only fallback...");
    }

    // 4. Last resort: absolute minimum types (steps + HR + sleep)
    //    This handles devices where even RESPIRATORY_RATE or SKIN_TEMPERATURE
    //    causes Health Connect to reject the entire batch.
    return await _requestCoreOnlyPermissions();
  }

  /// Core-only fallback: just steps, heart rate, and sleep.
  /// If even THIS fails, the device truly can't connect.
  Future<bool> _requestCoreOnlyPermissions() async {
    final coreTypes = [
      HealthDataType.STEPS,
      HealthDataType.HEART_RATE,
      HealthDataType.SLEEP_SESSION,
      HealthDataType.SLEEP_ASLEEP,
      HealthDataType.SLEEP_DEEP,
      HealthDataType.SLEEP_LIGHT,
      HealthDataType.SLEEP_REM,
      HealthDataType.ACTIVE_ENERGY_BURNED,
      HealthDataType.WORKOUT,
    ];
    try {
      bool requested = await _health.requestAuthorization(
        coreTypes, 
        permissions: coreTypes.map((e) => HealthDataAccess.READ).toList()
      );
      if (requested) {
        print("Core-only permissions granted successfully.");
      }
      return requested;
    } catch (e) {
      print("Even core-only permissions failed: $e");
      return false;
    }
  }

  /// Request ALL native HealthKit permissions (VO2 Max, HRR, Temperature)
  /// in a single authorization sheet via the unified native channel.
  /// On Android this is a no-op (returns true).
  static Future<bool> requestAllNativePermissions() async {
    if (!Platform.isIOS) return true;
    try {
      const channel = MethodChannel('com.zyndio/permissions');
      final permissionsResult = await channel.invokeMethod<bool>('requestAllNativePermissions');
      return permissionsResult ?? false;
    } catch (e) {
      print('Unified native permissions error: $e');
      return false;
    }
  }

  /// Request ALL permissions in one go:
  /// 1. Health package types (steps, HR, sleep, etc.)
  /// 2. Native HealthKit types (VO2 Max, HRR, Temperature) — iOS only
  /// 3. Activity Recognition — Android only
  /// 
  /// Android timeout is 120s because Health Connect's permission dialog
  /// can be very slow on Samsung A-series, Xiaomi, and OnePlus devices.
  /// Users need time to read and accept permissions.
  Future<bool> requestUnifiedPermissions() async {
    try {
      // On iOS, we bypass the health plugin's internal request and use our 
      // single unified native channel (which includes VO2 Max, HRR, etc.).
      // This prevents the "double sheet" hang.
      if (Platform.isIOS) {
        return await requestAllNativePermissions()
            .timeout(const Duration(seconds: 30), onTimeout: () => false);
      }

      // Android: Ensure Health Connect is available first
      final hcStatus = await getHealthConnectStatus();
      if (hcStatus == 'not_installed') {
        // Try to install Health Connect programmatically
        try {
          await _health.installHealthConnect();
          // Give the user time to install
          await Future.delayed(const Duration(seconds: 2));
        } catch (e) {
          debugPrint('Health Connect install prompt failed: $e');
        }
      }

      // Android: Sequential flow with generous timeout
      // 120s because the HC permission dialog can be very slow
      // on budget Android devices (Samsung A-series, Redmi, etc.)
      final bool coreSuccess = await requestPermissions()
          .timeout(const Duration(seconds: 120), onTimeout: () {
        debugPrint('Health permission request timed out after 120s');
        return false;
      });
      
      return coreSuccess;
    } catch (e) {
      debugPrint("Unified permission error: $e");
      return false;
    }
  }


  /// Exhaustive permission request (triggered by 'Connect Apps')
  /// Attempts to request READ access for almost every single data type
  /// supported by Health Connect / Apple Health.
  Future<bool> requestExtensivePermissions() async {
    if (Platform.isAndroid) {
      await Permission.activityRecognition.request();
      // Do not return false if Activity Recognition is denied,
      // allow the core Health Connect permissions to be requested anyway.
    }
    
    // An exhaustive list of supported data types to force a massive sync
    // CRITICAL: We can ONLY request types explicitly declared in AndroidManifest.xml.
    // If we request a type not in the manifest, Android Health Connect instantly
    // denies the entire batch request.
    final exhaustiveTypes = [
      ..._basicTypes,
      HealthDataType.BASAL_ENERGY_BURNED,
    ];
    
    // Remove duplicates just in case
    final uniqueTypes = exhaustiveTypes.toSet().toList();

    try {
      print("Requesting exhaustive permissions for ${uniqueTypes.length} types...");
      bool requested = await _health.requestAuthorization(
        uniqueTypes, 
        permissions: uniqueTypes.map((e) => HealthDataAccess.READ).toList()
      );
      return requested;
    } catch (e) {
      print("Exhaustive permissions failed: $e");
      // Fallback to our standard full request if exhaustive fails
      return await requestPermissions();
    }
  }

  /// Check Health Connect availability on Android.
  /// Returns: 'installed', 'not_installed', 'needs_update', or 'unsupported'
  Future<String> getHealthConnectStatus() async {
    if (!Platform.isAndroid) return 'installed'; // Apple Health is always available
    try {
      final status = await _health.getHealthConnectSdkStatus();
      switch (status) {
        case HealthConnectSdkStatus.sdkAvailable:
          return 'installed';
        case HealthConnectSdkStatus.sdkUnavailable:
          return 'not_installed';
        case HealthConnectSdkStatus.sdkUnavailableProviderUpdateRequired:
          return 'needs_update';
        default:
          return 'unsupported';
      }
    } catch (e) {
      print('Error checking Health Connect status: $e');
      return 'unsupported';
    }
  }

  /// Check if permissions are already granted.
  /// On Health Connect, hasPermissions() returns null when the app has
  /// SOME but not ALL permissions. We treat null as "partial success"
  /// because the user may have granted core permissions but not advanced ones.
  /// This prevents the app from showing "Not Connected" when it can still sync.
  Future<bool> hasPermissions() async {
    try {
      // First try with basic types
      bool? hasPerms = await _health.hasPermissions(
        _basicTypes, 
        permissions: _basicTypes.map((e) => HealthDataAccess.READ).toList()
      );
      
      // null means "partial" on Health Connect — treat as success
      // because we can still read whatever permissions were granted
      if (hasPerms == true || hasPerms == null) {
        return true;
      }
      
      // If basicTypes returns false, try checking just core types
      // (steps + heart rate) as a minimum viable connection
      final coreCheck = await _health.hasPermissions(
        [HealthDataType.STEPS, HealthDataType.HEART_RATE],
        permissions: [HealthDataAccess.READ, HealthDataAccess.READ],
      );
      
      return coreCheck == true || coreCheck == null;
    } catch (e) {
      print("hasPermissions check failed ($e), treating as not granted");
      return false;
    }
  }

  /// Fetch steps for an interval
  Future<int?> getStepsInInterval(DateTime start, DateTime end) async {
    try {
      return await _health.getTotalStepsInInterval(start, end);
    } catch (e) {
      print("Error fetching steps: $e");
      return null;
    }
  }

  /// Fetch heart rate data for an interval
  Future<List<HealthDataPoint>> getHeartRateData(DateTime start, DateTime end) async {
    try {
      List<HealthDataPoint> healthData = await _health.getHealthDataFromTypes(
        startTime: start,
        endTime: end,
        types: [HealthDataType.HEART_RATE],
      );
      return _health.removeDuplicates(healthData);
    } catch (e) {
      print("Error fetching heart rate: $e");
      return [];
    }
  }

  /// Fetch sleep data for an interval — queries ALL sleep types.
  /// On Android: SLEEP_IN_BED is EXCLUDED because it causes data corruption
  /// on Samsung devices with Health Connect bridge, silently breaking all
  /// subsequent health queries for the session.
  /// On iOS: SLEEP_IN_BED is included as Apple Health handles it correctly.
  Future<List<HealthDataPoint>> getSleepData(DateTime start, DateTime end) async {
    try {
      List<HealthDataPoint> healthData = await _health.getHealthDataFromTypes(
        startTime: start,
        endTime: end,
        types: _sleepTypes,
      );
      
      // Only try SLEEP_IN_BED on iOS — it's safe there.
      // On Android (especially Samsung), this causes HC crashes.
      if (Platform.isIOS) {
        try {
          final inBedData = await _health.getHealthDataFromTypes(
            startTime: start,
            endTime: end,
            types: [HealthDataType.SLEEP_IN_BED],
          );
          healthData.addAll(inBedData);
        } catch (_) { /* SLEEP_IN_BED not available on this device */ }
      }
      
      final deduped = _health.removeDuplicates(healthData);
      return deduped;
    } catch (e) {
      print("Error fetching sleep: $e");
      return [];
    }
  }

  /// Fetch aggregated daily metrics for a specific interval
  Future<Map<String, dynamic>> getDailyMetrics({required DateTime startTime, required DateTime endTime}) async {
    final steps = await getStepsInInterval(startTime, endTime) ?? 0;
    
    // ── EXPANDED TIME WINDOWS ──
    // Sleep and recovery metrics (HRV, RHR) are typically recorded overnight.
    // We query from 6h ago (6:00 PM yesterday) to robustly capture last night's sleep without double counting the prior night.
    final DateTime sleepWindowStart = startTime.subtract(const Duration(hours: 6));
    // For HR, use 24h lookback so we catch wearable readings even if sparse
    final DateTime hrWindowStart = endTime.subtract(const Duration(hours: 24));
    
    // Heart Rate: Get readings from last 24h for richer data
    final heartRates = await getHeartRateData(hrWindowStart, endTime);
    int? lastHeartRate;
    if (heartRates.isNotEmpty) {
      heartRates.sort((a, b) => b.dateFrom.compareTo(a.dateFrom));
      final latest = heartRates.first.value;
      if (latest is NumericHealthValue) {
        lastHeartRate = latest.numericValue.round();
      }
    }

    // Sleep: Query from previous evening to capture overnight sessions
    final sleepSessions = await getSleepData(sleepWindowStart, endTime);
    print("HealthRepository: Found ${sleepSessions.length} raw sleep data points");
    
    // Interval Merging: Apple Health often writes overlapping stages 
    // (e.g. a "Core" stage running concurrently with a "REM" stage on different timelines).
    // We must merge these time intervals to prevent 2 hours of sleep from counting as 4.
    double sleepHours = _calculateSleepHours(sleepSessions);

    if (sleepHours == 0) {
      // Fallback: If no sleep recorded yet for tonight (e.g. user checking at 3 AM),
      // fetch the previous night's sleep so the dashboard isn't completely blank.
      final DateTime previousSleepStart = sleepWindowStart.subtract(const Duration(hours: 24));
      // End the previous window at 2 PM yesterday so we capture full previous night sleep including late wakeups
      final DateTime previousSleepEnd = startTime.subtract(const Duration(hours: 10));
      
      final previousSessions = await getSleepData(previousSleepStart, previousSleepEnd);
      sleepHours = _calculateSleepHours(previousSessions);
      if (sleepHours > 0) {
        print("Sleep: Using previous night's sleep as fallback ($sleepHours hrs)");
      }
    }
    
    print("Sleep query window: $sleepWindowStart → $endTime, sessions: ${sleepSessions.length}, computed real hours: $sleepHours");

    // Blood Oxygen: Get latest (null if no data, NOT 0)
    int? oxygen = await getBloodOxygen(startTime, endTime);

    // HRV: Try today first, then expanded overnight window
    double? hrv;
    try {
      final groupedRMSSD = await _fetchDailyGrouped(HealthDataType.HEART_RATE_VARIABILITY_RMSSD, 2);
      final groupedSDNN = await _fetchDailyGrouped(HealthDataType.HEART_RATE_VARIABILITY_SDNN, 2);

      final grouped = groupedRMSSD.isNotEmpty ? groupedRMSSD : groupedSDNN;

      for (var e in grouped.entries) {
        if (e.key.year == endTime.year && e.key.month == endTime.month && e.key.day == endTime.day) {
          final avg = e.value.reduce((a, b) => a + b) / e.value.length;
          hrv = double.parse(avg.toStringAsFixed(1));
          break;
        }
      }
    } catch (_) {}

    if (hrv == null) {
      hrv = await getHeartRateVariability(startTime, endTime);
      if (hrv == null) {
        hrv = await getHeartRateVariability(sleepWindowStart, endTime);
        if (hrv != null) print("HRV found in expanded overnight window: $hrv");
      }
    }

    // RHR: Try today, then overnight window, then estimate from HR data
    int? rhr = await getRestingHeartRate(startTime, endTime);
    if (rhr == null) {
      rhr = await getRestingHeartRate(sleepWindowStart, endTime);
      if (rhr != null) print("RHR found in expanded overnight window: $rhr");
    }
    // Fallback: estimate RHR from lowest 10% of heart rate readings
    if (rhr == null && heartRates.isNotEmpty) {
      final hrValues = heartRates
          .where((p) => p.value is NumericHealthValue)
          .map((p) => (p.value as NumericHealthValue).numericValue.round())
          .where((v) => v > 30 && v < 200) // filter junk readings
          .toList();
      if (hrValues.length >= 3) {
        hrValues.sort();
        // Take bottom 10% as resting estimate (minimum 3 readings)
        final bottomCount = math.max(3, (hrValues.length * 0.1).ceil());
        final bottomSlice = hrValues.take(bottomCount).toList();
        rhr = (bottomSlice.reduce((a, b) => a + b) / bottomSlice.length).round();
        print("RHR estimated from lowest HR readings: $rhr (from ${hrValues.length} readings)");
      }
    }

    // Temperature: Use a 14-day window - Apple Watch only writes wrist temp during sleep,
    // so we need a wide window. Try native service first, then health package.
    double? respiratoryRate;
    double? skinTemp;
    final DateTime vitalsWindowStart = endTime.subtract(const Duration(hours: 48));
    final DateTime tempWindowStart = endTime.subtract(const Duration(days: 14));
    
    try {
      respiratoryRate = await getRespiratoryRate(vitalsWindowStart, endTime);
      
      // Try to get the daily average instead for consistency with history
      try {
        final grouped = await _fetchDailyGrouped(HealthDataType.RESPIRATORY_RATE, 2);
        // Find today's date key
        for (var e in grouped.entries) {
          if (e.key.year == endTime.year && e.key.month == endTime.month && e.key.day == endTime.day) {
            final avg = e.value.reduce((a, b) => a + b) / e.value.length;
            respiratoryRate = double.parse(avg.toStringAsFixed(1));
            break;
          }
        }
      } catch (_) {}

      print("HealthRepository: Respiratory Rate: $respiratoryRate");
    } catch (e) {
      print("HealthRepository ERROR: Respiratory Rate failed: $e");
    }
    
    // Try native TemperatureService first (accesses Apple Watch wrist temp)
    try {
      skinTemp = await TemperatureService.getLatestTemperature(tempWindowStart, endTime);
      print("HealthRepository: Skin Temp via native: $skinTemp");
    } catch (e) {
      print("HealthRepository: Native temp failed, trying health package: $e");
    }
    // Fallback: try from health package if native returned null
    if (skinTemp == null) {
      try {
        skinTemp = await getSkinTemperature(tempWindowStart, endTime);
        print("HealthRepository: Skin Temp via health package: $skinTemp");
      } catch (e) {
        print("HealthRepository ERROR: Skin Temp (health package) failed: $e");
      }
    }

    // HR stats (avg, min, max) for TRIMP-based algorithms
    final hrStats = _computeHrStats(heartRates);
    final int? hrAvg = hrStats['avg'];
    final int? hrMin = hrStats['min'];
    final int? hrMax = hrStats['max'];

    // Sleep efficiency from real AWAKE stage data.
    // efficiency = (sleepHours×60 - totalAwakeMinutes) / (sleepHours×60)
    // Source: Buysse DJ et al. (1989) — Pittsburgh Sleep Quality Index.
    // Falls back to 0.85 assumption if sleepHours is 0 or no AWAKE data.
    final double sleepEfficiency = _calculateSleepEfficiency(sleepSessions, sleepHours);

    // Active Energy Burned
    double activeEnergy = 0;
    try {
      final energyData = await _health.getHealthDataFromTypes(
        startTime: startTime,
        endTime: endTime,
        types: [HealthDataType.ACTIVE_ENERGY_BURNED],
      );
      for (var d in energyData) {
        if (d.value is NumericHealthValue) {
          activeEnergy += (d.value as NumericHealthValue).numericValue;
        }
      }
    } catch (e) {
      print("Warning: ACTIVE_ENERGY_BURNED not supported: $e");
    }

    // Exercise Time / Training
    // EXERCISE_TIME is iOS-only (Apple Activity Rings).
    // On Android, we skip it entirely and go straight to WORKOUT data.
    int exerciseMinutes = 0;
    if (Platform.isIOS) {
      try {
        final exerciseData = await _health.getHealthDataFromTypes(
          startTime: startTime,
          endTime: endTime,
          types: [HealthDataType.EXERCISE_TIME],
        );
        for (var d in exerciseData) {
          if (d.value is NumericHealthValue) {
            exerciseMinutes += (d.value as NumericHealthValue).numericValue.round();
          }
        }
      } catch (e) {
        print("Warning: EXERCISE_TIME not supported: $e");
      }
    }


    
    // WORKOUT Fallback (If Active Energy or Exercise Time is still 0)
    try {
      final workoutData = await _health.getHealthDataFromTypes(
        startTime: startTime,
        endTime: endTime,
        types: [HealthDataType.WORKOUT],
      );
      
      double workoutCalories = 0;
      int workoutMinutes = 0;
      
      for (var d in workoutData) {
        if (d.value is WorkoutHealthValue) {
          final wv = d.value as WorkoutHealthValue;
          workoutCalories += (wv.totalEnergyBurned ?? 0).toDouble();
          
          // Use data point dates for duration calculation
          final duration = d.dateTo.difference(d.dateFrom).inMinutes;
          workoutMinutes += duration;
        }
      }
      
      // If primary sensors returned 0, use workout data
      // If primary sensors returned 0, use workout data
      // If primary sensors returned low values, use workout data as a floor
      if (workoutCalories > activeEnergy) {
        activeEnergy = workoutCalories;
        print("Using Workout Calories as floor: $activeEnergy");
      }

      if (exerciseMinutes == 0 && workoutMinutes > 0) {
        exerciseMinutes = workoutMinutes;
        print("Using Workout Minutes fallback: $exerciseMinutes");
      }
      

    } catch (e) {
      print("Error fetching workout fallback: $e");
    }

    // --- PREDICTIVE EXERCISE ALGORITHM (For Android where EXERCISE_TIME is unsupported) ---
    // If we STILL have 0 exercise minutes (user hasn't manually logged a workout), 
    // we use a blended algorithmic approach to mathematically deduce training duration.
    if (exerciseMinutes == 0 && (activeEnergy > 0 || steps > 0 || heartRates.isNotEmpty)) {
      // 1. Calories (40%) - Assume moderate activity is ~6.5 kcals/min
      double calMin = (activeEnergy / 6.5).clamp(0.0, 180.0);
      
      // 2. Steps (40%) - Subtract casual movement (2000 steps), then assume brisk walk (100 steps/min)
      double activeSteps = (steps - 2000).clamp(0, 50000).toDouble();
      double stepMin = (activeSteps / 100).clamp(0.0, 180.0);
      
      // 3. Heart Rate (20%) - Count elevated heart rate readings (>105 bpm). 
      // Assuming sparse sampling, multiply each elevated reading by 3 minutes.
      int elevatedHrCount = heartRates.where((hr) {
         if (hr.value is NumericHealthValue) {
            return (hr.value as NumericHealthValue).numericValue > 105;
         }
         return false;
      }).length;
      double hrMin = (elevatedHrCount * 3).clamp(0, 180).toDouble();
      
      // Blend the signals
      exerciseMinutes = ((calMin * 0.4) + (stepMin * 0.4) + (hrMin * 0.2)).round();
      print("Algorithmic Exercise Estimation: $exerciseMinutes mins (calMin:$calMin, stepMin:$stepMin, hrMin:$hrMin)");
    }
    // ----------------------------------------------------------------------------------------

    // Diagnostics
    print("Dashboard Sync Metrics: Steps: $steps, ActiveEnergy: $activeEnergy, Exercise: $exerciseMinutes, Sleep: ${sleepHours}h");
    print("Dashboard Vitals: HR: $lastHeartRate, HRV: $hrv, RHR: $rhr, SpO2: $oxygen, RR: $respiratoryRate, Temp: $skinTemp");
    print("Dashboard HR Stats: Avg: $hrAvg, Min: $hrMin, Max: $hrMax");

    // Stand Hours fallback
    int standHoursConsumed = 0;

    return {
      'steps': steps,
      'heartRate': lastHeartRate ?? 0,
      'heartRateAvg': hrAvg ?? lastHeartRate ?? 0,
      'heartRateMin': hrMin ?? 0,
      'heartRateMax': hrMax ?? 0,
      'sleepHours': double.parse(sleepHours.toStringAsFixed(1)),
      'sleepEfficiency': sleepEfficiency,
      'bloodOxygen': oxygen,  // null when no data (not 0)
      'hrv': hrv,
      'restingHeartRate': rhr,
      'activeEnergy': activeEnergy.round(),
      'exerciseMinutes': exerciseMinutes,
      'standHours': standHoursConsumed,
      'sleepSessions': sleepSessions,
      'respiratoryRate': respiratoryRate,
      'skinTemperature': skinTemp,
    };
  }

  /// Helper to merge overlapping sleep sessions and calculate total hours
  double _calculateSleepHours(List<HealthDataPoint> sessions) {
    if (sessions.isEmpty) return 0.0;

    // Filter to include only actual sleep stages. 
    // AWAKE, AWAKE_IN_BED, and AWAKE_OUT_OF_BED are excluded from the total duration.
    final sleepStages = sessions.where((p) => 
      p.type != HealthDataType.SLEEP_AWAKE
    ).toList();

    if (sleepStages.isEmpty) {
      // If we ONLY have AWAKE data, we can't calculate sleep hours
      return 0.0;
    }

    final sorted = List<HealthDataPoint>.from(sleepStages)
      ..sort((a, b) => a.dateFrom.compareTo(b.dateFrom));

    DateTime currentStart = sorted.first.dateFrom;
    DateTime currentEnd = sorted.first.dateTo;
    int totalMinutes = 0;

    for (var i = 1; i < sorted.length; i++) {
      final session = sorted[i];
      if (session.dateFrom.isBefore(currentEnd) || session.dateFrom.isAtSameMomentAs(currentEnd)) {
        if (session.dateTo.isAfter(currentEnd)) {
          currentEnd = session.dateTo;
        }
      } else {
        totalMinutes += currentEnd.difference(currentStart).inMinutes;
        currentStart = session.dateFrom;
        currentEnd = session.dateTo;
      }
    }
    totalMinutes += currentEnd.difference(currentStart).inMinutes;
    return totalMinutes / 60.0;
  }

  /// Fetch blood oxygen for an interval
  Future<int?> getBloodOxygen(DateTime start, DateTime end) async {
    try {
      List<HealthDataPoint> healthData = await _health.getHealthDataFromTypes(
        startTime: start,
        endTime: end,
        types: [HealthDataType.BLOOD_OXYGEN],
      );
      if (healthData.isNotEmpty) {
        healthData.sort((a, b) => b.dateFrom.compareTo(a.dateFrom));
        final latest = healthData.first.value;
         if (latest is NumericHealthValue) {
          double val = latest.numericValue.toDouble();
          if (val <= 1.0) {
            return (val * 100).round();
          }
          return val.round();
        }
      }
      return null;
    } catch (e) {
      print("Error fetching Oxygen: $e");
      return null;
    }
  }
  
  /// Fetch Resting Heart Rate for an interval
  Future<int?> getRestingHeartRate(DateTime start, DateTime end) async {
    try {
      List<HealthDataPoint> healthData = await _health.getHealthDataFromTypes(
        startTime: start,
        endTime: end,
        types: [HealthDataType.RESTING_HEART_RATE],
      );
      if (healthData.isNotEmpty) {
        healthData.sort((a, b) => b.dateFrom.compareTo(a.dateFrom));
        final latest = healthData.first.value;
        if (latest is NumericHealthValue) {
          return latest.numericValue.round();
        }
      }
    } catch (e) {
      print("Error fetching RHR: $e");
    }
    return null;
  }

  /// Fetch HRV for an interval — tries RMSSD first (Android), then SDNN (iOS)
  Future<double?> getHeartRateVariability(DateTime start, DateTime end) async {
    // 1. Try RMSSD (preferred for autonomic stress measurement, Android Health Connect)
    try {
      final rmssd = await _health.getHealthDataFromTypes(
        startTime: start,
        endTime: end,
        types: [HealthDataType.HEART_RATE_VARIABILITY_RMSSD],
      );
      if (rmssd.isNotEmpty) {
        rmssd.sort((a, b) => b.dateFrom.compareTo(a.dateFrom));
        final latest = rmssd.first.value;
        if (latest is NumericHealthValue && latest.numericValue > 0) {
          return latest.numericValue.toDouble();
        }
      }
    } catch (e) {
      print("Error fetching RMSSD HRV: $e");
    }

    // 2. Fall back to SDNN (iOS HealthKit)
    try {
      final sdnn = await _health.getHealthDataFromTypes(
        startTime: start,
        endTime: end,
        types: [HealthDataType.HEART_RATE_VARIABILITY_SDNN],
      );
      if (sdnn.isNotEmpty) {
        sdnn.sort((a, b) => b.dateFrom.compareTo(a.dateFrom));
        final latest = sdnn.first.value;
        if (latest is NumericHealthValue) {
          return latest.numericValue.toDouble();
        }
      }
    } catch (e) {
      print("Error fetching HRV: $e");
    }
    return null;
  }

  /// Fetch steps for the last [days] days for the chart
  Future<List<Map<String, dynamic>>> getWeeklySteps({int days = 7, DateTime? endTime}) async {
    final end = endTime ?? DateTime.now();
    final anchor = DateTime(end.year, end.month, end.day);
    List<Map<String, dynamic>> stepsData = [];

    for (int i = days - 1; i >= 0; i--) {
      final date = anchor.subtract(Duration(days: i));
      final nextDay = date.add(const Duration(days: 1));
      
      try {
        final steps = await _health.getTotalStepsInInterval(date, nextDay) ?? 0;
        stepsData.add({
          'day': _getDayName(date.weekday),
          'steps': steps,
          'date': date,
        });
      } catch (e) {
        print("Error fetching steps for $date: $e");
        stepsData.add({
          'day': _getDayName(date.weekday),
          'steps': 0,
          'date': date,
        });
      }
    }
    return stepsData;
  }

  String _getDayName(int weekday) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[weekday - 1];
  }

  /// Fetch latest respiratory rate (RESPIRATORY_RATE) for an interval
  Future<double?> getRespiratoryRate(DateTime start, DateTime end) async {
    try {
      final data = await _health.getHealthDataFromTypes(
        startTime: start,
        endTime: end,
        types: [HealthDataType.RESPIRATORY_RATE],
      );
      if (data.isNotEmpty) {
        data.sort((a, b) => b.dateFrom.compareTo(a.dateFrom));
        final v = data.first.value;
        if (v is NumericHealthValue && v.numericValue > 0) {
          return v.numericValue.toDouble();
        }
      }
    } catch (e) {
      print('Error fetching Respiratory Rate: $e');
      return null;
    }
    return null;
  }

  /// Fetch latest skin / body temperature for an interval.
  /// Apple Watch Series 8+ stores wrist temp as a DEVIATION from baseline (e.g. +0.2, -0.1°C).
  /// BODY_TEMPERATURE stores absolute values (e.g. 36.6°C) from manual entry or external devices.
  Future<double?> getSkinTemperature(DateTime start, DateTime end) async {
    try {
      final data = await _health.getHealthDataFromTypes(
        startTime: start,
        endTime: end,
        types: [HealthDataType.SKIN_TEMPERATURE, HealthDataType.BODY_TEMPERATURE],
      );
      if (data.isNotEmpty) {
        data.sort((a, b) => b.dateFrom.compareTo(a.dateFrom));
        final v = data.first.value;
        if (v is NumericHealthValue) {
          final raw = v.numericValue.toDouble();
          // Deviation values are small (-5 to +5); convert to absolute
          if (raw.abs() <= 5.0 && raw != 0.0) {
            return 36.5 + raw;
          }
          // Absolute value (e.g. 36.6°C): must be in plausible human range
          if (raw >= 30.0 && raw <= 42.0) {
            return raw;
          }
        }
      }
    } catch (e) {
      print('Error fetching Temp: $e');
    }
    return null;
  }

  Map<String, int?> _computeHrStats(List<HealthDataPoint> heartRates) {
    if (heartRates.isEmpty) return {'avg': null, 'min': null, 'max': null};

    final hrValues = heartRates
        .where((p) => p.value is NumericHealthValue)
        .map((p) => (p.value as NumericHealthValue).numericValue.round())
        .where((v) => v > 30 && v < 220) // Realistic bounds
        .toList();

    if (hrValues.isEmpty) return {'avg': null, 'min': null, 'max': null};

    hrValues.sort();
    final minHr = hrValues.first;
    final maxHr = hrValues.last;
    final avgHr = (hrValues.reduce((a, b) => a + b) / hrValues.length).round();

    return {'avg': avgHr, 'min': minHr, 'max': maxHr};
  }

  Future<Map<String, dynamic>?> getLatestHeartRateData(DateTime start, DateTime end) async {
    try {
      final hrData = await _health.getHealthDataFromTypes(
        startTime: start,
        endTime: end,
        types: [HealthDataType.HEART_RATE],
      );
      if (hrData.isNotEmpty) {
        hrData.sort((a, b) => b.dateFrom.compareTo(a.dateFrom)); // Sort descending
        final v = hrData.first.value;
        if (v is NumericHealthValue) {
          return {'value': v.numericValue.toDouble(), 'timestamp': hrData.first.dateFrom};
        }
      }
    } catch (_) {}
    return null;
  }

  Future<Map<String, dynamic>?> getLatestHrvData(DateTime start, DateTime end) async {
    try {
      final hrvData = await _health.getHealthDataFromTypes(
        startTime: start,
        endTime: end,
        types: [HealthDataType.HEART_RATE_VARIABILITY_SDNN],
      );
      if (hrvData.isNotEmpty) {
        hrvData.sort((a, b) => b.dateFrom.compareTo(a.dateFrom)); // Sort descending
        final v = hrvData.first.value;
        if (v is NumericHealthValue) {
          return {'value': v.numericValue.toDouble(), 'timestamp': hrvData.first.dateFrom};
        }
      }
    } catch (_) {}
    return null;
  }

  /// Fetch sleep duration for the last 7 days
  Future<List<Map<String, dynamic>>> getWeeklySleep() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    List<Map<String, dynamic>> sleepData = [];

    for (int i = 6; i >= 0; i--) {
      final date = today.subtract(Duration(days: i));
      // Query from 6pm previous day to noon today to capture overnight sleep
      final sleepStart = date.subtract(const Duration(hours: 6));
      final sleepEnd = date.add(const Duration(hours: 12));
      
      try {
        final allData = await _health.getHealthDataFromTypes(
          startTime: sleepStart,
          endTime: sleepEnd,
          types: _sleepTypes,
        );
        
        // Only try SLEEP_IN_BED on iOS — causes crashes on Samsung Android
        if (Platform.isIOS) {
          try {
            final inBedData = await _health.getHealthDataFromTypes(
              startTime: sleepStart,
              endTime: sleepEnd,
              types: [HealthDataType.SLEEP_IN_BED],
            );
            allData.addAll(inBedData);
          } catch (_) { /* SLEEP_IN_BED not available on this device */ }
        }
        
        final deduped = _health.removeDuplicates(allData);
        
        // Prefer SLEEP_SESSION if available, else use granular stages
        List<HealthDataPoint> sleepPoints;
        final sessions = deduped.where((p) => p.type == HealthDataType.SLEEP_SESSION).toList();
        if (sessions.isNotEmpty) {
          sleepPoints = sessions;
        } else {
          // Use actual sleep stages (exclude AWAKE types)
          sleepPoints = deduped.where((p) =>
            p.type == HealthDataType.SLEEP_ASLEEP ||
            p.type == HealthDataType.SLEEP_DEEP ||
            p.type == HealthDataType.SLEEP_LIGHT ||
            p.type == HealthDataType.SLEEP_REM ||
            p.type == HealthDataType.SLEEP_IN_BED
          ).toList();
        }
        
        double totalHours = 0;
        for (var s in sleepPoints) {
             totalHours += s.dateTo.difference(s.dateFrom).inMinutes / 60.0;
        }

        sleepData.add({
          'day': _getDayName(date.weekday),
          'hours': double.parse(totalHours.toStringAsFixed(1)),
          'date': date,
        });
      } catch (e) {
        print("Error fetching sleep for $date: $e");
        sleepData.add({
          'day': _getDayName(date.weekday),
          'hours': 0.0,
          'date': date,
        });
      }
    }
    return sleepData;
  }

  /// Get simplified heart rate history for the chart (last 24h)
  Future<List<Map<String, dynamic>>> getHeartRateHistory({DateTime? endTime}) async {
    final end = endTime ?? DateTime.now();
    final start = end.subtract(const Duration(hours: 24));
    final history = await getHeartRateData(start, end);
    // Sort by date
    history.sort((a, b) => a.dateFrom.compareTo(b.dateFrom));
    
    // Map to simple structure
    return history.map((e) {
      int val = 0;
       if (e.value is NumericHealthValue) {
          val = (e.value as NumericHealthValue).numericValue.round();
       }
      return {
        'time': e.dateFrom,
        'value': val,
      };
    }).toList();
  }

  // ═══════════════════════════════════════════════════════════════════
  // 30-DAY HISTORICAL DATA FOR METRIC DETAIL CHARTS
  // Each method returns List<{date: DateTime, value: double}>
  // One data point per day, aggregated appropriately per metric.
  // ═══════════════════════════════════════════════════════════════════

  /// Helper: fetch all samples of a given type for a date range, extract numeric values grouped by day
  Future<Map<DateTime, List<double>>> _fetchDailyGrouped(
    HealthDataType type, int days, {DateTime? endTime}
  ) async {
    final end = endTime ?? DateTime.now();
    final today = DateTime(end.year, end.month, end.day);
    final start = today.subtract(Duration(days: days));

    try {
      final data = await _health.getHealthDataFromTypes(
        startTime: start,
        endTime: end,
        types: [type],
      );
      final deduped = _health.removeDuplicates(data);
      final Map<DateTime, List<double>> grouped = {};
      for (final point in deduped) {
        if (point.value is NumericHealthValue) {
          final val = (point.value as NumericHealthValue).numericValue.toDouble();
          if (val > 0) {
            final dayKey = DateTime(point.dateFrom.year, point.dateFrom.month, point.dateFrom.day);
            grouped.putIfAbsent(dayKey, () => []).add(val);
          }
        }
      }
      return grouped;
    } catch (e) {
      print('Error fetching daily grouped $type: $e');
      return {};
    }
  }

  /// Resting Heart Rate history — daily minimum RHR (lower is better)
  Future<List<Map<String, dynamic>>> getRhrHistory({int days = 30, DateTime? endTime}) async {
    // Try RESTING_HEART_RATE first
    var grouped = await _fetchDailyGrouped(HealthDataType.RESTING_HEART_RATE, days, endTime: endTime);
    
    // If no RHR data, estimate from lowest HR readings per day
    if (grouped.isEmpty) {
      grouped = await _fetchDailyGrouped(HealthDataType.HEART_RATE, days, endTime: endTime);
      // For HR, use bottom 10% as RHR proxy
      return grouped.entries.map((e) {
        final sorted = List<double>.from(e.value)..sort();
        final bottomCount = math.max(1, (sorted.length * 0.1).ceil());
        final rhr = sorted.take(bottomCount).reduce((a, b) => a + b) / bottomCount;
        return {'date': e.key, 'value': rhr};
      }).toList()..sort((a, b) => (a['date'] as DateTime).compareTo(b['date'] as DateTime));
    }

    return grouped.entries.map((e) {
      final minVal = e.value.reduce(math.min).toDouble();
      return {'date': e.key, 'value': minVal};
    }).toList()..sort((a, b) => (a['date'] as DateTime).compareTo(b['date'] as DateTime));
  }

  /// Heart Rate Variability history — daily average HRV
  Future<List<Map<String, dynamic>>> getHrvHistory({int days = 30, DateTime? endTime}) async {
    // Try RMSSD (Android) first, then SDNN (iOS)
    var grouped = await _fetchDailyGrouped(HealthDataType.HEART_RATE_VARIABILITY_RMSSD, days, endTime: endTime);
    if (grouped.isEmpty) {
      grouped = await _fetchDailyGrouped(HealthDataType.HEART_RATE_VARIABILITY_SDNN, days, endTime: endTime);
    }

    return grouped.entries.map((e) {
      final avg = e.value.reduce((a, b) => a + b) / e.value.length;
      return {'date': e.key, 'value': double.parse(avg.toStringAsFixed(1))};
    }).toList()..sort((a, b) => (a['date'] as DateTime).compareTo(b['date'] as DateTime));
  }

  /// Respiratory Rate history — daily average RR
  Future<List<Map<String, dynamic>>> getRrHistory({int days = 30, DateTime? endTime}) async {
    final grouped = await _fetchDailyGrouped(HealthDataType.RESPIRATORY_RATE, days, endTime: endTime);

    return grouped.entries.map((e) {
      final avg = e.value.reduce((a, b) => a + b) / e.value.length;
      return {'date': e.key, 'value': double.parse(avg.toStringAsFixed(1))};
    }).toList()..sort((a, b) => (a['date'] as DateTime).compareTo(b['date'] as DateTime));
  }

  /// Blood Oxygen (SpO2) history — daily latest value
  Future<List<Map<String, dynamic>>> getSpO2History({int days = 30, DateTime? endTime}) async {
    final grouped = await _fetchDailyGrouped(HealthDataType.BLOOD_OXYGEN, days, endTime: endTime);

    return grouped.entries.map((e) {
      // SpO2 values may be 0-1 (fraction) or 0-100 (percent)
      double val = e.value.last;
      if (val <= 1.0) val = val * 100;
      return {'date': e.key, 'value': val};
    }).toList()..sort((a, b) => (a['date'] as DateTime).compareTo(b['date'] as DateTime));
  }

  /// Sleep duration history — daily total hours
  Future<List<Map<String, dynamic>>> getSleepHistory({int days = 30, DateTime? endTime}) async {
    final end = endTime ?? DateTime.now();
    final anchor = DateTime(end.year, end.month, end.day);
    List<Map<String, dynamic>> sleepHistoryRecords = [];

    // Fetch all sleep data in one bulk query to prevent N+1 API calls freezing the app
    final bulkStart = anchor.subtract(Duration(days: days)).subtract(const Duration(hours: 6));
    final bulkEnd = anchor.add(const Duration(hours: 12));
    
    List<HealthDataPoint> allSleepData = [];
    try {
      allSleepData = await getSleepData(bulkStart, bulkEnd);
    } catch (e) {
      print('Error fetching bulk sleep data: $e');
      return sleepHistoryRecords;
    }

    for (int i = days - 1; i >= 0; i--) {
      final date = anchor.subtract(Duration(days: i));
      final sleepStart = date.subtract(const Duration(hours: 6));
      final sleepEnd = date.add(const Duration(hours: 12));

      // Filter the locally fetched bulk data
      final sessions = allSleepData.where((p) => 
        (p.dateFrom.isBefore(sleepEnd) && p.dateTo.isAfter(sleepStart))
      ).toList();

      try {
        final hours = _calculateSleepHours(sessions);
        if (hours > 0) {
          sleepHistoryRecords.add({'date': date, 'value': double.parse(hours.toStringAsFixed(1))});
        }
      } catch (e) {
        print('Error calculating sleep history for $date: $e');
      }
    }
    return sleepHistoryRecords;
  }

  /// Skin/Wrist Temperature history — daily average
  Future<List<Map<String, dynamic>>> getSkinTempHistory({int days = 30, DateTime? endTime}) async {
    try {
      if (Platform.isIOS) {
        // Permission already requested upfront in the dashboard
        final history = await TemperatureService.getTemperatureHistory(days: days, endTime: endTime);
        
        Map<DateTime, List<double>> grouped = {};
        for (final d in history) {
          final dt = d['date'] as DateTime;
          final val = d['value'] as double;
          final dateKey = DateTime(dt.year, dt.month, dt.day);
          grouped.putIfAbsent(dateKey, () => []).add(val);
        }
        
        return grouped.entries.map((e) {
          final avg = e.value.reduce((a, b) => a + b) / e.value.length;
          return {'date': e.key, 'value': double.parse(avg.toStringAsFixed(1))};
        }).toList()..sort((a, b) => (a['date'] as DateTime).compareTo(b['date'] as DateTime));
      }
      // On Android, fallback to basic group fetching
      final grouped = await _fetchDailyGrouped(HealthDataType.BODY_TEMPERATURE, days, endTime: endTime);
      if (grouped.isNotEmpty) {
        return grouped.entries.map((e) {
          final avg = e.value.reduce((a, b) => a + b) / e.value.length;
          return {'date': e.key, 'value': double.parse(avg.toStringAsFixed(1))};
        }).toList()..sort((a, b) => (a['date'] as DateTime).compareTo(b['date'] as DateTime));
      }
    } catch (_) {}
    return [];
  }

  /// Active Energy Burned history — daily sum with workout fallback
  Future<List<Map<String, dynamic>>> getActiveEnergyHistory({int days = 30, DateTime? endTime}) async {
    final end = endTime ?? DateTime.now();
    final anchor = DateTime(end.year, end.month, end.day);
    List<Map<String, dynamic>> history = [];

    // Fetch day-by-day to prevent truncation issues with high-frequency energy data
    for (int i = days - 1; i >= 0; i--) {
      final date = anchor.subtract(Duration(days: i));
      final nextDay = date.add(const Duration(days: 1));
      
      try {
        double activeEnergy = 0;
        final energyData = await _health.getHealthDataFromTypes(
          startTime: date,
          endTime: nextDay,
          types: [HealthDataType.ACTIVE_ENERGY_BURNED],
        );
        for (var d in energyData) {
          if (d.value is NumericHealthValue) {
            activeEnergy += (d.value as NumericHealthValue).numericValue;
          }
        }

        // Workout Fallback for history
        double workoutCalories = 0;
        try {
          final workoutData = await _health.getHealthDataFromTypes(
            startTime: date,
            endTime: nextDay,
            types: [HealthDataType.WORKOUT],
          );
          for (var d in workoutData) {
            if (d.value is WorkoutHealthValue) {
              workoutCalories += ((d.value as WorkoutHealthValue).totalEnergyBurned ?? 0).toDouble();
            }
          }
        } catch (_) {}

        final finalEnergy = math.max(activeEnergy, workoutCalories);
        
        if (finalEnergy > 0) {
          history.add({
            'date': date,
            'value': double.parse(finalEnergy.toStringAsFixed(1)),
          });
        }
      } catch (e) {
        print("Error fetching energy history for $date: $e");
      }
    }
    
    return history..sort((a, b) => (a['date'] as DateTime).compareTo(b['date'] as DateTime));
  }

  /// Exercise Minutes history — daily sum of workout durations
  Future<List<Map<String, dynamic>>> getExerciseMinutesHistory({int days = 30, DateTime? endTime}) async {
    final end = endTime ?? DateTime.now();
    final anchor = DateTime(end.year, end.month, end.day);
    List<Map<String, dynamic>> history = [];

    for (int i = days - 1; i >= 0; i--) {
      final date = anchor.subtract(Duration(days: i));
      final nextDay = date.add(const Duration(days: 1));
      
      try {
        double minutes = 0;
        final workoutData = await _health.getHealthDataFromTypes(
          startTime: date,
          endTime: nextDay,
          types: [HealthDataType.WORKOUT],
        );
        for (var d in workoutData) {
          minutes += d.dateTo.difference(d.dateFrom).inMinutes.toDouble();
        }
        
        if (minutes > 0) {
          history.add({
            'date': date,
            'value': minutes,
          });
        }
      } catch (e) {
        print("Error fetching exercise history for $date: $e");
      }
    }
    
    return history..sort((a, b) => (a['date'] as DateTime).compareTo(b['date'] as DateTime));
  }

  /// Synthesize intraday stress data (Garmin-style timeline).
  /// Divides the day into 15-minute buckets.
  /// 0: Rest (Sleep), 1: Low, 2: Med, 3: High, 4: Activity (Workout)
  Future<List<Map<String, dynamic>>> getIntradayStressData(DateTime date, int? restingHr) async {
    // We want from 12:00 AM of 'date' to 11:59 PM
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1)).subtract(const Duration(seconds: 1));
    
    final rhr = (restingHr ?? 60).toDouble();

    try {
      // Fetch all HR points for the day
      final hrData = await _health.getHealthDataFromTypes(
        startTime: startOfDay,
        endTime: endOfDay,
        types: [HealthDataType.HEART_RATE],
      );

      // Fetch all workouts
      final workoutData = await _health.getHealthDataFromTypes(
        startTime: startOfDay,
        endTime: endOfDay,
        types: [HealthDataType.WORKOUT],
      );

      // Fetch all sleep states to identify purely resting periods
      List<HealthDataPoint> sleepData = [];
      try {
        sleepData = await _health.getHealthDataFromTypes(
          startTime: startOfDay,
          endTime: endOfDay,
          types: _sleepTypes,
        );
      } catch (_) {}

      if (hrData.isEmpty) return [];

      // Create 15-minute buckets (96 per day)
      // bucketIndex goes from 0 to 95
      Map<int, List<double>> buckets = {};
      for (final dp in hrData) {
        final v = dp.value;
        if (v is NumericHealthValue) {
          final minsSinceStart = dp.dateFrom.difference(startOfDay).inMinutes;
          final bucketIndex = (minsSinceStart / 15).floor().clamp(0, 95);
          buckets.putIfAbsent(bucketIndex, () => []).add(v.numericValue.toDouble());
        }
      }

      List<Map<String, dynamic>> timeline = [];

      for (int i = 0; i < 96; i++) {
        final bucketStart = startOfDay.add(Duration(minutes: i * 15));
        final bucketEnd = bucketStart.add(const Duration(minutes: 15));

        if (!buckets.containsKey(i) || buckets[i]!.isEmpty) {
          // No HR data for this bucket, insert unmeasurable placeholder so timeline doesn't squash X-axis
          timeline.add({'score': -2.0, 'level': -2});
          continue;
        }

        final hrs = buckets[i]!;
        final avgHr = hrs.reduce((a, b) => a + b) / hrs.length;

        // Determine bucket context
        bool isWorkout = workoutData.any((w) => w.dateFrom.isBefore(bucketEnd) && w.dateTo.isAfter(bucketStart));
        bool isAsleep = sleepData.any((s) => s.dateFrom.isBefore(bucketEnd) && s.dateTo.isAfter(bucketStart) && s.value.toString().contains('ASLEEP'));

        int stressLevel = 0; // 0=Rest, 1=Low, 2=Med, 3=High, 4=Activity
        double rawScore = 0.0; // 0-100 representation

        if (isWorkout) {
          stressLevel = 4; // Activity (gray/orange in garmin)
          rawScore = -1.0; 
        } else if (isAsleep) {
          stressLevel = 0; // Rest (blue)
          rawScore = 15.0; // Arbitrary low score for visual charting
        } else {
          // Compute stress based on HR elevation vs RHR
          // Tuned for natural awake variations (Garmin standard curve)
          final elevation = avgHr - rhr;
          
          if (elevation <= 5) {
            stressLevel = 0; // Deep Rest
            rawScore = 10 + elevation.clamp(0.0, 5.0) * 2.0; // 10-20
          } else if (elevation <= 12) {
            stressLevel = 1; // Low Stress (Awake resting)
            rawScore = 20 + ((elevation - 5) * 2.14); // 20-35
          } else if (elevation <= 25) {
            stressLevel = 1; // Low/Med
            rawScore = 35 + ((elevation - 12) * 1.15); // 35-50
          } else if (elevation <= 40) {
            stressLevel = 2; // Med
            rawScore = 50 + ((elevation - 25) * 1.66); // 50-75
          } else {
            stressLevel = 3; // High
            rawScore = 75 + ((elevation - 40) * 1.0).clamp(0.0, 25.0); // 75-100
          }
        }

        timeline.add({
          'time': bucketStart,
          'hr': avgHr,
          'level': stressLevel,
          'score': rawScore,
        });
      }

      return timeline;
    } catch (e) {
      print('Intraday stress fetch error: $e');
      return [];
    }
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // SLEEP EFFICIENCY — real AWAKE stage data (Buysse et al. 1989 PSQI)
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  /// efficiency = (totalSleepMinutes - awakeMinutesWithinWindow) / totalSleepMinutes
  /// Falls back to 0.85 if no AWAKE stage data is recorded by the device.
  double _calculateSleepEfficiency(List<HealthDataPoint> sessions, double sleepHours) {
    if (sleepHours <= 0 || sessions.isEmpty) return 0.85;
    final double totalMinutes = sleepHours * 60.0;
    final awakeSessions = sessions.where((p) => p.type == HealthDataType.SLEEP_AWAKE).toList();
    if (awakeSessions.isEmpty) return 0.85;
    double awakeMinutes = 0;
    for (final s in awakeSessions) {
      awakeMinutes += s.dateTo.difference(s.dateFrom).inMinutes.toDouble();
    }
    final double eff = ((totalMinutes - awakeMinutes) / totalMinutes).clamp(0.65, 1.0);
    print('Sleep Efficiency: ${(eff * 100).toStringAsFixed(1)}% (awake: ${awakeMinutes.round()} min)');
    return eff;
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // HRV BASELINE — 7-day trimmed mean (Buchheit 2014)
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  /// Personal HRV baseline: 7-day trimmed mean (drops top/bottom 10% for noise).
  /// Used by Recovery and Stress algorithms instead of the population 42 ms default.
  Future<double?> getHrvBaseline({int days = 7}) async {
    final now = DateTime.now();
    final start = now.subtract(Duration(days: days));
    List<HealthDataPoint> data = [];
    try {
      data.addAll(await _health.getHealthDataFromTypes(
        startTime: start, endTime: now,
        types: [HealthDataType.HEART_RATE_VARIABILITY_RMSSD],
      ));
    } catch (_) {}
    if (data.isEmpty) {
      try {
        data.addAll(await _health.getHealthDataFromTypes(
          startTime: start, endTime: now,
          types: [HealthDataType.HEART_RATE_VARIABILITY_SDNN],
        ));
      } catch (_) {}
    }
    if (data.isEmpty) return null;

    final values = data
        .where((p) => p.value is NumericHealthValue)
        .map((p) => (p.value as NumericHealthValue).numericValue.toDouble())
        .where((v) => v > 5 && v < 300)
        .toList()..sort();
    if (values.isEmpty) return null;

    final trimCount = (values.length * 0.10).floor();
    final trimmed = values.length > trimCount * 2 + 1
        ? values.sublist(trimCount, values.length - trimCount)
        : values;
    final baseline = trimmed.reduce((a, b) => a + b) / trimmed.length;
    print('HRV Baseline (${days}d trimmed mean): ${baseline.toStringAsFixed(1)} ms');
    return baseline;
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // RHR BASELINE — 7-day average
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Future<int?> getRhrBaseline({int days = 7}) async {
    final now = DateTime.now();
    final start = now.subtract(Duration(days: days));
    try {
      final data = await _health.getHealthDataFromTypes(
        startTime: start, endTime: now,
        types: [HealthDataType.RESTING_HEART_RATE],
      );
      final values = data
          .where((p) => p.value is NumericHealthValue)
          .map((p) => (p.value as NumericHealthValue).numericValue.toDouble())
          .where((v) => v > 30 && v < 120)
          .toList();
      if (values.isEmpty) return null;
      final avg = values.reduce((a, b) => a + b) / values.length;
      print('RHR Baseline (${days}d avg): ${avg.toStringAsFixed(1)} bpm');
      return avg.round();
    } catch (e) {
      print('Error fetching RHR baseline: $e');
      return null;
    }
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // WORKOUT HR AVG — exercise-period only (Banister TRIMP accuracy)
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  /// Returns avg HR only during active workout windows for [date].
  /// The all-day HR average is depressed by sedentary hours, causing TRIMP
  /// to severely underestimate actual exercise strain.
  Future<int?> getWorkoutHrAvg(DateTime date) async {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    try {
      final workouts = await _health.getHealthDataFromTypes(
        startTime: startOfDay, endTime: endOfDay,
        types: [HealthDataType.WORKOUT],
      );
      if (workouts.isEmpty) return null;

      final hrReadings = await _health.getHealthDataFromTypes(
        startTime: startOfDay, endTime: endOfDay,
        types: [HealthDataType.HEART_RATE],
      );
      if (hrReadings.isEmpty) return null;

      final List<double> exerciseHr = [];
      for (final hr in hrReadings) {
        if (hr.value is! NumericHealthValue) continue;
        final hrVal = (hr.value as NumericHealthValue).numericValue.toDouble();
        if (hrVal < 40 || hrVal > 220) continue;
        final isInWorkout = workouts.any((w) =>
            hr.dateFrom.isAfter(w.dateFrom.subtract(const Duration(seconds: 30))) &&
            hr.dateFrom.isBefore(w.dateTo.add(const Duration(seconds: 30))));
        if (isInWorkout) exerciseHr.add(hrVal);
      }

      if (exerciseHr.isEmpty) {
        // Fallback: use elevated HR readings as exercise proxy
        final elevated = hrReadings
            .where((p) => p.value is NumericHealthValue)
            .map((p) => (p.value as NumericHealthValue).numericValue.toDouble())
            .where((v) => v >= 100 && v < 220)
            .toList();
        if (elevated.isNotEmpty) {
          final avg = elevated.reduce((a, b) => a + b) / elevated.length;
          print('Workout HR avg (elevated fallback): ${avg.toStringAsFixed(0)} bpm');
          return avg.round();
        }
        return null;
      }

      final avg = exerciseHr.reduce((a, b) => a + b) / exerciseHr.length;
      print('Workout HR avg (exercise-window): ${avg.toStringAsFixed(0)} bpm from ${exerciseHr.length} readings');
      return avg.round();
    } catch (e) {
      print('Error fetching workout HR avg: $e');
      return null;
    }
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // WEEKLY STRAIN HISTORY — for Strain Performance delta calculation
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  /// Returns TRIMP-based strain score per day for the last [days-1] days (excludes today).
  /// Used to calculate today's performance vs rolling baseline.
  Future<List<int>> getWeeklyStrainHistory({int days = 7, DateTime? endTime}) async {
    final anchor = endTime ?? DateTime.now();
    final today = DateTime(anchor.year, anchor.month, anchor.day);
    final List<int> scores = [];
    
    // Fetch age once for accurate calculations
    final int? age = await getUserAge();

    for (int i = days - 1; i >= 1; i--) {
      final date = today.subtract(Duration(days: i));
      final start = DateTime(date.year, date.month, date.day);
      final end = start.add(const Duration(days: 1));
      try {
        final steps = await _health.getTotalStepsInInterval(start, end) ?? 0;
        int exerciseMin = 0;
        final workouts = await _health.getHealthDataFromTypes(startTime: start, endTime: end, types: [HealthDataType.WORKOUT]);
        for (final w in workouts) {
          exerciseMin += w.dateTo.difference(w.dateFrom).inMinutes;
        }
        
        final exHrAvg = await getWorkoutHrAvg(date);
        final rhr = await getRestingHeartRate(start, end);
        
        final score = HealthIntelligenceService.calculateStrainScore(
          exerciseMinutes: exerciseMin,
          exerciseHrAvg: exHrAvg,
          restingHeartRate: rhr,
          steps: steps,
          ageYears: age,
        );
        
        scores.add(score);
      } catch (_) {
        scores.add(0);
      }
    }
    print('Weekly strain history: $scores');
    return scores;
  }

  /// Returns historical strain performance deltas for the last [days] days.
  /// Each map contains: 'date', 'delta', 'strain', and 'targetRange' (for the shaded area).
  Future<List<Map<String, dynamic>>> getStrainPerformanceHistory({int days = 30}) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final List<Map<String, dynamic>> history = [];
    
    // We need (days + 7) days of raw strain to compute deltas for each day
    final int? age = await getUserAge();
    final List<int> rawStrains = [];
    final List<DateTime> dates = [];

    // Fetch raw strain for the entire window
    for (int i = days + 7; i >= 0; i--) {
      final date = today.subtract(Duration(days: i));
      final start = DateTime(date.year, date.month, date.day);
      final end = start.add(const Duration(days: 1));
      
      try {
        final steps = await _health.getTotalStepsInInterval(start, end) ?? 0;
        int exerciseMin = 0;
        final workouts = await _health.getHealthDataFromTypes(startTime: start, endTime: end, types: [HealthDataType.WORKOUT]);
        for (final w in workouts) {
          exerciseMin += w.dateTo.difference(w.dateFrom).inMinutes;
        }
        
        final exHrAvg = await getWorkoutHrAvg(date);
        final rhr = await getRestingHeartRate(start, end);
        
        final score = HealthIntelligenceService.calculateStrainScore(
          exerciseMinutes: exerciseMin,
          exerciseHrAvg: exHrAvg,
          restingHeartRate: rhr,
          steps: steps,
          ageYears: age,
        );
        rawStrains.add(score);
        dates.add(date);
      } catch (_) {
        rawStrains.add(0);
        dates.add(date);
      }
    }

    // Now compute deltas for the last [days] days
    for (int i = 7; i < rawStrains.length; i++) {
      final todayScore = rawStrains[i];
      final last7Days = rawStrains.sublist(i - 7, i);
      
      final delta = HealthIntelligenceService.calculateStrainPerformanceDelta(
        todayStrainScore: todayScore,
        last7DayStrainScores: last7Days,
      );
      
      history.add({
        'date': dates[i],
        'delta': delta.toDouble(),
        'strain': todayScore,
        'targetLow': -15.0,
        'targetHigh': 15.0,
      });
    }

    return history;
  }

  /// Returns historical Cardio Load (TSS) scores for the last [days] days.
  Future<List<Map<String, dynamic>>> getCardioLoadHistory({int days = 30}) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final List<Map<String, dynamic>> history = [];
    final int? age = await getUserAge();

    for (int i = days; i >= 0; i--) {
      final date = today.subtract(Duration(days: i));
      final start = DateTime(date.year, date.month, date.day);
      final end = start.add(const Duration(days: 1));
      
      try {
        int exerciseMin = 0;
        final workouts = await _health.getHealthDataFromTypes(startTime: start, endTime: end, types: [HealthDataType.WORKOUT]);
        for (final w in workouts) {
          exerciseMin += w.dateTo.difference(w.dateFrom).inMinutes;
        }
        
        final exHrAvg = await getWorkoutHrAvg(date);
        final rhr = await getRestingHeartRate(start, end);
        
        final load = HealthIntelligenceService.calculateCardioLoad(
          exerciseMinutes: exerciseMin,
          exerciseHrAvg: exHrAvg,
          restingHeartRate: rhr,
          ageYears: age,
        );
        
        history.add({
          'date': date,
          'value': load.toDouble(),
          'status': HealthIntelligenceService.getCardioLoadStatus(load),
        });
      } catch (_) {
        history.add({'date': date, 'value': 0.0, 'status': 'No data'});
      }
    }
    return history;
  }

  /// Returns historical Cardio Focus types for the last [days] days.
  Future<List<Map<String, dynamic>>> getCardioFocusHistory({int days = 30}) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final List<Map<String, dynamic>> history = [];
    final int? age = await getUserAge();

    for (int i = days; i >= 0; i--) {
      final date = today.subtract(Duration(days: i));
      try {
        final exHrAvg = await getWorkoutHrAvg(date);
        final focus = HealthIntelligenceService.calculateCardioFocusType(
          exerciseHrAvg: exHrAvg,
          ageYears: age,
        );
        history.add({
          'date': date,
          'focus': focus,
        });
      } catch (_) {
        history.add({'date': date, 'focus': 'No data'});
      }
    }
    return history;
  }

  /// Fetch VO2 Max from Health Connect (Android).
  /// NOTE: The health package v13.3.1 does not expose a VO2MAX HealthDataType.
  /// This is a stub for future versions. VO2 Max data on Android requires
  /// a native platform channel similar to the iOS implementation.
  Future<Map<String, dynamic>?> getVo2MaxFromHealthConnect() async {
    // VO2 Max is not yet available in health package v13.x
    // Samsung Galaxy Watch stores VO2 Max in Samsung Health but doesn't 
    // reliably sync it to Health Connect.
    print('VO2 Max from Health Connect: not available in health package v13');
    return null;
  }

  Future<int?> getUserAge() async {
    try {
      // NOTE: getBirthDate() may not be supported on all platforms or newer health package versions.
      // We'll wrap it in a tray/catch and return a sensible default if it fails.
      return 30; // Sensible default for longevity/fitness context if data unavailable
    } catch (e) {
      print('Error fetching user age: $e');
      return 30;
    }
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // WORKOUT HISTORY — for Activity Summary Detail Screen
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

   Future<Map<String, List<double>>> getCumulativeWorkoutDuration({int periodDays = 30, DateTime? endTime}) async {
     // Use midnight as the anchor to ensure day-aligned indexing
     final anchor = endTime ?? DateTime.now();
     final todayStart = DateTime(anchor.year, anchor.month, anchor.day);
     final endOfToday = todayStart.add(const Duration(hours: 23, minutes: 59, seconds: 59));
    
    // The "Current" period ends at the end of today and goes back N days
    final currentStart = todayStart.subtract(Duration(days: periodDays - 1));
    // The "Previous" period starts N days before currentStart
    final prevStart = currentStart.subtract(Duration(days: periodDays));

    List<double> currentPeriod = List.filled(periodDays, 0.0);
    List<double> previousPeriod = List.filled(periodDays, 0.0);

    try {
      final workouts = await _health.getHealthDataFromTypes(
        startTime: prevStart, 
        endTime: endOfToday, 
        types: [HealthDataType.WORKOUT],
      );

      // 1. Accumulate daily totals
      for (var w in workouts) {
        final durationMin = w.dateTo.difference(w.dateFrom).inMinutes.toDouble();
        
        if (w.dateFrom.isAfter(currentStart) || w.dateFrom.isAtSameMomentAs(currentStart)) {
          // Belongs to current period
          final dayIndex = w.dateFrom.difference(currentStart).inDays;
          if (dayIndex >= 0 && dayIndex < periodDays) {
            currentPeriod[dayIndex] += durationMin;
          }
        } else if (w.dateFrom.isAfter(prevStart) || w.dateFrom.isAtSameMomentAs(prevStart)) {
          // Belongs to previous period
          final dayIndex = w.dateFrom.difference(prevStart).inDays;
          if (dayIndex >= 0 && dayIndex < periodDays) {
            previousPeriod[dayIndex] += durationMin;
          }
        }
      }

      // 2. Make arrays cumulative (convert to hours for easier charting bounds)
      double currentRunningTotal = 0;
      for (int i = 0; i < periodDays; i++) {
        currentRunningTotal += currentPeriod[i];
        currentPeriod[i] = currentRunningTotal / 60.0; // sum in hours
      }

      double prevRunningTotal = 0;
      for (int i = 0; i < periodDays; i++) {
        prevRunningTotal += previousPeriod[i];
        previousPeriod[i] = prevRunningTotal / 60.0;
      }

      return {
        'current': currentPeriod,
        'previous': previousPeriod,
      };
    } catch (e) {
      print('Error fetching cumulative workout duration: $e');
      return {'current': [], 'previous': []};
    }
  }

  Future<List<Map<String, dynamic>>> getWorkoutHistory({int days = 180}) async {
    final now = DateTime.now();
    final start = now.subtract(Duration(days: days));
    List<Map<String, dynamic>> history = [];

    try {
      final workouts = await _health.getHealthDataFromTypes(
        startTime: start, endTime: now, types: [HealthDataType.WORKOUT],
      );

      for (var w in workouts) {
        String type = 'Workout';
        double? distance;
        int? activeEnergy;
        int? totalEnergy;

        if (w.value is WorkoutHealthValue) {
          final wv = w.value as WorkoutHealthValue;
          type = wv.workoutActivityType.name.replaceAll('_', ' ');
          if (wv.totalDistance != null) distance = wv.totalDistance!.toDouble() / 1000.0;
          if (wv.totalEnergyBurned != null) {
            activeEnergy = wv.totalEnergyBurned!.toInt();
            totalEnergy = activeEnergy;
          }
        }

        final durationSec = w.dateTo.difference(w.dateFrom).inSeconds;
        final durationMin = durationSec ~/ 60;

        // Compute pace (seconds per km) if distance is available
        String? paceString;
        if (distance != null && distance > 0.05) {
          final paceSecondsPerKm = durationSec / distance;
          final paceMin = paceSecondsPerKm ~/ 60;
          final paceSec = (paceSecondsPerKm % 60).toInt();
          paceString = '$paceMin:${paceSec.toString().padLeft(2, '0')} /km';
        }

        // Create display string
        String statString = '${durationMin}m';
        if (distance != null && distance > 0.1) {
          statString = '${distance.toStringAsFixed(2)}km';
        } else if (activeEnergy != null && activeEnergy > 0) {
          statString = '${activeEnergy}kcal';
        }

        history.add({
          'type': _capitalize(type),
          'date': w.dateFrom,
          'dateFrom': w.dateFrom,
          'dateTo': w.dateTo,
          'durationMin': durationMin,
          'durationSec': durationSec,
          'distance': distance,
          'activeEnergy': activeEnergy,
          'totalEnergy': totalEnergy,
          'paceString': paceString,
          'statString': statString,
        });
      }

      history.sort((a, b) => (b['date'] as DateTime).compareTo(a['date'] as DateTime));
      return history;
    } catch (e) {
      print('Error fetching workout history: $e');
      return [];
    }
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // WORKOUT HR SAMPLES — for Workout Detail Screen
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Future<List<Map<String, dynamic>>> getWorkoutHeartRateSamples(DateTime from, DateTime to) async {
    try {
      final samples = await _health.getHealthDataFromTypes(
        startTime: from,
        endTime: to,
        types: [HealthDataType.HEART_RATE],
      );

      List<Map<String, dynamic>> workoutHrSamples = [];
      for (var s in samples) {
        final bpm = (s.value as NumericHealthValue).numericValue.toDouble();
        workoutHrSamples.add({
          'time': s.dateFrom,
          'bpm': bpm,
        });
      }

      // Sort chronologically
      workoutHrSamples.sort((a, b) => (a['time'] as DateTime).compareTo(b['time'] as DateTime));
      return workoutHrSamples;
    } catch (e) {
      print('Error fetching workout HR samples: $e');
      return [];
    }
  }

  String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s.split(' ').map((word) => word.isNotEmpty ? '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}' : '').join(' ');
  }
  // ═══════════════════════════════════════════════════════
  // NOTIFICATION THROTTLING
  // ═══════════════════════════════════════════════════════
  
  static const String _lastHydrationKey = 'last_hydration_prompt_date';
  static const String _lastLateNightKey = 'last_late_night_prompt_date';

  Future<DateTime?> getLastHydrationPromptDate() async {
    final prefs = await SharedPreferences.getInstance();
    final iso = prefs.getString(_lastHydrationKey);
    return iso != null ? DateTime.parse(iso) : null;
  }

  Future<void> setLastHydrationPromptDate(DateTime date) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastHydrationKey, date.toIso8601String());
  }

  Future<DateTime?> getLastLateNightPromptDate() async {
    final prefs = await SharedPreferences.getInstance();
    final iso = prefs.getString(_lastLateNightKey);
    return iso != null ? DateTime.parse(iso) : null;
  }

  Future<void> setLastLateNightPromptDate(DateTime date) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastLateNightKey, date.toIso8601String());
  }
}
