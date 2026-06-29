//
//  UserDashboardView.swift
//  AppleBehaviorTraceApp
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct UserDashboardView: View {
    @ObservedObject var authModel: AuthViewModel

    @State private var activeStudySheet: StudyCatalogSheet?
    @State private var isPresentingStudySheet = false
    @State private var studyCatalogRefreshID = UUID()
    @State private var showingAlreadyRegisteredAlert = false

    var body: some View {
        ZStack {
            List {
                NotificationPermissionSection()

                if let session = authModel.session {
                    StudyCatalogView(
                        accessToken: session.accessToken,
                        refreshID: studyCatalogRefreshID,
                        onRegisterStudy: { study in
                            presentStudySheet(.register(study))
                        },
                        onLeaveStudy: { study in
                            presentStudySheet(.leave(study))
                        },
                        onAlreadyRegisteredStudy: {
                            showingAlreadyRegisteredAlert = true
                        }
                    )
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
            .scrollDismissesKeyboard(.immediately)

            if let sheet = activeStudySheet, let accessToken = authModel.session?.accessToken {
                StudyCatalogModalOverlay {
                    closeStudySheet(refreshesCatalog: false)
                } content: {
                    switch sheet {
                    case .register(let study):
                        StudyRegistrationView(
                            study: study,
                            accessToken: accessToken,
                            onCancel: {
                                closeStudySheet(refreshesCatalog: false)
                            },
                            onRegistered: {
                                closeStudySheet(refreshesCatalog: true)
                            }
                        )

                    case .leave(let study):
                        LeaveStudyView(
                            study: study,
                            accessToken: accessToken,
                            onCancel: {
                                closeStudySheet(refreshesCatalog: false)
                            },
                            onLeft: {
                                closeStudySheet(refreshesCatalog: true)
                            }
                        )
                    }
                }
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
                .zIndex(2)
            }

            if showingAlreadyRegisteredAlert {
                StudyMessageOverlay(
                    title: "Already Registered",
                    message: "You're already registered with this study.",
                    actionTitle: "OK"
                ) {
                    showingAlreadyRegisteredAlert = false
                }
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
                .zIndex(3)
            }
        }
        .animation(.easeOut(duration: 0.16), value: activeStudySheet?.id)
        .animation(.easeOut(duration: 0.16), value: showingAlreadyRegisteredAlert)
    }

    private func presentStudySheet(_ sheet: StudyCatalogSheet) {
        guard activeStudySheet == nil, !isPresentingStudySheet else {
            return
        }

        isPresentingStudySheet = true
        activeStudySheet = sheet
    }

    private func closeStudySheet(refreshesCatalog: Bool) {
        activeStudySheet = nil
        isPresentingStudySheet = false

        if refreshesCatalog {
            studyCatalogRefreshID = UUID()
        }
    }
}

struct StudyCatalogView: View {
    let accessToken: String
    let refreshID: UUID
    let onRegisterStudy: (StudyPublicRecord) -> Void
    let onLeaveStudy: (StudyPublicRecord) -> Void
    let onAlreadyRegisteredStudy: () -> Void

    @State private var registeredStudies: [StudyPublicRecord] = []
    @State private var searchResults: [StudyPublicRecord] = []
    @State private var searchText = ""
    @State private var errorMessage: String?
    @State private var isLoadingRegistered = false
    @State private var isSearching = false
    @State private var searchTask: Task<Void, Never>?
    @FocusState private var isSearchFocused: Bool

    private let service = StudySupabaseService()

    private var registeredStudyIDs: Set<Int> {
        Set(registeredStudies.map(\.id))
    }

    var body: some View {
        Group {
            Section {
                if isLoadingRegistered {
                    ProgressView("Loading registered studies")
                } else if registeredStudies.isEmpty {
                    Text("0 studies registered")
                        .foregroundStyle(.secondary)
                        .onTapGesture {
                            dismissSearchKeyboard()
                        }
                } else {
                    ForEach(registeredStudies) { study in
                        RegisteredStudyRow(study: study) {
                            dismissSearchKeyboard()
                            onLeaveStudy(study)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            dismissSearchKeyboard()
                        }
                    }
                }
            } header: {
                Text("Your Registered Studies")
            }

            Section {
                TextField("Search studies", text: $searchText)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($isSearchFocused)
                    .appInputField()
                    .onSubmit {
                        searchTask?.cancel()
                        Task {
                            await searchStudies()
                        }
                    }
                    .onChange(of: searchText) { _, _ in
                        scheduleSearch()
                    }

                if isSearching {
                    ProgressView("Searching studies")
                } else if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text("Type study keywords to search.")
                        .foregroundStyle(.secondary)
                        .onTapGesture {
                            dismissSearchKeyboard()
                        }
                } else if searchResults.isEmpty {
                    Text("No studies found.")
                        .foregroundStyle(.secondary)
                        .onTapGesture {
                            dismissSearchKeyboard()
                        }
                } else {
                    ForEach(searchResults) { study in
                        let isRegistered = registeredStudyIDs.contains(study.id)
                        Button {
                            if isRegistered {
                                onAlreadyRegisteredStudy()
                                dismissSearchKeyboard()
                            } else {
                                onRegisterStudy(study)
                                dismissSearchKeyboard()
                            }
                        } label: {
                            HStack(alignment: .top, spacing: 12) {
                                PublicStudySummaryRow(study: study, showsCode: true)

                                Spacer()

                                if isRegistered {
                                    HStack(spacing: 4) {
                                        Image(systemName: "checkmark.circle.fill")
                                        Text("Registered")
                                    }
                                        .font(.caption)
                                        .foregroundStyle(.green)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(AppPressableRowButtonStyle())
                    }
                }
            } header: {
                Text("Search Studies")
            }
    
            if let errorMessage {
                Section {
                    Label(errorMessage, systemImage: "xmark.octagon")
                        .foregroundStyle(.red)
                }
            }
        }
        .task {
            await loadRegisteredStudies()
        }
        .refreshable {
            await loadRegisteredStudies()
        }
        .onChange(of: refreshID) { _, _ in
            Task {
                await loadRegisteredStudies()
                await searchStudies()
            }
        }
        .onDisappear {
            searchTask?.cancel()
            dismissSearchKeyboard()
        }
    }

    private func loadRegisteredStudies() async {
        guard !accessToken.isEmpty else {
            return
        }

        isLoadingRegistered = true
        errorMessage = nil
        defer { isLoadingRegistered = false }

        do {
            registeredStudies = try await service.fetchRegisteredStudies(accessToken: accessToken)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func searchStudies() async {
        guard !accessToken.isEmpty else {
            return
        }

        let trimmedSearch = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedSearch.isEmpty else {
            searchResults = []
            return
        }

        isSearching = true
        errorMessage = nil
        defer { isSearching = false }

        do {
            searchResults = try await service.searchStudies(query: trimmedSearch, accessToken: accessToken)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func scheduleSearch() {
        searchTask?.cancel()
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(250))

            guard !Task.isCancelled else {
                return
            }

            await searchStudies()
        }
    }

    private func dismissSearchKeyboard() {
        isSearchFocused = false
        #if canImport(UIKit)
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        #endif
    }
}

private enum StudyCatalogSheet: Identifiable {
    case register(StudyPublicRecord)
    case leave(StudyPublicRecord)

    var id: String {
        switch self {
        case .register(let study):
            return "register-\(study.id)"
        case .leave(let study):
            return "leave-\(study.id)"
        }
    }
}

private struct RegisteredStudyRow: View {
    let study: StudyPublicRecord
    let onLeave: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            PublicStudySummaryRow(study: study, showsCode: true)

            HStack {
                Spacer()
                Button {
                    onLeave()
                } label: {
                    Label("Leave Study", systemImage: "rectangle.portrait.and.arrow.right")
                }
                .buttonStyle(AppFilledButtonStyle(variant: .destructive))
                .frame(maxWidth: AppTheme.Layout.actionMaxWidth)
                Spacer()
            }
        }
        .padding(.vertical, 4)
    }
}

private struct StudyCatalogModalOverlay<Content: View>: View {
    let onDismiss: () -> Void
    @ViewBuilder let content: () -> Content

    var body: some View {
        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()

            content()
                .frame(maxWidth: 420)
                .frame(maxHeight: 560)
                .background(AppTheme.Colors.panelBackground)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.Layout.cornerRadius, style: .continuous))
                .shadow(color: .black.opacity(0.2), radius: 18, x: 0, y: 10)
                .padding(.horizontal, 18)
        }
        .accessibilityAddTraits(.isModal)
    }
}

private struct StudyMessageOverlay: View {
    let title: String
    let message: String
    let actionTitle: String
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 18) {
                Text(title)
                    .font(.headline)

                Text(message)
                    .font(.body)
                    .foregroundStyle(.secondary)

                AppCenteredActionButton(variant: .primary, action: onDismiss) {
                    Text(actionTitle)
                }
            }
            .padding(20)
            .frame(maxWidth: 360)
            .background(AppTheme.Colors.panelBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Layout.cornerRadius, style: .continuous))
            .shadow(color: .black.opacity(0.2), radius: 18, x: 0, y: 10)
            .padding(.horizontal, 18)
        }
        .accessibilityAddTraits(.isModal)
    }
}

private struct StudyRegistrationView: View {
    let study: StudyPublicRecord
    let accessToken: String
    let onCancel: () -> Void
    let onRegistered: () -> Void

    @State private var password = ""
    @State private var errorMessage: String?
    @State private var isRegistering = false
    @FocusState private var isPasswordFocused: Bool

    private let service = StudySupabaseService()

    var body: some View {
        VStack(spacing: 0) {
            ModalHeader(title: "Join Study", onCancel: cancel)

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    FieldGroupHeader("Study")
                    PublicStudySummaryRow(study: study, showsCode: true)

                    FieldGroupHeader("Register")
                    SecureField("Study password", text: $password)
                        .focused($isPasswordFocused)
                        .appInputField()

                    if let errorMessage {
                        Label(errorMessage, systemImage: "xmark.octagon")
                            .foregroundStyle(.red)
                    }
                }
                .padding(16)
            }
            .scrollDismissesKeyboard(.immediately)

            Divider()

            AppCenteredActionButton(
                variant: .primary,
                isDisabled: isRegistering || password.isEmpty
            ) {
                isPasswordFocused = false
                Task {
                    await register()
                }
            } label: {
                Label("Register Study", systemImage: "checkmark.seal")
            }
            .padding(16)
            .background(.bar)
        }
        .onDisappear {
            isPasswordFocused = false
        }
    }

    private func cancel() {
        isPasswordFocused = false
        onCancel()
    }

    private func register() async {
        isRegistering = true
        errorMessage = nil
        defer { isRegistering = false }

        do {
            _ = try await service.registerForStudy(formID: study.id, password: password, accessToken: accessToken)
            onRegistered()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct LeaveStudyView: View {
    let study: StudyPublicRecord
    let accessToken: String
    let onCancel: () -> Void
    let onLeft: () -> Void

    @State private var confirmationStudyID = ""
    @State private var errorMessage: String?
    @State private var isLeaving = false
    @FocusState private var isConfirmationFocused: Bool

    private let service = StudySupabaseService()

    private var canLeaveStudy: Bool {
        confirmationStudyID.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() == study.studyCode.uppercased()
            && !isLeaving
    }

    var body: some View {
        VStack(spacing: 0) {
            ModalHeader(title: "Leave Study", onCancel: cancel)

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        FieldGroupHeader("Are you sure?")
                        PublicStudySummaryRow(study: study, showsCode: true)

                        Text("Type the study ID to leave this study.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)

                        FieldGroupHeader("Confirm Study ID")
                        TextField("Study ID", text: $confirmationStudyID)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                            .focused($isConfirmationFocused)
                            .appInputField()
                            .id("studyIDField")

                        if let errorMessage {
                            Label(errorMessage, systemImage: "xmark.octagon")
                                .foregroundStyle(.red)
                        }
                    }
                    .padding(16)
                }
                .scrollDismissesKeyboard(.immediately)
                .onChange(of: isConfirmationFocused) { _, isFocused in
                    guard isFocused else {
                        return
                    }

                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        withAnimation(.easeOut(duration: 0.2)) {
                            proxy.scrollTo("studyIDField", anchor: .center)
                        }
                    }
                }
            }

            Divider()

            AppCenteredActionButton(
                variant: .destructive,
                isDisabled: !canLeaveStudy
            ) {
                isConfirmationFocused = false
                Task {
                    await leaveStudy()
                }
            } label: {
                Label("Leave Study", systemImage: "rectangle.portrait.and.arrow.right")
            }
            .padding(16)
            .background(.bar)
        }
        .onDisappear {
            isConfirmationFocused = false
        }
    }

    private func cancel() {
        isConfirmationFocused = false
        onCancel()
    }

    private func leaveStudy() async {
        isLeaving = true
        errorMessage = nil
        defer { isLeaving = false }

        do {
            try await service.leaveStudy(studyCode: study.studyCode, accessToken: accessToken)
            onLeft()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct ModalHeader: View {
    let title: String
    let onCancel: () -> Void

    var body: some View {
        HStack {
            Text(title)
                .font(.headline)

            Spacer()

            Button(action: onCancel) {
                Image(systemName: "xmark")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .frame(width: 34, height: 34)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close")
        }
        .padding(.leading, 16)
        .padding(.trailing, 10)
        .padding(.vertical, 10)
        .background(.bar)
    }
}

private struct FieldGroupHeader: View {
    let title: String

    init(_ title: String) {
        self.title = title
    }

    var body: some View {
        Text(title)
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
    }
}
