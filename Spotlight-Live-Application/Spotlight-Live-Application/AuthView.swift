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

        print("[AuthViewModel] submit started. isRegister=\(isRegister)")
        print("[AuthViewModel] email=\(email), displayName=\(displayName), city=\(city)")
        print("[AuthViewModel] password length=\(password.count)")

        do {
            let response: AuthResponse
            if isRegister {
                print("[AuthViewModel] -> ApiClient.register")
                response = try await appState.api.register(email: email, password: password, displayName: displayName, city: city)
                print("[AuthViewModel] <- ApiClient.register OK. user.id=\(response.user.id) token.len=\(response.token.count)")
            } else {
                print("[AuthViewModel] -> ApiClient.login")
                response = try await appState.api.login(email: email, password: password)
                print("[AuthViewModel] <- ApiClient.login OK. user.id=\(response.user.id) token.len=\(response.token.count)")
            }

            print("[AuthViewModel] -> AppState.updateAuth")
            await appState.updateAuth(with: response)
            print("[AuthViewModel] <- AppState.updateAuth OK. appState.user.id=\(appState.currentUser?.id ?? "nil") token.set=\(appState.token != nil)")
        } catch {
            let nsError = error as NSError
            print("[AuthViewModel] submit failed.")
            print("[AuthViewModel] error.localizedDescription = \(error.localizedDescription)")
            print("[AuthViewModel] NSError.domain = \(nsError.domain)")
            print("[AuthViewModel] NSError.code = \(nsError.code)")
            print("[AuthViewModel] NSError.userInfo = \(nsError.userInfo)")
            errorMessage = "İşlem başarısız: \(error.localizedDescription) [\(nsError.domain):\(nsError.code)]"
        }

        isLoading = false
        print("[AuthViewModel] submit finished.")
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
