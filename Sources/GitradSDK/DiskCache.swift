import Foundation

enum DiskCache {
    private static let fileManager = FileManager.default

    // Library/Caches/gitrad/{envName}/translations.json
    static func cachePath(envName: String) -> URL? {
        fileManager
            .urls(for: .cachesDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent("gitrad", isDirectory: true)
            .appendingPathComponent(envName, isDirectory: true)
            .appendingPathComponent("translations.json")
    }

    static func read(envName: String) -> OTAPayload? {
        guard
            let path = cachePath(envName: envName),
            fileManager.fileExists(atPath: path.path)
        else { return nil }

        do {
            let data = try Data(contentsOf: path)
            return try JSONDecoder().decode(OTAPayload.self, from: data)
        } catch {
            clear(envName: envName)
            return nil
        }
    }

    static func write(_ payload: OTAPayload, envName: String) {
        guard let path = cachePath(envName: envName) else { return }
        do {
            try fileManager.createDirectory(
                at: path.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let data = try JSONEncoder().encode(payload)
            try data.write(to: path, options: .atomic)
        } catch {
            // Non-fatal: in-memory payload continues to serve strings.
        }
    }

    static func clear(envName: String) {
        guard let path = cachePath(envName: envName) else { return }
        try? fileManager.removeItem(at: path)
    }

    static func modificationDate(envName: String) -> Date? {
        guard let path = cachePath(envName: envName) else { return nil }
        let attrs = try? fileManager.attributesOfItem(atPath: path.path)
        return attrs?[.modificationDate] as? Date
    }
}
