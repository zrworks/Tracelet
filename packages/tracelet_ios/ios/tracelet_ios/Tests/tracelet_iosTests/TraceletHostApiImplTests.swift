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

    func testRegisterHeadlessHeadersCallback_delegatesToService() {
        let headlessRunner = HeadlessRunner()
        let hostApi = TraceletHostApiImpl(headlessRunner: headlessRunner)
        
        let defaults = UserDefaults.standard
        defaults.set(0, forKey: HeadlessRunner.CallbackType.headers.regKey)
        defaults.set(0, forKey: HeadlessRunner.CallbackType.headers.dispatchKey)
        
        let expectation = XCTestExpectation(description: "completion")
        hostApi.registerHeadlessHeadersCallback(callbackIds: [100, 200]) { _ in
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
        
        XCTAssertEqual(defaults.integer(forKey: HeadlessRunner.CallbackType.headers.regKey), 100)
        XCTAssertEqual(defaults.integer(forKey: HeadlessRunner.CallbackType.headers.dispatchKey), 200)
    }

    func testRegisterHeadlessSyncBodyBuilder_delegatesToService() {
        let headlessRunner = HeadlessRunner()
        let hostApi = TraceletHostApiImpl(headlessRunner: headlessRunner)
        
        let defaults = UserDefaults.standard
        defaults.set(0, forKey: HeadlessRunner.CallbackType.syncBody.regKey)
        defaults.set(0, forKey: HeadlessRunner.CallbackType.syncBody.dispatchKey)
        
        let expectation = XCTestExpectation(description: "completion")
        hostApi.registerHeadlessSyncBodyBuilder(callbackIds: [300, 400]) { _ in
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
        
        XCTAssertEqual(defaults.integer(forKey: HeadlessRunner.CallbackType.syncBody.regKey), 300)
        XCTAssertEqual(defaults.integer(forKey: HeadlessRunner.CallbackType.syncBody.dispatchKey), 400)
    }
}
