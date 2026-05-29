import XCTest
import Domain

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
        XCTAssertEqual(PluralRules.form(count: 0, map: map, language: "en"), "No notifications")
        XCTAssertEqual(PluralRules.form(count: 1, map: map, language: "en"), "1 notification")
        XCTAssertEqual(PluralRules.form(count: 5, map: map, language: "en"), "5 notifications")
    }

    func test_form_falls_back_to_other_when_category_missing() {
        let map = ["other": "%d items"]
        XCTAssertEqual(PluralRules.form(count: 1, map: map, language: "en"), "1 items")
    }
}
