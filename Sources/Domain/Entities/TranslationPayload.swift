package struct TranslationPayload: Equatable {
    package let translations: [String: [String: TranslationEntry]]

    package static let empty = TranslationPayload(translations: [:])

    package var isEmpty: Bool { translations.isEmpty }

    package init(translations: [String: [String: TranslationEntry]]) {
        self.translations = translations
    }
}
