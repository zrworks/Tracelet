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
    private let database: TraceletDatabase
    private let configManager: ConfigManager
    private let rustDatabase: DatabaseManager?
    private let engine: AuditTrailEngine

    private let defaults = UserDefaults.standard
    private let prefsKey = "com.tracelet.audit"

    public init(database: TraceletDatabase, configManager: ConfigManager, rustDatabase: DatabaseManager? = nil) {
        self.database = database
        self.configManager = configManager
        self.rustDatabase = rustDatabase ?? (try? DatabaseManager(dbPath: ":memory:"))

        // Restore persisted chain state from local UserDefaults
        let prefs = defaults.dictionary(forKey: prefsKey) ?? [:]
        let savedIndex = (prefs["chain_index"] as? NSNumber)?.intValue ?? 0
        let savedHash = prefs["latest_hash"] as? String

        #if canImport(UIKit)
        let vendorId = UIDevice.current.identifierForVendor?.uuidString ?? "unknown-device"
        #else
        let vendorId = "mac-host-device"
        #endif

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

        // Standardize coordinates extraction supporting both flat and nested models
        let coords = locationMap["coords"] as? [String: Any]
        let lat = coords?["latitude"] as? Double ?? locationMap["latitude"] as? Double ?? 0.0
        let lng = coords?["longitude"] as? Double ?? locationMap["longitude"] as? Double ?? 0.0
        let altitude = coords?["altitude"] as? Double ?? locationMap["altitude"] as? Double ?? 0.0
        let speed = coords?["speed"] as? Double ?? locationMap["speed"] as? Double ?? -1.0
        let heading = coords?["heading"] as? Double ?? locationMap["heading"] as? Double ?? -1.0
        let accuracy = coords?["accuracy"] as? Double ?? locationMap["accuracy"] as? Double ?? -1.0

        let uuid = locationMap["uuid"] as? String ?? ""
        let timestamp = locationMap["timestamp"] as? String ?? ""
        let odometer = locationMap["odometer"] as? Double ?? 0.0

        let isMoving: Bool
        if let moving = locationMap["is_moving"] as? Bool {
            isMoving = moving
        } else if let moving = (locationMap["is_moving"] as? NSNumber)?.intValue {
            isMoving = moving == 1
        } else {
            isMoving = false
        }

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
            odometer: odometer,
            isMoving: isMoving
        )

        // Delegate next hash generation to the Rust Core engine
        let result = engine.generateNextHash(loc: loc)

        // Double persist: Write to native iOS SQLite DB
        database.insertAuditRecord(
            uuid: uuid,
            hash: result.hash,
            previousHash: result.previousHash,
            chainIndex: Int(result.chainIndex)
        )

        // Write to the shared Rust Core SQLite engine
        do {
            try rustDatabase?.insertAuditTrail(
                uuid: uuid,
                hash: result.hash,
                prevHash: result.previousHash,
                index: result.chainIndex
            )
        } catch {
            NSLog("AuditTrailManager: Failed to write audit trail to Rust Core DB: \(error)")
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
            let locationFlat = database.getLocationForAudit(uuid: uuid)
            let hasLocation = locationFlat != nil

            let loc: LocationRecord?
            if let flat = locationFlat {
                let coords = flat["coords"] as? [String: Any]
                let lat = coords?["latitude"] as? Double ?? flat["latitude"] as? Double ?? 0.0
                let lng = coords?["longitude"] as? Double ?? flat["longitude"] as? Double ?? 0.0
                let altitude = coords?["altitude"] as? Double ?? flat["altitude"] as? Double ?? 0.0
                let speed = coords?["speed"] as? Double ?? flat["speed"] as? Double ?? -1.0
                let heading = coords?["heading"] as? Double ?? flat["heading"] as? Double ?? -1.0
                let accuracy = coords?["accuracy"] as? Double ?? flat["accuracy"] as? Double ?? -1.0
                let timestamp = flat["timestamp"] as? String ?? ""
                let odometer = flat["odometer"] as? Double ?? 0.0
                
                let isMoving: Bool
                if let moving = flat["is_moving"] as? Bool {
                    isMoving = moving
                } else if let moving = (flat["is_moving"] as? NSNumber)?.intValue {
                    isMoving = moving == 1
                } else {
                    isMoving = false
                }

                loc = LocationRecord(
                    uuid: uuid,
                    latitude: lat,
                    longitude: lng,
                    timestamp: timestamp,
                    accuracy: accuracy,
                    speed: speed,
                    heading: heading,
                    altitude: altitude,
                    odometer: odometer,
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

        return map
    }

    /// Returns the audit proof for a specific location UUID.
    /// Pairs the DB block properties with the location coordinates retrieved by UUID.
    public func getProof(uuid: String) -> [String: Any]? {
        let auditRecords = (try? rustDatabase?.getAuditTrail()) ?? []
        guard let matchedRecord = auditRecords.first(where: { $0.uuid == uuid }) else { return nil }
        let location = database.getLocationForAudit(uuid: uuid)

        return [
            "uuid": matchedRecord.uuid,
            "hash": matchedRecord.auditHash,
            "previous_hash": matchedRecord.auditPreviousHash,
            "chain_index": Int(matchedRecord.auditChainIndex),
            "timestamp": location?["timestamp"] as? String ?? "",
            "latitude": location?["latitude"] as? Double ?? 0.0,
            "longitude": location?["longitude"] as? Double ?? 0.0,
            "accuracy": location?["accuracy"] as? Double ?? 0.0,
            "speed": location?["speed"] as? Double ?? 0.0,
            "heading": location?["heading"] as? Double ?? 0.0,
            "altitude": location?["altitude"] as? Double ?? 0.0,
        ]
    }

    /// Resets the cryptographic chain state and clears local logs.
    public func reset() {
        database.deleteAllAuditRecords()
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
