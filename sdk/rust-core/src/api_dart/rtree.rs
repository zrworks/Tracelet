use crate::spatial::rtree::RTree as NativeRTree;

/// An R-Tree implementation used for efficient spatial querying of geofences or locations.
pub struct RTreeDart {
    inner: NativeRTree<String>,
}

impl RTreeDart {
    /// Initializes an empty R-Tree.
    #[flutter_rust_bridge::frb(sync)]
    pub fn new() -> Self {
        Self {
            inner: NativeRTree::new(9),
        }
    }

    /// Inserts a new spatial entity into the R-Tree.
    #[flutter_rust_bridge::frb(sync)]
    pub fn insert(&mut self, id: String, lat: f64, lng: f64, radius_meters: f64) {
        self.inner.insert(lat, lng, radius_meters, id);
    }

    /// Searches the R-Tree for any bounding boxes that intersect with the given point.
    #[flutter_rust_bridge::frb(sync)]
    pub fn search(&self, lat: f64, lng: f64) -> Vec<String> {
        self.inner.query_circle(lat, lng, 0.0).into_iter().cloned().collect()
    }

    /// Queries the R-Tree for entities that intersect with a given circular area.
    #[flutter_rust_bridge::frb(sync)]
    pub fn query_circle(&self, lat: f64, lng: f64, radius_meters: f64) -> Vec<String> {
        self.inner.query_circle(lat, lng, radius_meters).into_iter().cloned().collect()
    }

    /// Removes all elements from the R-Tree.
    #[flutter_rust_bridge::frb(sync)]
    pub fn clear(&mut self) {
        self.inner.clear();
    }
}
