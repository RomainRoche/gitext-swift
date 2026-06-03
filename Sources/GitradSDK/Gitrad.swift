import Foundation
import Domain

public final class Gitrad {

    // MARK: - Singleton

    public static let shared = Gitrad()
    private init() {}

    // MARK: - State (lock-protected)

    // Minimum interval between network requests as mandated by the server's
    // Cache-Control: max-age=60 header to stay within rate limits.
    private static let serverCacheMaxAge: TimeInterval = 60

    private let lock = NSLock()
    private var _container: DependencyContainer?
    private var _payload: TranslationPayload = .empty
    private var _lastFetchDate: Date?
    private var _eventHandler: ((GitradEvent) -> Void)?

    public let observableStore = GitradStore()

    // MARK: - Public API

    /// Configure the SDK. Call once before any string lookup — typically at app launch.
    public static func configure(
        apiKey: String,
        baseUrl: String,
        envName: String,
        maxCacheAge: Int = 3600,
        namespace: String? = nil
    ) {
        let config = GitradConfig(
            apiKey: apiKey,
            baseUrl: baseUrl,
            envName: envName,
            maxCacheAge: maxCacheAge,
            namespace: namespace
        )
        let container = DependencyContainer(config: config)
        shared.withLock { shared._container = container }

        let (payload, source) = container.loadInitial.execute()
        shared.withLock { shared._payload = payload }

        switch source {
        case .cache:  shared.emit(.cacheHit)
        case .bundle: shared.emit(.bundleFallback)
        case .empty:  break
        }
    }

    /// Fetches translations unconditionally. Call at app launch (non-blocking).
    public static func prefetch() async {
        await shared.fetchAlways()
    }

    /// Fetches translations if the cached payload is older than `maxCacheAge`.
    /// Call on every foreground resume. Does nothing when cache is fresh.
    public static func refresh() async {
        await shared.fetchIfStale()
    }

    /// Returns a translated string, never throws.
    /// Falls back through: exact locale → base language → "en" → key itself.
    /// When a `namespace` is configured, it is automatically prepended to `key`.
    public static func string(
        _ key: String,
        count: Int? = nil,
        language: String? = nil
    ) -> String {
        let lang = language ?? currentLanguage()
        let (payload, resolve, namespace) = shared.withLock {
            (shared._payload, shared._container?.resolve, shared._container?.namespace)
        }
        let lookupKey = namespace.map { "\($0).\(key)" } ?? key
        return resolve?.execute(key: lookupKey, count: count, language: lang, in: payload) ?? key
    }

    /// Register an event handler for observability (analytics, crash reporting).
    public static func onEvent(_ handler: @escaping (GitradEvent) -> Void) {
        shared.withLock { shared._eventHandler = handler }
    }

    // MARK: - Private fetch machinery

    private func fetchAlways() async {
        guard let container = withLock({ _container }) else { return }

        // Respect Cache-Control: max-age=60 — skip if last fetch was recent.
        let lastFetch = withLock { _lastFetchDate }
        if let lastFetch, Date().timeIntervalSince(lastFetch) < Self.serverCacheMaxAge { return }

        emit(.fetchStarted)
        let start = Date()

        do {
            let payload = try await container.fetch.execute()
            withLock {
                _payload = payload
                _lastFetchDate = Date()
            }
            let ms = Int(Date().timeIntervalSince(start) * 1000)
            emit(.fetchSucceeded(languages: payload.translations.keys.count, ms: ms))
            observableStore.notifyRefresh()
        } catch {
            emit(.fetchFailed(error: GitradError(from: error)))
        }
    }

    private func fetchIfStale() async {
        guard let container = withLock({ _container }) else { return }

        // Staleness check lives here rather than in a use case so that fetchStarted
        // is only emitted when a network call is certain to follow.
        let cacheDate = container.repository.cacheModificationDate()
        let maxAge = container.maxCacheAge

        let isStale: Bool
        if maxAge == 0 {
            isStale = true
        } else if let date = cacheDate {
            isStale = Date().timeIntervalSince(date) > maxAge
        } else {
            isStale = true
        }

        guard isStale else { return }
        await fetchAlways()
    }

    // MARK: - Helpers

    @discardableResult
    private func withLock<T>(_ block: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return block()
    }

    private func emit(_ event: GitradEvent) {
        let handler = withLock { _eventHandler }
        handler?(event)
    }

    private static func currentLanguage() -> String {
        let lang = Locale.current.language
        var code = lang.languageCode?.identifier ?? "en"
        if let region = lang.region?.identifier {
            code += "-\(region)"
        }
        return code
    }
}
