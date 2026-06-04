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
            guard let url = coreHttp.url, !url.isEmpty else { return }
            guard coreHttp.autoSync else { return }
            
            NSLog("[TraceletSync] Triggering sync to URL: \(url)")
            
            let limit: Int32 = coreHttp.maxBatchSize > 0 ? coreHttp.maxBatchSize : 250
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
            
            let syncHttp = tracelet_sync.SyncHttpConfig(
                url: coreHttp.url,
                method: coreHttp.method,
                headers: coreHttp.headers,
                batchSync: coreHttp.batchSync,
                maxBatchSize: coreHttp.maxBatchSize,
                autoSync: coreHttp.autoSync,
                maxRetries: coreHttp.maxRetries,
                retryBackoffBase: coreHttp.retryBackoffBase,
                retryBackoffCap: coreHttp.retryBackoffCap,
                sslPinningCertificates: coreHttp.sslPinningCertificates,
                httpRootProperty: coreHttp.httpRootProperty,
                params: coreHttp.params,
                extras: coreHttp.extras,
                disableAutoSyncOnCellular: coreHttp.disableAutoSyncOnCellular,
                enableDeltaCompression: coreHttp.enableDeltaCompression,
                deltaCoordinatePrecision: coreHttp.deltaCoordinatePrecision,
                locationsOrderDirection: coreHttp.locationsOrderDirection
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
