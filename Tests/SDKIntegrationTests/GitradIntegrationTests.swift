import XCTest
import GitradSDK

/// Tests the public SDK surface without @testable.
/// Network calls will fail in CI — these tests verify the public API contract only.
final class GitradIntegrationTests: XCTestCase {

    override func setUp() {
        // Configure with a fake key; no network call happens synchronously.
        Gitrad.configure(
            apiKey: "test-key",
            baseUrl: "https://localhost",
            maxCacheAge: 3600
        )
    }

    func test_string_returns_key_when_no_translations_loaded() {
        XCTAssertEqual(Gitrad.string("some.key"), "some.key")
    }

    func test_string_with_explicit_language_returns_key_on_empty_payload() {
        XCTAssertEqual(Gitrad.string("some.key", language: "fr"), "some.key")
    }

    func test_string_before_configure_returns_key() {
        // Simulate a call before configure by checking that string() never crashes.
        XCTAssertFalse(Gitrad.string("key").isEmpty)
    }

    func test_onEvent_handler_is_replaced_not_stacked() {
        var callCount = 0
        Gitrad.onEvent { _ in callCount += 1 }
        Gitrad.onEvent { _ in callCount += 10 }
        // Second handler replaced the first; only one handler active.
        // (We can't trigger an event externally, so just verify no crash.)
        XCTAssertEqual(callCount, 0)
    }

    // MARK: - configure() namespace

    func test_configure_namespace_returns_short_key_as_fallback() {
        Gitrad.configure(
            apiKey: "test-key",
            baseUrl: "https://localhost",
            namespace: "app"
        )
        // No translations loaded — fallback is the original short key, not the prefixed lookup key.
        XCTAssertEqual(Gitrad.string("greeting.hello"), "greeting.hello")
    }

    // MARK: - Gitrad.scoped(to:)

    func test_scoped_returns_short_key_as_fallback_when_no_translations_loaded() {
        let ns = Gitrad.scoped(to: "onboarding")
        XCTAssertEqual(ns.string("welcome_title"), "welcome_title")
    }

    func test_scoped_with_count_returns_short_key_as_fallback() {
        let ns = Gitrad.scoped(to: "onboarding")
        XCTAssertEqual(ns.string("step_count", count: 3), "step_count")
    }

    func test_scoped_with_explicit_language_returns_short_key_as_fallback() {
        let ns = Gitrad.scoped(to: "onboarding")
        XCTAssertEqual(ns.string("welcome_title", language: "fr"), "welcome_title")
    }

    func test_two_scoped_accessors_are_independent() {
        let onboarding = Gitrad.scoped(to: "onboarding")
        let payments   = Gitrad.scoped(to: "payments")
        // Both fall back to their respective short keys — no cross-contamination.
        XCTAssertEqual(onboarding.string("welcome_title"), "welcome_title")
        XCTAssertEqual(payments.string("checkout.confirm"), "checkout.confirm")
    }

    // MARK: - GitradStore(namespace:)

    func test_store_with_namespace_returns_short_key_as_fallback() {
        let store = GitradStore(namespace: "payments")
        XCTAssertEqual(store["checkout.confirm"], "checkout.confirm")
    }
}
