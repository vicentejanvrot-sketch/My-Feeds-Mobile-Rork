import SwiftUI

/// Local inline toast used only on auth screens.
struct AuthToast: Equatable {
    let message: String
    let isError: Bool
}

/// Shared scaffold for auth screens: card, branding, inline toast.
struct AuthScaffold<Content: View>: View {
    var showBack = false
    var backAction: (() -> Void)?
    @Binding var toast: AuthToast?
    @ViewBuilder let content: Content

    var body: some View {
        ZStack(alignment: .top) {
            Theme.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    if showBack {
                        Button {
                            backAction?()
                        } label: {
                            Image(systemName: "arrow.left")
                                .font(.system(size: 20))
                                .foregroundStyle(Theme.textSecondary)
                                .padding(8)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.bottom, 16)
                    }

                    VStack(spacing: 0) {
                        content
                    }
                    .padding(28)
                    .frame(maxWidth: 440)
                    .background(Theme.card)
                    .clipShape(.rect(cornerRadius: 12))
                }
                .padding(.horizontal, 24)
                .padding(.top, 60)
                .padding(.bottom, 40)
                .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)

            if let toast {
                HStack {
                    Text(toast.message)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(toast.isError ? Theme.destructive : Theme.success)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 13)
                .background(toast.isError ? Theme.destructiveBg : Color(hsl: 142, 30, 12))
                .clipShape(.rect(cornerRadius: 10))
                .overlay(alignment: .leading) {
                    UnevenRoundedRectangle(topLeadingRadius: 10, bottomLeadingRadius: 10)
                        .fill(toast.isError ? Theme.destructive : Theme.success)
                        .frame(width: 3)
                }
                .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: toast)
        .onChange(of: toast) { _, newValue in
            guard newValue != nil else { return }
            Task {
                try? await Task.sleep(for: .seconds(3.5))
                withAnimation { toast = nil }
            }
        }
    }
}

/// Branding block: logo + title + subtitle.
struct AuthBranding: View {
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey
    var titleSize: CGFloat = 22

    var body: some View {
        VStack(spacing: 0) {
            Image("AppLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 64, height: 64)
                .clipShape(.rect(cornerRadius: 16))
                .padding(.bottom, 16)
            Text(title)
                .font(.system(size: titleSize, weight: .bold))
                .foregroundStyle(Theme.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.bottom, 8)
            Text(subtitle)
                .font(.system(size: 14))
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.bottom, 28)
        }
    }
}

/// Uppercase field label.
struct AuthFieldLabel: View {
    let text: LocalizedStringKey
    var topMargin: CGFloat = 16

    var body: some View {
        Text(text)
            .textCase(.uppercase)
            .font(.system(size: 13, weight: .semibold))
            .kerning(0.5)
            .foregroundStyle(Theme.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, topMargin)
            .padding(.bottom, 6)
    }
}

/// Styled auth input container.
struct AuthInputStyle: ViewModifier {
    var isFocused: Bool
    var borderColor: Color?

    func body(content: Content) -> some View {
        content
            .font(.system(size: 15))
            .foregroundStyle(Theme.textPrimary)
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
            .background(Theme.input)
            .clipShape(.rect(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(borderColor ?? (isFocused ? Theme.borderFocus : Theme.border), lineWidth: 1)
            )
    }
}

/// Primary gradient button used across the app.
struct PrimaryButton: View {
    let title: LocalizedStringKey
    var isLoading = false
    var isDisabled = false
    var icon: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView().tint(.white)
                } else {
                    if let icon {
                        Image(systemName: icon)
                            .font(.system(size: 16, weight: .semibold))
                    }
                    Text(title)
                        .font(.system(size: 16, weight: .bold))
                }
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(Theme.accentGradient)
            .clipShape(.rect(cornerRadius: 10))
            .opacity(isDisabled ? 0.5 : 1)
        }
        .disabled(isDisabled || isLoading)
    }
}
