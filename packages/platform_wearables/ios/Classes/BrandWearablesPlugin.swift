import Flutter
import UIKit

public class BrandWearablesPlugin: NSObject, FlutterPlugin {
    private let healthKitManager = BrandHealthKitManager()
    private let oauthManager = BrandOAuthManager()
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "platform_wearables", binaryMessenger: registrar.messenger())
        let instance = BrandWearablesPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
        
        let eventChannel = FlutterEventChannel(name: "platform_wearables/events", binaryMessenger: registrar.messenger())
        // Future event streams
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as? [String: Any]
        
        Task {
            do {
                switch call.method {
                case "requestHealthPermissions":
                    let success = try await healthKitManager.requestAuthorization()
                    result(success)
                    
                case "getSleepSessions":
                    let (start, end) = parseDates(args)
                    let data = try await healthKitManager.getSleepSessions(from: start, to: end)
                    result(data.map { $0.toDictionary() })
                    
                case "getHeartRate":
                    let (start, end) = parseDates(args)
                    let data = try await healthKitManager.getHeartRate(from: start, to: end)
                    result(data.map { $0.toDictionary() })
                    
                case "getHRV":
                    let (start, end) = parseDates(args)
                    let data = try await healthKitManager.getHRV(from: start, to: end)
                    result(data.map { $0.toDictionary() })
                    
                case "getSpO2":
                    let (start, end) = parseDates(args)
                    let data = try await healthKitManager.getSpO2(from: start, to: end)
                    result(data.map { $0.toDictionary() })
                    
                case "getActivity":
                    let (start, end) = parseDates(args)
                    let data = try await healthKitManager.getActivity(from: start, to: end)
                    result(data.map { $0.toDictionary() })
                    
                case "getWorkouts":
                    let (start, end) = parseDates(args)
                    let data = try await healthKitManager.getWorkouts(from: start, to: end)
                    result(data.map { $0.toDictionary() })
                    
                case "getBodyMeasurements":
                    let (start, end) = parseDates(args)
                    let data = try await healthKitManager.getBodyMeasurements(from: start, to: end)
                    result(data.map { $0.toDictionary() })
                    
                case "getGlucose":
                    let (start, end) = parseDates(args)
                    let data = try await healthKitManager.getGlucose(from: start, to: end)
                    result(data.map { $0.toDictionary() })
                    
                case "startOAuthFlow":
                    guard let url = args?["authUrl"] as? String,
                          let scheme = args?["callbackScheme"] as? String else {
                        result(FlutterError(code: "INVALID_ARGS", message: "Missing authUrl or callbackScheme", details: nil))
                        return
                    }
                    let callbackUrl = try await oauthManager.startOAuthFlow(authUrl: url, callbackScheme: scheme)
                    result(callbackUrl.absoluteString)
                    
                default:
                    result(FlutterMethodNotImplemented)
                }
            } catch {
                result(FlutterError(code: "ERROR", message: error.localizedDescription, details: nil))
            }
        }
    }
    
    private func parseDates(_ args: [String: Any]?) -> (Date, Date) {
        let startMillis = (args?["start"] as? NSNumber)?.int64Value ?? 0
        let endMillis = (args?["end"] as? NSNumber)?.int64Value ?? Int64(Date().timeIntervalSince1970 * 1000)
        return (Date(timeIntervalSince1970: Double(startMillis) / 1000.0),
                Date(timeIntervalSince1970: Double(endMillis) / 1000.0))
    }
}
