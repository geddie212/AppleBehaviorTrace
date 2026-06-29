//
//  StudySupabaseService.swift
//  AppleBehaviorTraceApp
//

import Foundation
import CryptoKit

struct StudySupabaseService {
    private let configuration = StudySupabaseConfiguration.current
    private let decoder = JSONDecoder.supabaseStudies
    private let encoder = JSONEncoder()

    func fetchForms(accessToken: String) async throws -> [StudyFormRecord] {
        do {
            return try await request(
                path: "/rest/v1/forms?select=id,title,description,study_code,labels(id,label_name,prompt_text,prompt_interval_seconds,active)&order=created_at.desc",
                method: "GET",
                accessToken: accessToken,
                body: Optional<EmptyStudyRequest>.none
            )
        } catch StudyError.server(let message) where Self.isMissingStudySchema(message) {
            let legacyForms: [LegacyStudyFormRecord] = try await request(
                path: "/rest/v1/forms?select=id,title,description,labels(id,label_name,prompt_text,prompt_interval_seconds,active)&order=created_at.desc",
                method: "GET",
                accessToken: accessToken,
                body: Optional<EmptyStudyRequest>.none
            )

            return legacyForms.map(\.studyFormRecord)
        }
    }

    func createStudy(
        title: String,
        studyCode: String,
        studyPassword: String,
        description: String,
        labels: [DraftStudyLabel],
        adminUserID: UUID,
        accessToken: String
    ) async throws {
        let forms: [CreatedStudyForm] = try await request(
            path: "/rest/v1/forms?select=id",
            method: "POST",
            accessToken: accessToken,
            prefer: "return=representation",
            body: CreateStudyFormRequest(
                title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                description: description.trimmingCharacters(in: .whitespacesAndNewlines),
                studyCode: studyCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased(),
                studyPasswordHash: Self.sha256(studyPassword),
                createdBy: adminUserID
            )
        )

        guard let form = forms.first else {
            throw StudyError.invalidResponse
        }

        let labelRequests = labels.map {
            CreateStudyLabelRequest(
                formID: form.id,
                labelName: $0.name,
                promptText: $0.notificationTitle.isEmpty ? $0.name : $0.notificationTitle,
                promptIntervalSeconds: $0.intervalMinutes * 60,
                active: true
            )
        }

        let _: [StudyLabelRecord] = try await request(
            path: "/rest/v1/labels?select=id,label_name,prompt_text,prompt_interval_seconds,active",
            method: "POST",
            accessToken: accessToken,
            prefer: "return=representation",
            body: labelRequests
        )
    }

    func createLabel(_ label: EditableStudyLabel, formID: Int, accessToken: String) async throws {
        let _: [StudyLabelRecord] = try await request(
            path: "/rest/v1/labels?select=id,label_name,prompt_text,prompt_interval_seconds,active",
            method: "POST",
            accessToken: accessToken,
            prefer: "return=representation",
            body: CreateStudyLabelRequest(
                formID: formID,
                labelName: label.labelName,
                promptText: label.notificationTitle.isEmpty ? label.labelName : label.notificationTitle,
                promptIntervalSeconds: label.intervalMinutes * 60,
                active: true
            )
        )
    }

    func updateLabel(_ label: EditableStudyLabel, databaseID: Int, accessToken: String) async throws {
        let _: [StudyLabelRecord] = try await request(
            path: "/rest/v1/labels?id=eq.\(databaseID)&select=id,label_name,prompt_text,prompt_interval_seconds,active",
            method: "PATCH",
            accessToken: accessToken,
            prefer: "return=representation",
            body: UpdateStudyLabelRequest(
                labelName: label.labelName,
                promptText: label.notificationTitle.isEmpty ? label.labelName : label.notificationTitle,
                promptIntervalSeconds: label.intervalMinutes * 60
            )
        )
    }

    func deleteLabel(id: Int, accessToken: String) async throws {
        try await requestNoResponse(
            path: "/rest/v1/labels?id=eq.\(id)",
            method: "DELETE",
            accessToken: accessToken
        )
    }

    func fetchRegisteredStudies(accessToken: String) async throws -> [StudyPublicRecord] {
        try await request(
            path: "/rest/v1/rpc/registered_studies",
            method: "POST",
            accessToken: accessToken,
            body: EmptyStudyRequest()
        )
    }

    func searchStudies(query: String, accessToken: String) async throws -> [StudyPublicRecord] {
        try await request(
            path: "/rest/v1/rpc/search_studies",
            method: "POST",
            accessToken: accessToken,
            body: SearchStudiesRequest(searchQuery: query.trimmingCharacters(in: .whitespacesAndNewlines))
        )
    }

    func registerForStudy(formID: Int, password: String, accessToken: String) async throws -> StudyPublicRecord {
        let studies: [StudyPublicRecord] = try await request(
            path: "/rest/v1/rpc/register_for_study",
            method: "POST",
            accessToken: accessToken,
            body: RegisterForStudyRequest(requestedFormID: formID, passwordHash: Self.sha256(password))
        )

        guard let study = studies.first else {
            throw StudyError.invalidResponse
        }

        return study
    }

    func leaveStudy(studyCode: String, accessToken: String) async throws {
        try await requestNoResponse(
            path: "/rest/v1/rpc/leave_study",
            method: "POST",
            accessToken: accessToken,
            body: LeaveStudyRequest(requestedStudyCode: studyCode)
        )
    }

    private func request<Response: Decodable, Body: Encodable>(
        path: String,
        method: String,
        accessToken: String,
        prefer: String? = nil,
        body: Body?
    ) async throws -> Response {
        guard let url = URL(string: path, relativeTo: configuration.url) else {
            throw StudyError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue(configuration.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let prefer {
            request.setValue(prefer, forHTTPHeaderField: "Prefer")
        }

        if let body {
            request.httpBody = try encoder.encode(body)
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw StudyError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            let message = Self.errorMessage(from: data) ?? "Supabase request failed with status \(httpResponse.statusCode)."
            throw StudyError.server(Self.studySchemaMessage(for: message))
        }

        return try decoder.decode(Response.self, from: data)
    }

    private func requestNoResponse<Body: Encodable>(path: String, method: String, accessToken: String, body: Body? = Optional<EmptyStudyRequest>.none) async throws {
        guard let url = URL(string: path, relativeTo: configuration.url) else {
            throw StudyError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue(configuration.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let body {
            request.httpBody = try encoder.encode(body)
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw StudyError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            let message = Self.errorMessage(from: data) ?? "Supabase request failed with status \(httpResponse.statusCode)."
            throw StudyError.server(Self.studySchemaMessage(for: message))
        }
    }

    private static func errorMessage(from data: Data) -> String? {
        guard let errorResponse = try? JSONDecoder().decode(StudySupabaseErrorResponse.self, from: data) else {
            return String(data: data, encoding: .utf8)
        }

        return errorResponse.msg ?? errorResponse.message ?? errorResponse.errorDescription ?? errorResponse.error
    }

    private static func studySchemaMessage(for message: String) -> String {
        if isMissingStudySchema(message) {
            return "Run the EMA study forms migrations in Supabase before creating studies. The hosted database is missing forms.study_code or forms.study_password_hash."
        }

        return message
    }

    private static func isMissingStudySchema(_ message: String) -> Bool {
        let normalizedMessage = message.lowercased()
        return normalizedMessage.contains("study_code")
            || normalizedMessage.contains("study_password")
            || normalizedMessage.contains("study_password_hash")
    }

    private static func sha256(_ value: String) -> String {
        let digest = SHA256.hash(data: Data(value.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}

private struct StudySupabaseConfiguration {
    static let current = StudySupabaseConfiguration()
    private static let bundledURL = "https://ygvknoctxtxqhkkxwntc.supabase.co"
    private static let bundledAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inlndmtub2N0eHR4cWhra3h3bnRjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODA3Njg4NzMsImV4cCI6MjA5NjM0NDg3M30.fjygZOhrD-IKb-eVwm5mIEk3gjxXMV9c6M05hMm037Q"

    let url: URL
    let anonKey: String

    init() {
        let environment = ProcessInfo.processInfo.environment
        let urlString = environment["SUPABASE_URL"] ?? Self.bundledURL
        url = URL(string: urlString) ?? URL(string: "https://localhost")!
        anonKey = environment["SUPABASE_ANON_KEY"] ?? Self.bundledAnonKey
    }
}

private struct LegacyStudyFormRecord: Decodable, Identifiable {
    let id: Int
    let title: String
    let description: String?
    let labels: [StudyLabelRecord]

    var studyFormRecord: StudyFormRecord {
        StudyFormRecord(
            id: id,
            title: title,
            description: description,
            studyCode: "STUDY-\(id)",
            labels: labels
        )
    }
}

private struct CreatedStudyForm: Decodable {
    let id: Int
}

private struct CreateStudyFormRequest: Encodable {
    let title: String
    let description: String
    let studyCode: String
    let studyPasswordHash: String
    let createdBy: UUID

    enum CodingKeys: String, CodingKey {
        case title
        case description
        case studyCode = "study_code"
        case studyPasswordHash = "study_password_hash"
        case createdBy = "created_by"
    }
}

private struct SearchStudiesRequest: Encodable {
    let searchQuery: String

    enum CodingKeys: String, CodingKey {
        case searchQuery = "search_query"
    }
}

private struct RegisterForStudyRequest: Encodable {
    let requestedFormID: Int
    let passwordHash: String

    enum CodingKeys: String, CodingKey {
        case requestedFormID = "requested_form_id"
        case passwordHash = "password_hash"
    }
}

private struct LeaveStudyRequest: Encodable {
    let requestedStudyCode: String

    enum CodingKeys: String, CodingKey {
        case requestedStudyCode = "requested_study_code"
    }
}

private struct CreateStudyLabelRequest: Encodable {
    let formID: Int
    let labelName: String
    let promptText: String
    let promptIntervalSeconds: Int
    let active: Bool

    enum CodingKeys: String, CodingKey {
        case formID = "form_id"
        case labelName = "label_name"
        case promptText = "prompt_text"
        case promptIntervalSeconds = "prompt_interval_seconds"
        case active
    }
}

private struct UpdateStudyLabelRequest: Encodable {
    let labelName: String
    let promptText: String
    let promptIntervalSeconds: Int

    enum CodingKeys: String, CodingKey {
        case labelName = "label_name"
        case promptText = "prompt_text"
        case promptIntervalSeconds = "prompt_interval_seconds"
    }
}

private struct EmptyStudyRequest: Encodable {
}

private struct StudySupabaseErrorResponse: Decodable {
    let error: String?
    let errorDescription: String?
    let message: String?
    let msg: String?
}

private enum StudyError: LocalizedError {
    case invalidResponse
    case invalidURL
    case server(String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Supabase returned an invalid response."
        case .invalidURL:
            return "The Supabase URL is invalid."
        case .server(let message):
            return message
        }
    }
}
