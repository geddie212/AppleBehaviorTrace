//
//  EditFormView.swift
//  AppleBehaviorTraceApp
//

import SwiftUI

struct EditFormView: View {
    let form: StudyFormRecord
    let accessToken: String
    let onChanged: () -> Void

    @State private var labels: [EditableStudyLabel]
    @State private var errorMessage: String?
    @State private var isSaving = false
    @State private var lastSavedSignature: String
    @State private var saveSucceeded = false

    private let service = StudySupabaseService()

    init(form: StudyFormRecord, accessToken: String, onChanged: @escaping () -> Void) {
        self.form = form
        self.accessToken = accessToken
        self.onChanged = onChanged
        let initialLabels = form.labels.map { EditableStudyLabel($0, formID: form.id) }
        _labels = State(initialValue: initialLabels)
        _lastSavedSignature = State(initialValue: Self.signature(for: initialLabels))
    }

    var body: some View {
        Form {
            Section {
                StudySummaryRow(form: form, showsCode: true)
            } header: {
                Text("Study")
            }

            Section {
                if labels.isEmpty {
                    ContentUnavailableView("No Labels", systemImage: "tag")
                } else {
                    ForEach($labels) { $label in
                        EditableLabelFields(label: $label) {
                            deleteLocally(label.id)
                        }
                    }
                }

                Button {
                    labels.append(EditableStudyLabel(formID: form.id))
                    saveSucceeded = false
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
            } else if hasUnsavedChanges {
                Section {
                    Label("Unsaved changes", systemImage: "xmark.circle.fill")
                        .foregroundStyle(.red)
                }
            } else if saveSucceeded {
                Section {
                    Label("Saved changes", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
            }

            if hasUnsavedChanges || isSaving {
                Section {
                    Button {
                        Task {
                            await save()
                        }
                    } label: {
                        Label("Save Form", systemImage: "tray.and.arrow.down")
                    }
                    .disabled(isSaving)
                }
            }
        }
        .navigationTitle(form.title)
    }

    private var hasUnsavedChanges: Bool {
        Self.signature(for: labels) != lastSavedSignature
    }

    private func deleteLocally(_ id: EditableStudyLabel.ID) {
        labels.removeAll { $0.id == id }
        saveSucceeded = false
    }

    private func save() async {
        let cleanedLabels = labels.map(\.trimmed).filter { !$0.labelName.isEmpty }

        guard !cleanedLabels.isEmpty else {
            errorMessage = "Add at least one label."
            return
        }

        isSaving = true
        errorMessage = nil
        saveSucceeded = false
        defer { isSaving = false }

        do {
            let existingIDs = Set(form.labels.map(\.id))
            let currentExistingIDs = Set(cleanedLabels.compactMap(\.databaseID))
            let deletedIDs = existingIDs.subtracting(currentExistingIDs)

            for labelID in deletedIDs {
                try await service.deleteLabel(id: labelID, accessToken: accessToken)
            }

            for label in cleanedLabels {
                if let databaseID = label.databaseID {
                    try await service.updateLabel(label, databaseID: databaseID, accessToken: accessToken)
                } else {
                    try await service.createLabel(label, formID: form.id, accessToken: accessToken)
                }
            }

            labels = cleanedLabels
            lastSavedSignature = Self.signature(for: cleanedLabels)
            saveSucceeded = true
            onChanged()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private static func signature(for labels: [EditableStudyLabel]) -> String {
        labels
            .map { "\($0.databaseID ?? -1)|\($0.labelName)|\($0.notificationTitle)|\($0.intervalMinutes)" }
            .joined(separator: "\n")
    }
}

private struct EditableLabelFields: View {
    @Binding var label: EditableStudyLabel
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField("Label", text: $label.labelName)
            TextField("Notification title", text: $label.notificationTitle)
            IntervalMinutesControl(minutes: $label.intervalMinutes)
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete Label", systemImage: "trash")
            }
        }
        .padding(.vertical, 4)
    }
}
