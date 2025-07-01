import Foundation

enum APIError: Error, LocalizedError {
    case invalidURL
    case requestFailed(Error)
    case decodingFailed(Error)
    case serverError(statusCode: Int)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "The server URL is invalid."
        case .requestFailed:
            return "The network request failed. Please check your connection."
        case .decodingFailed:
            return "Failed to process the server's response."
        case .serverError(let statusCode):
            return "The server returned an error (Code: \(statusCode))."
        }
    }
}

@MainActor
class APIService {
    private let urlString = "http://127.0.0.1:8000/api/chat"

    func send(requestBody: ChatRequest) async -> Result<ChatResponse, APIError> {
        guard let url = URL(string: urlString) else {
            return .failure(.invalidURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            // Configure date encoding to match Python's datetime format
            encoder.dateEncodingStrategy = .iso8601
            
            request.httpBody = try encoder.encode(requestBody)
            if let jsonString = String(data: request.httpBody!, encoding: .utf8) {
                print("API Request Body: \(jsonString)")
            }
        } catch {
            return .failure(.decodingFailed(error)) // Technically encoding, but same category
        }

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                return .failure(.serverError(statusCode: 500))
            }
            
            // Log the response body for non-200 status codes
            if !(200...299).contains(httpResponse.statusCode) {
                if let errorString = String(data: data, encoding: .utf8) {
                    print("Server error response (\(httpResponse.statusCode)): \(errorString)")
                }
                return .failure(.serverError(statusCode: httpResponse.statusCode))
            }
            
            if let jsonString = String(data: data, encoding: .utf8) {
                print("API Response Body: \(jsonString)")
            }
            
            let decoder = JSONDecoder()
            // Configure date decoding strategy to handle ISO8601 dates from the API
            decoder.dateDecodingStrategy = .iso8601
            
            let decodedResponse = try decoder.decode(ChatResponse.self, from: data)
            return .success(decodedResponse)
        } catch let error as DecodingError {
            print("Decoding error: \(error)")
            if let debugDescription = (error as NSError).userInfo[NSDebugDescriptionErrorKey] {
                print("Debug description: \(debugDescription)")
            }
            return .failure(.decodingFailed(error))
        } catch {
            return .failure(.requestFailed(error))
        }
    }
} 