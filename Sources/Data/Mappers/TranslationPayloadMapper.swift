import Domain

enum TranslationPayloadMapper {
    static func toDomain(_ dto: TranslationPayloadDTO) -> TranslationPayload {
        let translations = dto.mapValues { langDict in
            langDict.mapValues { entry -> TranslationEntry in
                switch entry {
                case .string(let s): return .string(s)
                case .plurals(let m): return .plurals(m)
                }
            }
        }
        return TranslationPayload(translations: translations)
    }

    static func toDTO(_ payload: TranslationPayload) -> TranslationPayloadDTO {
        payload.translations.mapValues { langDict in
            langDict.mapValues { entry -> TranslationEntryDTO in
                switch entry {
                case .string(let s): return .string(s)
                case .plurals(let m): return .plurals(m)
                }
            }
        }
    }
}
