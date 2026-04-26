import Foundation

struct AuthUser: Codable {
    let id: String
    let email: String
}

struct AuthResponse: Codable {
    let token: String
    let user: AuthUser
}

struct LoginPayload: Encodable {
    let email: String
    let password: String
}
