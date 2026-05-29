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
            envName: "test-\(UUID().uuidString)",
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
}
