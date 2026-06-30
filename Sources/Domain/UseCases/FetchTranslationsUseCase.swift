package struct FetchTranslationsUseCase {
    private let repository: any TranslationRepository

    package init(repository: any TranslationRepository) {
        self.repository = repository
    }

    /// Fetches fresh translations unconditionally, persists to cache, and returns the payload.
    package func execute() async throws -> TranslationPayload {
        try await repository.fetchRemoteAndPersist()
    }
}
