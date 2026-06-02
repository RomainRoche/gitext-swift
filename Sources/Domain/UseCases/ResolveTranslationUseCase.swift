package struct ResolveTranslationUseCase {
    package init() {}

    /// Resolves a translation key. Fallback chain: exact locale → base language → "en" → key.
    package func execute(key: String, count: Int?, language: String, in payload: TranslationPayload) -> String {
        let base = baseLang(language)
        let entry = payload.translations[language]?[key]
                 ?? payload.translations[base]?[key]
                 ?? payload.translations["en"]?[key]

        guard let entry else { return key }

        switch entry {
        case .string(let s):
            return s
        case .plurals(let map):
            guard let count else { return map["other"] ?? key }
            return PluralRules.form(count: count, map: map, language: language)
        }
    }

    private func baseLang(_ lang: String) -> String {
        guard let idx = lang.firstIndex(of: "-") else { return lang }
        return String(lang[..<idx])
    }
}
