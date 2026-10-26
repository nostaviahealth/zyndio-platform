import Flutter
import UIKit
import HealthKit

class SceneDelegate: FlutterSceneDelegate {
  private let healthStore = HKHealthStore()

  override func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
    super.scene(scene, willConnectTo: session, options: connectionOptions)

    guard let windowScene = scene as? UIWindowScene,
          let flutterViewController = windowScene.windows.first?.rootViewController as? FlutterViewController else {
      return
    }

    // VO2 Max channel
    let vo2Channel = FlutterMethodChannel(name: "com.zyndio/vo2max", binaryMessenger: flutterViewController.binaryMessenger)
    vo2Channel.setMethodCallHandler { [weak self] (call, result) in
      guard let self = self else { return }
      switch call.method {
      case "getVo2Max":
        self.getVo2Max(result: result)
      case "getVo2MaxHistory":
        let args = call.arguments as? [String: Any]
        let days = args?["days"] as? Int ?? 30
        self.getVo2MaxHistory(days: days, result: result)
      case "requestPermission":
        self.requestVo2MaxPermission(result: result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    // HRR (Heart Rate Recovery) channel
    let hrrChannel = FlutterMethodChannel(name: "com.zyndio/hrr", binaryMessenger: flutterViewController.binaryMessenger)
    hrrChannel.setMethodCallHandler { [weak self] (call, result) in
      guard let self = self else { return }
      switch call.method {
      case "getHrr":
        self.getHrr(result: result)
      case "requestPermission":
        self.requestHrrPermission(result: result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    // Temperature channel
    let tempChannel = FlutterMethodChannel(name: "com.zyndio/temperature", binaryMessenger: flutterViewController.binaryMessenger)
    tempChannel.setMethodCallHandler { [weak self] (call, result) in
      guard let self = self else { return }
      switch call.method {
      case "getTemperatureHistory":
        let args = call.arguments as? [String: Any]
        let days = args?["days"] as? Int ?? 30
        self.getTemperatureHistory(days: days, result: result)
      case "requestPermission":
        self.requestTemperaturePermission(result: result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  // MARK: - VO2 Max

  private func requestVo2MaxPermission(result: @escaping FlutterResult) {
    guard HKHealthStore.isHealthDataAvailable(),
          let vo2MaxType = HKObjectType.quantityType(forIdentifier: .vo2Max) else {
      result(false)
      return
    }
    healthStore.requestAuthorization(toShare: nil, read: [vo2MaxType]) { success, _ in
      DispatchQueue.main.async { result(success) }
    }
  }

  private func getVo2Max(result: @escaping FlutterResult) {
    guard HKHealthStore.isHealthDataAvailable(),
          let vo2MaxType = HKObjectType.quantityType(forIdentifier: .vo2Max) else {
      result(nil)
      return
    }

    let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
    let query = HKSampleQuery(sampleType: vo2MaxType, predicate: nil, limit: 1, sortDescriptors: [sort]) { _, samples, _ in
      DispatchQueue.main.async {
        guard let sample = samples?.first as? HKQuantitySample else { result(nil); return }
        let formatter = ISO8601DateFormatter()
        result([
          "value": sample.quantity.doubleValue(for: HKUnit(from: "ml/kg*min")),
          "date": formatter.string(from: sample.endDate),
          "source": sample.sourceRevision.source.name
        ])
      }
    }
    healthStore.execute(query)
  }

  private func getVo2MaxHistory(days: Int, result: @escaping FlutterResult) {
    guard HKHealthStore.isHealthDataAvailable(),
          let vo2MaxType = HKObjectType.quantityType(forIdentifier: .vo2Max) else {
      result([])
      return
    }

    let endDate = Date()
    let startDate = Calendar.current.date(byAdding: .day, value: -days, to: endDate)!
    let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
    let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: true)

    let query = HKSampleQuery(sampleType: vo2MaxType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sort]) { _, samples, _ in
      DispatchQueue.main.async {
        guard let samples = samples as? [HKQuantitySample] else { result([]); return }
        let formatter = ISO8601DateFormatter()
        result(samples.map { s in
          ["value": s.quantity.doubleValue(for: HKUnit(from: "ml/kg*min")),
           "date": formatter.string(from: s.endDate),
           "source": s.sourceRevision.source.name]
        })
      }
    }
    healthStore.execute(query)
  }

  // MARK: - HRR (Heart Rate Recovery)

  private func requestHrrPermission(result: @escaping FlutterResult) {
    guard HKHealthStore.isHealthDataAvailable() else { result(false); return }

    var typesToRead: Set<HKObjectType> = []
    // heartRateRecoveryOneMinute is iOS 16+
    if #available(iOS 16.0, *) {
      if let hrrType = HKObjectType.quantityType(forIdentifier: .heartRateRecoveryOneMinute) {
        typesToRead.insert(hrrType)
      }
    }
    // Also request heart rate + workouts as fallback
    if let hrType = HKObjectType.quantityType(forIdentifier: .heartRate) {
      typesToRead.insert(hrType)
    }
    typesToRead.insert(HKObjectType.workoutType())

    healthStore.requestAuthorization(toShare: nil, read: typesToRead) { success, _ in
      DispatchQueue.main.async { result(success) }
    }
  }

  private func getHrr(result: @escaping FlutterResult) {
    guard HKHealthStore.isHealthDataAvailable() else { result(nil); return }

    // Try native HRR first (iOS 16+)
    if #available(iOS 16.0, *) {
      if let hrrType = HKObjectType.quantityType(forIdentifier: .heartRateRecoveryOneMinute) {
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        let query = HKSampleQuery(sampleType: hrrType, predicate: nil, limit: 1, sortDescriptors: [sort]) { [weak self] _, samples, _ in
          if let sample = samples?.first as? HKQuantitySample {
            let hrrValue = sample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
            let formatter = ISO8601DateFormatter()
            DispatchQueue.main.async {
              result([
                "value": hrrValue,
                "date": formatter.string(from: sample.endDate),
                "source": sample.sourceRevision.source.name,
                "method": "native"
              ])
            }
          } else {
            // Fallback: compute from workout HR data
            self?.computeHrrFromWorkout(result: result)
          }
        }
        healthStore.execute(query)
        return
      }
    }

    // Fallback for iOS < 16: compute from workout HR data
    computeHrrFromWorkout(result: result)
  }

  /// Compute HRR from the most recent workout's heart rate data.
  /// HRR = peak HR during last 5min of workout - HR at 1min post-workout
  private func computeHrrFromWorkout(result: @escaping FlutterResult) {
    let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
    let query = HKSampleQuery(sampleType: HKObjectType.workoutType(), predicate: nil, limit: 1, sortDescriptors: [sort]) { [weak self] _, samples, _ in
      guard let self = self, let workout = samples?.first as? HKWorkout else {
        DispatchQueue.main.async { result(nil) }
        return
      }

      guard let hrType = HKObjectType.quantityType(forIdentifier: .heartRate) else {
        DispatchQueue.main.async { result(nil) }
        return
      }

      // Get HR from last 5min of workout and 2min after
      let fiveMinBefore = workout.endDate.addingTimeInterval(-300)
      let twoMinAfter = workout.endDate.addingTimeInterval(120)
      let predicate = HKQuery.predicateForSamples(withStart: fiveMinBefore, end: twoMinAfter, options: .strictStartDate)
      let hrSort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: true)

      let hrQuery = HKSampleQuery(sampleType: hrType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [hrSort]) { _, hrSamples, _ in
        DispatchQueue.main.async {
          guard let hrSamples = hrSamples as? [HKQuantitySample], hrSamples.count >= 2 else {
            result(nil)
            return
          }

          let bpmUnit = HKUnit.count().unitDivided(by: .minute())

          // Find peak HR during workout (before end)
          var peakHR: Double = 0
          for s in hrSamples where s.endDate <= workout.endDate {
            let hr = s.quantity.doubleValue(for: bpmUnit)
            if hr > peakHR { peakHR = hr }
          }

          // Find HR closest to 1min after workout end
          let targetTime = workout.endDate.addingTimeInterval(60)
          var recoveryHR: Double? = nil
          var closestDiff: TimeInterval = .greatestFiniteMagnitude
          for s in hrSamples where s.endDate > workout.endDate {
            let diff = abs(s.endDate.timeIntervalSince(targetTime))
            if diff < closestDiff {
              closestDiff = diff
              recoveryHR = s.quantity.doubleValue(for: bpmUnit)
            }
          }

          guard peakHR > 0, let recHR = recoveryHR else {
            result(nil)
            return
          }

          let hrrValue = peakHR - recHR
          let formatter = ISO8601DateFormatter()
          result([
            "value": hrrValue,
            "date": formatter.string(from: workout.endDate),
            "source": workout.sourceRevision.source.name,
            "method": "computed",
            "peakHR": peakHR,
            "recoveryHR": recHR
          ])
        }
      }
      self.healthStore.execute(hrQuery)
    }
    healthStore.execute(query)
  }

  // MARK: - Temperature

  private func requestTemperaturePermission(result: @escaping FlutterResult) {
    guard HKHealthStore.isHealthDataAvailable() else { result(false); return }

    var typesToRead: Set<HKObjectType> = []
    if #available(iOS 16.0, *) {
      if let tempType = HKObjectType.quantityType(forIdentifier: .appleSleepingWristTemperature) {
        typesToRead.insert(tempType)
      }
    }
    if let bodyTempType = HKObjectType.quantityType(forIdentifier: .bodyTemperature) {
        typesToRead.insert(bodyTempType)
    }

    healthStore.requestAuthorization(toShare: nil, read: typesToRead) { success, _ in
      DispatchQueue.main.async { result(success) }
    }
  }

  private func getTemperatureHistory(days: Int, result: @escaping FlutterResult) {
    guard HKHealthStore.isHealthDataAvailable() else { result([]); return }

    var tempType: HKQuantityType? = nil
    var isDeviation = false

    // Prefer wrist temp (iOS 16+)
    if #available(iOS 16.0, *) {
      if let type = HKQuantityType.quantityType(forIdentifier: .appleSleepingWristTemperature) {
        tempType = type
        isDeviation = true
      }
    }
    
    // Fallback to body temp
    if tempType == nil {
        tempType = HKQuantityType.quantityType(forIdentifier: .bodyTemperature)
        isDeviation = false
    }

    guard let targetType = tempType else { result([]); return }

    let endDate = Date()
    let startDate = Calendar.current.date(byAdding: .day, value: -days, to: endDate)!
    let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
    let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: true)

    let query = HKSampleQuery(sampleType: targetType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sort]) { _, samples, _ in
      DispatchQueue.main.async {
        guard let samples = samples as? [HKQuantitySample] else { result([]); return }
        let formatter = ISO8601DateFormatter()
        let unit = HKUnit.degreeCelsius()
        
        let out: [[String: Any]] = samples.map { s in
          let raw = s.quantity.doubleValue(for: unit)
          let finalVal = isDeviation ? (36.5 + raw) : raw
          return [
           "value": finalVal,
           "date": formatter.string(from: s.endDate),
           "source": s.sourceRevision.source.name
          ]
        }
        result(out)
      }
    }
    healthStore.execute(query)
  }
}
