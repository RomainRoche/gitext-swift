package struct ResolveTranslationUseCase {
    package init() {}

    /// Resolves a translation key, returning `nil` if not found in the payload.
    package func resolve(key: String, count: Int?, language: String, in payload: TranslationPayload) -> String? {
        let base = baseLang(language)
        let entry = payload.translations[language]?[key]
                 ?? payload.translations[base]?[key]
                 ?? payload.translations["en"]?[key]

        guard let entry else { return nil }

        switch entry {
        case .string(let s):
            return s
        case .plurals(let map):
            guard let count else { return map["other"] }
            return PluralRules.form(count: count, map: map, language: language)
        }
    }

    /// Resolves a translation key. Fallback chain: exact locale → base language → "en" → key.
    package func execute(key: String, count: Int?, language: String, in payload: TranslationPayload) -> String {
        resolve(key: key, count: count, language: language, in: payload) ?? key
    }

    private func baseLang(_ lang: String) -> String {
        guard let idx = lang.firstIndex(of: "-") else { return lang }
        return String(lang[..<idx])
    }
}
