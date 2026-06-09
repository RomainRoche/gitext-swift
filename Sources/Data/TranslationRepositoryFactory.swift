import Foundation
import Domain

/// The only package-visible entry point into the Data layer.
/// All concrete data source types remain internal to this target.
package enum TranslationRepositoryFactory {
    package static func make(
        apiKey: String,
        baseUrl: String,
        bundle: Bundle
    ) -> any TranslationRepository {
        DefaultTranslationRepository(
            remote: RemoteTranslationDataSource(apiKey: apiKey, baseUrl: baseUrl),
            local: LocalTranslationDataSource(cacheId: cacheId(for: apiKey)),
            bundleDS: BundleTranslationDataSource(bundle: bundle)
        )
    }

    /// FNV-1a 64-bit hash of the API key — stable across launches, unique per key.
    /// Used as the local cache directory name without exposing the raw key.
    static func cacheId(for apiKey: String) -> String {
        var hash: UInt64 = 14695981039346656037
        for byte in apiKey.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1099511628211
        }
        return String(hash, radix: 16)
    }
}
