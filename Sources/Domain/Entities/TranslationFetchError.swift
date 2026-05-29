package enum TranslationFetchError: Error {
    case unauthorized
    case subscriptionInactive
    case network(Error)
    case parse(Error)
}
