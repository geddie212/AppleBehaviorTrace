//
//  LoginView.swift
//  AppleBehaviorTraceApp
//

import SwiftUI

struct LoginView: View {
    @ObservedObject var authModel: AuthViewModel
    @State private var email = ""
    @State private var password = ""
    @State private var showingParticipantRegistration = false
    @State private var showingAdminBootstrap = false
    @State private var loginSucceeded = false

    private var canLogIn: Bool {
        !email.isBlank && !password.isEmpty && !authModel.isWorking
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if let configurationMessage = authModel.configurationMessage {
                    Label(configurationMessage, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                }

                Text("Login")
                    .font(.headline)

                TextField("Email", text: $email)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                    .autocorrectionDisabled()
                    .appInputField()

                SecureField("Password", text: $password)
                    .appInputField()

                if let errorMessage = authModel.errorMessage {
                    Label(errorMessage, systemImage: "xmark.octagon")
                        .foregroundStyle(.red)
                }

                Button {
                    Task {
                        await authModel.signIn(email: email, password: password)
                        if authModel.session != nil {
                            loginSucceeded = true
                        }
                    }
                } label: {
                    Label(loginSucceeded ? "Logged In" : "Log In", systemImage: loginSucceeded ? "checkmark.circle.fill" : "person.crop.circle")
                }
                .buttonStyle(AppFilledButtonStyle(variant: loginSucceeded ? .success : .primary))
                .disabled(!canLogIn)

                Button {
                    showingParticipantRegistration = true
                } label: {
                    Label("Create Account", systemImage: "person.badge.plus")
                }
                .buttonStyle(AppSecondaryButtonStyle())
                .disabled(authModel.isWorking)

                Button {
                    showingAdminBootstrap = true
                } label: {
                    Label("Create Admin", systemImage: "person.badge.key")
                }
                .buttonStyle(AppSecondaryButtonStyle())
                .disabled(authModel.isWorking)
            }
            .frame(maxWidth: AppTheme.Layout.formMaxWidth)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 24)
            .padding(.vertical, 32)
        }
        .background(Color(.systemGroupedBackground))
        .sheet(isPresented: $showingParticipantRegistration) {
            NavigationStack {
                RegisterView(authModel: authModel, mode: .participant)
            }
        }
        .sheet(isPresented: $showingAdminBootstrap) {
            NavigationStack {
                RegisterView(authModel: authModel, mode: .admin)
            }
        }
    }
}
