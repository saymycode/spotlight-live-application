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
        Task { await restoreFirebaseSession() }
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
        TokenStore.shared.save(token: token)
    }

    func logout() async {
        token = nil
        currentUser = nil
        await api.logout()
        await api.setToken(nil)
        TokenStore.shared.save(token: nil)
    }

    private func restoreFirebaseSession() async {
        if let session = await api.restoreSession() {
            await updateAuth(with: session)
        }
    }
}
