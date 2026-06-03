import CoreLocation
import Foundation

/// **[Enterprise]** Privacy Zone Manager.
///
/// This subsystem coordinates geographic compliance and privacy zones on iOS.
/// It intercepts GPS location events, evaluates them against registered geographic
/// zones, and determines whether to pass, drop, degrade, or trigger event-only dispatch.
///
/// Under the hood, this manager delegates its math and overlapping zone priority resolution
/// (Exclude > EventOnly > Degrade) entirely to the shared Rust Core's `PrivacyZoneEvaluator`
/// to guarantee mathematical and behavioral parity across platforms.
public final class PrivacyZoneManager {

    // Action constants — must match Dart `PrivacyZoneAction` enum indices
    public static let actionExclude  = 0
    public static let actionDegrade  = 1
    public static let actionEventOnly = 2

    private let configManager: ConfigManager
    private let rustDatabase: DatabaseManager?

    /// In-memory cache of active privacy zones to prevent database queries per location update.
    private var cachedZones: [CorePrivacyZone]?

    public init(configManager: ConfigManager, rustDatabase: DatabaseManager? = nil) {
        self.configManager = configManager
        self.rustDatabase = rustDatabase ?? (try? DatabaseManager(dbPath: ":memory:"))
    }

    /// Checks whether privacy zone enforcement is active in configuration.
    public func isEnabled() -> Bool {
        return configManager.getPrivacyZoneEnabled()
    }

    // MARK: - Zone Cache

    /// Returns privacy zones from cache, refreshing from the Rust DB when invalidated.
    private func getCachedZones() -> [CorePrivacyZone] {
        if let cached = cachedZones {
            return cached
        }
        let loaded = (try? rustDatabase?.getPrivacyZones()) ?? []
        cachedZones = loaded
        return loaded
    }

    /// Invalidates the cache, forcing a database query on the next evaluation.
    private func invalidateCache() {
        cachedZones = nil
    }

    // MARK: - Zone CRUD

    /// Registers a new geographic privacy zone in the Rust core SQLite database.
    public func addZone(_ zone: [String: Any]) -> Bool {
        guard let identifier = zone["identifier"] as? String else { return false }
        let lat = (zone["latitude"] as? NSNumber)?.doubleValue ?? 0.0
        let lng = (zone["longitude"] as? NSNumber)?.doubleValue ?? 0.0
        let radius = (zone["radius"] as? NSNumber)?.doubleValue ?? 200.0
        let action = (zone["action"] as? NSNumber)?.intValue ?? PrivacyZoneManager.actionExclude
        let degradedAccuracy = (zone["degradedAccuracyMeters"] as? NSNumber)?.doubleValue ?? 1000.0

        invalidateCache()
        do {
            try rustDatabase?.insertPrivacyZone(
                identifier: identifier,
                lat: lat,
                lng: lng,
                radius: radius,
                action: Int32(action),
                degradedAccuracy: degradedAccuracy
            )
            return true
        } catch {
            return false
        }
    }

    /// Registers multiple privacy zones in a single sweep.
    public func addZones(_ zones: [[String: Any]]) -> Bool {
        var allSuccess = true
        for zone in zones {
            if !addZone(zone) {
                allSuccess = false
            }
        }
        return allSuccess
    }

    /// Removes a specific privacy zone from the database by its identifier.
    public func removeZone(_ identifier: String) -> Bool {
        invalidateCache()
        do {
            try rustDatabase?.deletePrivacyZone(identifier: identifier)
            return true
        } catch {
            return false
        }
    }

    /// Removes all registered privacy zones.
    public func removeAllZones() -> Bool {
        invalidateCache()
        do {
            try rustDatabase?.clearPrivacyZones()
            return true
        } catch {
            return false
        }
    }

    /// Returns a generic array representation of privacy zones to maintain compatibility with Dart channel bridges.
    public func getZones() -> [[String: Any]] {
        return getCachedZones().map { mapFromCorePrivacyZone($0) }
    }

    // MARK: - Location Evaluation

    /// Encapsulates evaluation outcomes against privacy zones.
    public struct EvaluationResult {
        public let action: Int?
        public let zone: [String: Any]?
    }

    /// Evaluates a location coordinate against active privacy zones.
    /// Employs Rust `PrivacyZoneEvaluator` to resolve overlapping priorities.
    public func evaluate(latitude: Double, longitude: Double) -> EvaluationResult {
        guard isEnabled() else {
            return EvaluationResult(action: nil, zone: nil)
        }
        let zones = getCachedZones()
        guard !zones.isEmpty else {
            return EvaluationResult(action: nil, zone: nil)
        }

        // Instantiate the Rust spatial evaluator
        let evaluator = PrivacyZoneEvaluator()
        let result = evaluator.evaluate(latitude: latitude, longitude: longitude, zones: zones)

        guard let action = result.action else {
            return EvaluationResult(action: nil, zone: nil)
        }

        // Match the winner zone to build the bridge-compatible map representation
        let matchedZone = zones.first(where: { $0.identifier == result.matchedZoneId })
        let matchedZoneMap = matchedZone.map { mapFromCorePrivacyZone($0) }

        return EvaluationResult(action: Int(action), zone: matchedZoneMap)
    }

    // MARK: - Processed Location

    public enum ProcessedAction {
        /// No privacy zone matches — location passes unchanged.
        case passThrough
        /// Location falls in an exclusion zone — drops completely.
        case drop
        /// Keep event-only — dispatch to framework listeners but do not persist.
        case eventOnly
        /// Coordinate degraded — persists and dispatches coordinates snapped to the coarse grid.
        case degraded
    }

    public struct ProcessedLocation {
        public let action: ProcessedAction
        public let location: [String: Any]?
    }

    /// Processes a location structure against geographic privacy rules.
    public func processLocation(_ locationMap: [String: Any]) -> ProcessedLocation {
        guard let coords = locationMap["coords"] as? [String: Any],
              let lat = coords["latitude"] as? Double,
              let lng = coords["longitude"] as? Double else {
            return ProcessedLocation(action: .passThrough, location: locationMap)
        }

        let result = evaluate(latitude: lat, longitude: lng)
        guard let action = result.action else {
            return ProcessedLocation(action: .passThrough, location: locationMap)
        }

        switch action {
        case PrivacyZoneManager.actionExclude:
            return ProcessedLocation(action: .drop, location: nil)

        case PrivacyZoneManager.actionEventOnly:
            return ProcessedLocation(action: .eventOnly, location: locationMap)

        case PrivacyZoneManager.actionDegrade:
            let accuracy = result.zone?["degradedAccuracyMeters"] as? Double ?? 1000.0
            let degraded = degradeLocation(locationMap, lat: lat, lng: lng, accuracyMeters: accuracy)
            return ProcessedLocation(action: .degraded, location: degraded)

        default:
            return ProcessedLocation(action: .passThrough, location: locationMap)
        }
    }

    // MARK: - Internals

    /// Snaps coordinates to a coarse precision grid utilizing the Rust core evaluator.
    private func degradeLocation(
        _ location: [String: Any],
        lat: Double,
        lng: Double,
        accuracyMeters: Double
    ) -> [String: Any] {
        let evaluator = PrivacyZoneEvaluator()
        let snapped = evaluator.degradeCoordinates(lat: lat, lng: lng, accuracyMeters: accuracyMeters)

        var modified = location
        if var coords = modified["coords"] as? [String: Any] {
            coords["latitude"] = snapped.lat
            coords["longitude"] = snapped.lng
            coords["accuracy"] = accuracyMeters
            modified["coords"] = coords
        }
        // Sync top-level keys
        modified["latitude"] = snapped.lat
        modified["longitude"] = snapped.lng
        modified["accuracy"] = accuracyMeters
        return modified
    }

    /// Transforms a Rust `CorePrivacyZone` record into a dictionary compatible with platform channels.
    private func mapFromCorePrivacyZone(_ zone: CorePrivacyZone) -> [String: Any] {
        return [
            "identifier": zone.identifier,
            "latitude": zone.latitude,
            "longitude": zone.longitude,
            "radius": zone.radius,
            "action": Int(zone.action),
            "degradedAccuracyMeters": zone.degradedAccuracyMeters
        ]
    }
}
