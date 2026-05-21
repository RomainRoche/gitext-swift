import Foundation

public enum GitradError: Error {
    case unauthorized
    case subscriptionInactive
    case networkError(Error)
    case parseError(Error)
    case notConfigured
}
