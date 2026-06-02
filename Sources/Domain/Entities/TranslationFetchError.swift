package enum TranslationFetchError: Error {
    case unauthorized
    case subscriptionInactive
    /// Rate limit hit — caller should wait `retryAfter` seconds before the next attempt.
    case rateLimited(retryAfter: TimeInterval)
    case network(Error)
    case parse(Error)
}
