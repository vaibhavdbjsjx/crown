import AuthenticationServices
import CryptoKit
import Foundation
import Security
import UIKit

struct UserProfile: Codable, Equatable {
    enum Provider: String, Codable { case apple, gmail }
    var id: String
    var name: String
    var email: String?
    var provider: Provider
    var joined: Date

    var firstName: String {
        name.split(separator: " ").first.map(String.init) ?? name
    }
}

/// Holds the signed-in profile. Identity lives in the Keychain on this device;
/// Crown has no server, so nothing about the account is uploaded.
@MainActor
final class Account: ObservableObject {
    @Published private(set) var profile: UserProfile?
    @Published var errorMessage: String?
    @Published var busy = false

    private let key = "crown.profile"
    private let google = GoogleSignIn()

    init() {
        profile = Keychain.read(key).flatMap { try? JSONDecoder().decode(UserProfile.self, from: $0) }
        verifyAppleCredential()
    }

    var isSignedIn: Bool { profile != nil }
    var gmailAvailable: Bool { GoogleSignIn.clientID != nil }

    // MARK: Apple

    func configure(_ request: ASAuthorizationAppleIDRequest) {
        request.requestedScopes = [.fullName, .email]
    }

    func handleApple(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let auth):
            guard let credential = auth.credential as? ASAuthorizationAppleIDCredential else { return }
            let formatted = PersonNameComponentsFormatter.localizedString(from: credential.fullName ?? PersonNameComponents(), style: .default)
            // Apple only sends name and email the first time; keep what we already had.
            let existing = profile?.id == credential.user ? profile : nil
            save(UserProfile(id: credential.user,
                             name: formatted.isEmpty ? (existing?.name ?? "") : formatted,
                             email: credential.email ?? existing?.email,
                             provider: .apple,
                             joined: existing?.joined ?? Date()))
            Haptics.success()
        case .failure(let error):
            if (error as? ASAuthorizationError)?.code != .canceled {
                errorMessage = "Sign in with Apple didn't complete. Please try again."
            }
        }
    }

    private func verifyAppleCredential() {
        guard let profile, profile.provider == .apple else { return }
        ASAuthorizationAppleIDProvider().getCredentialState(forUserID: profile.id) { state, _ in
            if state == .revoked || state == .notFound {
                Task { @MainActor in self.signOut() }
            }
        }
    }

    // MARK: Gmail

    func signInWithGmail() async {
        busy = true
        defer { busy = false }
        do {
            let user = try await google.signIn()
            save(UserProfile(id: "google:" + user.sub, name: user.name ?? "", email: user.email,
                             provider: .gmail, joined: profile?.joined ?? Date()))
            Haptics.success()
        } catch GoogleSignIn.Failure.cancelled {
            return
        } catch {
            errorMessage = "Gmail sign-in didn't complete. Check your connection and try again."
        }
    }

    // MARK: Profile

    func updateName(_ name: String) {
        guard var p = profile else { return }
        p.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        save(p)
    }

    func signOut() {
        Keychain.delete(key)
        profile = nil
    }

    private func save(_ p: UserProfile) {
        if let data = try? JSONEncoder().encode(p) { Keychain.write(data, for: key) }
        profile = p
    }
}

// MARK: - Google OAuth (PKCE, no SDK)

/// Signs in with a Google (Gmail) account using the system web sheet and PKCE.
/// Requires `GoogleClientID` (an iOS OAuth client ID) in Info.plist.
final class GoogleSignIn: NSObject, ASWebAuthenticationPresentationContextProviding {
    enum Failure: Error { case cancelled, notConfigured, badResponse }
    struct User { let sub: String; let email: String?; let name: String? }

    static var clientID: String? {
        guard let id = Bundle.main.object(forInfoDictionaryKey: "GoogleClientID") as? String,
              id.hasSuffix(".apps.googleusercontent.com") else { return nil }
        return id
    }

    private var session: ASWebAuthenticationSession?

    @MainActor
    func signIn() async throws -> User {
        guard let clientID = Self.clientID else { throw Failure.notConfigured }
        let scheme = "com.googleusercontent.apps." + clientID.replacingOccurrences(of: ".apps.googleusercontent.com", with: "")
        let redirect = scheme + ":/oauth2redirect"
        let verifier = Self.randomString(64)
        let challenge = Self.base64url(Data(SHA256.hash(data: Data(verifier.utf8))))
        let state = Self.randomString(24)

        var comps = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")!
        comps.queryItems = [
            .init(name: "client_id", value: clientID),
            .init(name: "redirect_uri", value: redirect),
            .init(name: "response_type", value: "code"),
            .init(name: "scope", value: "openid email profile"),
            .init(name: "code_challenge", value: challenge),
            .init(name: "code_challenge_method", value: "S256"),
            .init(name: "state", value: state),
            .init(name: "prompt", value: "select_account"),
        ]

        let callback: URL = try await withCheckedThrowingContinuation { cont in
            let s = ASWebAuthenticationSession(url: comps.url!, callbackURLScheme: scheme) { url, error in
                if let url { cont.resume(returning: url) }
                else if (error as? ASWebAuthenticationSessionError)?.code == .canceledLogin { cont.resume(throwing: Failure.cancelled) }
                else { cont.resume(throwing: error ?? Failure.badResponse) }
            }
            s.presentationContextProvider = self
            s.prefersEphemeralWebBrowserSession = false
            session = s
            s.start()
        }

        let items = URLComponents(url: callback, resolvingAgainstBaseURL: false)?.queryItems ?? []
        guard items.first(where: { $0.name == "state" })?.value == state,
              let code = items.first(where: { $0.name == "code" })?.value else { throw Failure.badResponse }

        var request = URLRequest(url: URL(string: "https://oauth2.googleapis.com/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let form = ["code": code, "client_id": clientID, "redirect_uri": redirect,
                    "grant_type": "authorization_code", "code_verifier": verifier]
        request.httpBody = form.map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? "")" }
            .joined(separator: "&").data(using: .utf8)
        let (data, _) = try await URLSession.shared.data(for: request)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let idToken = json["id_token"] as? String else { throw Failure.badResponse }

        let parts = idToken.split(separator: ".")
        guard parts.count > 1, let payload = Self.decodeBase64url(String(parts[1])),
              let claims = try JSONSerialization.jsonObject(with: payload) as? [String: Any],
              let sub = claims["sub"] as? String else { throw Failure.badResponse }
        return User(sub: sub, email: claims["email"] as? String, name: claims["name"] as? String)
    }

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes.compactMap { ($0 as? UIWindowScene)?.keyWindow }.first ?? ASPresentationAnchor()
    }

    private static func randomString(_ length: Int) -> String {
        let chars = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
        var bytes = [UInt8](repeating: 0, count: length)
        _ = SecRandomCopyBytes(kSecRandomDefault, length, &bytes)
        return String(bytes.map { chars[Int($0) % chars.count] })
    }

    private static func base64url(_ data: Data) -> String {
        data.base64EncodedString().replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
    }

    private static func decodeBase64url(_ s: String) -> Data? {
        var b = s.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        while b.count % 4 != 0 { b += "=" }
        return Data(base64Encoded: b)
    }
}

// MARK: - Keychain

enum Keychain {
    static func write(_ data: Data, for key: String) {
        delete(key)
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrAccount as String: key,
                                    kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
                                    kSecValueData as String: data]
        SecItemAdd(query as CFDictionary, nil)
    }

    static func read(_ key: String) -> Data? {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrAccount as String: key,
                                    kSecReturnData as String: true,
                                    kSecMatchLimit as String: kSecMatchLimitOne]
        var out: AnyObject?
        return SecItemCopyMatching(query as CFDictionary, &out) == errSecSuccess ? out as? Data : nil
    }

    static func delete(_ key: String) {
        SecItemDelete([kSecClass as String: kSecClassGenericPassword, kSecAttrAccount as String: key] as CFDictionary)
    }
}
