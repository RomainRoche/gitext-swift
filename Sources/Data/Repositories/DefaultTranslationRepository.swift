import Foundation
import Domain

final class DefaultTranslationRepository: TranslationRepository {
    private let remote: RemoteTranslationDataSource
    private let local: LocalTranslationDataSource
    private let bundleDS: BundleTranslationDataSource

    init(
        remote: RemoteTranslationDataSource,
        local: LocalTranslationDataSource,
        bundleDS: BundleTranslationDataSource
    ) {
        self.remote = remote
        self.local = local
        self.bundleDS = bundleDS
    }

    func fetchRemote() async throws -> TranslationPayload {
        let dto = try await remote.fetch()
        return TranslationPayloadMapper.toDomain(dto)
    }

    func fetchRemoteAndPersist() async throws -> TranslationPayload {
        let (dto, raw) = try await remote.fetchRaw()
        local.writeRaw(raw)
        return TranslationPayloadMapper.toDomain(dto)
    }

    func loadCached() -> TranslationPayload? {
        local.read().map(TranslationPayloadMapper.toDomain)
    }

    func save(_ payload: TranslationPayload) {
        local.write(TranslationPayloadMapper.toDTO(payload))
    }

    func loadBundled() -> TranslationPayload? {
        bundleDS.load().map(TranslationPayloadMapper.toDomain)
    }

    func cacheModificationDate() -> Date? {
        local.modificationDate()
    }
}
