import AuthenticationServices
import Foundation

public class BrandOAuthManager: NSObject, ASWebAuthenticationPresentationContextProviding {
    
    public override init() {
        super.init()
    }
    
    public func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        // Try to get the active window scene
        guard let windowScene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
              let window = windowScene.windows.first(where: { $0.isKeyWindow }) else {
            return ASPresentationAnchor()
        }
        return window
    }
    
    public func startOAuthFlow(
        authUrl: String,
        callbackScheme: String
    ) async throws -> URL {
        guard let url = URL(string: authUrl) else {
            throw NSError(domain: "BrandOAuth", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(url: url, callbackURLScheme: callbackScheme) { callbackURL, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let callbackURL = callbackURL {
                    continuation.resume(returning: callbackURL)
                } else {
                    continuation.resume(throwing: NSError(domain: "BrandOAuth", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unknown error"]))
                }
            }
            
            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = false
            session.start()
        }
    }
}
