//
//  AdminDashboardView.swift
//  AppleBehaviorTraceApp
//

import SwiftUI

struct AdminDashboardView: View {
    @ObservedObject var authModel: AuthViewModel

    var body: some View {
        Form {
            if let errorMessage = authModel.errorMessage {
                Section {
                    Label(errorMessage, systemImage: "xmark.octagon")
                        .foregroundStyle(.red)
                }
            }

            if let session = authModel.session {
                StudyManagementView(accessToken: session.accessToken, adminUserID: session.profile.id)
            }

            Section {
                HStack {
                    Spacer()
                    Button {
                        authModel.signOut()
                    } label: {
                        Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                    .buttonStyle(AppFilledButtonStyle(variant: .destructive))
                    .frame(maxWidth: AppTheme.Layout.actionMaxWidth)
                    Spacer()
                }
            }
            .listRowBackground(Color.clear)
        }
    }
}

struct StudyManagementView: View {
    let accessToken: String
    let adminUserID: UUID

    @State private var forms: [StudyFormRecord] = []
    @State private var errorMessage: String?
    @State private var isLoading = false
    @State private var showingCreateStudy = false

    private let service = StudySupabaseService()

    var body: some View {
        Section {
            Button {
                showingCreateStudy = true
            } label: {
                Label("Create EMA Study", systemImage: "plus.circle")
            }

            if isLoading {
                ProgressView("Loading studies")
            } else if forms.isEmpty {
                ContentUnavailableView("No Studies", systemImage: "doc.text.magnifyingglass")
            } else {
                ForEach(forms) { form in
                    NavigationLink {
                        EditFormView(form: form, accessToken: accessToken) {
                            Task {
                                await loadForms()
                            }
                        }
                    } label: {
                        StudySummaryRow(form: form, showsCode: true)
                    }
                }
            }
        } header: {
            Text("Your EMA Studies")
        }
        .task {
            await loadForms()
        }
        .refreshable {
            await loadForms()
        }
        .sheet(isPresented: $showingCreateStudy) {
            NavigationStack {
                CreateFormView(accessToken: accessToken, adminUserID: adminUserID) {
                    showingCreateStudy = false
                    Task {
                        await loadForms()
                    }
                }
            }
        }

        if let errorMessage {
            Section {
                Label(errorMessage, systemImage: "xmark.octagon")
                    .foregroundStyle(.red)
            }
        }
    }

    private func loadForms() async {
        guard !accessToken.isEmpty else {
            return
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            forms = try await service.fetchForms(accessToken: accessToken)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
