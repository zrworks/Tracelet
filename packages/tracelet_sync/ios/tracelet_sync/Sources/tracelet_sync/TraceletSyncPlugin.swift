import Flutter
import UIKit
import TraceletSDK

actor SyncCoordinator {
    private var isSyncing = false
    private var syncTask: Task<Void, Never>?
    
    func scheduleSync() {
        let delayMs = TraceletSdk.shared.rustEngineState?.getConfig().http.autoSyncDelay ?? 10000
        let delayNanos = UInt64(delayMs) * 1_000_000
        
        if syncTask != nil { return }
        
        // CRITICAL FIX: Explicitly request background execution time.
        // Without this, iOS will suspend the app immediately after the location event completes,
        // preventing the HTTP sync task from ever firing.
        let bgTaskId = BackgroundTaskHelper.shared.begin("tracelet_sync_task")
        
        syncTask = Task {
            try? await Task.sleep(nanoseconds: delayNanos)
            self.syncTask = nil
            await self.triggerSync()
            BackgroundTaskHelper.shared.end(bgTaskId)
        }
    }
    
    func triggerSync() async {
        guard !isSyncing else { return }
        isSyncing = true
        defer { isSyncing = false }
        
        guard let db = TraceletSdk.shared.rustDatabase,
              let state = TraceletSdk.shared.rustEngineState else {
            return
        }
        
        do {
            let coreHttp = state.getConfig().http
            
            // 1. Request Fresh Headers
            let interceptor = TraceletSdk.shared.dartSyncInterceptor
            if interceptor?.requestFreshHeaders() == true {
                NSLog("[TraceletSync] Headers refreshed via Dart interceptor")
            }
            
            let updatedHttp = state.getConfig().http
            guard let url = updatedHttp.url, !url.isEmpty else { return }
            guard updatedHttp.autoSync else { return }
            
            NSLog("[TraceletSync] Triggering sync to URL: \(url)")
            
            let limit: Int32 = updatedHttp.maxBatchSize > 0 ? updatedHttp.maxBatchSize : 250
            let coreRecords = try db.getLocationsBatch(query: LocationQuery(
                startTimeMs: nil,
                endTimeMs: nil,
                limit: limit,
                offset: nil,
                orderDescending: nil
            ))
            NSLog("[TraceletSync] Found \(coreRecords.count) locations in DB.")
            if coreRecords.isEmpty { return }
            
            let syncRecords: [tracelet_sync.SyncLocationRecord] = coreRecords.map { r in
                tracelet_sync.SyncLocationRecord(
                    id: r.id,
                    uuid: r.uuid,
                    timestamp: r.timestamp,
                    latitude: r.latitude,
                    longitude: r.longitude,
                    accuracy: r.accuracy,
                    speed: r.speed,
                    heading: r.heading,
                    altitude: r.altitude,
                    isMock: r.isMock,
                    activity: r.activity,
                    routeContext: r.routeContext
                )
            }
            
            let syncRecordsMap: [[String: Any]] = coreRecords.map { r in
                var dict: [String: Any] = [
                    "timestamp": r.timestamp,
                    "latitude": r.latitude,
                    "longitude": r.longitude,
                    "accuracy": r.accuracy,
                    "speed": r.speed,
                    "heading": r.heading,
                    "altitude": r.altitude,
                    "isMock": r.isMock,
                    "activity": r.activity
                ]
                if let uuid = r.uuid { dict["uuid"] = uuid }
                if let routeContext = r.routeContext { dict["routeContext"] = routeContext }
                return dict
            }
            
            NSLog("[TraceletSync] interceptor is \(interceptor == nil ? "nil" : "NOT nil")")

            if interceptor == nil {
                let _ = await executeFallbackHttpSync(coreHttp: updatedHttp, customBody: "{\"error\": \"INTERCEPTOR_IS_NIL\"}", interceptor: nil)
            } else if let customBody = interceptor?.requestSyncBody(locations: syncRecordsMap) {
                NSLog("[TraceletSync] customBody from interceptor: \(customBody)")
                let success = await executeFallbackHttpSync(coreHttp: updatedHttp, customBody: customBody, interceptor: interceptor)
                if success {
                    if let lastId = coreRecords.last?.id {
                        try? db.clearLocationsUpTo(maxId: lastId)
                        NSLog("[TraceletSync] Synced and cleared \(coreRecords.count) locations via custom body fallback.")
                    }
                    TraceletSdk.shared.getEventSender().sendHttp([
                        "success": true,
                        "status": 200,
                        "responseText": "Synced \(coreRecords.count) locations via custom body",
                        "isRetry": false,
                        "retryCount": 0
                    ])
                } else {
                    NSLog("[TraceletSync] Custom body sync failed")
                    TraceletSdk.shared.getEventSender().sendHttp([
                        "success": false,
                        "status": 0,
                        "responseText": "Custom body sync failed",
                        "isRetry": false,
                        "retryCount": 0
                    ])
                }
                return
            }

            let syncHttp = tracelet_sync.SyncHttpConfig(
                url: updatedHttp.url,
                method: updatedHttp.method,
                headers: updatedHttp.headers,
                batchSync: updatedHttp.batchSync,
                maxBatchSize: updatedHttp.maxBatchSize,
                autoSync: updatedHttp.autoSync,
                maxRetries: updatedHttp.maxRetries,
                retryBackoffBase: updatedHttp.retryBackoffBase,
                retryBackoffCap: updatedHttp.retryBackoffCap,
                sslPinningCertificates: updatedHttp.sslPinningCertificates,
                sslPinningFingerprints: updatedHttp.sslPinningFingerprints,
                httpRootProperty: updatedHttp.httpRootProperty,
                params: updatedHttp.params,
                extras: updatedHttp.extras,
                disableAutoSyncOnCellular: updatedHttp.disableAutoSyncOnCellular,
                enableDeltaCompression: updatedHttp.enableDeltaCompression,
                deltaCoordinatePrecision: updatedHttp.deltaCoordinatePrecision,
                locationsOrderDirection: updatedHttp.locationsOrderDirection
            )
            
            let syncManager = SyncManager()
            
            // OFF-LOAD TO GCD THREAD SO IT DOESN'T BLOCK SWIFT CONCURRENCY THREAD POOL
            let count = try await withCheckedThrowingContinuation { continuation in
                DispatchQueue.global(qos: .utility).async {
                    do {
                        let c = try syncManager.syncBatchBlocking(config: syncHttp, records: syncRecords)
                        continuation.resume(returning: c)
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
            
            if count > 0, let lastId = coreRecords.last?.id {
                try db.clearLocationsUpTo(maxId: lastId)
                NSLog("[TraceletSync] Synced and cleared \(count) locations.")
                TraceletSdk.shared.getEventSender().sendHttp([
                    "success": true,
                    "status": 200,
                    "responseText": "Synced \(count) locations",
                    "isRetry": false,
                    "retryCount": 0
                ])
            } else {
                NSLog("[TraceletSync] No locations synced or count was 0.")
            }
        } catch {
            NSLog("[TraceletSync] Sync failed with error: \(error)")
            TraceletSdk.shared.getEventSender().sendHttp([
                "success": false,
                "status": 0,
                "responseText": error.localizedDescription,
                "isRetry": false,
                "retryCount": 0
            ])
        }
    }

    func executeFallbackHttpSync(coreHttp: HttpConfig, customBody: String, interceptor: DartSyncInterceptor?) async -> Bool {
        var currentHeaders = coreHttp.headers
        let maxRetries = Int(coreHttp.maxRetries)
        
        for attempt in 0...maxRetries {
            guard let urlStr = coreHttp.url, let url = URL(string: urlStr) else { return false }
            
            var request = URLRequest(url: url)
            request.httpMethod = coreHttp.method == 1 ? "PUT" : "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.timeoutInterval = 15.0
            
            for (k, v) in currentHeaders {
                request.setValue(v, forHTTPHeaderField: k)
            }
            
            request.httpBody = customBody.data(using: .utf8)
            
            do {
                let (_, response) = try await URLSession.shared.data(for: request)
                if let httpResponse = response as? HTTPURLResponse {
                    if (200...299).contains(httpResponse.statusCode) {
                        return true
                    } else if httpResponse.statusCode == 401, let interceptor = interceptor {
                        if interceptor.requestTokenRefresh() {
                            if let newConfig = TraceletSdk.shared.rustEngineState?.getConfig().http {
                                currentHeaders = newConfig.headers
                            }
                            continue
                        }
                    }
                }
            } catch {
                NSLog("[TraceletSync] Fallback sync error: \(error)")
            }
            
            if attempt < maxRetries {
                try? await Task.sleep(nanoseconds: UInt64(1_000_000_000 * (attempt + 1)))
            }
        }
        return false
    }
}

class TraceletSyncSink: LocationDataSink, SyncProvider {
    let coordinator = SyncCoordinator()
    
    @discardableResult
    func insertLocation(_ location: [String: Any]) -> String {
        Task {
            await coordinator.scheduleSync()
        }
        return ""
    }
    
    func syncBatchBlocking(config: HttpConfig, records: [DbLocationRecord]) throws -> UInt32 {
        let syncRecords: [tracelet_sync.SyncLocationRecord] = records.map { r in
            tracelet_sync.SyncLocationRecord(
                id: r.id,
                uuid: r.uuid,
                timestamp: r.timestamp,
                latitude: r.latitude,
                longitude: r.longitude,
                accuracy: r.accuracy,
                speed: r.speed,
                heading: r.heading,
                altitude: r.altitude,
                isMock: r.isMock,
                activity: r.activity,
                routeContext: r.routeContext
            )
        }
        
        // INTERCEPTOR LOGIC
        if let interceptor = TraceletSdk.shared.dartSyncInterceptor {
            if interceptor.requestFreshHeaders() {
                NSLog("[TraceletSync] Headers refreshed in syncBatchBlocking")
            }
            let updatedHttp = TraceletSdk.shared.rustEngineState?.getConfig().http ?? config
            
            let syncRecordsMap: [[String: Any]] = records.map { r in
                var dict: [String: Any] = [
                    "timestamp": r.timestamp,
                    "latitude": r.latitude,
                    "longitude": r.longitude,
                    "accuracy": r.accuracy,
                    "speed": r.speed,
                    "heading": r.heading,
                    "altitude": r.altitude,
                    "isMock": r.isMock,
                    "activity": r.activity
                ]
                if let uuid = r.uuid { dict["uuid"] = uuid }
                if let routeContext = r.routeContext { dict["routeContext"] = routeContext }
                return dict
            }
            
            if let customBody = interceptor.requestSyncBody(locations: syncRecordsMap) {
                NSLog("[TraceletSync] customBody from interceptor (syncBatchBlocking): \(customBody)")
                let sem = DispatchSemaphore(value: 0)
                var fallbackSuccess = false
                
                Task {
                    fallbackSuccess = await coordinator.executeFallbackHttpSync(coreHttp: updatedHttp, customBody: customBody, interceptor: interceptor)
                    sem.signal()
                }
                
                sem.wait()
                
                if fallbackSuccess {
                    return UInt32(records.count)
                } else {
                    NSLog("[TraceletSync] Custom body sync failed in syncBatchBlocking")
                    return 0
                }
            }
        }

        let syncHttp = tracelet_sync.SyncHttpConfig(
            url: config.url,
            method: config.method,
            headers: config.headers,
            batchSync: config.batchSync,
            maxBatchSize: config.maxBatchSize,
            autoSync: config.autoSync,
            maxRetries: config.maxRetries,
            retryBackoffBase: config.retryBackoffBase,
            retryBackoffCap: config.retryBackoffCap,
            sslPinningCertificates: config.sslPinningCertificates,
            sslPinningFingerprints: config.sslPinningFingerprints,
            httpRootProperty: config.httpRootProperty,
            params: config.params,
            extras: config.extras,
            disableAutoSyncOnCellular: config.disableAutoSyncOnCellular,
            enableDeltaCompression: config.enableDeltaCompression,
            deltaCoordinatePrecision: config.deltaCoordinatePrecision,
            locationsOrderDirection: config.locationsOrderDirection
        )
        
        let syncManager = SyncManager()
        return try syncManager.syncBatchBlocking(config: syncHttp, records: syncRecords)
    }
}

@objc(TraceletSyncPlugin)
public class TraceletSyncPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "tracelet_sync", binaryMessenger: registrar.messenger())
    let instance = TraceletSyncPlugin()
    
    TraceletSyncFFIDummy.enforceBundling()
    
    let sink = TraceletSyncSink()
    TraceletSdk.shared.locationEngine.registerSink(sink)
    TraceletSdk.shared.syncProvider = sink
    print("TraceletSync: Native iOS sink registered!")

    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    if call.method == "initialize" {
      result(true)
    } else {
      result(FlutterMethodNotImplemented)
    }
  }
}
