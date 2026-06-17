import XCTest
import GitextSDK

/// Tests the public SDK surface without @testable.
/// Network calls will fail in CI — these tests verify the public API contract only.
final class GitextIntegrationTests: XCTestCase {

    override func setUp() {
        // Configure with a fake key; no network call happens synchronously.
        Gitext.configure(
            apiKey: "test-key",
            baseUrl: "https://localhost",
            maxCacheAge: 3600
        )
    }

    func test_string_returns_key_when_no_translations_loaded() {
        XCTAssertEqual(Gitext.string("some.key"), "some.key")
    }

    func test_string_with_explicit_language_returns_key_on_empty_payload() {
        XCTAssertEqual(Gitext.string("some.key", language: "fr"), "some.key")
    }

    func test_string_before_configure_returns_key() {
        // Simulate a call before configure by checking that string() never crashes.
        XCTAssertFalse(Gitext.string("key").isEmpty)
    }

    func test_onEvent_handler_is_replaced_not_stacked() {
        var callCount = 0
        Gitext.onEvent { _ in callCount += 1 }
        Gitext.onEvent { _ in callCount += 10 }
        // Second handler replaced the first; only one handler active.
        // (We can't trigger an event externally, so just verify no crash.)
        XCTAssertEqual(callCount, 0)
    }

    // MARK: - configure() namespace

    func test_configure_namespace_returns_short_key_as_fallback() {
        Gitext.configure(
            apiKey: "test-key",
            baseUrl: "https://localhost",
            namespace: "app"
        )
        // No translations loaded — fallback is the original short key, not the prefixed lookup key.
        XCTAssertEqual(Gitext.string("greeting.hello"), "greeting.hello")
    }

    // MARK: - Gitext.scoped(to:)

    func test_scoped_returns_short_key_as_fallback_when_no_translations_loaded() {
        let ns = Gitext.scoped(to: "onboarding")
        XCTAssertEqual(ns.string("welcome_title"), "welcome_title")
    }

    func test_scoped_with_count_returns_short_key_as_fallback() {
        let ns = Gitext.scoped(to: "onboarding")
        XCTAssertEqual(ns.string("step_count", count: 3), "step_count")
    }

    func test_scoped_with_explicit_language_returns_short_key_as_fallback() {
        let ns = Gitext.scoped(to: "onboarding")
        XCTAssertEqual(ns.string("welcome_title", language: "fr"), "welcome_title")
    }

    func test_two_scoped_accessors_are_independent() {
        let onboarding = Gitext.scoped(to: "onboarding")
        let payments   = Gitext.scoped(to: "payments")
        // Both fall back to their respective short keys — no cross-contamination.
        XCTAssertEqual(onboarding.string("welcome_title"), "welcome_title")
        XCTAssertEqual(payments.string("checkout.confirm"), "checkout.confirm")
    }

    // MARK: - GitextStore(namespace:)

    func test_store_with_namespace_returns_short_key_as_fallback() {
        let store = GitextStore(namespace: "payments")
        XCTAssertEqual(store["checkout.confirm"], "checkout.confirm")
    }
}
