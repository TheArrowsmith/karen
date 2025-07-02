import Foundation
import Darwin

enum APIError: Error, LocalizedError {
    case invalidURL
    case requestFailed(Error)
    case decodingFailed(Error)
    case serverError(statusCode: Int)
    case socketError(String)

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
        case .socketError(let message):
            return "Socket error: \(message)"
        }
    }
}

@MainActor
class APIService {
    private var socketPath: String {
        // Use the app's cache directory which is within the sandbox
        let cachesDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let socketURL = cachesDir.appendingPathComponent("karen_dev.sock")
        print("Using socket path: \(socketURL.path)")
        return socketURL.path
    }
    
    func send(requestBody: ChatRequest) async -> Result<ChatResponse, APIError> {
        return await withCheckedContinuation { continuation in
            do {
                    // Encode the request body to JSON
                    let encoder = JSONEncoder()
                    encoder.outputFormatting = .prettyPrinted
                    encoder.dateEncodingStrategy = .iso8601
                    
                    let jsonData = try encoder.encode(requestBody)
                    if let jsonString = String(data: jsonData, encoding: .utf8) {
                        print("API Request Body: \(jsonString)")
                    }
                    
                    // Create HTTP request
                    let httpRequest = """
                    POST /api/chat HTTP/1.1\r
                    Host: localhost\r
                    Content-Type: application/json\r
                    Content-Length: \(jsonData.count)\r
                    Connection: close\r
                    \r
                    
                    """
                    
                    var requestData = Data(httpRequest.utf8)
                    requestData.append(jsonData)
                    
                    // Connect to the UNIX socket
                    let socketFD = socket(AF_UNIX, SOCK_STREAM, 0)
                    if socketFD == -1 {
                        continuation.resume(returning: .failure(.socketError("Failed to create socket")))
                        return
                    }
                    
                    defer {
                        close(socketFD)
                    }
                    
                    var addr = sockaddr_un()
                    addr.sun_family = sa_family_t(AF_UNIX)
                    
                    socketPath.withCString { pathPtr in
                        withUnsafeMutablePointer(to: &addr.sun_path.0) { sunPathPtr in
                            _ = strcpy(sunPathPtr, pathPtr)
                        }
                    }
                    
                    let connectResult = withUnsafePointer(to: &addr) { ptr in
                        ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPtr in
                            connect(socketFD, sockaddrPtr, socklen_t(MemoryLayout<sockaddr_un>.size))
                        }
                    }
                    
                    if connectResult == -1 {
                        let errorCode = errno
                        let errorMessage = String(cString: strerror(errorCode))
                        print("Socket connection failed with errno \(errorCode): \(errorMessage)")
                        continuation.resume(returning: .failure(.socketError("Failed to connect to socket at \(socketPath): \(errorMessage)")))
                        return
                    }
                    
                    // Send the request
                    requestData.withUnsafeBytes { bytes in
                        _ = Darwin.send(socketFD, bytes.baseAddress, requestData.count, 0)
                    }
                    
                    // Read the response
                    var responseData = Data()
                    let bufferSize = 4096
                    let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
                    defer {
                        buffer.deallocate()
                    }
                    
                    var httpHeadersComplete = false
                    var contentLength: Int?
                    var statusCode: Int = 0
                    
                    while true {
                        let bytesRead = recv(socketFD, buffer, bufferSize, 0)
                        if bytesRead <= 0 {
                            break
                        }
                        
                        let chunk = Data(bytes: buffer, count: bytesRead)
                        responseData.append(chunk)
                        
                        // Parse HTTP headers if not done yet
                        if !httpHeadersComplete {
                            if let responseString = String(data: responseData, encoding: .utf8),
                               let headerEndRange = responseString.range(of: "\r\n\r\n") {
                                httpHeadersComplete = true
                                
                                // Extract status code
                                if let statusLine = responseString.split(separator: "\r\n").first {
                                    let parts = statusLine.split(separator: " ")
                                    if parts.count >= 2, let code = Int(parts[1]) {
                                        statusCode = code
                                    }
                                }
                                
                                // Extract content length
                                let headers = String(responseString[..<headerEndRange.lowerBound])
                                if let contentLengthRange = headers.range(of: "Content-Length: ", options: .caseInsensitive) {
                                    let start = headers.index(contentLengthRange.upperBound, offsetBy: 0)
                                    if let end = headers[start...].firstIndex(of: "\r") {
                                        if let length = Int(headers[start..<end]) {
                                            contentLength = length
                                        }
                                    }
                                }
                                
                                // Check if we have all the body data
                                let headerEndIndex = responseString.distance(from: responseString.startIndex, to: headerEndRange.upperBound)
                                let bodyLength = responseData.count - headerEndIndex
                                if let expectedLength = contentLength, bodyLength >= expectedLength {
                                    break
                                }
                            }
                        }
                    }
                    
                    // Parse the response
                    guard let responseString = String(data: responseData, encoding: .utf8),
                          let headerBodySeparator = responseString.range(of: "\r\n\r\n") else {
                        continuation.resume(returning: .failure(.socketError("Invalid HTTP response")))
                        return
                    }
                    
                    // Check status code
                    if !(200...299).contains(statusCode) {
                        print("Server error response (\(statusCode)): \(responseString)")
                        continuation.resume(returning: .failure(.serverError(statusCode: statusCode)))
                        return
                    }
                    
                    // Extract JSON body
                    let bodyStartIndex = headerBodySeparator.upperBound
                    let jsonString = String(responseString[bodyStartIndex...])
                    print("API Response Body: \(jsonString)")
                    
                    guard let jsonData = jsonString.data(using: .utf8) else {
                        continuation.resume(returning: .failure(.decodingFailed(NSError(domain: "APIService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to convert response to data"]))))
                        return
                    }
                    
                    // Decode the response
                    let decoder = JSONDecoder()
                    decoder.dateDecodingStrategy = .iso8601
                    
                    let decodedResponse = try decoder.decode(ChatResponse.self, from: jsonData)
                    continuation.resume(returning: .success(decodedResponse))
                    
                } catch let error as DecodingError {
                    print("Decoding error: \(error)")
                    if let debugDescription = (error as NSError).userInfo[NSDebugDescriptionErrorKey] {
                        print("Debug description: \(debugDescription)")
                    }
                    continuation.resume(returning: .failure(.decodingFailed(error)))
                } catch {
                    continuation.resume(returning: .failure(.requestFailed(error)))
                }
        }
    }
} 