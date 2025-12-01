import SwiftUI
import Observation

@Observable
@MainActor
final class AuthViewModel {
    var email: String = ""
    var password: String = ""
    var displayName: String = ""
    var city: String = ""
    var isRegister = false
    var isLoading = false
    var errorMessage: String?

    func submit(appState: AppState) async {
        isLoading = true
        errorMessage = nil
        do {
            let response: AuthResponse
            if isRegister {
                response = try await appState.api.register(email: email, password: password, displayName: displayName, city: city)
            } else {
                response = try await appState.api.login(email: email, password: password)
            }
            await appState.updateAuth(with: response)
        } catch {
            errorMessage = "İşlem başarısız: \(error.localizedDescription)"
        }
        isLoading = false
    }
}

struct AuthView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel = AuthViewModel()

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text(viewModel.isRegister ? "Kayıt ol" : "Giriş yap")) {
                    TextField("Email", text: $viewModel.email)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                    SecureField("Şifre", text: $viewModel.password)
                    if viewModel.isRegister {
                        TextField("Ad Soyad", text: $viewModel.displayName)
                        TextField("Şehir", text: $viewModel.city)
                    }
                }

                if let error = viewModel.errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                }

                Button(action: {
                    Task { await viewModel.submit(appState: appState) }
                }) {
                    if viewModel.isLoading {
                        ProgressView()
                    } else {
                        Text(viewModel.isRegister ? "Kayıt ol" : "Giriş yap")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
            }
            .navigationTitle("SpotlightLive")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(viewModel.isRegister ? "Giriş" : "Kaydol") {
                        viewModel.isRegister.toggle()
                    }
                }
            }
        }
    }
}
