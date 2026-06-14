import CoreLocation
import Foundation

#if canImport(UIKit)
import UIKit
#endif

/// **[Enterprise]** Tamper-proof location audit trail manager on iOS.
///
/// This manager maintains a cryptographic SHA-256 hash chain over persisted location records.
/// By delegating hashing, canonical formatting, and verification tasks directly to the
/// shared Rust Core's `AuditTrailEngine`, we guarantee cross-platform cryptographic parity.
///
/// For chain validation, it reads the sequential cryptographic ledger from the `rustDatabase`
/// and matches each block's UUID with its corresponding spatial coordinates retrieved
/// from the native SQLite database.
public final class AuditTrailManager {
    private let configManager: ConfigManager
    private let rustDatabase: DatabaseManager?
    private let engine: AuditTrailEngine

    private let defaults = UserDefaults.standard
    private let prefsKey = "com.tracelet.audit"

    /// Serializes chain mutations. `appendToChain` is now reachable from both the
    /// foreground dispatch path and direct background persists, possibly on
    /// different threads, so the chain cursor must be updated atomically.
    private let chainLock = NSLock()

    /// Bump this version whenever the hashing logic changes.
    /// On init, if the stored version doesn't match, the chain is
    /// automatically reset so stale hashes don't cause false "broken" reports.
    // v4: audit links are now created at the single persistence chokepoint and
    // uuid-less records are no longer chained — reset any orphaned/incomplete
    // chains produced by the prior partial-coverage logic.
    private static let auditHashVersion = 4
    private static let auditHashVersionKey = "com.tracelet.audit.hashVersion"

    public init(configManager: ConfigManager, rustDatabase: DatabaseManager? = nil) {
        self.configManager = configManager
        self.rustDatabase = rustDatabase ?? (try? DatabaseManager(dbPath: ":memory:"))

        #if canImport(UIKit)
        let vendorId = UIDevice.current.identifierForVendor?.uuidString ?? "unknown-device"
        #else
        let vendorId = "mac-host-device"
        #endif

        // --- Migration: auto-reset chain if hash logic version changed ---
        let storedVersion = defaults.integer(forKey: Self.auditHashVersionKey)
        if storedVersion < Self.auditHashVersion {
            TraceletLog.debug("AuditTrailManager: hash logic upgraded (v\(storedVersion) → v\(Self.auditHashVersion)) — resetting chain")
            try? rustDatabase?.clearAuditTrail()
            let genesisHash = computeGenesisHash(deviceId: vendorId)
            defaults.set([
                "chain_index": 0,
                "latest_hash": genesisHash,
            ], forKey: prefsKey)
            defaults.set(Self.auditHashVersion, forKey: Self.auditHashVersionKey)
        }

        // Restore persisted chain state from local UserDefaults
        let prefs = defaults.dictionary(forKey: prefsKey) ?? [:]
        let savedIndex = (prefs["chain_index"] as? NSNumber)?.intValue ?? 0
        let savedHash = prefs["latest_hash"] as? String

        // Initialize the Rust AuditTrailEngine with the restored state
        self.engine = AuditTrailEngine(
            deviceId: vendorId,
            initialChainIndex: Int32(savedIndex),
            initialLatestHash: savedHash
        )
    }

    // MARK: - Public API

    /// Appends a location to the cryptographic audit chain.
    ///
    /// - Parameter locationMap: Flat or nested location properties.
    /// - Returns: Audit fields (hash, previous_hash, chain_index) to merge into the location map.
    public func appendToChain(_ locationMap: [String: Any]) -> [String: Any]? {
        guard configManager.getAuditEnabled() else { return nil }
        chainLock.lock()
        defer { chainLock.unlock() }

        // Standardize coordinates extraction supporting both flat and nested models
        let coords = locationMap["coords"] as? [String: Any]
        let lat = coords?["latitude"] as? Double ?? locationMap["latitude"] as? Double ?? 0.0
        let lng = coords?["longitude"] as? Double ?? locationMap["longitude"] as? Double ?? 0.0
        let altitude = coords?["altitude"] as? Double ?? locationMap["altitude"] as? Double ?? 0.0
        let speed = coords?["speed"] as? Double ?? locationMap["speed"] as? Double ?? -1.0
        let heading = coords?["heading"] as? Double ?? locationMap["heading"] as? Double ?? -1.0
        let accuracy = coords?["accuracy"] as? Double ?? locationMap["accuracy"] as? Double ?? -1.0

        // A record with no uuid cannot be looked up by getLocationForAudit during
        // verification, so chaining it would create an orphan audit row that
        // permanently breaks verifyChain ("missing location record"). Skip it —
        // mirrors the Android AuditTrailManager guard.
        guard let uuid = locationMap["uuid"] as? String, !uuid.isEmpty else {
            TraceletLog.debug("AuditTrailManager: appendToChain — no uuid, skipping")
            return nil
        }
        let timestamp = locationMap["timestamp"] as? String ?? ""
        // Odometer is not persisted in location_events, so we must hash it as 0.0 to match verifyChain
        let odometer = 0.0

        let activityDict = locationMap["activity"] as? [String: Any]
        let activityString = activityDict?["type"] as? String ?? "unknown"
        let isMoving = activityString != "still"

        // Reconstruct the LocationRecord FFI structure
        let loc = LocationRecord(
            uuid: uuid,
            latitude: lat,
            longitude: lng,
            timestamp: timestamp,
            accuracy: accuracy,
            speed: speed,
            heading: heading,
            altitude: altitude,
            isMoving: isMoving
        )

        TraceletLog.debug("AuditTrailManager: appendToChain [uuid=\(uuid), ts=\(timestamp), lat=\(lat), lng=\(lng), speed=\(speed), heading=\(heading), acc=\(accuracy), alt=\(altitude), isMoving=\(isMoving)]")

        // Delegate next hash generation to the Rust Core engine
        let result = engine.generateNextHash(loc: loc)

        // Write to the shared Rust Core SQLite engine
        do {
            try rustDatabase?.insertAuditTrail(
                uuid: uuid,
                hash: result.hash,
                prevHash: result.previousHash,
                index: result.chainIndex
            )
        } catch {
            TraceletLog.error("AuditTrailManager: Failed to write audit trail to Rust Core DB: \(error)")
        }

        // Persist the updated chain cursor locally
        persistChainState(chainIndex: Int(result.chainIndex), latestHash: result.hash)

        return [
            "audit_hash": result.hash,
            "audit_previous_hash": result.previousHash,
            "audit_chain_index": Int(result.chainIndex),
        ]
    }

    /// Verifies the cryptographic integrity of the entire audit chain.
    /// Walks all blocks sequentially, matches coordinates by UUID from the native database,
    /// and compares hashes using the Rust [AuditTrailEngine].
    public func verifyChain() -> [String: Any] {
        let auditRecords = (try? rustDatabase?.getAuditTrail()) ?? []

        if auditRecords.isEmpty {
            return [
                "is_valid": true,
                "total_records": 0,
                "verified_records": 0,
            ]
        }

        // Map audit blocks to AuditRecordWithLocation structures
        let rustRecords = auditRecords.map { auditRecord -> AuditRecordWithLocation in
            let uuid = auditRecord.uuid
            let location = try? rustDatabase?.getLocationForAudit(uuid: uuid)
            let hasLocation = location != nil

            let loc: LocationRecord?
            if let flat = location {
                let isMoving = flat.activity != "still" // Deriving motion state from activity

                loc = LocationRecord(
                    uuid: uuid,
                    latitude: flat.latitude,
                    longitude: flat.longitude,
                    timestamp: flat.timestamp,
                    accuracy: flat.accuracy,
                    speed: flat.speed,
                    heading: flat.heading,
                    altitude: flat.altitude,
                    isMoving: isMoving
                )
            } else {
                loc = nil
            }

            return AuditRecordWithLocation(
                hash: auditRecord.auditHash,
                previousHash: auditRecord.auditPreviousHash,
                chainIndex: auditRecord.auditChainIndex,
                hasLocation: hasLocation,
                location: loc
            )
        }

        // Run full cryptographic chain audit verification in Rust Core
        let result = engine.verifyChain(records: rustRecords)

        TraceletLog.debug("AuditTrailManager: Full Audit Trail Dump:")
        for record in rustRecords {
            if let loc = record.location {
                TraceletLog.debug("AuditTrailManager: Record [index=\(record.chainIndex), uuid=\(loc.uuid), hash=\(record.hash), prevHash=\(record.previousHash), ts=\(loc.timestamp), speed=\(loc.speed), heading=\(loc.heading), acc=\(loc.accuracy), isMoving=\(loc.isMoving)]")
            } else {
                TraceletLog.debug("AuditTrailManager: Record [index=\(record.chainIndex), NO LOCATION, hash=\(record.hash), prevHash=\(record.previousHash)]")
            }
        }

        var map: [String: Any] = [
            "is_valid": result.isValid,
            "total_records": result.totalRecords,
            "verified_records": result.verifiedRecords,
        ]
        if let brokenIdx = result.brokenAtIndex {
            map["broken_at_index"] = Int(brokenIdx)
        }
        if let brokenUuid = result.brokenAtUuid {
            map["broken_at_uuid"] = brokenUuid
        }
        if let err = result.error {
            map["error"] = err
        }

        TraceletLog.debug("AuditTrailManager: verifyChain result: \(map)")

        return map
    }

    /// Returns the audit proof for a specific location UUID.
    /// Pairs the DB block properties with the location coordinates retrieved by UUID.
    public func getProof(uuid: String) -> [String: Any]? {
        let auditRecords = (try? rustDatabase?.getAuditTrail()) ?? []
        guard let matchedRecord = auditRecords.first(where: { $0.uuid == uuid }) else { return nil }
        let location = try? rustDatabase?.getLocationForAudit(uuid: uuid)

        return [
            "uuid": matchedRecord.uuid,
            "hash": matchedRecord.auditHash,
            "previous_hash": matchedRecord.auditPreviousHash,
            "chain_index": Int(matchedRecord.auditChainIndex),
            "timestamp": location?.timestamp ?? "",
            "latitude": location?.latitude ?? 0.0,
            "longitude": location?.longitude ?? 0.0,
            "accuracy": location?.accuracy ?? 0.0,
            "speed": location?.speed ?? 0.0,
            "heading": location?.heading ?? 0.0,
            "altitude": location?.altitude ?? 0.0,
        ]
    }

    /// Resets the cryptographic chain state and clears local logs.
    public func reset() {
        try? rustDatabase?.clearAuditTrail()
        engine.resetState()
        
        let vendorId = UIDevice.current.identifierForVendor?.uuidString ?? "unknown-device"
        let genesisHash = computeGenesisHash(deviceId: vendorId)
        
        persistChainState(chainIndex: 0, latestHash: genesisHash)
    }

    // MARK: - Internals

    /// Local cache persistence for chain states.
    private func persistChainState(chainIndex: Int, latestHash: String) {
        defaults.set([
            "chain_index": chainIndex,
            "latest_hash": latestHash,
        ], forKey: prefsKey)
    }
}
