@testable import EOSIO
import Foundation

#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif

struct MockSession: SessionAdapter {
    fileprivate let queue = DispatchQueue(label: "MockSession")

    enum Mode {
        case replay
        case record
    }

    let storageDir: URL
    let mode: Mode

    init(_ storageDir: URL, mode: Mode = .replay) {
        precondition(storageDir.isFileURL, "invalid url")
        if #available(OSX 10.11, iOS 9, *) {
            precondition(storageDir.hasDirectoryPath, "invalid url")
        }
        if mode == .record {
            print("MockSession: Recording responses to \(storageDir)")
        }
        self.storageDir = storageDir
        self.mode = mode
    }

    func fileUrl(for request: URLRequest) -> URL {
        guard let url = request.url else {
            preconditionFailure("invalid http request")
        }
        let body: Data
        if request.httpMethod == "GET" {
            let query = URLComponents(url: url, resolvingAgainstBaseURL: true)?.query ?? ""
            body = query.utf8Data
        } else {
            body = request.httpBody ?? Data()
        }
        let name = url.relativePath.dropFirst().replacingOccurrences(of: "/", with: "_")
        let digest = body.sha256Digest.hexEncodedString()
        return self.storageDir
            .appendingPathComponent("\(name)-\(digest)")
            .appendingPathExtension("json")
    }

    func dataTask(
        with request: URLRequest,
        completionHandler: @escaping (Data?, URLResponse?, Error?) -> Void
    ) -> SessionDataTask {
        switch self.mode {
        case .replay:
            return MockDataTask(session: self, request: request, completionHandler: completionHandler)
        case .record:
            let fileUrl = self.fileUrl(for: request)
            if FileManager.default.fileExists(atPath: fileUrl.path) {
                print("MockSession: Using existing response for \(request.url!): \(fileUrl.lastPathComponent)")
                return MockDataTask(session: self, request: request, completionHandler: completionHandler)
            }
            let session = URLSession.shared
            let task: URLSessionDataTask = session.dataTask(with: request) { data, response, error in
                if let data = data, let response = response as? HTTPURLResponse {
                    let res = FileResponse(response, data)
                    do {
                        print("MockSession: Saving response from \(request.url!) to \(fileUrl.lastPathComponent)")
                        try res.write(to: fileUrl)
                    } catch {
                        print("MockSession: WARNING - Unable to record response data: \(error)")
                    }
                }
                completionHandler(data, response, error)
            }
            return task
        }
    }
}

struct MockDataTask: SessionDataTask {
    let session: MockSession
    let request: URLRequest
    let completionHandler: (Data?, URLResponse?, Error?) -> Void
    func resume() {
        self.session.queue.async {
            do {
                let res = try FileResponse(self.session.fileUrl(for: self.request))
                self.completionHandler(res.data, res.urlResponse, nil)
            } catch {
                self.completionHandler(nil, nil, error)
            }
        }
    }
}

/// Wrapper so that `HTTPURLResponse` can be serialized.
struct ResponseWrapper: Codable {
    let value: HTTPURLResponse

    enum Keys: CodingKey {
        case url
        case status
        case headers
    }

    init(_ response: HTTPURLResponse) {
        self.value = response
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: Keys.self)
        guard let response = HTTPURLResponse(
            url: try container.decode(URL.self, forKey: .url),
            statusCode: try container.decode(Int.self, forKey: .status),
            httpVersion: nil,
            headerFields: try container.decodeIfPresent([String: String].self, forKey: .headers)
        ) else {
            throw DecodingError.valueNotFound(HTTPURLResponse.self, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Unable to decode response"))
        }
        self.value = response
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: Keys.self)
        guard let url = self.value.url else {
            throw EncodingError.invalidValue(self.value, EncodingError.Context(
                codingPath: container.codingPath,
                debugDescription: "Missing request URL"
            ))
        }
        try container.encode(url, forKey: .url)
        try container.encode(self.value.statusCode, forKey: .status)
        let headers = self.value.allHeaderFields as? [String: String]
        try container.encodeIfPresent(headers, forKey: .headers)
    }
}

struct FileResponse: Codable {
    let data: Data
    let response: ResponseWrapper

    var urlResponse: HTTPURLResponse { self.response.value }

    init(_ response: HTTPURLResponse, _ data: Data) {
        self.response = ResponseWrapper(response)
        self.data = data
    }

    init(_ fileUrl: URL) throws {
        let data = try Data(contentsOf: fileUrl)
        self = try JSONDecoder().decode(Self.self, from: data)
    }

    func write(to fileUrl: URL) throws {
        let encoder = JSONEncoder()
        let data = try encoder.encode(self)
        try data.write(to: fileUrl)
    }
}
