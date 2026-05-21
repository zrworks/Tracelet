import XCTest
@testable import tracelet_ios

final class TraceletHostApiImplTests: XCTestCase {
    
    // We can expose the private method using Swift reflection or just changing it to internal,
    // but the easiest way to test a private method in Swift without changing access modifiers
    // is using `@testable import tracelet_ios` if it was internal.
    // Let's modify TraceletHostApiImpl.swift to make `intToAuthStatus` internal instead of private
    // so we can test it directly!
    
    func testIntToAuthStatusMapping() throws {
        // Issue 80 fix test for iOS
        let headlessRunner = HeadlessRunner()
        let hostApi = TraceletHostApiImpl(headlessRunner: headlessRunner)
        
        // This relies on `intToAuthStatus` being internal
        XCTAssertEqual(hostApi.intToAuthStatus(0), .notDetermined)
        XCTAssertEqual(hostApi.intToAuthStatus(1), .denied)
        XCTAssertEqual(hostApi.intToAuthStatus(2), .whenInUse)
        XCTAssertEqual(hostApi.intToAuthStatus(3), .always)
        XCTAssertEqual(hostApi.intToAuthStatus(4), .deniedForever)
    }
}
