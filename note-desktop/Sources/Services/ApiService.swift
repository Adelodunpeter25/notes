import Foundation

public enum ApiError: Error, Sendable {
    case httpError(status: Int, body: String)
    case invalidResponse
    case network(Error)
}

public final class ApiService: @unchecked Sendable {
    public let baseUrl: URL
    private let lock = NSLock()
    private var _token: String?
    private let tokenKey = "auth_token"
    
    public init(baseUrlString: String = "https://notes-api.scaleitpro.com/api") {
        guard let url = URL(string: baseUrlString) else { fatalError("Invalid API base URL") }
        self.baseUrl = url
        self._token = UserDefaults.standard.string(forKey: tokenKey)
    }
    
    public func saveToken(_ token: String) {
        lock.lock(); defer { lock.unlock() }; _token = token
        UserDefaults.standard.set(token, forKey: tokenKey)
    }
    public func clearToken() {
        lock.lock(); defer { lock.unlock() }; _token = nil
        UserDefaults.standard.removeObject(forKey: tokenKey)
    }
    public func getToken() -> String? { lock.lock(); defer { lock.unlock() }; return _token }
    
    // Swift 6 typed throws + async (concurrent)
    public func post(path: String, body: [String: Any]) async throws(ApiError) -> (Int, Data) {
        try await sendRequest(path: path, method: "POST", body: body)
    }
    public func get(path: String) async throws(ApiError) -> (Int, Data) {
        try await sendRequest(path: path, method: "GET", body: nil)
    }
    // Compat wrappers (non-async, no Task capture issue)
    public func post(path: String, body: [String: Any], completion: @escaping (Result<(Int, Data), Error>) -> Void) {
        sendRequestLegacy(path: path, method: "POST", body: body, completion: completion)
    }
    public func get(path: String, completion: @escaping (Result<(Int, Data), Error>) -> Void) {
        sendRequestLegacy(path: path, method: "GET", body: nil, completion: completion)
    }
    private func sendRequestLegacy(path: String, method: String, body: [String: Any]?, completion: @escaping (Result<(Int, Data), Error>) -> Void) {
        let requestURL = baseUrl.appendingPathComponent(path.trimmingCharacters(in: CharacterSet(charactersIn: "/")))
        var request = URLRequest(url: requestURL)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        lock.lock(); let token = _token; lock.unlock()
        if let token { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        if let body { request.httpBody = try? JSONSerialization.data(withJSONObject: body, options: []) }
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error { completion(.failure(error)); return }
            completion(.success(((response as? HTTPURLResponse)?.statusCode ?? -1, data ?? Data())))
        }.resume()
    }
    private func sendRequest(path: String, method: String, body: [String: Any]?) async throws(ApiError) -> (Int, Data) {
        let requestURL = baseUrl.appendingPathComponent(path.trimmingCharacters(in: CharacterSet(charactersIn: "/")))
        var request = URLRequest(url: requestURL)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let token: String? = { lock.lock(); defer { lock.unlock() }; return _token }()
        if let token { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        if let body { request.httpBody = try? JSONSerialization.data(withJSONObject: body, options: []) }
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            return ((response as? HTTPURLResponse)?.statusCode ?? -1, data)
        } catch {
            throw .network(error)
        }
    }
}
