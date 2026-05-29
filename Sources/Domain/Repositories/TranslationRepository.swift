import Foundation

package protocol TranslationRepository {
    func fetchRemote() async throws -> TranslationPayload
    func loadCached() -> TranslationPayload?
    func save(_ payload: TranslationPayload)
    func loadBundled() -> TranslationPayload?
    func cacheModificationDate() -> Date?
}
