public struct GitradConfig {
    public let apiKey: String
    public let baseUrl: String
    public let maxCacheAge: Int
    /// Key namespace configured for the translation file on this environment.
    /// When set, this prefix is automatically prepended to every key lookup:
    /// `Gitrad.string("greeting.hello")` resolves `"<namespace>.greeting.hello"`.
    /// Environments created before namespaces were introduced should leave this `nil`.
    public let namespace: String?

    public init(
        apiKey: String,
        baseUrl: String,
        maxCacheAge: Int = 3600,
        namespace: String? = nil
    ) {
        self.apiKey = apiKey
        self.baseUrl = baseUrl
        self.maxCacheAge = maxCacheAge
        self.namespace = namespace
    }
}
