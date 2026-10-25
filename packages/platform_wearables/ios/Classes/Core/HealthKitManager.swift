import Foundation
import HealthKit

public class BrandHealthKitManager {
    private let healthStore = HKHealthStore()
    
    public init() {}
    
    public static var isAvailable: Bool {
        return HKHealthStore.isHealthDataAvailable()
    }
    
    private var allReadTypes: Set<HKObjectType> {
        return [
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
            HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!,
            HKObjectType.quantityType(forIdentifier: .restingHeartRate)!,
            HKObjectType.quantityType(forIdentifier: .oxygenSaturation)!,
            HKObjectType.quantityType(forIdentifier: .bloodGlucose)!,
            HKObjectType.quantityType(forIdentifier: .respiratoryRate)!,
            HKObjectType.quantityType(forIdentifier: .stepCount)!,
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)!,
            HKObjectType.quantityType(forIdentifier: .flightsClimbed)!,
            HKObjectType.quantityType(forIdentifier: .bodyMass)!,
            HKObjectType.quantityType(forIdentifier: .height)!,
            HKObjectType.quantityType(forIdentifier: .bodyMassIndex)!,
            HKObjectType.quantityType(forIdentifier: .bodyFatPercentage)!,
            HKObjectType.quantityType(forIdentifier: .bodyTemperature)!,
            HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!,
            HKObjectType.workoutType()
        ]
    }
    
    public func requestAuthorization() async throws -> Bool {
        guard Self.isAvailable else { return false }
        try await healthStore.requestAuthorization(toShare: [], read: allReadTypes)
        return true
    }
    
    public func getSourceApp(for sample: HKSample) -> String {
        return sample.sourceRevision.source.bundleIdentifier
    }
    
    public func getSleepSessions(from start: Date, to end: Date) async throws -> [BrandSleepSession] {
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
        let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
        
        let samples = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[HKSample], Error>) in
            let query = HKSampleQuery(sampleType: sleepType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sortDescriptor]) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: samples ?? [])
                }
            }
            healthStore.execute(query)
        }
        
        guard let sleepSamples = samples as? [HKCategorySample] else { return [] }
        
        // Simple grouping by start/end overlapping, in reality this needs complex session grouping.
        // For demonstration, mapping individual samples to sessions or keeping it simplified.
        var sessions: [BrandSleepSession] = []
        for sample in sleepSamples {
            let value = sample.value
            var light = 0, deep = 0, rem = 0, awake = 0
            let duration = Int(sample.endDate.timeIntervalSince(sample.startDate))
            
            if #available(iOS 16.0, *) {
                switch value {
                case HKCategoryValueSleepAnalysis.asleepCore.rawValue: light = duration
                case HKCategoryValueSleepAnalysis.asleepDeep.rawValue: deep = duration
                case HKCategoryValueSleepAnalysis.asleepREM.rawValue: rem = duration
                case HKCategoryValueSleepAnalysis.awake.rawValue: awake = duration
                default: light = duration
                }
            } else {
                switch value {
                case HKCategoryValueSleepAnalysis.asleep.rawValue: light = duration
                case HKCategoryValueSleepAnalysis.awake.rawValue: awake = duration
                default: light = duration
                }
            }
            
            let session = BrandSleepSession(
                id: sample.uuid.uuidString,
                source: BrandSource(provider: "healthKit", deviceName: getSourceApp(for: sample)),
                bedtime: sample.startDate,
                wakeTime: sample.endDate,
                totalSleepSec: duration,
                deepSleepSec: deep,
                remSleepSec: rem,
                lightSleepSec: light,
                awakeSec: awake,
                efficiency: 0.0,
                sleepScore: nil,
                latencySec: nil,
                avgHeartRate: nil,
                avgHrv: nil,
                respiratoryRate: nil,
                recordedAt: Date()
            )
            sessions.append(session)
        }
        return sessions
    }
    
    public func getHeartRate(from start: Date, to end: Date) async throws -> [BrandHeartRateSample] {
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
        let type = HKObjectType.quantityType(forIdentifier: .heartRate)!
        
        let samples = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[HKSample], Error>) in
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sortDescriptor]) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: samples ?? [])
                }
            }
            healthStore.execute(query)
        }
        
        guard let quantitySamples = samples as? [HKQuantitySample] else { return [] }
        return quantitySamples.map { sample in
            BrandHeartRateSample(
                id: sample.uuid.uuidString,
                source: BrandSource(provider: "healthKit", deviceName: getSourceApp(for: sample)),
                timestamp: sample.startDate,
                bpm: sample.quantity.doubleValue(for: HKUnit(from: "count/min")),
                context: .unknown
            )
        }
    }
    
    public func getHRV(from start: Date, to end: Date) async throws -> [BrandHrvReading] {
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
        let type = HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!
        
        let samples = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[HKSample], Error>) in
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sortDescriptor]) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: samples ?? [])
                }
            }
            healthStore.execute(query)
        }
        
        guard let quantitySamples = samples as? [HKQuantitySample] else { return [] }
        return quantitySamples.map { sample in
            BrandHrvReading(
                id: sample.uuid.uuidString,
                source: BrandSource(provider: "healthKit", deviceName: getSourceApp(for: sample)),
                timestamp: sample.startDate,
                rmssd: nil,
                sdnn: sample.quantity.doubleValue(for: HKUnit.secondUnit(with: .milli)),
                context: .unknown,
                recordedAt: Date()
            )
        }
    }
    
    public func getSpO2(from start: Date, to end: Date) async throws -> [BrandSpO2Reading] {
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
        let type = HKObjectType.quantityType(forIdentifier: .oxygenSaturation)!
        
        let samples = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[HKSample], Error>) in
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sortDescriptor]) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: samples ?? [])
                }
            }
            healthStore.execute(query)
        }
        
        guard let quantitySamples = samples as? [HKQuantitySample] else { return [] }
        return quantitySamples.map { sample in
            BrandSpO2Reading(
                id: sample.uuid.uuidString,
                source: BrandSource(provider: "healthKit", deviceName: getSourceApp(for: sample)),
                timestamp: sample.startDate,
                percent: sample.quantity.doubleValue(for: HKUnit.percent()) * 100.0,
                context: .spotCheck,
                recordedAt: Date()
            )
        }
    }
    
    public func getActivity(from start: Date, to end: Date) async throws -> [BrandActivitySummary] {
        // Mock implementation using sample query, proper implementation uses HKStatisticsCollectionQuery
        // For simplicity returning an empty array or fetching samples.
        return []
    }
    
    public func getWorkouts(from start: Date, to end: Date) async throws -> [BrandWorkoutSession] {
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
        let type = HKObjectType.workoutType()
        
        let samples = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[HKSample], Error>) in
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sortDescriptor]) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: samples ?? [])
                }
            }
            healthStore.execute(query)
        }
        
        guard let workoutSamples = samples as? [HKWorkout] else { return [] }
        return workoutSamples.map { sample in
            let wType: WorkoutType
            switch sample.workoutActivityType {
            case .running: wType = .run
            case .cycling: wType = .cycle
            case .swimming: wType = .swim
            case .traditionalStrengthTraining: wType = .strength
            case .yoga: wType = .yoga
            case .highIntensityIntervalTraining: wType = .hiit
            case .walking: wType = .walk
            case .hiking: wType = .hike
            default: wType = .other
            }
            
            return BrandWorkoutSession(
                id: sample.uuid.uuidString,
                source: BrandSource(provider: "healthKit", deviceName: getSourceApp(for: sample)),
                type: wType,
                startTime: sample.startDate,
                endTime: sample.endDate,
                durationSec: Int(sample.duration),
                caloriesBurned: sample.totalEnergyBurned?.doubleValue(for: HKUnit.kilocalorie()),
                distanceMeters: sample.totalDistance?.doubleValue(for: HKUnit.meter()),
                avgHeartRate: nil,
                maxHeartRate: nil,
                recordedAt: Date()
            )
        }
    }
    
    public func getBodyMeasurements(from start: Date, to end: Date) async throws -> [BrandBodyMeasurement] {
        return []
    }
    
    public func getGlucose(from start: Date, to end: Date) async throws -> [BrandGlucoseReading] {
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
        let type = HKObjectType.quantityType(forIdentifier: .bloodGlucose)!
        
        let samples = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[HKSample], Error>) in
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sortDescriptor]) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: samples ?? [])
                }
            }
            healthStore.execute(query)
        }
        
        guard let quantitySamples = samples as? [HKQuantitySample] else { return [] }
        let unit = HKUnit(from: "mg/dL")
        return quantitySamples.map { sample in
            BrandGlucoseReading(
                id: sample.uuid.uuidString,
                source: BrandSource(provider: "healthKit", deviceName: getSourceApp(for: sample)),
                timestamp: sample.startDate,
                valueMgDl: sample.quantity.doubleValue(for: unit),
                trend: nil,
                recordedAt: Date()
            )
        }
    }
}
