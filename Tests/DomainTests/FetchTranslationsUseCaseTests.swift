import XCTest
import Foundation
import Domain

final class FetchTranslationsUseCaseTests: XCTestCase {

    func test_execute_calls_fetchRemote_and_save() async throws {
        let mock = MockTranslationRepository()
        mock.stubbedRemotePayload = TranslationPayload(translations: [
            "en": ["key": .string("value")]
        ])
        let useCase = FetchTranslationsUseCase(repository: mock)

        let result = try await useCase.execute()

        XCTAssertEqual(result, mock.stubbedRemotePayload)
        XCTAssertEqual(mock.fetchCallCount, 1)
        XCTAssertEqual(mock.savedPayloads.last, mock.stubbedRemotePayload)
    }

    func test_execute_propagates_error() async {
        let mock = MockTranslationRepository()
        mock.fetchError = TranslationFetchError.unauthorized
        let useCase = FetchTranslationsUseCase(repository: mock)

        do {
            _ = try await useCase.execute()
            XCTFail("Expected error")
        } catch {
            XCTAssertTrue(error is TranslationFetchError)
        }
    }

    func test_save_is_not_called_on_error() async {
        let mock = MockTranslationRepository()
        mock.fetchError = TranslationFetchError.unauthorized
        let useCase = FetchTranslationsUseCase(repository: mock)

        _ = try? await useCase.execute()
        XCTAssertTrue(mock.savedPayloads.isEmpty)
    }
}

// MARK: - Mock

private final class MockTranslationRepository: TranslationRepository {
    var stubbedRemotePayload: TranslationPayload = .empty
    var fetchError: Error?
    var stubbedCached: TranslationPayload?
    var stubbedBundled: TranslationPayload?
    var stubbedModDate: Date?
    var fetchCallCount = 0
    var savedPayloads: [TranslationPayload] = []

    func fetchRemote() async throws -> TranslationPayload {
        fetchCallCount += 1
        if let error = fetchError { throw error }
        return stubbedRemotePayload
    }

    func loadCached() -> TranslationPayload? { stubbedCached }
    func save(_ payload: TranslationPayload) { savedPayloads.append(payload) }
    func loadBundled() -> TranslationPayload? { stubbedBundled }
    func cacheModificationDate() -> Date? { stubbedModDate }
}
