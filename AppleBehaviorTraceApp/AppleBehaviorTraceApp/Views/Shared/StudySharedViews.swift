//
//  StudySharedViews.swift
//  AppleBehaviorTraceApp
//

import SwiftUI
import UserNotifications

struct StudySummaryRow: View {
    let form: StudyFormRecord
    let showsCode: Bool

    var body: some View {
        StudySummaryContent(title: form.title, description: form.description, studyCode: form.studyCode, showsCode: showsCode)
    }
}

struct PublicStudySummaryRow: View {
    let study: StudyPublicRecord
    let showsCode: Bool

    var body: some View {
        StudySummaryContent(title: study.title, description: study.description, studyCode: study.studyCode, showsCode: showsCode)
    }
}

private struct StudySummaryContent: View {
    let title: String
    let description: String?
    let studyCode: String
    let showsCode: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)

            if let description, !description.isEmpty {
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if showsCode {
                Text("ID: \(studyCode)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct IntervalMinutesControl: View {
    @Binding var minutes: Int

    var body: some View {
        HStack(spacing: 12) {
            Button {
                minutes = max(1, minutes - 1)
            } label: {
                Image(systemName: "minus.circle")
            }
            .buttonStyle(.borderless)

            TextField("Minutes", value: $minutes, format: .number)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .frame(minWidth: 72)
                .onChange(of: minutes) { _, newValue in
                    minutes = min(240, max(1, newValue))
                }

            Button {
                minutes = min(240, minutes + 1)
            } label: {
                Image(systemName: "plus.circle")
            }
            .buttonStyle(.borderless)

            Text("min")
                .foregroundStyle(.secondary)
        }
    }
}

struct NotificationPermissionSection: View {
    @State private var statusText: String?

    var body: some View {
        Section {
            Button {
                Task {
                    await requestNotifications()
                }
            } label: {
                Label("Allow Study Notifications", systemImage: "bell.badge")
            }

            if let statusText {
                Text(statusText)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Notifications")
        }
    }

    private func requestNotifications() async {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])
            statusText = granted ? "Notifications allowed." : "Notifications were not allowed."
        } catch {
            statusText = error.localizedDescription
        }
    }
}
