import Foundation

package protocol TranslationRepository {
    func fetchRemote() async throws -> TranslationPayload
    func fetchRemoteAndPersist() async throws -> TranslationPayload
    func loadCached() -> TranslationPayload?
    func save(_ payload: TranslationPayload)
    func loadBundled() -> TranslationPayload?
    func cacheModificationDate() -> Date?
}

package extension TranslationRepository {
    func fetchRemoteAndPersist() async throws -> TranslationPayload {
        let payload = try await fetchRemote()
        save(payload)
        return payload
    }
}
