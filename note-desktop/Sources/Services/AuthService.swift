import Foundation

public struct AuthResponse: Decodable, Sendable {
    public let token: String
    public let user: AuthUser
}

public struct AuthUser: Decodable, Sendable {
    public let id: String
    public let email: String
    public let username: String?
    public let name: String?
}

public final class AuthService: @unchecked Sendable {
    private let storage: StorageService
    private let api: ApiService
    private let sessionKey = "user_session_token"
    
    public init(storage: StorageService, api: ApiService) {
        self.storage = storage
        self.api = api
    }
    
    /// Registers a new user via the backend server.
    public func registerUser(username: String, email: String, password: [Character], completion: @escaping @Sendable (Result<AuthResponse, Error>) -> Void) {
        let body: [String: Any] = [
            "username": username,
            "email": email,
            "password": String(password)
        ]
        
        api.post(path: "auth/signup", body: body) { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success(let (statusCode, data)):
                guard statusCode == 200 || statusCode == 201 else {
                    let errorMessage = self.extractError(from: data, fallback: "Registration failed with status code: \(statusCode)")
                    completion(.failure(NSError(domain: "AuthService", code: statusCode, userInfo: [NSLocalizedDescriptionKey: errorMessage])))
                    return
                }
                
                do {
                    let response = try JSONDecoder().decode(AuthResponse.self, from: data)
                    self.saveSession(token: response.token)
                    
                    let dbUser = DBUser(
                        id: response.user.id,
                        username: response.user.username ?? response.user.name ?? username,
                        email: response.user.email
                    )
                    _ = self.storage.insertUser(dbUser)
                    
                    completion(.success(response))
                } catch {
                    completion(.failure(error))
                }
            }
        }
    }
    
    /// Performs user authentication via the backend server.
    public func login(email: String, password: [Character], completion: @escaping @Sendable (Result<AuthResponse, Error>) -> Void) {
        let body: [String: Any] = [
            "email": email,
            "password": String(password)
        ]
        
        api.post(path: "auth/login", body: body) { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success(let (statusCode, data)):
                guard statusCode == 200 else {
                    let errorMessage = self.extractError(from: data, fallback: "Login failed with status code: \(statusCode)")
                    completion(.failure(NSError(domain: "AuthService", code: statusCode, userInfo: [NSLocalizedDescriptionKey: errorMessage])))
                    return
                }
                
                do {
                    let response = try JSONDecoder().decode(AuthResponse.self, from: data)
                    self.saveSession(token: response.token)
                    
                    let dbUser = DBUser(
                        id: response.user.id,
                        username: response.user.username ?? response.user.name ?? "",
                        email: response.user.email
                    )
                    _ = self.storage.insertUser(dbUser)
                    
                    completion(.success(response))
                } catch {
                    completion(.failure(error))
                }
            }
        }
    }
    
    /// Returns the active session authentication token if logged in.
    public func getSessionToken() -> String? {
        return UserDefaults.standard.string(forKey: sessionKey)
    }
    
    /// Clears the authentication token and resets session settings.
    public func logout() {
        api.clearToken()
        UserDefaults.standard.removeObject(forKey: sessionKey)
    }
    
    private func saveSession(token: String) {
        api.saveToken(token)
        UserDefaults.standard.set(token, forKey: sessionKey)
    }
    
    private func extractError(from data: Data, fallback: String) -> String {
        guard let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
              let errorMsg = json["error"] as? String else {
            return fallback
        }
        return errorMsg
    }
}
