import Foundation

public final class ApiService {
    public let baseUrl: URL
    private var token: String?
    private let tokenKey = "auth_token"
    
    public init(baseUrlString: String = "https://notes-api.scaleitpro.com/api") {
        guard let url = URL(string: baseUrlString) else {
            fatalError("Invalid API base URL")
        }
        self.baseUrl = url
        
        // Load persisted token on startup
        self.token = UserDefaults.standard.string(forKey: tokenKey)
    }
    
    public func saveToken(_ token: String) {
        self.token = token
        UserDefaults.standard.set(token, forKey: tokenKey)
    }
    
    public func clearToken() {
        self.token = nil
        UserDefaults.standard.removeObject(forKey: tokenKey)
    }
    
    public func getToken() -> String? {
        return token
    }
    
    public func post(path: String, body: [String: Any], completion: @escaping (Result<(Int, Data), Error>) -> Void) {
        sendRequest(path: path, method: "POST", body: body, completion: completion)
    }
    
    public func get(path: String, completion: @escaping (Result<(Int, Data), Error>) -> Void) {
        sendRequest(path: path, method: "GET", body: nil, completion: completion)
    }
    
    private func sendRequest(path: String, method: String, body: [String: Any]?, completion: @escaping (Result<(Int, Data), Error>) -> Void) {
        let requestURL = baseUrl.appendingPathComponent(path.trimmingCharacters(in: CharacterSet(charactersIn: "/")))
        var request = URLRequest(url: requestURL)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let token = token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        if let body = body {
            request.httpBody = try? JSONSerialization.data(withJSONObject: body, options: [])
        }
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            let responseData = data ?? Data()
            completion(.success((statusCode, responseData)))
        }
        task.resume()
    }
}
