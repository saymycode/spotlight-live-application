import Foundation
import Observation

@Observable
@MainActor
final class AppState {
    var token: String? {
        didSet { TokenStore.shared.save(token: token) }
    }
    var currentUser: User?
    var categories: [EventCategory] = []

    let api = ApiClient.shared
    let locationManager = LocationManager()

    init() {
        self.token = TokenStore.shared.load()
        Task { await api.setToken(token) }
        Task {
            if let token, let user = await api.restoreUserFromToken(token) {
                currentUser = user
            }
        }
        Task { await refreshCategoriesIfNeeded() }
    }

    func refreshCategoriesIfNeeded() async {
        guard categories.isEmpty else { return }
        do {
            categories = try await api.fetchCategories()
        } catch {
            print("Kategori yüklenemedi: \(error)")
        }
    }

    func updateAuth(with response: AuthResponse) async {
        token = response.token
        currentUser = response.user
        await api.setToken(token)
    }

    func logout() async {
        token = nil
        currentUser = nil
        await api.setToken(nil)
    }
}
