import Foundation

final class LocalTranslationDataSource {
    private let cacheId: String
    private let fileManager = FileManager.default
    private let lock = NSLock()
    private var _lastSaveDate: Date?

    init(cacheId: String) {
        self.cacheId = cacheId
    }

    func read() -> TranslationPayloadDTO? {
        guard
            let path = cachePath(),
            fileManager.fileExists(atPath: path.path)
        else { return nil }

        guard let data = try? Foundation.Data(contentsOf: path) else { return nil }

        if let dto = try? JSONDecoder().decode(TranslationPayloadDTO.self, from: data) {
            return dto
        }
        clear()
        return nil
    }

    func write(_ dto: TranslationPayloadDTO) {
        // Update in-memory date before the disk write so that a failed write
        // still marks the cache as fresh and avoids an infinite retry loop.
        lock.withLock { _lastSaveDate = Date() }

        guard let path = cachePath() else { return }
        do {
            try fileManager.createDirectory(
                at: path.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let data = try JSONEncoder().encode(dto)
            try data.write(to: path, options: .atomic)
        } catch {
            // Non-fatal: in-memory payload continues to serve strings.
        }
    }

    func clear() {
        guard let path = cachePath() else { return }
        try? fileManager.removeItem(at: path)
    }

    func modificationDate() -> Date? {
        lock.withLock { _lastSaveDate } ?? diskModificationDate()
    }

    private func diskModificationDate() -> Date? {
        guard let path = cachePath() else { return nil }
        let attrs = try? fileManager.attributesOfItem(atPath: path.path)
        return attrs?[.modificationDate] as? Date
    }

    // Library/Caches/gitrad/{cacheId}/translations.json
    private func cachePath() -> URL? {
        fileManager
            .urls(for: .cachesDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent("gitrad", isDirectory: true)
            .appendingPathComponent(cacheId, isDirectory: true)
            .appendingPathComponent("translations.json")
    }
}
