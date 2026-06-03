import Foundation

struct TranslationPayloadDTO: Codable, Equatable {
    let namespaces: [String]
    let translations: [String: [String: TranslationEntryDTO]]

    init(namespaces: [String] = [], translations: [String: [String: TranslationEntryDTO]]) {
        self.namespaces = namespaces
        self.translations = translations
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: AnyCodingKey.self)
        namespaces = (try? container.decode([String].self, forKey: AnyCodingKey("_namespaces"))) ?? []
        var result: [String: [String: TranslationEntryDTO]] = [:]
        for key in container.allKeys where key.stringValue != "_namespaces" {
            if let dict = try? container.decode([String: TranslationEntryDTO].self, forKey: key) {
                result[key.stringValue] = dict
            }
        }
        translations = result
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: AnyCodingKey.self)
        if !namespaces.isEmpty {
            try container.encode(namespaces, forKey: AnyCodingKey("_namespaces"))
        }
        for (lang, dict) in translations {
            try container.encode(dict, forKey: AnyCodingKey(lang))
        }
    }
}

private struct AnyCodingKey: CodingKey {
    let stringValue: String
    var intValue: Int? { nil }
    init(_ stringValue: String) { self.stringValue = stringValue }
    init?(stringValue: String) { self.stringValue = stringValue }
    init?(intValue: Int) { nil }
}

enum TranslationEntryDTO: Codable, Equatable {
    case string(String)
    case plurals([String: String])

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let s = try? container.decode(String.self) {
            self = .string(s)
        } else if let map = try? container.decode([String: String].self) {
            self = .plurals(map)
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Expected a string or a plural-forms object"
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let s):    try container.encode(s)
        case .plurals(let map): try container.encode(map)
        }
    }
}
