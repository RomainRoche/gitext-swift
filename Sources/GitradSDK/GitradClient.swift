import Foundation

final class GitradClient {
    private let config: GitradConfig

    init(config: GitradConfig) {
        self.config = config
    }

    // Step 1 – exchange the API key for a signed Storage URL (returns the Location from 302).
    func downloadUrl() async throws -> URL {
        let base = config.baseUrl.trimmingCharacters(in: .init(charactersIn: "/"))
        guard let url = URL(string: base + "/api/ota/download") else {
            throw GitradError.networkError(URLError(.badURL))
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(config.apiKey, forHTTPHeaderField: "x-api-key")

        let (_, response) = try await Self.noRedirectSession.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw GitradError.networkError(URLError(.badServerResponse))
        }

        switch http.statusCode {
        case 301, 302, 303, 307, 308:
            guard
                let location = http.value(forHTTPHeaderField: "Location"),
                let signedUrl = URL(string: location)
            else {
                throw GitradError.networkError(URLError(.redirectToNonExistentLocation))
            }
            return signedUrl
        case 401:
            throw GitradError.unauthorized
        case 403:
            throw GitradError.subscriptionInactive
        default:
            throw GitradError.networkError(URLError(.badServerResponse))
        }
    }

    // Step 2 – download the OTA payload from a signed URL.
    // If the signed URL has expired (403 from Storage), requests a fresh URL and retries once.
    func download(from signedUrl: URL, retrying: Bool = true) async throws -> OTAPayload {
        let (data, response) = try await URLSession.shared.data(from: signedUrl)

        guard let http = response as? HTTPURLResponse else {
            throw GitradError.networkError(URLError(.badServerResponse))
        }

        if http.statusCode == 403 && retrying {
            let freshUrl = try await downloadUrl()
            return try await download(from: freshUrl, retrying: false)
        }

        guard (200..<300).contains(http.statusCode) else {
            throw GitradError.networkError(URLError(.badServerResponse))
        }

        do {
            return try JSONDecoder().decode(OTAPayload.self, from: data)
        } catch {
            throw GitradError.parseError(error)
        }
    }

    // URLSession configured to stop at the first redirect so we can inspect the Location header.
    private static let noRedirectSession: URLSession = {
        let delegate = NoRedirectDelegate()
        return URLSession(configuration: .ephemeral, delegate: delegate, delegateQueue: nil)
    }()
}

private final class NoRedirectDelegate: NSObject, URLSessionTaskDelegate {
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        completionHandler(nil)
    }
}
