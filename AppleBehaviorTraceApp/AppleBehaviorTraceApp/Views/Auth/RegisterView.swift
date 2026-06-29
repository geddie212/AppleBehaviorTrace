//
//  RegisterView.swift
//  AppleBehaviorTraceApp
//

import SwiftUI

enum RegistrationMode {
    case participant
    case admin

    var title: String {
        switch self {
        case .participant:
            return "Create Account"
        case .admin:
            return "Create Admin"
        }
    }

    var emailPrompt: String {
        switch self {
        case .participant:
            return "Email"
        case .admin:
            return "Admin email"
        }
    }

    var buttonTitle: String {
        switch self {
        case .participant:
            return "Create Account"
        case .admin:
            return "Create Admin Account"
        }
    }

    var buttonIcon: String {
        switch self {
        case .participant:
            return "person.badge.plus"
        case .admin:
            return "checkmark.seal"
        }
    }

    var footer: String? {
        switch self {
        case .participant:
            return nil
        case .admin:
            return "Use this once for a development Supabase project. Do not ship client-side admin bootstrapping in production."
        }
    }
}

struct RegisterView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var authModel: AuthViewModel
    let mode: RegistrationMode

    @State private var email = ""
    @State private var password = ""

    var body: some View {
        Form {
            Section {
                TextField(mode.emailPrompt, text: $email)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                    .autocorrectionDisabled()
                    .appInputField()

                SecureField("Password", text: $password)
                    .appInputField()
            } header: {
                Text(mode.title)
            } footer: {
                if let footer = mode.footer {
                    Text(footer)
                }
            }

            if let errorMessage = authModel.errorMessage {
                Section {
                    Label(errorMessage, systemImage: "xmark.octagon")
                        .foregroundStyle(.red)
                }
            }

            Section {
                Button {
                    Task {
                        switch mode {
                        case .participant:
                            await authModel.registerParticipant(email: email, password: password)
                        case .admin:
                            await authModel.createAdmin(email: email, password: password)
                        }

                        if authModel.session != nil {
                            dismiss()
                        }
                    }
                } label: {
                    Label(mode.buttonTitle, systemImage: mode.buttonIcon)
                }
                .disabled(authModel.isWorking)
            }
        }
        .navigationTitle(mode.title)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }
        }
    }
}
