import SwiftUI

struct SignupView: View {
    @Binding var path: [AuthRoute]
    @Environment(AuthStore.self) private var auth

    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var isLoading = false
    @State private var toast: AuthToast?
    @FocusState private var focusedField: Field?

    private enum Field { case email, password, confirm }

    var body: some View {
        AuthScaffold(toast: $toast) {
            AuthBranding(title: "Create Account", subtitle: "Sign up to start using My Feeds.")

            AuthFieldLabel(text: "Email", topMargin: 0)
            TextField(text: $email, prompt: Text(verbatim: "you@example.com")) { Text("Email") }
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($focusedField, equals: .email)
                .submitLabel(.next)
                .onSubmit { focusedField = .password }
                .modifier(AuthInputStyle(isFocused: focusedField == .email))
                .disabled(isLoading)

            AuthFieldLabel(text: "Password")
            SecureField("At least 6 characters", text: $password)
                .textContentType(.newPassword)
                .focused($focusedField, equals: .password)
                .submitLabel(.next)
                .onSubmit { focusedField = .confirm }
                .modifier(AuthInputStyle(isFocused: focusedField == .password))
                .disabled(isLoading)

            AuthFieldLabel(text: "Confirm Password")
            SecureField("Re-enter your password", text: $confirmPassword)
                .textContentType(.newPassword)
                .focused($focusedField, equals: .confirm)
                .submitLabel(.done)
                .onSubmit { submit() }
                .modifier(AuthInputStyle(isFocused: focusedField == .confirm))
                .disabled(isLoading)

            PrimaryButton(title: "Create Account", isLoading: isLoading) { submit() }
                .padding(.top, 28)

            Button {
                path.removeAll()
            } label: {
                Text("Already have an account? Sign in")
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
        guard !trimmedEmail.isEmpty, !password.isEmpty, !confirmPassword.isEmpty else {
            showError(String(localized: "Please fill in all fields."))
            return
        }
        guard password == confirmPassword else {
            showError(String(localized: "Passwords do not match."))
            return
        }
        guard password.count >= 6 else {
            showError(String(localized: "Password must be at least 6 characters."))
            return
        }
        isLoading = true
        Task {
            let error = await auth.signUp(email: trimmedEmail, password: password)
            isLoading = false
            if let error {
                showError(error)
            } else {
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                toast = AuthToast(message: String(localized: "Account created!"), isError: false)
            }
        }
    }

    private func showError(_ message: String) {
        UINotificationFeedbackGenerator().notificationOccurred(.error)
        toast = AuthToast(message: message, isError: true)
    }
}
