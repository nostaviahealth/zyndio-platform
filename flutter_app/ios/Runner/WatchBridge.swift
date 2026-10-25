import Foundation
import WatchConnectivity
import Flutter

@objc class WatchBridge: NSObject, WCSessionDelegate {
    static let shared = WatchBridge()
    private var channel: FlutterMethodChannel?
    private var actionChannel: FlutterMethodChannel?
    
    private override init() {
        super.init()
    }
    
    func setup(messenger: FlutterBinaryMessenger) {
        channel = FlutterMethodChannel(name: "com.zyndio/watch_sync", binaryMessenger: messenger)
        actionChannel = FlutterMethodChannel(name: "com.zyndio/watch_actions", binaryMessenger: messenger)
        
        channel?.setMethodCallHandler { [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
            switch call.method {
            case "syncMetrics":
                if let args = call.arguments as? [String: Any] {
                    self?.sendDataToWatch(data: args)
                    result(true)
                } else {
                    result(FlutterError(code: "INVALID_ARGS", message: "Expected dictionary", details: nil))
                }
            default:
                result(FlutterMethodNotImplemented)
            }
        }
        
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
    }
    
    private func sendDataToWatch(data: [String: Any]) {
        guard WCSession.default.activationState == .activated else {
            print("WCSession not activated on iPhone")
            return
        }
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: data, options: [])
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                // Update application context (better for background sync)
                try WCSession.default.updateApplicationContext(["payload": jsonString])
                
                // If watch is reachable (app is open), send temporary message too
                if WCSession.default.isReachable {
                    WCSession.default.sendMessage(["payload": jsonString], replyHandler: nil, errorHandler: { error in
                        print("Error sending immediate message to watch: \(error)")
                    })
                }
            }
        } catch {
             print("Error serializing watch data: \(error)")
        }
    }
    
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        print("iPhone WCSession activated: \(activationState.rawValue)")
    }
    
    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
    
    // MARK: - Receive from Watch
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        print("Received message from Watch: \(message)")
        
        if let action = message["action"] as? String {
            DispatchQueue.main.async {
                self.actionChannel?.invokeMethod("handleAction", arguments: ["action": action])
            }
        }
    }
}

