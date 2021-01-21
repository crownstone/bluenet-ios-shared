import XCTest
@testable import bluenet_ios_shared

final class bluenet_ios_sharedTests: XCTestCase {
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct
        // results.
        XCTAssertEqual(bluenet_ios_shared().text, "Hello, World!")
    }

    static var allTests = [
        ("testExample", testExample),
    ]
}
