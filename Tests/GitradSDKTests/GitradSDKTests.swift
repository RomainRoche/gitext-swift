import XCTest
@testable import GitradSDK

// MARK: - Plural rules

final class PluralRulesTests: XCTestCase {

    func test_english_one_other() {
        XCTAssertEqual(PluralRules.category(count: 1,   language: "en"), "one")
        XCTAssertEqual(PluralRules.category(count: 0,   language: "en"), "other")
        XCTAssertEqual(PluralRules.category(count: 2,   language: "en"), "other")
        XCTAssertEqual(PluralRules.category(count: 100, language: "en"), "other")
    }

    func test_french_zero_one() {
        XCTAssertEqual(PluralRules.category(count: 0, language: "fr"), "one")
        XCTAssertEqual(PluralRules.category(count: 1, language: "fr"), "one")
        XCTAssertEqual(PluralRules.category(count: 2, language: "fr"), "other")
    }

    func test_russian_slavic() {
        XCTAssertEqual(PluralRules.category(count: 1,  language: "ru"), "one")
        XCTAssertEqual(PluralRules.category(count: 2,  language: "ru"), "few")
        XCTAssertEqual(PluralRules.category(count: 5,  language: "ru"), "many")
        XCTAssertEqual(PluralRules.category(count: 11, language: "ru"), "many")
        XCTAssertEqual(PluralRules.category(count: 21, language: "ru"), "one")
        XCTAssertEqual(PluralRules.category(count: 22, language: "ru"), "few")
    }

    func test_arabic_six_forms() {
        XCTAssertEqual(PluralRules.category(count: 0,   language: "ar"), "zero")
        XCTAssertEqual(PluralRules.category(count: 1,   language: "ar"), "one")
        XCTAssertEqual(PluralRules.category(count: 2,   language: "ar"), "two")
        XCTAssertEqual(PluralRules.category(count: 5,   language: "ar"), "few")
        XCTAssertEqual(PluralRules.category(count: 15,  language: "ar"), "many")
        XCTAssertEqual(PluralRules.category(count: 100, language: "ar"), "other")
    }

    func test_japanese_invariant() {
        XCTAssertEqual(PluralRules.category(count: 1, language: "ja"), "other")
        XCTAssertEqual(PluralRules.category(count: 2, language: "ja"), "other")
    }

    func test_regional_variant_strips_to_base() {
        // fr-FR should behave as fr
        XCTAssertEqual(PluralRules.category(count: 0, language: "fr-FR"), "one")
        XCTAssertEqual(PluralRules.category(count: 2, language: "fr-FR"), "other")
    }

    func test_form_substitutes_count() {
        let map = ["one": "%d item", "other": "%d items"]
        XCTAssertEqual(PluralRules.form(count: 1, map: map, language: "en"), "1 item")
        XCTAssertEqual(PluralRules.form(count: 5, map: map, language: "en"), "5 items")
    }

    func test_form_zero_key_wins_over_cldr_other() {
        let map = ["zero": "No notifications", "one": "%d notification", "other": "%d notifications"]
        // English CLDR has no "zero" category, but the explicit "zero" key is honoured for count==0.
        XCTAssertEqual(PluralRules.form(count: 0, map: map, language: "en"), "No notifications")
        XCTAssertEqual(PluralRules.form(count: 1, map: map, language: "en"), "1 notification")
        XCTAssertEqual(PluralRules.form(count: 5, map: map, language: "en"), "5 notifications")
    }

    func test_form_falls_back_to_other_when_category_missing() {
        let map = ["other": "%d items"]
        XCTAssertEqual(PluralRules.form(count: 1, map: map, language: "en"), "1 items")
    }
}

// MARK: - Entry decoding

final class EntryDecodingTests: XCTestCase {

    func test_decode_string_entry() throws {
        let json = #""Hello""#
        let entry = try JSONDecoder().decode(Entry.self, from: Data(json.utf8))
        XCTAssertEqual(entry, .string("Hello"))
    }

    func test_decode_plural_entry() throws {
        let json = #"{"one": "%d item", "other": "%d items"}"#
        let entry = try JSONDecoder().decode(Entry.self, from: Data(json.utf8))
        XCTAssertEqual(entry, .plurals(["one": "%d item", "other": "%d items"]))
    }

    func test_decode_full_payload() throws {
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
        let payload = try JSONDecoder().decode(OTAPayload.self, from: Data(json.utf8))
        XCTAssertEqual(payload["en"]?["greeting.hello"], .string("Hello"))
        XCTAssertEqual(payload["fr"]?["greeting.hello"], .string("Bonjour"))
        XCTAssertEqual(payload["en"]?["notifications.count"], .plurals([
            "zero": "No notifications",
            "one":  "%d notification",
            "other": "%d notifications"
        ]))
    }

    func test_encode_decode_roundtrip() throws {
        let original: OTAPayload = [
            "en": [
                "key1": .string("Hello"),
                "key2": .plurals(["one": "%d item", "other": "%d items"])
            ]
        ]
        let data    = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(OTAPayload.self, from: data)
        XCTAssertEqual(decoded["en"]?["key1"], .string("Hello"))
        XCTAssertEqual(decoded["en"]?["key2"], .plurals(["one": "%d item", "other": "%d items"]))
    }
}

// MARK: - Resolve / fallback chain

final class ResolveTests: XCTestCase {

    private func makeGitrad(payload: OTAPayload) -> Gitrad {
        let g = Gitrad.shared
        // Inject payload directly for testing without a network call.
        g.injectPayloadForTesting(payload)
        return g
    }

    func test_exact_language_match() {
        Gitrad.shared.injectPayloadForTesting([
            "fr-FR": ["greeting.hello": .string("Salut")]
        ])
        XCTAssertEqual(Gitrad.string("greeting.hello", language: "fr-FR"), "Salut")
    }

    func test_base_language_fallback() {
        Gitrad.shared.injectPayloadForTesting([
            "fr": ["greeting.hello": .string("Bonjour")]
        ])
        XCTAssertEqual(Gitrad.string("greeting.hello", language: "fr-FR"), "Bonjour")
    }

    func test_english_fallback() {
        Gitrad.shared.injectPayloadForTesting([
            "en": ["greeting.hello": .string("Hello")]
        ])
        XCTAssertEqual(Gitrad.string("greeting.hello", language: "de"), "Hello")
    }

    func test_key_fallback_when_missing() {
        Gitrad.shared.injectPayloadForTesting([:])
        XCTAssertEqual(Gitrad.string("missing.key", language: "en"), "missing.key")
    }

    func test_plural_resolution() {
        Gitrad.shared.injectPayloadForTesting([
            "en": [
                "notifications.count": .plurals([
                    "zero": "No notifications",
                    "one":  "%d notification",
                    "other": "%d notifications"
                ])
            ]
        ])
        XCTAssertEqual(Gitrad.string("notifications.count", count: 0,  language: "en"), "No notifications")
        XCTAssertEqual(Gitrad.string("notifications.count", count: 1,  language: "en"), "1 notification")
        XCTAssertEqual(Gitrad.string("notifications.count", count: 5,  language: "en"), "5 notifications")
    }
}

// MARK: - DiskCache

final class DiskCacheTests: XCTestCase {
    private let envName = "test-\(UUID().uuidString)"

    override func tearDown() {
        DiskCache.clear(envName: envName)
    }

    func test_write_read_roundtrip() throws {
        let payload: OTAPayload = ["en": ["key": .string("value")]]
        DiskCache.write(payload, envName: envName)
        let loaded = DiskCache.read(envName: envName)
        XCTAssertEqual(loaded?["en"]?["key"], .string("value"))
    }

    func test_clear_removes_file() {
        let payload: OTAPayload = ["en": ["key": .string("value")]]
        DiskCache.write(payload, envName: envName)
        DiskCache.clear(envName: envName)
        XCTAssertNil(DiskCache.read(envName: envName))
    }

    func test_modification_date_after_write() {
        let payload: OTAPayload = ["en": ["key": .string("value")]]
        DiskCache.write(payload, envName: envName)
        XCTAssertNotNil(DiskCache.modificationDate(envName: envName))
    }
}
