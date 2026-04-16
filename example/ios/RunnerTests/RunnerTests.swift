import Flutter
import UIKit
import XCTest


@testable import tracelet_ios
@testable import TraceletSDK

// This demonstrates a simple unit test of the Swift portion of this plugin's implementation.
//
// See https://developer.apple.com/documentation/xctest for more information about using XCTest.

class RunnerTests: XCTestCase {

  func testPluginRegistersWithoutCrash() {
    // Verify TraceletIosPlugin can be instantiated.
    let plugin = TraceletIosPlugin()
    XCTAssertNotNil(plugin)
  }

}
