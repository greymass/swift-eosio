
import Foundation

/// A EOSIO (nodeos) API request, encoded and sent as the request JSON body.
public protocol Request: Encodable {
    /// The response type, must be decodable.
    associatedtype Response: Decodable
    /// The request path, e.g. `/v1/chain/get_info`
    static var path: String { get }
}

/// Type representing a nodeos response error.
public struct ResponseError: Codable {
    public struct Detail: Codable {
        public let message: String
        public let file: String
        public let lineNumber: UInt64
        public let method: String
    }

    public struct Info: Codable {
        public let code: Int64
        public let name: String
        public let what: String
        public let details: [Detail]
    }

    /// The HTTP status code.
    public let code: UInt16
    /// The HTTP status message.
    public let message: String
    /// The underlying EOSIO error.
    public let error: Info
}

let SWIFT_EOSIO_VERSION = "1.0.0"

/// EOSIO API Client.
public class Client {
    /// The clients user-agent string.
    static let userAgent = "swift-eosio/\(SWIFT_EOSIO_VERSION) (+https://github.com/greymass/swift-eosio)"

    /// All errors `Client` can throw.
    public enum Error: LocalizedError {
        /// Unable to send request or invalid response from server.
        case networkError(message: String, error: Swift.Error?)
        /// Server responded with an error.
        case responseError(error: ResponseError)
        /// Unable to decode the result or encode the request params.
        case codingError(message: String, error: Swift.Error)

        public var errorDescription: String? {
            switch self {
            case let .networkError(message, error):
                var rv = "Unable to send request: \(message)"
                if let error = error {
                    rv += " (caused by \(String(describing: error))"
                }
                return rv
            case let .codingError(message, error):
                return "Unable to serialize data: \(message) (caused by \(String(describing: error))"
            case let .responseError(error):
                return "Error: \(error.error.what) (code=\(error.error.code))"
            }
        }
    }

    /// The RPC Server address.
    public let address: URL

    /// The URLSession.
    internal var session: SessionAdapter

    /// Create a new client instance.
    /// - Parameter address: The rpc server to connect to.
    /// - Parameter session: The session to use when sending requests to the server.
    public init(address: URL, session: URLSession = URLSession.shared) {
        self.address = address
        self.session = session as SessionAdapter
    }

    /// Internal initializer for testing with a `SessionAdapter`
    internal init(address: URL, session: SessionAdapter) {
        self.address = address
        self.session = session
    }

    /// Return a URLRequest with a JSON request payload for given Request.
    internal func urlRequest<T: Request>(for request: T) throws -> URLRequest {
        let encoder = Client.JSONEncoder()
        let url = self.address.appendingPathComponent(T.path)
        var urlRequest = URLRequest(url: url)
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue(Self.userAgent, forHTTPHeaderField: "User-Agent")
        urlRequest.httpMethod = "POST"
        urlRequest.httpBody = try encoder.encode(request)
        return urlRequest
    }

    /// Resolve a URLSession dataTask to a `Response`.
    internal func resolveResponse<T: Request>(for _: T, data: Data?, response: URLResponse?) -> Result<T.Response, Error> {
        guard let response = response else {
            return Result.failure(Error.networkError(message: "No response from server", error: nil))
        }
        guard let httpResponse = response as? HTTPURLResponse else {
            return Result.failure(Error.networkError(message: "Not a HTTP response", error: nil))
        }
        guard let data = data else {
            return Result.failure(Error.networkError(message: "Response body empty", error: nil))
        }
        let decoder = Client.JSONDecoder()
        if httpResponse.statusCode > 299 {
            do {
                let error = try decoder.decode(ResponseError.self, from: data)
                return Result.failure(Error.responseError(error: error))
            } catch {
                return Result.failure(Error.networkError(message: "Server responded with HTTP \(httpResponse.statusCode)", error: error))
            }
        }
        let rv: T.Response
        do {
            rv = try decoder.decode(T.Response.self, from: data)
        } catch {
            return Result.failure(Error.codingError(message: "Unable to decode response", error: error))
        }
        return Result.success(rv)
    }

    /// Send a request.
    /// - Parameter request: The request to be sent.
    /// - Parameter completionHandler: Callback function, called with either a response or an error.
    public func send<T: Request>(_ request: T, completionHandler: @escaping (Result<T.Response, Error>) -> Void) -> Void {
        let urlRequest: URLRequest
        do {
            urlRequest = try self.urlRequest(for: request)
        } catch {
            return completionHandler(Result.failure(Error.codingError(message: "Unable to encode payload", error: error)))
        }
        self.session.dataTask(with: urlRequest) { data, response, error in
            if let error = error {
                return completionHandler(Result.failure(Error.networkError(message: "Unable to send request", error: error)))
            }
            let result = self.resolveResponse(for: request, data: data, response: response)
            completionHandler(result)
        }.resume()
    }

    /// Blocking send.
    /// - Parameter request: The request to be sent.
    /// - Attention: This should never be called from the main thread.
    public func sendSync<T: Request>(_ request: T) -> Result<T.Response, Error> {
        let semaphore = DispatchSemaphore(value: 0)
        var result: Result<T.Response, Error>?
        self.send(request) {
            result = $0
            semaphore.signal()
        }
        semaphore.wait()
        return result!
    }
}

// MARK: JSON Coding helpers

extension Client {
    static let dateEncoder = Foundation.JSONEncoder.DateEncodingStrategy.custom { (date, encoder) throws in
        var container = encoder.singleValueContainer()
        try container.encode(TimePoint(date).stringValue)
    }

    static let dataEncoder = Foundation.JSONEncoder.DataEncodingStrategy.custom { (data, encoder) throws in
        var container = encoder.singleValueContainer()
        try container.encode(data.hexEncodedString())
    }

    static let dateDecoder = Foundation.JSONDecoder.DateDecodingStrategy.custom { (decoder) -> Date in
        let container = try decoder.singleValueContainer()
        guard let date = TimePoint(try container.decode(String.self))?.date else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid date")
        }
        return date
    }

    static let dataDecoder = Foundation.JSONDecoder.DataDecodingStrategy.custom { (decoder) -> Data in
        let container = try decoder.singleValueContainer()
        return Data(hexEncoded: try container.decode(String.self))
    }

    /// Returns a JSONDecoder instance configured for the EOSIO JSON format.
    public static func JSONDecoder() -> Foundation.JSONDecoder {
        let decoder = Foundation.JSONDecoder()
        decoder.dataDecodingStrategy = self.dataDecoder
        decoder.dateDecodingStrategy = self.dateDecoder
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }

    /// Returns a JSONEncoder instance configured for the EOSIO JSON format.
    public static func JSONEncoder() -> Foundation.JSONEncoder {
        let encoder = Foundation.JSONEncoder()
        encoder.dataEncodingStrategy = self.dataEncoder
        encoder.dateEncodingStrategy = self.dateEncoder
        encoder.keyEncodingStrategy = .convertToSnakeCase
        return encoder
    }
}

// MARK: URLSession adapter

internal protocol SessionAdapter {
    func dataTask(with request: URLRequest, completionHandler: @escaping (Data?, URLResponse?, Error?) -> Void) -> SessionDataTask
}

internal protocol SessionDataTask {
    func resume()
}

extension URLSessionDataTask: SessionDataTask {}
extension URLSession: SessionAdapter {
    internal func dataTask(with request: URLRequest, completionHandler: @escaping (Data?, URLResponse?, Error?) -> Void) -> SessionDataTask {
        let task: URLSessionDataTask = self.dataTask(with: request, completionHandler: completionHandler)
        return task as SessionDataTask
    }
}
