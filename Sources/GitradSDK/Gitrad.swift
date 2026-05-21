import Foundation

public final class Gitrad {

    // MARK: - Singleton

    public static let shared = Gitrad()
    private init() {}

    // MARK: - State (lock-protected)

    private let lock = NSLock()
    private var _config: GitradConfig?
    private var _payload: OTAPayload = [:]
    private var _lastFetchDate: Date?
    private var _eventHandler: ((GitradEvent) -> Void)?

    public let observableStore = GitradStore()

    // MARK: - Public API

    /// Configure the SDK. Call once before any string lookup — typically at app launch.
    public static func configure(
        apiKey: String,
        baseUrl: String,
        envName: String,
        maxCacheAge: Int = 3600
    ) {
        let cfg = GitradConfig(
            apiKey: apiKey,
            baseUrl: baseUrl,
            envName: envName,
            maxCacheAge: maxCacheAge
        )
        shared.withLock { shared._config = cfg }

        if let cached = DiskCache.read(envName: envName) {
            shared.withLock { shared._payload = cached }
            shared.emit(.cacheHit)
        } else {
            let baseline = BundleBaseline.load()
            shared.withLock { shared._payload = baseline }
            if !baseline.isEmpty { shared.emit(.bundleFallback) }
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
    public static func string(
        _ key: String,
        count: Int? = nil,
        language: String? = nil
    ) -> String {
        let lang = language ?? Self.currentLanguage()
        return shared.resolve(key: key, count: count, language: lang)
    }

    /// Register an event handler for observability (analytics, crash reporting).
    public static func onEvent(_ handler: @escaping (GitradEvent) -> Void) {
        shared.withLock { shared._eventHandler = handler }
    }

    // MARK: - Internal

    func resolve(key: String, count: Int? = nil, language: String) -> String {
        let payload = withLock { _payload }
        let base    = baseLang(language)

        let entry = payload[language]?[key]
                 ?? payload[base]?[key]
                 ?? payload["en"]?[key]

        guard let entry else { return key }

        switch entry {
        case .string(let s):
            return s
        case .plurals(let map):
            guard let count else { return map["other"] ?? key }
            return PluralRules.form(count: count, map: map, language: language)
        }
    }

    // MARK: - Private fetch machinery

    private func fetchIfStale() async {
        guard let config = withLock({ _config }) else { return }
        let lastFetch = withLock { _lastFetchDate }
                     ?? DiskCache.modificationDate(envName: config.envName)

        let stale: Bool
        if config.maxCacheAge == 0 {
            stale = true
        } else if let date = lastFetch {
            stale = Date().timeIntervalSince(date) > TimeInterval(config.maxCacheAge)
        } else {
            stale = true
        }

        if stale { await fetchAlways() }
    }

    private func fetchAlways() async {
        guard let config = withLock({ _config }) else { return }

        emit(.fetchStarted)
        let start = Date()

        do {
            let payload = try await fetchWithRetry(config: config)
            withLock {
                _payload       = payload
                _lastFetchDate = Date()
            }
            DiskCache.write(payload, envName: config.envName)
            let ms = Int(Date().timeIntervalSince(start) * 1000)
            emit(.fetchSucceeded(languages: payload.keys.count, ms: ms))
            observableStore.notifyRefresh()
        } catch {
            emit(.fetchFailed(error: error))
            // Existing in-memory payload (from disk cache or bundle) continues to serve.
        }
    }

    private func fetchWithRetry(config: GitradConfig) async throws -> OTAPayload {
        let delays: [UInt64] = [2, 4, 8, 16].map { $0 * 1_000_000_000 }
        var lastError: Error = GitradError.networkError(URLError(.unknown))

        for attempt in 0..<5 {
            do {
                return try await doFetch(config: config)
            } catch GitradError.unauthorized {
                throw GitradError.unauthorized
            } catch GitradError.subscriptionInactive {
                throw GitradError.subscriptionInactive
            } catch GitradError.parseError(let e) {
                throw GitradError.parseError(e)
            } catch {
                lastError = error
            }
            if attempt < 4 {
                try await Task.sleep(nanoseconds: delays[attempt])
            }
        }
        throw lastError
    }

    private func doFetch(config: GitradConfig) async throws -> OTAPayload {
        let client    = GitradClient(config: config)
        let signedUrl = try await client.downloadUrl()
        return try await client.download(from: signedUrl)
    }

    // MARK: - Testing

    func injectPayloadForTesting(_ payload: OTAPayload) {
        withLock { _payload = payload }
    }

    // MARK: - Helpers

    @discardableResult
    private func withLock<T>(_ block: () throws -> T) rethrows -> T {
        lock.lock()
        defer { lock.unlock() }
        return try block()
    }

    private func emit(_ event: GitradEvent) {
        let handler = withLock { _eventHandler }
        handler?(event)
    }

    private func baseLang(_ lang: String) -> String {
        guard let idx = lang.firstIndex(of: "-") else { return lang }
        return String(lang[..<idx])
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
