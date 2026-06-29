//
//  AuthViewModel.swift
//  AppleBehaviorTraceApp
//

import Combine
import Foundation

@MainActor
final class AuthViewModel: ObservableObject {
    private let authService = SupabaseAuthService()

    @Published var session: AppSession?
    @Published var errorMessage: String?
    @Published var isWorking = false
    @Published var isCheckingSession = true

    var configurationMessage: String? {
        SupabaseConfiguration.current.validationMessage
    }

    func restoreSession() async {
        defer { isCheckingSession = false }
        guard session == nil else {
            return
        }
        session = authService.restoreSession()
    }

    func signIn(email: String, password: String) async {
        await runAuthAction {
            session = try await authService.signIn(email: email, password: password)
        }
    }

    func registerParticipant(email: String, password: String) async {
        guard validateCredentials(email: email, password: password) else {
            return
        }

        await runAuthAction {
            session = try await authService.signUp(email: email, password: password, role: .user)
        }
    }

    func createAdmin(email: String, password: String) async {
        guard validateCredentials(email: email, password: password) else {
            return
        }

        await runAuthAction {
            session = try await authService.bootstrapAdmin(email: email, password: password)
        }
    }

    func createUser(email: String, password: String) async {
        guard let currentSession = session, currentSession.profile.role == .admin else {
            errorMessage = "Only an admin can create user accounts."
            return
        }

        guard validateCredentials(email: email, password: password) else {
            return
        }

        await runAuthAction {
            _ = try await authService.signUp(email: email, password: password, role: .user)
            session = currentSession
            authService.saveSession(currentSession)
        }
    }

    func signOut() {
        authService.clearSession()
        session = nil
        errorMessage = nil
    }

    private func runAuthAction(_ action: () async throws -> Void) async {
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }

        do {
            try await action()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func validateCredentials(email: String, password: String) -> Bool {
        if email.isBlank {
            errorMessage = "Enter an email address."
            return false
        }

        if !email.normalizedEmail.contains("@") {
            errorMessage = "Enter a valid email address."
            return false
        }

        if password.count < 6 {
            errorMessage = "Password must be at least 6 characters."
            return false
        }

        return true
    }
}

struct SupabaseAuthService {
    private let configuration = SupabaseConfiguration.current
    private let sessionKey = "behaviortrace.supabase.session"
    private let decoder = JSONDecoder.supabase
    private let encoder = JSONEncoder()

    func restoreSession() -> AppSession? {
        guard let data = UserDefaults.standard.data(forKey: sessionKey) else {
            return nil
        }

        return try? decoder.decode(AppSession.self, from: data)
    }

    func saveSession(_ session: AppSession) {
        guard let data = try? encoder.encode(session) else {
            return
        }

        UserDefaults.standard.set(data, forKey: sessionKey)
    }

    func clearSession() {
        UserDefaults.standard.removeObject(forKey: sessionKey)
    }

    func signIn(email: String, password: String) async throws -> AppSession {
        try configuration.validate()

        let response: AuthResponse = try await request(
            path: "/auth/v1/token?grant_type=password",
            method: "POST",
            accessToken: nil,
            body: AuthRequest(email: email.normalizedEmail, password: password)
        )

        guard let accessToken = response.accessToken else {
            throw AuthError.invalidResponse
        }

        let profile = try await ensureProfile(
            userID: response.user.id,
            email: response.user.email ?? email.normalizedEmail,
            role: inferredRole(for: response.user.email ?? email.normalizedEmail),
            accessToken: accessToken
        )
        let session = AppSession(accessToken: accessToken, refreshToken: response.refreshToken, user: response.user, profile: profile)
        saveSession(session)
        return session
    }

    func bootstrapAdmin(email: String, password: String) async throws -> AppSession {
        do {
            return try await signUp(email: email, password: password, role: .admin)
        } catch {
            guard Self.isAlreadyRegisteredError(error) else {
                throw error
            }

            return try await signIn(email: email, password: password)
        }
    }

    func signUp(email: String, password: String, role: UserRole) async throws -> AppSession {
        try configuration.validate()

        let response: AuthResponse = try await request(
            path: "/auth/v1/signup",
            method: "POST",
            accessToken: nil,
            body: SignUpRequest(email: email.normalizedEmail, password: password, data: SignUpMetadata(role: role.rawValue))
        )

        guard let accessToken = response.accessToken, let refreshToken = response.refreshToken else {
            throw AuthError.emailConfirmationRequired
        }

        let profile = try await ensureProfile(
            userID: response.user.id,
            email: response.user.email ?? email.normalizedEmail,
            role: role,
            accessToken: accessToken
        )

        let session = AppSession(accessToken: accessToken, refreshToken: refreshToken, user: response.user, profile: profile)
        saveSession(session)
        return session
    }

    private func ensureProfile(userID: UUID, email: String, role: UserRole, accessToken: String) async throws -> Profile {
        do {
            return try await fetchProfileWithRetry(userID: userID, accessToken: accessToken)
        } catch AuthError.missingProfile {
            return try await createProfile(userID: userID, email: email, role: role, accessToken: accessToken)
        }
    }

    private func createProfile(userID: UUID, email: String, role: UserRole, accessToken: String) async throws -> Profile {
        let profiles: [Profile]

        do {
            profiles = try await request(
                path: "/rest/v1/rpc/ensure_own_profile",
                method: "POST",
                accessToken: accessToken,
                body: EmptyRequest()
            )
        } catch {
            guard Self.isMissingFunctionError(error) else {
                throw error
            }

            profiles = try await request(
                path: "/rest/v1/profiles?on_conflict=id&select=id,email,role,created_at",
                method: "POST",
                accessToken: accessToken,
                prefer: "resolution=merge-duplicates,return=representation",
                body: ProfileUpsertRequest(id: userID, email: email, role: role.rawValue)
            )
        }

        guard let profile = profiles.first else {
            throw AuthError.missingProfile
        }

        return profile
    }

    private func fetchProfileWithRetry(userID: UUID, accessToken: String) async throws -> Profile {
        var lastError: Error?

        for attempt in 0..<3 {
            do {
                return try await fetchProfile(userID: userID, accessToken: accessToken)
            } catch {
                lastError = error
                if attempt < 2 {
                    try await Task.sleep(for: .milliseconds(250))
                }
            }
        }

        throw lastError ?? AuthError.missingProfile
    }

    private func fetchProfile(userID: UUID, accessToken: String) async throws -> Profile {
        let profiles: [Profile] = try await request(
            path: "/rest/v1/profiles?id=eq.\(userID.uuidString)&select=id,email,role,created_at",
            method: "GET",
            accessToken: accessToken,
            body: Optional<EmptyRequest>.none
        )

        guard let profile = profiles.first else {
            throw AuthError.missingProfile
        }

        return profile
    }

    private func request<Response: Decodable, Body: Encodable>(
        path: String,
        method: String,
        accessToken: String?,
        prefer: String? = nil,
        body: Body?
    ) async throws -> Response {
        guard let url = URL(string: path, relativeTo: configuration.url) else {
            throw AuthError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue(configuration.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(accessToken ?? configuration.anonKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let prefer {
            request.setValue(prefer, forHTTPHeaderField: "Prefer")
        }

        if let body {
            request.httpBody = try encoder.encode(body)
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            throw AuthError.serverError(Self.errorMessage(from: data) ?? "Supabase request failed with status \(httpResponse.statusCode).")
        }

        do {
            return try decoder.decode(Response.self, from: data)
        } catch {
            throw AuthError.decodingFailed(String(data: data, encoding: .utf8) ?? error.localizedDescription)
        }
    }

    private static func errorMessage(from data: Data) -> String? {
        guard let errorResponse = try? JSONDecoder().decode(SupabaseErrorResponse.self, from: data) else {
            return String(data: data, encoding: .utf8)
        }

        return errorResponse.msg ?? errorResponse.message ?? errorResponse.errorDescription ?? errorResponse.error
    }

    private static func isAlreadyRegisteredError(_ error: Error) -> Bool {
        guard case AuthError.serverError(let message) = error else {
            return false
        }

        let normalizedMessage = message.lowercased()
        return normalizedMessage.contains("already registered")
            || normalizedMessage.contains("already exists")
            || normalizedMessage.contains("user exists")
    }

    private static func isMissingFunctionError(_ error: Error) -> Bool {
        guard case AuthError.serverError(let message) = error else {
            return false
        }

        return message.lowercased().contains("could not find the function")
    }

    private func inferredRole(for email: String) -> UserRole {
        email.normalizedEmail == "pauliusgedrimas@gmail.com" ? .admin : .user
    }
}

struct SupabaseConfiguration {
    static let current = SupabaseConfiguration()
    private static let bundledURL = "https://ygvknoctxtxqhkkxwntc.supabase.co"
    private static let bundledAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inlndmtub2N0eHR4cWhra3h3bnRjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODA3Njg4NzMsImV4cCI6MjA5NjM0NDg3M30.fjygZOhrD-IKb-eVwm5mIEk3gjxXMV9c6M05hMm037Q"

    let url: URL
    let anonKey: String

    var validationMessage: String? {
        if url.absoluteString.isBlank || anonKey.isBlank {
            return "Set SUPABASE_URL and SUPABASE_ANON_KEY before logging in."
        }

        return nil
    }

    init() {
        let environment = ProcessInfo.processInfo.environment
        let urlString = environment["SUPABASE_URL"] ?? Self.bundledURL
        url = URL(string: urlString) ?? URL(string: "")
            ?? URL(string: "http://127.0.0.1:54321")!
        anonKey = environment["SUPABASE_ANON_KEY"] ?? Self.bundledAnonKey
    }

    func validate() throws {
        if url.absoluteString.isBlank || anonKey.isBlank {
            throw AuthError.missingConfiguration
        }
    }
}

struct AppSession: Codable {
    let accessToken: String
    let refreshToken: String?
    let user: SupabaseUser
    let profile: Profile
}

struct SupabaseUser: Codable {
    let id: UUID
    let email: String?
}

struct Profile: Codable {
    let id: UUID
    let email: String
    let role: UserRole
    let createdAt: Date?
}

enum UserRole: String, Codable {
    case admin
    case user
}

private struct AuthResponse: Codable {
    let accessToken: String?
    let refreshToken: String?
    let user: SupabaseUser
}

private struct AuthRequest: Encodable {
    let email: String
    let password: String
}

private struct SignUpRequest: Encodable {
    let email: String
    let password: String
    let data: SignUpMetadata
}

private struct SignUpMetadata: Encodable {
    let role: String
}

private struct ProfileUpsertRequest: Encodable {
    let id: UUID
    let email: String
    let role: String
}

struct EmptyRequest: Encodable {
}

private struct SupabaseErrorResponse: Decodable {
    let error: String?
    let errorDescription: String?
    let message: String?
    let msg: String?
}

private enum AuthError: LocalizedError {
    case emailConfirmationRequired
    case invalidResponse
    case invalidURL
    case missingConfiguration
    case missingProfile
    case decodingFailed(String)
    case serverError(String)

    var errorDescription: String? {
        switch self {
        case .emailConfirmationRequired:
            return "Supabase created the account, but email confirmation is enabled so no login session was returned."
        case .invalidResponse:
            return "Supabase returned an invalid response."
        case .invalidURL:
            return "The Supabase URL is invalid."
        case .missingConfiguration:
            return "Missing Supabase configuration. Add SUPABASE_URL and SUPABASE_ANON_KEY or update the bundled defaults."
        case .missingProfile:
            return "The Supabase user exists, but no profile row was found. Check that the profiles table migration and auth trigger are installed."
        case .decodingFailed(let response):
            return "Supabase returned a response the app could not read: \(response)"
        case .serverError(let message):
            return message
        }
    }
}
