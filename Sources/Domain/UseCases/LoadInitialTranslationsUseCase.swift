package enum InitialPayloadSource {
    case cache, bundle, empty
}

package struct LoadInitialTranslationsUseCase {
    private let repository: any TranslationRepository

    package init(repository: any TranslationRepository) {
        self.repository = repository
    }

    package func execute() -> (payload: TranslationPayload, source: InitialPayloadSource) {
        if let cached = repository.loadCached() {
            return (cached, .cache)
        }
        if let bundled = repository.loadBundled() {
            return (bundled, .bundle)
        }
        return (.empty, .empty)
    }
}
