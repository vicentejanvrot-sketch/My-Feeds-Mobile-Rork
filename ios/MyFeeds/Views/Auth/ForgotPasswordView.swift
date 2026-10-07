import SwiftUI

struct ForgotPasswordView: View {
    @Binding var path: [AuthRoute]
    @Environment(AuthStore.self) private var auth

    @State private var email = ""
    @State private var isLoading = false
    @State private var toast: AuthToast?
    @FocusState private var isFocused: Bool

    var body: some View {
        AuthScaffold(showBack: true, backAction: { path.removeLast() }, toast: $toast) {
            AuthBranding(
                title: "Reset your password",
                subtitle: "Enter the email address associated with your account and we'll send you a link to reset your password.",
                titleSize: 20
            )

            AuthFieldLabel(text: "Email", topMargin: 0)
            TextField(text: $email, prompt: Text(verbatim: "you@example.com")) { Text("Email") }
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($isFocused)
                .submitLabel(.done)
                .onSubmit { submit() }
                .modifier(AuthInputStyle(isFocused: isFocused))
                .disabled(isLoading)

            PrimaryButton(title: "Send reset link", isLoading: isLoading) { submit() }
                .padding(.top, 24)

            Button {
                path.removeLast()
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
        let trimmedEmail = email.trimmingCharacters(in: .whitespaces)
        guard !trimmedEmail.isEmpty else {
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            toast = AuthToast(message: String(localized: "Please enter your email address.", bundle: .appStrings), isError: true)
            return
        }
        isLoading = true
        Task {
            let error = await auth.sendPasswordReset(email: trimmedEmail)
            isLoading = false
            if let error {
                UINotificationFeedbackGenerator().notificationOccurred(.error)
                toast = AuthToast(message: error, isError: true)
            } else {
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                toast = AuthToast(message: String(localized: "Check your inbox — we've sent a password reset link.", bundle: .appStrings), isError: false)
            }
        }
    }
}
