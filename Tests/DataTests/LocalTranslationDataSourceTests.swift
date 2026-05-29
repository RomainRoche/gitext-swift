import XCTest
@testable import Data

final class LocalTranslationDataSourceTests: XCTestCase {

    private var source: LocalTranslationDataSource!
    private let envName = "test-\(UUID().uuidString)"

    override func setUp() {
        source = LocalTranslationDataSource(envName: envName)
    }

    override func tearDown() {
        source.clear()
    }

    func test_write_then_read_roundtrip() throws {
        let dto: TranslationPayloadDTO = ["en": ["key": .string("value")]]
        source.write(dto)
        let loaded = source.read()
        XCTAssertEqual(loaded?["en"]?["key"], .string("value"))
    }

    func test_clear_removes_cache() {
        let dto: TranslationPayloadDTO = ["en": ["key": .string("value")]]
        source.write(dto)
        source.clear()
        XCTAssertNil(source.read())
    }

    func test_modification_date_set_after_write() {
        source.write(["en": ["key": .string("value")]])
        XCTAssertNotNil(source.modificationDate())
    }

    func test_modification_date_nil_before_write() {
        XCTAssertNil(source.modificationDate())
    }

    func test_read_returns_nil_when_empty() {
        XCTAssertNil(source.read())
    }
}
