use std::collections::{HashSet, HashMap};
use std::sync::Arc;
use crate::algorithms::geo_utils::{haversine, is_point_in_polygon, Coordinate};
use crate::spatial::rtree::RTree;

#[derive(uniffi::Record, Clone, Debug)]
pub struct CoreGeofence {
    pub identifier: String,
    pub latitude: f64,
    pub longitude: f64,
    pub radius: f64,
    pub vertices: Vec<Coordinate>,
}

#[derive(uniffi::Record, Clone, Debug)]
pub struct GeofenceTransition {
    pub identifier: String,
    pub action: String,
}

#[derive(uniffi::Object)]
pub struct GeofenceEvaluator {
    inside_geofence_ids: std::sync::RwLock<HashSet<String>>,
    rtree: std::sync::RwLock<Option<RTree<CoreGeofence>>>,
    indexed_geofences: std::sync::RwLock<Option<HashMap<String, CoreGeofence>>>,
}

#[uniffi::export]
impl GeofenceEvaluator {
    #[uniffi::constructor]
    pub fn new() -> Arc<Self> {
        Arc::new(Self {
            inside_geofence_ids: std::sync::RwLock::new(HashSet::new()),
            rtree: std::sync::RwLock::new(None),
            indexed_geofences: std::sync::RwLock::new(None),
        })
    }

    pub fn index_geofences(&self, geofences: Vec<CoreGeofence>) {
        let mut tree = RTree::new(8);
        let mut lookup = HashMap::new();

        for gf in geofences {
            let id = gf.identifier.clone();
            tree.insert(gf.latitude, gf.longitude, gf.radius, gf.clone());
            lookup.insert(id, gf);
        }

        *self.rtree.write().unwrap() = Some(tree);
        *self.indexed_geofences.write().unwrap() = Some(lookup);
    }

    pub fn clear_index(&self) {
        *self.rtree.write().unwrap() = None;
        *self.indexed_geofences.write().unwrap() = None;
    }

    pub fn evaluate_proximity(&self, latitude: f64, longitude: f64, geofences: Vec<CoreGeofence>) -> Vec<GeofenceTransition> {
        let effective_geofences = self.resolve_geofences(latitude, longitude, geofences);
        let mut transitions = Vec::new();
        let mut inside_ids = self.inside_geofence_ids.write().unwrap();

        for gf in effective_geofences {
            let identifier = &gf.identifier;

            // ── Polygon geofence ──────────────────────────────────────────────
            if gf.vertices.len() >= 3 {
                let is_inside = is_point_in_polygon(latitude, longitude, gf.vertices);
                let was_inside = inside_ids.contains(identifier);

                if is_inside && !was_inside {
                    inside_ids.insert(identifier.clone());
                    transitions.push(GeofenceTransition {
                        identifier: identifier.clone(),
                        action: "ENTER".to_string(),
                    });
                } else if !is_inside && was_inside {
                    inside_ids.remove(identifier);
                    transitions.push(GeofenceTransition {
                        identifier: identifier.clone(),
                        action: "EXIT".to_string(),
                    });
                }
                continue; // Skip circular check
            }

            // ── Circular geofence ─────────────────────────────────────────────
            if gf.radius <= 0.0 {
                continue;
            }

            let distance = haversine(latitude, longitude, gf.latitude, gf.longitude);
            let was_inside = inside_ids.contains(identifier);
            let is_inside = distance <= gf.radius;

            if is_inside && !was_inside {
                inside_ids.insert(identifier.clone());
                transitions.push(GeofenceTransition {
                    identifier: identifier.clone(),
                    action: "ENTER".to_string(),
                });
            } else if !is_inside && was_inside {
                inside_ids.remove(identifier);
                transitions.push(GeofenceTransition {
                    identifier: identifier.clone(),
                    action: "EXIT".to_string(),
                });
            }
        }

        transitions
    }

    pub fn clear(&self) {
        self.inside_geofence_ids.write().unwrap().clear();
        self.clear_index();
    }

    pub fn remove_geofence(&self, identifier: String) {
        self.inside_geofence_ids.write().unwrap().remove(&identifier);
    }
}

impl GeofenceEvaluator {
    fn resolve_geofences(&self, lat: f64, lng: f64, all_geofences: Vec<CoreGeofence>) -> Vec<CoreGeofence> {
        let rtree_guard = self.rtree.read().unwrap();
        let lookup_guard = self.indexed_geofences.read().unwrap();

        if rtree_guard.is_none() || lookup_guard.is_none() {
            return all_geofences;
        }

        let tree = rtree_guard.as_ref().unwrap();
        let lookup = lookup_guard.as_ref().unwrap();

        let search_radius = 50000.0; // 50 km
        let nearby = tree.query_circle(lat, lng, search_radius);

        let inside_ids = self.inside_geofence_ids.read().unwrap();
        if inside_ids.is_empty() {
            return nearby.into_iter().cloned().collect();
        }

        let mut seen = HashSet::new();
        let mut merged = Vec::new();

        for gf in nearby {
            seen.insert(gf.identifier.clone());
            merged.push(gf.clone());
        }

        for id in inside_ids.iter() {
            if !seen.contains(id) {
                if let Some(gf) = lookup.get(id) {
                    merged.push(gf.clone());
                }
            }
        }

        merged
    }
}
