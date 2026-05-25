use crate::spatial::rtree::RTree as NativeRTree;

pub struct RTreeDart {
    inner: NativeRTree<String>,
}

impl RTreeDart {
    #[flutter_rust_bridge::frb(sync)]
    pub fn new() -> Self {
        Self {
            inner: NativeRTree::new(9),
        }
    }

    #[flutter_rust_bridge::frb(sync)]
    pub fn insert(&mut self, id: String, lat: f64, lng: f64, radius_meters: f64) {
        self.inner.insert(lat, lng, radius_meters, id);
    }

    #[flutter_rust_bridge::frb(sync)]
    pub fn search(&self, lat: f64, lng: f64) -> Vec<String> {
        self.inner.query_circle(lat, lng, 0.0).into_iter().cloned().collect()
    }

    #[flutter_rust_bridge::frb(sync)]
    pub fn query_circle(&self, lat: f64, lng: f64, radius_meters: f64) -> Vec<String> {
        self.inner.query_circle(lat, lng, radius_meters).into_iter().cloned().collect()
    }

    #[flutter_rust_bridge::frb(sync)]
    pub fn clear(&mut self) {
        self.inner.clear();
    }
}
