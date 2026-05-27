import Foundation

enum BundleBaseline {
    // Reads the bundled fallback payload shipped with the binary.
    // Returns an empty payload when the baseline file is absent.
    static func load() -> OTAPayload {
        guard
            let url = Bundle.module.url(
                forResource: "translations",
                withExtension: "json",
                subdirectory: "gitrad-baseline"
            ),
            let data = try? Data(contentsOf: url)
        else { return [:] }

        return (try? JSONDecoder().decode(OTAPayload.self, from: data)) ?? [:]
    }
}
