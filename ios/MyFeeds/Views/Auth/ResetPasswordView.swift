import SwiftUI

struct ResetPasswordView: View {
    @Binding var path: [AuthRoute]
    @Environment(AuthStore.self) private var auth

    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var isLoading = false
    @State private var toast: AuthToast?
    @FocusState private var focusedField: Field?

    private enum Field { case new, confirm }

    private var passwordsMatch: Bool {
        !newPassword.isEmpty && newPassword == confirmPassword
    }

    private var canSubmit: Bool {
        newPassword.count >= 6 && passwordsMatch
    }

    var body: some View {
        AuthScaffold(showBack: true, backAction: { path.removeLast() }, toast: $toast) {
            AuthBranding(
                title: "Set a new password",
                subtitle: "Choose a strong password for your account. Must be at least 6 characters.",
                titleSize: 20
            )

            AuthFieldLabel(text: "New password", topMargin: 0)
            SecureField("At least 6 characters", text: $newPassword)
                .textContentType(.newPassword)
                .focused($focusedField, equals: .new)
                .modifier(AuthInputStyle(
                    isFocused: focusedField == .new,
                    borderColor: passwordsMatch ? Theme.success : nil
                ))
                .overlay(alignment: .trailing) {
                    if passwordsMatch {
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Theme.success)
                            .padding(.trailing, 12)
                    }
                }
                .disabled(isLoading)

            AuthFieldLabel(text: "Confirm password")
            SecureField("Re-enter your new password", text: $confirmPassword)
                .textContentType(.newPassword)
                .focused($focusedField, equals: .confirm)
                .modifier(AuthInputStyle(
                    isFocused: focusedField == .confirm,
                    borderColor: passwordsMatch ? Theme.success : nil
                ))
                .disabled(isLoading)

            if !confirmPassword.isEmpty && newPassword != confirmPassword {
                Text("Passwords do not match")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.destructive)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 4)
            }

            PrimaryButton(title: "Update password", isLoading: isLoading, isDisabled: !canSubmit) {
                submit()
            }
            .padding(.top, 24)

            Button {
                path.removeAll()
            } label: {
                Text("Back to sign in")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Theme.accent)
            }
            .padding(.top, 20)
        }
        .navigationBarBackButtonHidden()
        .toolbar(.hidden, for: .navigationBar)
    }

    private func submit() {
        guard !newPassword.isEmpty, !confirmPassword.isEmpty else {
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            toast = AuthToast(message: String(localized: "Please fill in both password fields."), isError: true)
            return
        }
        isLoading = true
        Task {
            let error = await auth.updatePassword(newPassword)
            isLoading = false
            if let error {
                UINotificationFeedbackGenerator().notificationOccurred(.error)
                toast = AuthToast(message: error, isError: true)
            } else {
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                toast = AuthToast(message: String(localized: "Password updated! Sign in with your new password."), isError: false)
                try? await Task.sleep(for: .seconds(1.5))
                path.removeAll()
            }
        }
    }
}
