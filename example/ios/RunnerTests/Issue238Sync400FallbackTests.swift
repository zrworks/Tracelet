import XCTest
@testable import tracelet_sync
@testable import TraceletSDK

private final class MockURLProtocol: URLProtocol {
    static var requestHandler: ((URLRequest) -> (Int, String))?

    override class func canInit(with request: URLRequest) -> Bool { return true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { return request }

    override func startLoading() {
        let (statusCode, body) = MockURLProtocol.requestHandler?(request) ?? (200, "{\"ok\":true}")
        let response = HTTPURLResponse(url: request.url!, statusCode: statusCode, httpVersion: "HTTP/1.1", headerFields: nil)!
        let data = body.data(using: .utf8)!
        
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

final class Issue238Sync400FallbackTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        URLProtocol.registerClass(MockURLProtocol.self)
    }
    
    override func tearDown() {
        URLProtocol.unregisterClass(MockURLProtocol.self)
        MockURLProtocol.requestHandler = nil
        super.tearDown()
    }
    
    func testExecuteFallbackHttpSync_Returns400FallbackResult() async {
        let coordinator = SyncCoordinator()
        
        MockURLProtocol.requestHandler = { _ in
            return (400, "Bad Request")
        }
        
        let coreHttp = HttpConfig(
            url: "http://127.0.0.1:8080/sync",
            method: 0,
            headers: [:],
            batchSync: true,
            maxBatchSize: 100,
            autoSync: true,
            autoSyncDelay: 10000,
            maxRetries: 0,
            retryBackoffBase: 1000,
            retryBackoffCap: 10000,
            sslPinningCertificates: [],
            sslPinningFingerprints: [],
            httpRootProperty: "locations",
            params: [:],
            extras: [:],
            disableAutoSyncOnCellular: false,
            enableDeltaCompression: false,
            deltaCoordinatePrecision: 5,
            locationsOrderDirection: 0
        )
        
        let result = await coordinator.executeFallbackHttpSync(
            coreHttp: coreHttp,
            customBody: "{\"custom\":true}",
            interceptor: nil
        )
        
        XCTAssertFalse(result.success)
        XCTAssertEqual(result.status, 400)
        XCTAssertEqual(result.responseText, "Bad Request")
    }
}
