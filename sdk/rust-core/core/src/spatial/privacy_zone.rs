use std::sync::Arc;
use crate::algorithms::geo_utils::{haversine, Coordinate};

#[derive(uniffi::Record, Clone, Debug)]
pub struct CorePrivacyZone {
    pub identifier: String,
    pub latitude: f64,
    pub longitude: f64,
    pub radius: f64,
    pub action: i32,
    pub degraded_accuracy_meters: f64,
}

#[derive(uniffi::Record, Clone, Debug)]
pub struct PrivacyEvaluationResult {
    pub action: Option<i32>,
    pub matched_zone_id: Option<String>,
    pub degraded_accuracy_meters: Option<f64>,
}

#[derive(uniffi::Object)]
pub struct PrivacyZoneEvaluator {}

#[uniffi::export]
impl PrivacyZoneEvaluator {
    #[uniffi::constructor]
    pub fn new() -> Arc<Self> {
        Arc::new(Self)
    }

    pub fn evaluate(&self, latitude: f64, longitude: f64, zones: Vec<CorePrivacyZone>) -> PrivacyEvaluationResult {
        let mut matched_action: Option<i32> = None;
        let mut matched_zone_id: Option<String> = None;
        let mut degraded_accuracy: Option<f64> = None;

        for zone in zones {
            let distance = haversine(latitude, longitude, zone.latitude, zone.longitude);
            if distance <= zone.radius {
                let action = zone.action;
                if matched_action.is_none() || self.is_action_more_restrictive(action, matched_action.unwrap()) {
                    matched_action = Some(action);
                    matched_zone_id = Some(zone.identifier.clone());
                    if action == 1 { // ACTION_DEGRADE
                        degraded_accuracy = Some(zone.degraded_accuracy_meters);
                    } else {
                        degraded_accuracy = None;
                    }
                }
            }
        }

        PrivacyEvaluationResult {
            action: matched_action,
            matched_zone_id,
            degraded_accuracy_meters: degraded_accuracy,
        }
    }

    pub fn degrade_coordinates(&self, lat: f64, lng: f64, accuracy_meters: f64) -> Coordinate {
        let grid_deg = accuracy_meters / 111320.0;
        let snapped_lat = (lat / grid_deg).round() * grid_deg;
        let snapped_lng = (lng / grid_deg).round() * grid_deg;
        Coordinate { lat: snapped_lat, lng: snapped_lng }
    }
}

impl PrivacyZoneEvaluator {
    fn is_action_more_restrictive(&self, a: i32, b: i32) -> bool {
        let get_priority = |act: i32| -> i32 {
            match act {
                0 => 3, // Exclude
                2 => 2, // EventOnly
                1 => 1, // Degrade
                _ => 0,
            }
        };
        get_priority(a) > get_priority(b)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_privacy_evaluation_single_zone() {
        let evaluator = PrivacyZoneEvaluator::new();
        
        // Define a privacy zone around a central point (lat: 10.0, lng: 10.0) with radius 100 meters
        let zones = vec![CorePrivacyZone {
            identifier: "zone_1".to_string(),
            latitude: 10.0,
            longitude: 10.0,
            radius: 100.0,
            action: 0, // EXCLUDE
            degraded_accuracy_meters: 1000.0,
        }];

        // Location exactly at the center should match the zone
        let res_inside = evaluator.evaluate(10.0, 10.0, zones.clone());
        assert_eq!(res_inside.action, Some(0));
        assert_eq!(res_inside.matched_zone_id, Some("zone_1".to_string()));

        // Location far away (lat: 11.0, lng: 11.0) should not match the zone
        let res_outside = evaluator.evaluate(11.0, 11.0, zones);
        assert_eq!(res_outside.action, None);
        assert_eq!(res_outside.matched_zone_id, None);
    }

    #[test]
    fn test_privacy_evaluation_priority() {
        let evaluator = PrivacyZoneEvaluator::new();

        // Zone 1: Degrade (priority 1), radius 1000m
        let zone_degrade = CorePrivacyZone {
            identifier: "zone_degrade".to_string(),
            latitude: 10.0,
            longitude: 10.0,
            radius: 1000.0,
            action: 1, // DEGRADE
            degraded_accuracy_meters: 500.0,
        };

        // Zone 2: Event-Only (priority 2), radius 500m
        let zone_event_only = CorePrivacyZone {
            identifier: "zone_event_only".to_string(),
            latitude: 10.0,
            longitude: 10.0,
            radius: 500.0,
            action: 2, // EVENT_ONLY
            degraded_accuracy_meters: 1000.0,
        };

        // Zone 3: Exclude (priority 3), radius 100m
        let zone_exclude = CorePrivacyZone {
            identifier: "zone_exclude".to_string(),
            latitude: 10.0,
            longitude: 10.0,
            radius: 100.0,
            action: 0, // EXCLUDE
            degraded_accuracy_meters: 1000.0,
        };

        let zones = vec![zone_degrade, zone_event_only, zone_exclude];

        // Far out: distance = ~668m -> matches only DEGRADE (radius 1000m)
        let res_far = evaluator.evaluate(10.006, 10.0, zones.clone());
        assert_eq!(res_far.action, Some(1));
        assert_eq!(res_far.matched_zone_id, Some("zone_degrade".to_string()));
        assert_eq!(res_far.degraded_accuracy_meters, Some(500.0));

        // Mid range: distance = ~334m -> matches DEGRADE and EVENT_ONLY (radius 500m). EVENT_ONLY (priority 2) wins.
        let res_mid = evaluator.evaluate(10.003, 10.0, zones.clone());
        assert_eq!(res_mid.action, Some(2));
        assert_eq!(res_mid.matched_zone_id, Some("zone_event_only".to_string()));
        assert_eq!(res_mid.degraded_accuracy_meters, None);

        // Near range: distance = ~56m -> matches all three (radius 100m). EXCLUDE (priority 3) wins.
        let res_near = evaluator.evaluate(10.0005, 10.0, zones);
        assert_eq!(res_near.action, Some(0));
        assert_eq!(res_near.matched_zone_id, Some("zone_exclude".to_string()));
        assert_eq!(res_near.degraded_accuracy_meters, None);
    }

    #[test]
    fn test_coordinate_degradation_rounding() {
        let evaluator = PrivacyZoneEvaluator::new();
        // Snapping 37.7749 to a 1000m coarse grid.
        // gridDeg = 1000.0 / 111320.0 = 0.00898311175
        let coord = evaluator.degrade_coordinates(37.7749, -122.4194, 1000.0);
        let expected_lat = (37.7749f64 / (1000.0 / 111320.0)).round() * (1000.0 / 111320.0);
        let expected_lng = (-122.4194f64 / (1000.0 / 111320.0)).round() * (1000.0 / 111320.0);
        assert_eq!(coord.lat, expected_lat);
        assert_eq!(coord.lng, expected_lng);
    }
}
