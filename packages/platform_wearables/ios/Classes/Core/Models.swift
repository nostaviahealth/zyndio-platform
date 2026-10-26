import Foundation

public struct BrandSource: Codable {
    public let provider: String
    public let deviceName: String?
    
    public init(provider: String, deviceName: String?) {
        self.provider = provider
        self.deviceName = deviceName
    }
    
    public func toDictionary() -> [String: Any?] {
        return ["provider": provider, "deviceName": deviceName]
    }
}

public struct BrandSleepSession: Codable {
    public let id: String
    public let source: BrandSource
    public let bedtime: Date
    public let wakeTime: Date
    public let totalSleepSec: Int
    public let deepSleepSec: Int
    public let remSleepSec: Int
    public let lightSleepSec: Int
    public let awakeSec: Int
    public let efficiency: Double
    public let sleepScore: Int?
    public let latencySec: Int?
    public let avgHeartRate: Double?
    public let avgHrv: Double?
    public let respiratoryRate: Double?
    public let recordedAt: Date
    
    public init(id: String, source: BrandSource, bedtime: Date, wakeTime: Date, totalSleepSec: Int, deepSleepSec: Int, remSleepSec: Int, lightSleepSec: Int, awakeSec: Int, efficiency: Double, sleepScore: Int?, latencySec: Int?, avgHeartRate: Double?, avgHrv: Double?, respiratoryRate: Double?, recordedAt: Date) {
        self.id = id
        self.source = source
        self.bedtime = bedtime
        self.wakeTime = wakeTime
        self.totalSleepSec = totalSleepSec
        self.deepSleepSec = deepSleepSec
        self.remSleepSec = remSleepSec
        self.lightSleepSec = lightSleepSec
        self.awakeSec = awakeSec
        self.efficiency = efficiency
        self.sleepScore = sleepScore
        self.latencySec = latencySec
        self.avgHeartRate = avgHeartRate
        self.avgHrv = avgHrv
        self.respiratoryRate = respiratoryRate
        self.recordedAt = recordedAt
    }
    
    public func toDictionary() -> [String: Any?] {
        return [
            "id": id,
            "source": source.toDictionary(),
            "bedtime": Int(bedtime.timeIntervalSince1970 * 1000),
            "wakeTime": Int(wakeTime.timeIntervalSince1970 * 1000),
            "totalSleepSec": totalSleepSec,
            "deepSleepSec": deepSleepSec,
            "remSleepSec": remSleepSec,
            "lightSleepSec": lightSleepSec,
            "awakeSec": awakeSec,
            "efficiency": efficiency,
            "sleepScore": sleepScore,
            "latencySec": latencySec,
            "avgHeartRate": avgHeartRate,
            "avgHrv": avgHrv,
            "respiratoryRate": respiratoryRate,
            "recordedAt": Int(recordedAt.timeIntervalSince1970 * 1000)
        ]
    }
}

public enum HeartRateContext: String, Codable {
    case resting, active, sleep, workout, unknown
}

public struct BrandHeartRateSample: Codable {
    public let id: String
    public let source: BrandSource
    public let timestamp: Date
    public let bpm: Double
    public let context: HeartRateContext
    
    public init(id: String, source: BrandSource, timestamp: Date, bpm: Double, context: HeartRateContext) {
        self.id = id
        self.source = source
        self.timestamp = timestamp
        self.bpm = bpm
        self.context = context
    }
    
    public func toDictionary() -> [String: Any?] {
        return [
            "id": id,
            "source": source.toDictionary(),
            "timestamp": Int(timestamp.timeIntervalSince1970 * 1000),
            "bpm": bpm,
            "context": context.rawValue
        ]
    }
}

public struct BrandActivitySummary: Codable {
    public let id: String
    public let source: BrandSource
    public let date: Date
    public let steps: Int
    public let distanceMeters: Double
    public let caloriesTotal: Double
    public let caloriesActive: Double
    public let activeMinutes: Int
    public let sedentaryMinutes: Int
    public let floorsClimbed: Int
    public let recordedAt: Date
    
    public init(id: String, source: BrandSource, date: Date, steps: Int, distanceMeters: Double, caloriesTotal: Double, caloriesActive: Double, activeMinutes: Int, sedentaryMinutes: Int, floorsClimbed: Int, recordedAt: Date) {
        self.id = id
        self.source = source
        self.date = date
        self.steps = steps
        self.distanceMeters = distanceMeters
        self.caloriesTotal = caloriesTotal
        self.caloriesActive = caloriesActive
        self.activeMinutes = activeMinutes
        self.sedentaryMinutes = sedentaryMinutes
        self.floorsClimbed = floorsClimbed
        self.recordedAt = recordedAt
    }
    
    public func toDictionary() -> [String: Any?] {
        return [
            "id": id,
            "source": source.toDictionary(),
            "date": Int(date.timeIntervalSince1970 * 1000),
            "steps": steps,
            "distanceMeters": distanceMeters,
            "caloriesTotal": caloriesTotal,
            "caloriesActive": caloriesActive,
            "activeMinutes": activeMinutes,
            "sedentaryMinutes": sedentaryMinutes,
            "floorsClimbed": floorsClimbed,
            "recordedAt": Int(recordedAt.timeIntervalSince1970 * 1000)
        ]
    }
}

public enum HrvContext: String, Codable {
    case nightly, daily, spotCheck, unknown
}

public struct BrandHrvReading: Codable {
    public let id: String
    public let source: BrandSource
    public let timestamp: Date
    public let rmssd: Double?
    public let sdnn: Double?
    public let context: HrvContext
    public let recordedAt: Date
    
    public init(id: String, source: BrandSource, timestamp: Date, rmssd: Double?, sdnn: Double?, context: HrvContext, recordedAt: Date) {
        self.id = id
        self.source = source
        self.timestamp = timestamp
        self.rmssd = rmssd
        self.sdnn = sdnn
        self.context = context
        self.recordedAt = recordedAt
    }
    
    public func toDictionary() -> [String: Any?] {
        return [
            "id": id,
            "source": source.toDictionary(),
            "timestamp": Int(timestamp.timeIntervalSince1970 * 1000),
            "rmssd": rmssd,
            "sdnn": sdnn,
            "context": context.rawValue,
            "recordedAt": Int(recordedAt.timeIntervalSince1970 * 1000)
        ]
    }
}

public enum WorkoutType: String, Codable {
    case run, cycle, swim, strength, yoga, hiit, walk, hike, other
}

public struct BrandWorkoutSession: Codable {
    public let id: String
    public let source: BrandSource
    public let type: WorkoutType
    public let startTime: Date
    public let endTime: Date
    public let durationSec: Int
    public let caloriesBurned: Double?
    public let distanceMeters: Double?
    public let avgHeartRate: Double?
    public let maxHeartRate: Double?
    public let recordedAt: Date
    
    public init(id: String, source: BrandSource, type: WorkoutType, startTime: Date, endTime: Date, durationSec: Int, caloriesBurned: Double?, distanceMeters: Double?, avgHeartRate: Double?, maxHeartRate: Double?, recordedAt: Date) {
        self.id = id
        self.source = source
        self.type = type
        self.startTime = startTime
        self.endTime = endTime
        self.durationSec = durationSec
        self.caloriesBurned = caloriesBurned
        self.distanceMeters = distanceMeters
        self.avgHeartRate = avgHeartRate
        self.maxHeartRate = maxHeartRate
        self.recordedAt = recordedAt
    }
    
    public func toDictionary() -> [String: Any?] {
        return [
            "id": id,
            "source": source.toDictionary(),
            "type": type.rawValue,
            "startTime": Int(startTime.timeIntervalSince1970 * 1000),
            "endTime": Int(endTime.timeIntervalSince1970 * 1000),
            "durationSec": durationSec,
            "caloriesBurned": caloriesBurned,
            "distanceMeters": distanceMeters,
            "avgHeartRate": avgHeartRate,
            "maxHeartRate": maxHeartRate,
            "recordedAt": Int(recordedAt.timeIntervalSince1970 * 1000)
        ]
    }
}

public struct BrandBodyMeasurement: Codable {
    public let id: String
    public let source: BrandSource
    public let weightKg: Double?
    public let bodyFatPercent: Double?
    public let muscleMassKg: Double?
    public let bmi: Double?
    public let bodyTemperatureCelsius: Double?
    public let recordedAt: Date
    
    public init(id: String, source: BrandSource, weightKg: Double?, bodyFatPercent: Double?, muscleMassKg: Double?, bmi: Double?, bodyTemperatureCelsius: Double?, recordedAt: Date) {
        self.id = id
        self.source = source
        self.weightKg = weightKg
        self.bodyFatPercent = bodyFatPercent
        self.muscleMassKg = muscleMassKg
        self.bmi = bmi
        self.bodyTemperatureCelsius = bodyTemperatureCelsius
        self.recordedAt = recordedAt
    }
    
    public func toDictionary() -> [String: Any?] {
        return [
            "id": id,
            "source": source.toDictionary(),
            "weightKg": weightKg,
            "bodyFatPercent": bodyFatPercent,
            "muscleMassKg": muscleMassKg,
            "bmi": bmi,
            "bodyTemperatureCelsius": bodyTemperatureCelsius,
            "recordedAt": Int(recordedAt.timeIntervalSince1970 * 1000)
        ]
    }
}

public enum SpO2Context: String, Codable {
    case continuous, spotCheck, sleep
}

public struct BrandSpO2Reading: Codable {
    public let id: String
    public let source: BrandSource
    public let timestamp: Date
    public let percent: Double
    public let context: SpO2Context
    public let recordedAt: Date
    
    public init(id: String, source: BrandSource, timestamp: Date, percent: Double, context: SpO2Context, recordedAt: Date) {
        self.id = id
        self.source = source
        self.timestamp = timestamp
        self.percent = percent
        self.context = context
        self.recordedAt = recordedAt
    }
    
    public func toDictionary() -> [String: Any?] {
        return [
            "id": id,
            "source": source.toDictionary(),
            "timestamp": Int(timestamp.timeIntervalSince1970 * 1000),
            "percent": percent,
            "context": context.rawValue,
            "recordedAt": Int(recordedAt.timeIntervalSince1970 * 1000)
        ]
    }
}

public enum GlucoseTrend: String, Codable {
    case rising, risingQuickly, stable, falling, fallingQuickly
}

public struct BrandGlucoseReading: Codable {
    public let id: String
    public let source: BrandSource
    public let timestamp: Date
    public let valueMgDl: Double
    public let trend: GlucoseTrend?
    public let recordedAt: Date
    
    public init(id: String, source: BrandSource, timestamp: Date, valueMgDl: Double, trend: GlucoseTrend?, recordedAt: Date) {
        self.id = id
        self.source = source
        self.timestamp = timestamp
        self.valueMgDl = valueMgDl
        self.trend = trend
        self.recordedAt = recordedAt
    }
    
    public func toDictionary() -> [String: Any?] {
        return [
            "id": id,
            "source": source.toDictionary(),
            "timestamp": Int(timestamp.timeIntervalSince1970 * 1000),
            "valueMgDl": valueMgDl,
            "trend": trend?.rawValue,
            "recordedAt": Int(recordedAt.timeIntervalSince1970 * 1000)
        ]
    }
}
