import Foundation

public typealias OTAPayload = [String: [String: Entry]]

public enum Entry: Equatable {
    case string(String)
    case plurals([String: String])
}

extension Entry: Codable {
    public init(from decoder: Decoder) throws {
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

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let s):    try container.encode(s)
        case .plurals(let map): try container.encode(map)
        }
    }
}
