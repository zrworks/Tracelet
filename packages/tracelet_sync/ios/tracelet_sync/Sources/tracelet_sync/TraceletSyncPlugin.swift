import Flutter
import UIKit
import TraceletSDK

actor SyncCoordinator {
    private var isSyncing = false
    private var syncTask: Task<Void, Never>?
    
    func scheduleSync(sink: TraceletSyncSink) {
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
            await self.triggerSync(sink: sink)
            BackgroundTaskHelper.shared.end(bgTaskId)
        }
    }
    
    func triggerSync(sink: TraceletSyncSink) async {
        guard !isSyncing else { return }
        isSyncing = true
        defer { isSyncing = false }
        
        guard let db = TraceletSdk.shared.rustDatabase,
              let state = TraceletSdk.shared.rustEngineState else {
            return
        }
        
        do {
            let updatedHttp = state.getConfig().http
            guard let url = updatedHttp.url, !url.isEmpty else { return }
            guard updatedHttp.autoSync else { return }
            
            TraceletSdk.shared.logger.debug("Triggering sync to URL: \(url)")
            
            let limit: Int32 = updatedHttp.maxBatchSize > 0 ? updatedHttp.maxBatchSize : 250
            let coreRecords = try db.getLocationsBatch(query: LocationQuery(
                startTimeMs: nil,
                endTimeMs: nil,
                limit: limit,
                offset: nil,
                orderDescending: nil
            ))
            TraceletSdk.shared.logger.debug("Found \(coreRecords.count) locations in DB.")
            if coreRecords.isEmpty { return }
            
            // CRITICAL FIX: Offload the synchronous blocking FFI call to a background 
            // DispatchQueue so we do not starve the Swift Concurrency cooperative thread pool.
            let count = try await withCheckedThrowingContinuation { continuation in
                DispatchQueue.global(qos: .utility).async {
                    do {
                        let result = try sink.syncBatchBlocking(config: updatedHttp, records: coreRecords)
                        continuation.resume(returning: result)
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
            
            if count > 0, let lastId = coreRecords.last?.id {
                try db.clearLocationsUpTo(maxId: lastId)
                TraceletSdk.shared.logger.debug("Synced and cleared \(count) locations.")
            } else {
                TraceletSdk.shared.logger.debug("No locations synced or count was 0.")
            }
        } catch {
            TraceletSdk.shared.logger.debug("Sync failed with error: \(error)")
        }
    }

    // `nonisolated` is required: this is awaited from a `Task` while
    // `syncBatchBlocking` blocks the actor's executor on a semaphore during the
    // auto-sync path. If it were actor-isolated, that Task could never enter the
    // (blocked) actor and the semaphore would never be signaled — a deadlock
    // that silently killed custom-body auto-sync on iOS. It touches no actor
    // state, so isolation is unnecessary.
    nonisolated func executeFallbackHttpSync(coreHttp: HttpConfig, customBody: String, interceptor: DartSyncInterceptor?) async -> Bool {
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
                TraceletSdk.shared.logger.debug("Fallback sync error: \(error)")
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
            await coordinator.scheduleSync(sink: self)
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
                isMoving: r.isMoving,
                activity: r.activity,
                event: r.eventType,
                routeContext: r.routeContext
            )
        }
        
        // INTERCEPTOR LOGIC
        if let interceptor = TraceletSdk.shared.dartSyncInterceptor {
            if interceptor.requestFreshHeaders() {
                TraceletSdk.shared.logger.debug("Headers refreshed in syncBatchBlocking")
            }
            let updatedHttp = TraceletSdk.shared.rustEngineState?.getConfig().http ?? config
            
            // Issue #126: emit the SAME nested schema as onLocation/getLocations
            // (nested coords/activity/battery + route_context) so the Dart
            // custom-body builder receives a consistent shape instead of a flat
            // map with a raw String activity.
            let syncRecordsMap: [[String: Any]] = records.map {
                TraceletSdk.shared.mapRecordToLocation($0)
            }
            
            let customBody = interceptor.requestSyncBody(locations: syncRecordsMap)
            if customBody == nil {
                // A builder is registered but it timed out or threw.
                // requestSyncBody returns the sentinel (not nil) when no builder
                // exists, so nil here unambiguously means failure: abort the sync
                // rather than posting an error object or the default payload.
                TraceletSdk.shared.logger.error("Custom sync body failed to build; aborting sync.")
                TraceletSdk.shared.getEventSender().sendHttp([
                    "success": false,
                    "status": 0,
                    "responseText": "custom sync body failed to build",
                    "isRetry": false,
                    "retryCount": 0
                ])
                return 0
            }
            if let body = customBody, body != traceletNoSyncBodyBuilderSentinel {
                TraceletSdk.shared.logger.debug("customBody from interceptor (syncBatchBlocking): \(body)")
                let sem = DispatchSemaphore(value: 0)
                var fallbackSuccess = false

                Task {
                    fallbackSuccess = await coordinator.executeFallbackHttpSync(coreHttp: updatedHttp, customBody: body, interceptor: interceptor)
                    sem.signal()
                }

                sem.wait()

                if fallbackSuccess {
                    TraceletSdk.shared.getEventSender().sendHttp([
                        "success": true,
                        "status": 200,
                        "responseText": "Synced \(records.count) locations via custom body",
                        "isRetry": false,
                        "retryCount": 0
                    ])
                    return UInt32(records.count)
                } else {
                    TraceletSdk.shared.logger.debug("Custom body sync failed in syncBatchBlocking")
                    TraceletSdk.shared.getEventSender().sendHttp([
                        "success": false,
                        "status": 0,
                        "responseText": "Custom body sync failed",
                        "isRetry": false,
                        "retryCount": 0
                    ])
                    return 0
                }
            }
            // sentinel → no builder → fall through to the default sync below.
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
        do {
            let count = try syncManager.syncBatchBlocking(config: syncHttp, records: syncRecords)
            if count > 0 {
                TraceletSdk.shared.getEventSender().sendHttp([
                    "success": true,
                    "status": 200,
                    "responseText": "Synced \(count) locations",
                    "isRetry": false,
                    "retryCount": 0
                ])
            } else {
                TraceletSdk.shared.getEventSender().sendHttp([
                    "success": false,
                    "status": 0,
                    "responseText": "Sync failed",
                    "isRetry": false,
                    "retryCount": 0
                ])
            }
            return count
        } catch {
            TraceletSdk.shared.getEventSender().sendHttp([
                "success": false,
                "status": 0,
                "responseText": error.localizedDescription,
                "isRetry": false,
                "retryCount": 0
            ])
            throw error
        }
    }
}

@objc(TraceletSyncPlugin)
public class TraceletSyncPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "tracelet_sync", binaryMessenger: registrar.messenger())
    let instance = TraceletSyncPlugin()
    
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
