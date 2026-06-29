//
//  AppTheme.swift
//  AppleBehaviorTraceApp
//

import SwiftUI

enum AppTheme {
    enum Colors {
        static let primaryButton = Color(red: 0.0, green: 0.35, blue: 0.95)
        static let primaryButtonPressed = Color(red: 0.0, green: 0.22, blue: 0.70)
        static let successButton = Color(red: 0.0, green: 0.58, blue: 0.24)
        static let successButtonPressed = Color(red: 0.0, green: 0.42, blue: 0.18)
        static let destructiveButton = Color(red: 0.86, green: 0.12, blue: 0.12)
        static let destructiveButtonPressed = Color(red: 0.64, green: 0.06, blue: 0.06)
        static let disabledButton = Color.gray.opacity(0.45)
        static let fieldBackground = Color(.systemGray5)
        static let fieldBorder = Color(.systemGray3)
        static let panelBackground = Color(.systemBackground)
        static let secondaryBorder = Color(.separator)
    }

    enum Layout {
        static let formMaxWidth: CGFloat = 380
        static let actionMaxWidth: CGFloat = 340
        static let cornerRadius: CGFloat = 8
    }
}

struct AppInputFieldModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .textFieldStyle(.plain)
            .padding(12)
            .background(AppTheme.Colors.fieldBackground)
            .overlay {
                RoundedRectangle(cornerRadius: AppTheme.Layout.cornerRadius, style: .continuous)
                    .stroke(AppTheme.Colors.fieldBorder, lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Layout.cornerRadius, style: .continuous))
    }
}

struct AppFilledButtonStyle: ButtonStyle {
    enum Variant {
        case primary
        case success
        case destructive
    }

    let variant: Variant
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(backgroundColor(isPressed: configuration.isPressed))
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Layout.cornerRadius, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }

    private func backgroundColor(isPressed: Bool) -> Color {
        guard isEnabled else {
            return AppTheme.Colors.disabledButton
        }

        switch variant {
        case .primary:
            return isPressed ? AppTheme.Colors.primaryButtonPressed : AppTheme.Colors.primaryButton
        case .success:
            return isPressed ? AppTheme.Colors.successButtonPressed : AppTheme.Colors.successButton
        case .destructive:
            return isPressed ? AppTheme.Colors.destructiveButtonPressed : AppTheme.Colors.destructiveButton
        }
    }
}

struct AppCenteredActionButton<LabelContent: View>: View {
    let variant: AppFilledButtonStyle.Variant
    let isDisabled: Bool
    let action: () -> Void
    @ViewBuilder let label: () -> LabelContent

    init(
        variant: AppFilledButtonStyle.Variant,
        isDisabled: Bool = false,
        action: @escaping () -> Void,
        @ViewBuilder label: @escaping () -> LabelContent
    ) {
        self.variant = variant
        self.isDisabled = isDisabled
        self.action = action
        self.label = label
    }

    var body: some View {
        HStack {
            Spacer()
            Button(action: action) {
                label()
            }
            .buttonStyle(AppFilledButtonStyle(variant: variant))
            .frame(maxWidth: AppTheme.Layout.actionMaxWidth)
            .disabled(isDisabled)
            Spacer()
        }
    }
}

extension View {
    func appInputField() -> some View {
        modifier(AppInputFieldModifier())
    }
}

struct AppSecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(isEnabled ? AppTheme.Colors.primaryButton : .secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(AppTheme.Colors.panelBackground)
            .overlay {
                RoundedRectangle(cornerRadius: AppTheme.Layout.cornerRadius, style: .continuous)
                    .stroke(isEnabled ? AppTheme.Colors.primaryButton : AppTheme.Colors.secondaryBorder, lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Layout.cornerRadius, style: .continuous))
            .opacity(configuration.isPressed ? 0.72 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct AppPressableRowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.vertical, 2)
            .padding(.horizontal, 4)
            .background(configuration.isPressed ? Color(.systemGray5) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Layout.cornerRadius, style: .continuous))
            .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
    }
}
