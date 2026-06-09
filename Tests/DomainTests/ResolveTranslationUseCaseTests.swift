import XCTest
import Foundation
import Domain

final class ResolveTranslationUseCaseTests: XCTestCase {

    private let useCase = ResolveTranslationUseCase()

    func test_exact_language_match() {
        let payload = TranslationPayload(translations: [
            "fr-FR": ["greeting.hello": .string("Salut")]
        ])
        XCTAssertEqual(useCase.execute(key: "greeting.hello", count: nil, language: "fr-FR", in: payload), "Salut")
    }

    func test_base_language_fallback() {
        let payload = TranslationPayload(translations: [
            "fr": ["greeting.hello": .string("Bonjour")]
        ])
        XCTAssertEqual(useCase.execute(key: "greeting.hello", count: nil, language: "fr-FR", in: payload), "Bonjour")
    }

    func test_english_fallback() {
        let payload = TranslationPayload(translations: [
            "en": ["greeting.hello": .string("Hello")]
        ])
        XCTAssertEqual(useCase.execute(key: "greeting.hello", count: nil, language: "de", in: payload), "Hello")
    }

    func test_key_fallback_when_missing() {
        XCTAssertEqual(useCase.execute(key: "missing.key", count: nil, language: "en", in: .empty), "missing.key")
    }

    func test_resolve_returns_nil_when_missing() {
        XCTAssertNil(useCase.resolve(key: "missing.key", count: nil, language: "en", in: .empty))
    }

    func test_resolve_returns_value_when_found() {
        let payload = TranslationPayload(translations: ["en": ["hello": .string("Hello")]])
        XCTAssertEqual(useCase.resolve(key: "hello", count: nil, language: "en", in: payload), "Hello")
    }

    func test_plural_resolution() {
        let payload = TranslationPayload(translations: [
            "en": [
                "notifications.count": .plurals([
                    "zero": "No notifications",
                    "one":  "%d notification",
                    "other": "%d notifications"
                ])
            ]
        ])
        XCTAssertEqual(useCase.execute(key: "notifications.count", count: 0,  language: "en", in: payload), "No notifications")
        XCTAssertEqual(useCase.execute(key: "notifications.count", count: 1,  language: "en", in: payload), "1 notification")
        XCTAssertEqual(useCase.execute(key: "notifications.count", count: 5,  language: "en", in: payload), "5 notifications")
    }

    func test_plurals_without_count_returns_other() {
        let payload = TranslationPayload(translations: [
            "en": ["items": .plurals(["one": "1 item", "other": "many items"])]
        ])
        XCTAssertEqual(useCase.execute(key: "items", count: nil, language: "en", in: payload), "many items")
    }
}
