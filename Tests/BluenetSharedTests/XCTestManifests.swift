import XCTest

#if !canImport(ObjectiveC)
public func allTests() -> [XCTestCaseEntry] {
    return [
        testCase(bluenet_ios_sharedTests.allTests),
    ]
}
#endif
