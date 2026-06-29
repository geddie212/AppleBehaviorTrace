//
//  CreateFormView.swift
//  AppleBehaviorTraceApp
//

import SwiftUI

struct CreateFormView: View {
    @Environment(\.dismiss) private var dismiss

    let accessToken: String
    let adminUserID: UUID
    let onCreated: () -> Void

    @State private var title = ""
    @State private var studyCode = "STUDY-\(Int.random(in: 1000...9999))"
    @State private var studyPassword = ""
    @State private var description = ""
    @State private var labels = [DraftStudyLabel()]
    @State private var errorMessage: String?
    @State private var isSaving = false

    private let service = StudySupabaseService()

    var body: some View {
        Form {
            Section {
                TextField("Study name", text: $title)
                TextField("Study ID", text: $studyCode)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                SecureField("Study password", text: $studyPassword)
                TextField("Description", text: $description, axis: .vertical)
            } header: {
                Text("Study")
            }

            Section {
                ForEach($labels) { $label in
                    VStack(alignment: .leading, spacing: 10) {
                        TextField("Label", text: $label.name)
                        TextField("Notification title", text: $label.notificationTitle)
                        IntervalMinutesControl(minutes: $label.intervalMinutes)
                        Button(role: .destructive) {
                            labels.removeAll { $0.id == label.id }
                        } label: {
                            Label("Delete Label", systemImage: "trash")
                        }
                    }
                    .padding(.vertical, 4)
                }

                Button {
                    labels.append(DraftStudyLabel())
                } label: {
                    Label("Add Label", systemImage: "tag.badge.plus")
                }
            } header: {
                Text("Labels")
            }

            if let errorMessage {
                Section {
                    Label(errorMessage, systemImage: "xmark.octagon")
                        .foregroundStyle(.red)
                }
            }

            Section {
                Button {
                    Task {
                        await save()
                    }
                } label: {
                    Label("Save Study", systemImage: "tray.and.arrow.down")
                }
                .disabled(isSaving)
            }
        }
        .navigationTitle("New EMA Study")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }
        }
    }

    private func save() async {
        let trimmedLabels = labels.map { $0.trimmed }.filter { !$0.name.isEmpty }

        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Enter a study name."
            return
        }

        guard !studyCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Enter a study ID."
            return
        }

        guard studyPassword.count >= 4 else {
            errorMessage = "Study password must be at least 4 characters."
            return
        }

        guard !trimmedLabels.isEmpty else {
            errorMessage = "Add at least one label."
            return
        }

        isSaving = true
        errorMessage = nil
        defer { isSaving = false }

        do {
            try await service.createStudy(
                title: title,
                studyCode: studyCode,
                studyPassword: studyPassword,
                description: description,
                labels: trimmedLabels,
                adminUserID: adminUserID,
                accessToken: accessToken
            )
            onCreated()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
