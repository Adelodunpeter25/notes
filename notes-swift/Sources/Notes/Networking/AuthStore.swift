import Foundation

@MainActor
final class AuthStore: ObservableObject {
    @Published private(set) var user: AuthUser?
    @Published private(set) var isAuthenticated = false

    private let tokenKey = "auth_token"
    private let api = APIClient.shared

    init() {
        if let token = UserDefaults.standard.string(forKey: tokenKey) {
            api.token = token
            isAuthenticated = true
        }
    }

    func login(email: String, password: String) async throws {
        let response: AuthResponse = try await api.post("/auth/login", body: LoginPayload(email: email, password: password))
        api.token = response.token
        UserDefaults.standard.set(response.token, forKey: tokenKey)
        user = response.user
        isAuthenticated = true
    }

    func logout() {
        api.token = nil
        user = nil
        isAuthenticated = false
        UserDefaults.standard.removeObject(forKey: tokenKey)
    }
}
