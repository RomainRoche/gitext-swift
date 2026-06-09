import Domain
import Foundation

public enum GitradError: Error {
    case unauthorized
    case subscriptionInactive
    /// Rate limit hit — the SDK waited for `Retry-After` before retrying.
    case rateLimited(retryAfter: TimeInterval)
    case networkError(Error)
    case parseError(Error)
    case notConfigured
}

extension GitradError {
    init(from error: Error) {
        guard let fetchError = error as? TranslationFetchError else {
            self = .networkError(error)
            return
        }
        switch fetchError {
        case .unauthorized:                      self = .unauthorized
        case .subscriptionInactive:              self = .subscriptionInactive
        case .rateLimited(let retryAfter):       self = .rateLimited(retryAfter: retryAfter)
        case .network(let underlying):           self = .networkError(underlying)
        case .parse(let underlying):             self = .parseError(underlying)
        }
    }
}
