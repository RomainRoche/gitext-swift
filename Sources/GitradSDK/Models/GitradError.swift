import Domain

public enum GitradError: Error {
    case unauthorized
    case subscriptionInactive
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
        case .unauthorized:            self = .unauthorized
        case .subscriptionInactive:    self = .subscriptionInactive
        case .network(let underlying): self = .networkError(underlying)
        case .parse(let underlying):   self = .parseError(underlying)
        }
    }
}
