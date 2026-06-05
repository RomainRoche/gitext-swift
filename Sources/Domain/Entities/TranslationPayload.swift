package struct TranslationPayload: Equatable {
    package let translations: [String: [String: TranslationEntry]]
    package let namespaces: [String]

    package static let empty = TranslationPayload(translations: [:])

    package var isEmpty: Bool { translations.isEmpty }

    package init(translations: [String: [String: TranslationEntry]], namespaces: [String] = []) {
        self.translations = translations
        self.namespaces = namespaces
    }
}
