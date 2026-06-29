//
//  AuthRootView.swift
//  AppleBehaviorTraceApp
//

import SwiftUI

struct AuthRootView: View {
    @StateObject private var authModel = AuthViewModel()

    var body: some View {
        NavigationStack {
            Group {
                if authModel.isCheckingSession {
                    ProgressView("Checking session")
                } else if let session = authModel.session {
                    switch session.profile.role {
                    case .admin:
                        AdminDashboardView(authModel: authModel)
                    case .user:
                        UserDashboardView(authModel: authModel)
                    }
                } else {
                    LoginView(authModel: authModel)
                }
            }
            .navigationTitle("BehaviorTrace")
            .task {
                await authModel.restoreSession()
            }
        }
    }
}

struct AuthRootView_Previews: PreviewProvider {
    static var previews: some View {
        AuthRootView()
    }
}
