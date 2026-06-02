public struct GitradConfig {
    public let apiKey: String
    public let baseUrl: String
    public let envName: String
    public let maxCacheAge: Int

    public init(
        apiKey: String,
        baseUrl: String,
        envName: String,
        maxCacheAge: Int = 3600
    ) {
        self.apiKey = apiKey
        self.baseUrl = baseUrl
        self.envName = envName
        self.maxCacheAge = maxCacheAge
    }
}
