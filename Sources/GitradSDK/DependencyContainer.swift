import Foundation
import Domain
import Data

/// Composition root: wires every dependency from the outside in.
/// Created once per `Gitrad.configure()` call; never mutated afterwards.
struct DependencyContainer {
    let repository: any TranslationRepository
    let maxCacheAge: TimeInterval
    let namespace: String?
    let loadInitial: LoadInitialTranslationsUseCase
    let fetch: FetchTranslationsUseCase
    let resolve: ResolveTranslationUseCase

    init(config: GitradConfig) {
        let repo = TranslationRepositoryFactory.make(
            apiKey: config.apiKey,
            baseUrl: config.baseUrl,
            bundle: Bundle.module
        )
        repository = repo
        maxCacheAge = TimeInterval(config.maxCacheAge)
        namespace = config.namespace
        loadInitial = LoadInitialTranslationsUseCase(repository: repo)
        fetch = FetchTranslationsUseCase(repository: repo)
        resolve = ResolveTranslationUseCase()
    }
}
