import Flutter
import UIKit
import HealthKit
import FBSDKCoreKit
import Firebase
import FirebaseMessaging
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate, MessagingDelegate {

  private let healthStore = HKHealthStore()

  // Dev/CI builds ship without a real GoogleService-Info.plist (see
  // lib/config/firebase_config.dart). FirebaseApp.configure() aborts the app
  // without one, so only touch Firebase when the plist has an app ID.
  private let firebaseConfigured: Bool = {
    guard let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
          let plist = NSDictionary(contentsOfFile: path) else { return false }
    return plist["GOOGLE_APP_ID"] != nil
  }()

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    if firebaseConfigured {
      FirebaseApp.configure()
    }

    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self
      let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
      UNUserNotificationCenter.current().requestAuthorization(
        options: authOptions,
        completionHandler: { _, _ in }
      )
    } else {
      let settings: UIUserNotificationSettings =
        UIUserNotificationSettings(types: [.alert, .badge, .sound], categories: nil)
      application.registerUserNotificationSettings(settings)
    }

    application.registerForRemoteNotifications()
    if firebaseConfigured {
      Messaging.messaging().delegate = self
    }

    // ── Force Facebook SDK initialization BEFORE Flutter ──────────────────
    // SDK v18 ignores Info.plist and reads ATT status directly.
    // We must initialize natively to ensure advertiser ID collection is enabled.
    Settings.shared.isAdvertiserIDCollectionEnabled = true
    Settings.shared.isAutoLogAppEventsEnabled = true
    ApplicationDelegate.shared.application(application, didFinishLaunchingWithOptions: launchOptions)
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // With the UIScene life cycle the Flutter engine is created after launch,
  // so plugins and method channels are registered here, not in didFinishLaunching.
  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    guard let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "com.zyndio.HealthChannels") else {
      return
    }
    let messenger = registrar.messenger()

    // ── Unified Permissions Channel ───────────────────────────────────────────
    // Requests ALL native HealthKit types in a single authorization sheet.
    
    let permChannel = FlutterMethodChannel(
      name: "com.zyndio/permissions",
      binaryMessenger: messenger
    )
    permChannel.setMethodCallHandler { [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
      guard let self = self else { return }
      switch call.method {
      case "requestAllNativePermissions":
        self.requestAllNativePermissions(result: result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    // ── Temperature Channel ──────────────────────────────────────────────────
    let tempChannel = FlutterMethodChannel(
      name: "com.zyndio/temperature",
      binaryMessenger: messenger
    )
    tempChannel.setMethodCallHandler { [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
      guard let self = self else { return }
      switch call.method {
      case "requestPermission":
        self.requestTemperaturePermission(result: result)
      case "getTemperatureHistory":
        let args = call.arguments as? [String: Any]
        let days = args?["days"] as? Int ?? 30
        self.getTemperatureHistory(days: days, result: result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    // ── VO2 Max Channel ──────────────────────────────────────────────────────
    let vo2Channel = FlutterMethodChannel(
      name: "com.zyndio/vo2max",
      binaryMessenger: messenger
    )
    vo2Channel.setMethodCallHandler { [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
      guard let self = self else { return }
      switch call.method {
      case "requestPermission":
        self.requestVo2MaxPermission(result: result)
      case "getVo2Max":
        self.getVo2Max(result: result)
      case "getVo2MaxHistory":
        let args = call.arguments as? [String: Any]
        let days = args?["days"] as? Int ?? 30
        self.getVo2MaxHistory(days: days, result: result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    // ── HRR Channel ──────────────────────────────────────────────────────────
    let hrrChannel = FlutterMethodChannel(
      name: "com.zyndio/hrr",
      binaryMessenger: messenger
    )
    hrrChannel.setMethodCallHandler { [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
      guard let self = self else { return }
      switch call.method {
      case "requestPermission":
        self.requestHrrPermission(result: result)
      case "getHrr":
        self.getHrr(result: result)
      case "getHrrHistory":
        let args = call.arguments as? [String: Any]
        let days = args?["days"] as? Int ?? 30
        self.getHrrHistory(days: days, result: result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    // ── Vitals Channel ───────────────────────────────────────────────────────
    let vitalsChannel = FlutterMethodChannel(
      name: "com.zyndio/vitals",
      binaryMessenger: messenger
    )
    vitalsChannel.setMethodCallHandler { [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
      guard let self = self else { return }
      switch call.method {
      case "getRespiratoryRate":
        let args = call.arguments as? [String: Any]
        let days = args?["days"] as? Int ?? 30
        self.getRespiratoryRateData(days: days, result: result)
      case "getRespiratoryRateHistory":
        let args = call.arguments as? [String: Any]
        let days = args?["days"] as? Int ?? 30
        self.getRespiratoryRateHistory(days: days, result: result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    // ── Branding Channel ──────────────────────────────────────────────────────
    let brandingChannel = FlutterMethodChannel(
      name: "com.zyndio/branding",
      binaryMessenger: messenger
    )
    brandingChannel.setMethodCallHandler { [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
      guard let self = self else { return }
      switch call.method {
      case "setAlternateIconName":
        self.setAlternateIconName(call: call, result: result)
      case "getAlternateIconName":
        DispatchQueue.main.async {
          result(UIApplication.shared.alternateIconName)
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  // ═══════════════════════════════════════════════════════
  // UNIFIED PERMISSIONS (ALL native types in one sheet)
  // ═══════════════════════════════════════════════════════

  private func requestAllNativePermissions(result: @escaping FlutterResult) {
    guard HKHealthStore.isHealthDataAvailable() else {
      result(false)
      return
    }

    var readTypes: Set<HKObjectType> = []

    let quantityTypes: [HKQuantityTypeIdentifier] = [
      .stepCount,
      .heartRate,
      .activeEnergyBurned,
      .basalEnergyBurned,
      .distanceWalkingRunning,
      .flightsClimbed,
      .height,
      .bodyMass,
      .bodyMassIndex,
      .bodyFatPercentage,
      .bodyTemperature,
      .heartRateVariabilitySDNN,
      .restingHeartRate,
      .vo2Max,
      .bloodGlucose,
      .oxygenSaturation,
      .bloodPressureDiastolic,
      .bloodPressureSystolic,
      .dietaryWater,
      .respiratoryRate
    ]

    for identifier in quantityTypes {
      if let type = HKObjectType.quantityType(forIdentifier: identifier) {
        readTypes.insert(type)
      }
    }

    let categoryTypes: [HKCategoryTypeIdentifier] = [
      .sleepAnalysis,
      .menstrualFlow
    ]

    for identifier in categoryTypes {
      if let type = HKObjectType.categoryType(forIdentifier: identifier) {
        readTypes.insert(type)
      }
    }

    readTypes.insert(HKObjectType.workoutType())

    if #available(iOS 16.0, *) {
      let v16Identifiers: [HKQuantityTypeIdentifier] = [
        .appleSleepingWristTemperature,
        .heartRateRecoveryOneMinute
      ]
      for identifier in v16Identifiers {
        if let type = HKObjectType.quantityType(forIdentifier: identifier) {
          readTypes.insert(type)
        }
      }
    }

    if readTypes.isEmpty {
      result(true)
      return
    }

    healthStore.requestAuthorization(toShare: nil, read: readTypes) { success, error in
      DispatchQueue.main.async { result(success) }
    }
  }

  // ═══════════════════════════════════════════════════════
  // TEMPERATURE
  // ═══════════════════════════════════════════════════════


  private func requestTemperaturePermission(result: @escaping FlutterResult) {
    guard HKHealthStore.isHealthDataAvailable() else {
      result(false)
      return
    }

    var readTypes: Set<HKObjectType> = []

    // Apple Watch Series 8+ wrist temperature (deviation from baseline)
    if #available(iOS 16.0, *) {
      if let wristTempType = HKObjectType.quantityType(forIdentifier: .appleSleepingWristTemperature) {
        readTypes.insert(wristTempType)
      }
    }
    // Body temperature (absolute, e.g. from thermometer manual entry or 3rd party)
    if let bodyTempType = HKObjectType.quantityType(forIdentifier: .bodyTemperature) {
      readTypes.insert(bodyTempType)
    }

    if readTypes.isEmpty {
      result(false)
      return
    }

    healthStore.requestAuthorization(toShare: nil, read: readTypes) { success, _ in
      DispatchQueue.main.async { result(success) }
    }
  }

  private func getTemperatureHistory(days: Int, result: @escaping FlutterResult) {
    guard HKHealthStore.isHealthDataAvailable() else {
      result([])
      return
    }

    let group = DispatchGroup()
    var entries: [[String: Any]] = []
    let lock = NSLock()

    let endDate = Date()
    let startDate = Calendar.current.date(byAdding: .day, value: -days, to: endDate) ?? endDate

    // 1. Try appleSleepingWristTemperature (deviation °C, iOS 16+)
    if #available(iOS 16.0, *) {
      if let wristType = HKQuantityType.quantityType(forIdentifier: .appleSleepingWristTemperature) {
        group.enter()
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        let sortDesc = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
        let query = HKSampleQuery(sampleType: wristType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sortDesc]) { _, samples, _ in
          defer { group.leave() }
          guard let hwSamples = samples as? [HKQuantitySample] else { return }
          lock.lock()
          for s in hwSamples {
            // appleSleepingWristTemperature is a delta (deviation). 
            // Convert to approximate absolute by using 36.5°C baseline + deviation.
            let deviation = s.quantity.doubleValue(for: HKUnit.degreeCelsius())
            let absoluteTemp = 36.5 + deviation
            let isoDate = ISO8601DateFormatter().string(from: s.startDate)
            entries.append(["value": absoluteTemp, "date": isoDate, "source": "wristTemperature"])
          }
          lock.unlock()
        }
        healthStore.execute(query)
      }
    }

    // 2. Try bodyTemperature (absolute °C)
    if let bodyType = HKQuantityType.quantityType(forIdentifier: .bodyTemperature) {
      group.enter()
      let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
      let sortDesc = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
      let query = HKSampleQuery(sampleType: bodyType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sortDesc]) { _, samples, _ in
        defer { group.leave() }
        guard let bodySamples = samples as? [HKQuantitySample] else { return }
        lock.lock()
        for s in bodySamples {
          let temp = s.quantity.doubleValue(for: HKUnit.degreeCelsius())
          // Filter clearly invalid values (below 30°C or above 42°C)
          if temp >= 30 && temp <= 42 {
            let isoDate = ISO8601DateFormatter().string(from: s.startDate)
            entries.append(["value": temp, "date": isoDate, "source": "bodyTemperature"])
          }
        }
        lock.unlock()
      }
      healthStore.execute(query)
    }

    group.notify(queue: .main) {
      // Sort by date ascending
      let sorted = entries.sorted {
        let d1 = ($0["date"] as? String) ?? ""
        let d2 = ($1["date"] as? String) ?? ""
        return d1 < d2
      }
      result(sorted)
    }
  }

  // ═══════════════════════════════════════════════════════
  // VO2 MAX
  // ═══════════════════════════════════════════════════════

  private func requestVo2MaxPermission(result: @escaping FlutterResult) {
    guard HKHealthStore.isHealthDataAvailable(),
          let vo2Type = HKObjectType.quantityType(forIdentifier: .vo2Max) else {
      result(false)
      return
    }
    healthStore.requestAuthorization(toShare: nil, read: [vo2Type]) { success, _ in
      DispatchQueue.main.async { result(success) }
    }
  }

  private func getVo2Max(result: @escaping FlutterResult) {
    guard HKHealthStore.isHealthDataAvailable(),
          let vo2Type = HKQuantityType.quantityType(forIdentifier: .vo2Max) else {
      result(nil)
      return
    }
    let sortDesc = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
    let query = HKSampleQuery(sampleType: vo2Type, predicate: nil, limit: 1, sortDescriptors: [sortDesc]) { _, samples, _ in
      guard let sample = samples?.first as? HKQuantitySample else {
        DispatchQueue.main.async { result(nil) }
        return
      }
      let unit = HKUnit(from: "ml/kg*min")
      let value = sample.quantity.doubleValue(for: unit)
      let isoDate = ISO8601DateFormatter().string(from: sample.startDate)
      DispatchQueue.main.async { result(["value": value, "date": isoDate]) }
    }
    healthStore.execute(query)
  }

  private func getVo2MaxHistory(days: Int, result: @escaping FlutterResult) {
    guard HKHealthStore.isHealthDataAvailable(),
          let vo2Type = HKQuantityType.quantityType(forIdentifier: .vo2Max) else {
      result([])
      return
    }
    let endDate = Date()
    let startDate = Calendar.current.date(byAdding: .day, value: -days, to: endDate) ?? endDate
    let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
    let sortDesc = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
    let query = HKSampleQuery(sampleType: vo2Type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sortDesc]) { _, samples, _ in
      let unit = HKUnit(from: "ml/kg*min")
      let entries: [[String: Any]] = (samples as? [HKQuantitySample] ?? []).map { s in
        let value = s.quantity.doubleValue(for: unit)
        let isoDate = ISO8601DateFormatter().string(from: s.startDate)
        return ["value": value, "date": isoDate]
      }
      DispatchQueue.main.async { result(entries) }
    }
    healthStore.execute(query)
  }

  // ═══════════════════════════════════════════════════════
  // HRR (Heart Rate Recovery)
  // ═══════════════════════════════════════════════════════

  private func requestHrrPermission(result: @escaping FlutterResult) {
    guard HKHealthStore.isHealthDataAvailable(),
          let hrType = HKObjectType.quantityType(forIdentifier: .heartRate) else {
      result(false)
      return
    }
    healthStore.requestAuthorization(toShare: nil, read: [hrType]) { success, _ in
      DispatchQueue.main.async { result(success) }
    }
  }

  private func getHrr(result: @escaping FlutterResult) {
    guard HKHealthStore.isHealthDataAvailable(),
          let hrType = HKQuantityType.quantityType(forIdentifier: .heartRate) else {
      result(nil)
      return
    }
    let endDate = Date()
    let startDate = Calendar.current.date(byAdding: .day, value: -7, to: endDate) ?? endDate
    let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
    let sortDesc = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
    let query = HKSampleQuery(sampleType: hrType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sortDesc]) { _, samples, _ in
      guard let hrSamples = samples as? [HKQuantitySample], hrSamples.count >= 2 else {
        DispatchQueue.main.async { result(nil) }
        return
      }
      // Simple HRR: peak HR - HR 1 min after
      let beatsPerMin = HKUnit(from: "count/min")
      var peakHr: Double = 0
      var peakIdx = 0
      for (i, s) in hrSamples.enumerated() {
        let hr = s.quantity.doubleValue(for: beatsPerMin)
        if hr > peakHr { peakHr = hr; peakIdx = i }
      }
      let peakDate = hrSamples[peakIdx].startDate
      // Find reading ~60 seconds after peak
      var recoveryHr: Double?
      for s in hrSamples[(peakIdx + 1)...] {
        let secAfter = s.startDate.timeIntervalSince(peakDate)
        if secAfter >= 45 && secAfter <= 120 {
          recoveryHr = s.quantity.doubleValue(for: beatsPerMin)
          break
        }
      }
      if let rHr = recoveryHr {
        let hrrValue = peakHr - rHr
        DispatchQueue.main.async { result(["value": hrrValue]) }
      } else {
        DispatchQueue.main.async { result(nil) }
      }
    }
    healthStore.execute(query)
  }

  private func getHrrHistory(days: Int, result: @escaping FlutterResult) {
    guard HKHealthStore.isHealthDataAvailable(),
          let hrType = HKObjectType.quantityType(forIdentifier: .heartRate) else {
      result([])
      return
    }
    let endDate = Date()
    let startDate = Calendar.current.date(byAdding: .day, value: -days, to: endDate) ?? endDate
    let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
    let sortDesc = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
    
    let query = HKSampleQuery(sampleType: hrType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sortDesc]) { _, samples, _ in
      guard let hrSamples = samples as? [HKQuantitySample], hrSamples.count >= 2 else {
        DispatchQueue.main.async { result([]) }
        return
      }
      
      var history: [[String: Any]] = []
      let beatsPerMin = HKUnit(from: "count/min")
      let isoFormatter = ISO8601DateFormatter()
      
      // Look for recovery events: a peak > 100 followed by a drop 45-120s later
      var i = 1
      while i < (hrSamples.count - 1) {
        let prev = hrSamples[i-1].quantity.doubleValue(for: beatsPerMin)
        let curr = hrSamples[i].quantity.doubleValue(for: beatsPerMin)
        let next = hrSamples[i+1].quantity.doubleValue(for: beatsPerMin)
        
        if curr > 100 && curr > prev && curr >= next {
          let peakDate = hrSamples[i].startDate
          // Find first reading 45-120s after
          for j in (i+1)..<hrSamples.count {
            let secAfter = hrSamples[j].startDate.timeIntervalSince(peakDate)
            if secAfter > 120 { break }
            if secAfter >= 45 {
              let recoveryHr = hrSamples[j].quantity.doubleValue(for: beatsPerMin)
              let drop = curr - recoveryHr
              if drop > 5 { // Only record meaningful drops
                history.append([
                  "value": drop,
                  "date": isoFormatter.string(from: peakDate),
                  "peakHR": curr,
                  "recoveryHR": recoveryHr
                ])
                // Skip ahead at least 5 mins to avoid double-counting the same workout session
                let fiveMinsAfter = peakDate.addingTimeInterval(300)
                while i < hrSamples.count && hrSamples[i].startDate < fiveMinsAfter {
                  i += 1
                }
              }
              break
            }
          }
        }
        i += 1
      }
      DispatchQueue.main.async { result(history) }
    }
    healthStore.execute(query)
  }

  // ═══════════════════════════════════════════════════════
  // VITALS
  // ═══════════════════════════════════════════════════════

  private func getRespiratoryRateData(days: Int, result: @escaping FlutterResult) {
    self.getRespiratoryRateHistory(days: days, limit: 1, result: result)
  }

  private func getRespiratoryRateHistory(days: Int, limit: Int = HKObjectQueryNoLimit, result: @escaping FlutterResult) {
    guard HKHealthStore.isHealthDataAvailable(),
          let rrType = HKObjectType.quantityType(forIdentifier: .respiratoryRate) else {
      result(limit == 1 ? nil : [])
      return
    }

    let endDate = Date()
    let startDate = Calendar.current.date(byAdding: .day, value: -days, to: endDate)!
    let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
    let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)

    let query = HKSampleQuery(sampleType: rrType, predicate: predicate, limit: limit, sortDescriptors: [sort]) { _, samples, _ in
      DispatchQueue.main.async {
        let rrSamples = samples as? [HKQuantitySample] ?? []
        let formatter = ISO8601DateFormatter()
        let unit = HKUnit.count().unitDivided(by: .minute())
        
        let out: [[String: Any]] = rrSamples.map { s in
          [
            "value": s.quantity.doubleValue(for: unit),
            "date": formatter.string(from: s.endDate),
            "source": s.sourceRevision.source.name
          ]
        }
        
        if limit == 1 {
          result(out.first)
        } else {
          result(out)
        }
      }
    }
    healthStore.execute(query)
  }

  // ═══════════════════════════════════════════════════════
  // BRANDING (Dynamic Icons)
  // ═══════════════════════════════════════════════════════

  private func setAlternateIconName(call: FlutterMethodCall, result: @escaping FlutterResult) {
    if #available(iOS 10.3, *) {
      guard UIApplication.shared.supportsAlternateIcons else {
        result(FlutterError(code: "UNSUPPORTED", message: "Alternate icons not supported", details: nil))
        return
      }
      
      let args = call.arguments as? [String: Any]
      let iconName = args?["iconName"] as? String
      
      UIApplication.shared.setAlternateIconName(iconName) { error in
        if let error = error {
          result(FlutterError(code: "ERROR", message: error.localizedDescription, details: nil))
        } else {
          result(nil)
        }
      }
    } else {
      result(FlutterError(code: "UNAVAILABLE", message: "Requires iOS 10.3+", details: nil))
    }
  }

  // ═══════════════════════════════════════════════════════
  // FIREBASE MESSAGING DELEGATE
  // ═══════════════════════════════════════════════════════

  func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
    debugPrint("Firebase registration token: \(String(describing: fcmToken))")
    let dataDict: [String: String] = ["token": fcmToken ?? ""]
    NotificationCenter.default.post(
      name: Notification.Name("FCMToken"),
      object: nil,
      userInfo: dataDict
    )
  }
  
  override func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    if firebaseConfigured {
      Messaging.messaging().apnsToken = deviceToken
    }
    super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
  }
}

