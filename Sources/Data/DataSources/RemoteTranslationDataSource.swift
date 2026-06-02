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
        let backoffDelays: [UInt64] = [2, 4, 8, 16].map { $0 * 1_000_000_000 }
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
            } catch TranslationFetchError.rateLimited(let retryAfter) {
                lastError = TranslationFetchError.rateLimited(retryAfter: retryAfter)
                try await Task.sleep(nanoseconds: UInt64(retryAfter) * 1_000_000_000)
                continue
            } catch {
                lastError = error
            }
            if attempt < 4 {
                try await Task.sleep(nanoseconds: backoffDelays[attempt])
            }
        }
        throw lastError
    }

    // Single authenticated request — URLSession follows the 302 redirect automatically.
    private func performFetch() async throws -> TranslationPayloadDTO {
        let base = baseUrl.trimmingCharacters(in: .init(charactersIn: "/"))
        guard let url = URL(string: base + "/api/ota/download") else {
            throw TranslationFetchError.network(URLError(.badURL))
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw TranslationFetchError.network(URLError(.badServerResponse))
        }

        switch http.statusCode {
        case 200..<300:
            do {
                return try JSONDecoder().decode(TranslationPayloadDTO.self, from: data)
            } catch {
                throw TranslationFetchError.parse(error)
            }
        case 401:
            throw TranslationFetchError.unauthorized
        case 403:
            throw TranslationFetchError.subscriptionInactive
        case 429:
            let retryAfter = http.value(forHTTPHeaderField: "Retry-After")
                .flatMap(TimeInterval.init) ?? 60
            throw TranslationFetchError.rateLimited(retryAfter: retryAfter)
        default:
            throw TranslationFetchError.network(URLError(.badServerResponse))
        }
    }
}
