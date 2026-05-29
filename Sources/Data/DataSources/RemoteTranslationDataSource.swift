import Foundation
import Domain

final class RemoteTranslationDataSource {
    private let apiKey: String
    private let baseUrl: String

    init(apiKey: String, baseUrl: String) {
        self.apiKey = apiKey
        self.baseUrl = baseUrl
    }

    func fetch() async throws -> TranslationPayloadDTO {
        let delays: [UInt64] = [2, 4, 8, 16].map { $0 * 1_000_000_000 }
        var lastError: Error = TranslationFetchError.network(URLError(.unknown))

        for attempt in 0..<5 {
            do {
                return try await performFetch()
            } catch TranslationFetchError.unauthorized {
                throw TranslationFetchError.unauthorized
            } catch TranslationFetchError.subscriptionInactive {
                throw TranslationFetchError.subscriptionInactive
            } catch TranslationFetchError.parse(let e) {
                throw TranslationFetchError.parse(e)
            } catch {
                lastError = error
            }
            if attempt < 4 {
                try await Task.sleep(nanoseconds: delays[attempt])
            }
        }
        throw lastError
    }

    private func performFetch() async throws -> TranslationPayloadDTO {
        let signedUrl = try await downloadUrl()
        return try await download(from: signedUrl)
    }

    // Step 1 — exchange the API key for a signed Storage URL (captured from the Location header).
    private func downloadUrl() async throws -> URL {
        let base = baseUrl.trimmingCharacters(in: .init(charactersIn: "/"))
        guard let url = URL(string: base + "/api/ota/download") else {
            throw TranslationFetchError.network(URLError(.badURL))
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")

        let (_, response) = try await Self.noRedirectSession.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw TranslationFetchError.network(URLError(.badServerResponse))
        }

        switch http.statusCode {
        case 301, 302, 303, 307, 308:
            guard
                let location = http.value(forHTTPHeaderField: "Location"),
                let signedUrl = URL(string: location)
            else {
                throw TranslationFetchError.network(URLError(.redirectToNonExistentLocation))
            }
            return signedUrl
        case 401:
            throw TranslationFetchError.unauthorized
        case 403:
            throw TranslationFetchError.subscriptionInactive
        default:
            throw TranslationFetchError.network(URLError(.badServerResponse))
        }
    }

    // Step 2 — download the payload from a signed URL.
    // If the signed URL has expired (403 from Storage), requests a fresh URL and retries once.
    private func download(from signedUrl: URL, retrying: Bool = true) async throws -> TranslationPayloadDTO {
        let (data, response) = try await URLSession.shared.data(from: signedUrl)

        guard let http = response as? HTTPURLResponse else {
            throw TranslationFetchError.network(URLError(.badServerResponse))
        }

        if http.statusCode == 403 && retrying {
            let freshUrl = try await downloadUrl()
            return try await download(from: freshUrl, retrying: false)
        }

        guard (200..<300).contains(http.statusCode) else {
            throw TranslationFetchError.network(URLError(.badServerResponse))
        }

        do {
            return try JSONDecoder().decode(TranslationPayloadDTO.self, from: data)
        } catch {
            throw TranslationFetchError.parse(error)
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
