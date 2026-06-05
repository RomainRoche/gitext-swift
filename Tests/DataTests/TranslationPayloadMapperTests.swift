import XCTest
@testable import Data
import Domain

final class TranslationPayloadMapperTests: XCTestCase {

    func test_decode_string_entry_via_mapper() throws {
        let json = #"{"en": {"greeting.hello": "Hello"}}"#
        let dto = try JSONDecoder().decode(TranslationPayloadDTO.self, from: Foundation.Data(json.utf8))
        let payload = TranslationPayloadMapper.toDomain(dto)
        XCTAssertEqual(payload.translations["en"]?["greeting.hello"], .string("Hello"))
    }

    func test_decode_plural_entry_via_mapper() throws {
        let json = #"{"en": {"items": {"one": "%d item", "other": "%d items"}}}"#
        let dto = try JSONDecoder().decode(TranslationPayloadDTO.self, from: Foundation.Data(json.utf8))
        let payload = TranslationPayloadMapper.toDomain(dto)
        XCTAssertEqual(payload.translations["en"]?["items"], .plurals(["one": "%d item", "other": "%d items"]))
    }

    func test_decode_full_payload_via_mapper() throws {
        let json = """
        {
            "en": {
                "greeting.hello": "Hello",
                "notifications.count": {
                    "zero": "No notifications",
                    "one": "%d notification",
                    "other": "%d notifications"
                }
            },
            "fr": {
                "greeting.hello": "Bonjour"
            }
        }
        """
        let dto = try JSONDecoder().decode(TranslationPayloadDTO.self, from: Foundation.Data(json.utf8))
        let payload = TranslationPayloadMapper.toDomain(dto)
        XCTAssertEqual(payload.translations["en"]?["greeting.hello"], .string("Hello"))
        XCTAssertEqual(payload.translations["fr"]?["greeting.hello"], .string("Bonjour"))
        XCTAssertEqual(payload.translations["en"]?["notifications.count"], .plurals([
            "zero": "No notifications",
            "one":  "%d notification",
            "other": "%d notifications"
        ]))
    }

    func test_decode_namespaces_from_root_key() throws {
        let json = """
        {
            "_namespaces": ["app"],
            "en": {
                "app.greeting.hello": "Hello",
                "app.notifications.count": {
                    "one": "%d notification",
                    "other": "%d notifications"
                }
            },
            "fr": {
                "app.greeting.hello": "Bonjour"
            }
        }
        """
        let dto = try JSONDecoder().decode(TranslationPayloadDTO.self, from: Foundation.Data(json.utf8))
        let payload = TranslationPayloadMapper.toDomain(dto)
        XCTAssertEqual(payload.namespaces, ["app"])
        XCTAssertEqual(payload.translations["en"]?["app.greeting.hello"], .string("Hello"))
        XCTAssertEqual(payload.translations["fr"]?["app.greeting.hello"], .string("Bonjour"))
        XCTAssertNil(payload.translations["_namespaces"])
    }

    func test_namespaces_empty_when_key_absent() throws {
        let json = #"{"en": {"key": "value"}}"#
        let dto = try JSONDecoder().decode(TranslationPayloadDTO.self, from: Foundation.Data(json.utf8))
        let payload = TranslationPayloadMapper.toDomain(dto)
        XCTAssertEqual(payload.namespaces, [])
    }

    func test_roundtrip_domain_to_dto_and_back() throws {
        let original = TranslationPayload(
            translations: [
                "en": [
                    "key1": .string("Hello"),
                    "key2": .plurals(["one": "%d item", "other": "%d items"])
                ]
            ],
            namespaces: ["app"]
        )
        let dto = TranslationPayloadMapper.toDTO(original)
        let data = try JSONEncoder().encode(dto)
        let decodedDTO = try JSONDecoder().decode(TranslationPayloadDTO.self, from: data)
        let roundtripped = TranslationPayloadMapper.toDomain(decodedDTO)

        XCTAssertEqual(roundtripped.namespaces, ["app"])
        XCTAssertEqual(roundtripped.translations["en"]?["key1"], .string("Hello"))
        XCTAssertEqual(roundtripped.translations["en"]?["key2"], .plurals(["one": "%d item", "other": "%d items"]))
    }
}
