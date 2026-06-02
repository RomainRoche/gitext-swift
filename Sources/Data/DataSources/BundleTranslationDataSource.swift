import Foundation

final class BundleTranslationDataSource {
    private let bundle: Bundle

    init(bundle: Bundle) {
        self.bundle = bundle
    }

    func load() -> TranslationPayloadDTO? {
        guard
            let url = bundle.url(
                forResource: "translations",
                withExtension: "json",
                subdirectory: "gitrad-baseline"
            ),
            let data = try? Foundation.Data(contentsOf: url)
        else { return nil }

        return try? JSONDecoder().decode(TranslationPayloadDTO.self, from: data)
    }
}
