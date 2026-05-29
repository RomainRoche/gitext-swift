public enum GitradEvent {
    case fetchStarted
    case fetchSucceeded(languages: Int, ms: Int)
    case fetchFailed(error: Error)
    case cacheHit
    case bundleFallback
}
