import Foundation
import Domain

/// The only package-visible entry point into the Data layer.
/// All concrete data source types remain internal to this target.
package enum TranslationRepositoryFactory {
    package static func make(
        apiKey: String,
        baseUrl: String,
        envName: String,
        bundle: Bundle
    ) -> any TranslationRepository {
        DefaultTranslationRepository(
            remote: RemoteTranslationDataSource(apiKey: apiKey, baseUrl: baseUrl),
            local: LocalTranslationDataSource(envName: envName),
            bundleDS: BundleTranslationDataSource(bundle: bundle)
        )
    }
}
