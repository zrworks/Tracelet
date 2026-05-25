use std::f64;

#[derive(Clone, Debug)]
pub struct RTreeBBox {
    pub min_lat: f64,
    pub min_lng: f64,
    pub max_lat: f64,
    pub max_lng: f64,
}

impl RTreeBBox {
    pub fn new(min_lat: f64, min_lng: f64, max_lat: f64, max_lng: f64) -> Self {
        Self { min_lat, min_lng, max_lat, max_lng }
    }

    pub fn from_point(lat: f64, lng: f64) -> Self {
        Self::new(lat, lng, lat, lng)
    }

    pub fn expand(&mut self, other: &RTreeBBox) {
        if other.min_lat < self.min_lat { self.min_lat = other.min_lat; }
        if other.min_lng < self.min_lng { self.min_lng = other.min_lng; }
        if other.max_lat > self.max_lat { self.max_lat = other.max_lat; }
        if other.max_lng > self.max_lng { self.max_lng = other.max_lng; }
    }

    pub fn intersects(&self, other: &RTreeBBox) -> bool {
        self.min_lat <= other.max_lat &&
        self.max_lat >= other.min_lat &&
        self.min_lng <= other.max_lng &&
        self.max_lng >= other.min_lng
    }

    pub fn area(&self) -> f64 {
        (self.max_lat - self.min_lat) * (self.max_lng - self.min_lng)
    }

    pub fn enlargement(&self, other: &RTreeBBox) -> f64 {
        let new_min_lat = self.min_lat.min(other.min_lat);
        let new_min_lng = self.min_lng.min(other.min_lng);
        let new_max_lat = self.max_lat.max(other.max_lat);
        let new_max_lng = self.max_lng.max(other.max_lng);
        (new_max_lat - new_min_lat) * (new_max_lng - new_min_lng) - self.area()
    }
}

#[derive(Clone)]
pub struct RTreeEntry<T> {
    pub lat: f64,
    pub lng: f64,
    pub radius: f64,
    pub data: T,
    pub bbox: RTreeBBox,
}

impl<T> RTreeEntry<T> {
    pub fn new(lat: f64, lng: f64, radius: f64, data: T) -> Self {
        let lat_offset = radius / 111320.0;
        let lng_offset = radius / (111320.0 * (lat * f64::consts::PI / 180.0).cos());
        let bbox = RTreeBBox::new(
            lat - lat_offset,
            lng - lng_offset,
            lat + lat_offset,
            lng + lng_offset,
        );
        Self { lat, lng, radius, data, bbox }
    }
}

pub struct RTreeNode<T> {
    pub is_leaf: bool,
    pub children: Vec<Box<RTreeNode<T>>>,
    pub entries: Vec<RTreeEntry<T>>,
    pub bbox: RTreeBBox,
}

impl<T> RTreeNode<T> {
    pub fn new(is_leaf: bool) -> Self {
        Self {
            is_leaf,
            children: Vec::new(),
            entries: Vec::new(),
            bbox: RTreeBBox::new(f64::INFINITY, f64::INFINITY, f64::NEG_INFINITY, f64::NEG_INFINITY),
        }
    }

    pub fn recalculate_bbox(&mut self) {
        self.bbox = RTreeBBox::new(f64::INFINITY, f64::INFINITY, f64::NEG_INFINITY, f64::NEG_INFINITY);
        if self.is_leaf {
            for e in &self.entries {
                self.bbox.expand(&e.bbox);
            }
        } else {
            for c in &self.children {
                self.bbox.expand(&c.bbox);
            }
        }
    }

    pub fn count(&self) -> usize {
        if self.is_leaf {
            self.entries.len()
        } else {
            self.children.len()
        }
    }

    fn insert(&mut self, entry: RTreeEntry<T>, max_entries: usize) -> Option<Box<RTreeNode<T>>> {
        if self.is_leaf {
            self.entries.push(entry);
            self.recalculate_bbox();
            if self.entries.len() > max_entries {
                return Some(Box::new(self.split_leaf()));
            } else {
                return None;
            }
        } else {
            let mut best_idx = 0;
            let mut best_enlargement = f64::INFINITY;
            let mut best_area = f64::INFINITY;

            for (i, child) in self.children.iter().enumerate() {
                let enlargement = child.bbox.enlargement(&entry.bbox);
                let area = child.bbox.area();
                if enlargement < best_enlargement || (enlargement == best_enlargement && area < best_area) {
                    best_idx = i;
                    best_enlargement = enlargement;
                    best_area = area;
                }
            }

            if let Some(sibling) = self.children[best_idx].insert(entry, max_entries) {
                self.children.push(sibling);
                self.recalculate_bbox();
                if self.children.len() > max_entries {
                    return Some(Box::new(self.split_internal()));
                }
            } else {
                self.recalculate_bbox();
            }
            return None;
        }
    }

    fn split_leaf(&mut self) -> RTreeNode<T> {
        let entries = std::mem::take(&mut self.entries);
        let mut sibling = RTreeNode::new(true);

        let mut seed1 = 0;
        let mut seed2 = 1;
        let mut max_waste = f64::NEG_INFINITY;

        for i in 0..entries.len() {
            for j in (i + 1)..entries.len() {
                let combined = RTreeBBox::new(
                    entries[i].bbox.min_lat.min(entries[j].bbox.min_lat),
                    entries[i].bbox.min_lng.min(entries[j].bbox.min_lng),
                    entries[i].bbox.max_lat.max(entries[j].bbox.max_lat),
                    entries[i].bbox.max_lng.max(entries[j].bbox.max_lng),
                );
                let waste = combined.area() - entries[i].bbox.area() - entries[j].bbox.area();
                if waste > max_waste {
                    max_waste = waste;
                    seed1 = i;
                    seed2 = j;
                }
            }
        }

        let mut e1_opt = None;
        let mut e2_opt = None;
        let mut remaining = Vec::new();

        for (i, entry) in entries.into_iter().enumerate() {
            if i == seed1 {
                e1_opt = Some(entry);
            } else if i == seed2 {
                e2_opt = Some(entry);
            } else {
                remaining.push(entry);
            }
        }

        self.entries.push(e1_opt.unwrap());
        sibling.entries.push(e2_opt.unwrap());

        for entry in remaining {
            self.recalculate_bbox();
            sibling.recalculate_bbox();
            let e1 = self.bbox.enlargement(&entry.bbox);
            let e2 = sibling.bbox.enlargement(&entry.bbox);
            if e1 <= e2 {
                self.entries.push(entry);
            } else {
                sibling.entries.push(entry);
            }
        }

        self.recalculate_bbox();
        sibling.recalculate_bbox();
        sibling
    }

    fn split_internal(&mut self) -> RTreeNode<T> {
        let children = std::mem::take(&mut self.children);
        let mut sibling = RTreeNode::new(false);

        let mut seed1 = 0;
        let mut seed2 = 1;
        let mut max_waste = f64::NEG_INFINITY;

        for i in 0..children.len() {
            for j in (i + 1)..children.len() {
                let combined = RTreeBBox::new(
                    children[i].bbox.min_lat.min(children[j].bbox.min_lat),
                    children[i].bbox.min_lng.min(children[j].bbox.min_lng),
                    children[i].bbox.max_lat.max(children[j].bbox.max_lat),
                    children[i].bbox.max_lng.max(children[j].bbox.max_lng),
                );
                let waste = combined.area() - children[i].bbox.area() - children[j].bbox.area();
                if waste > max_waste {
                    max_waste = waste;
                    seed1 = i;
                    seed2 = j;
                }
            }
        }

        let mut child1 = None;
        let mut child2 = None;
        let mut remaining = Vec::new();

        for (i, child) in children.into_iter().enumerate() {
            if i == seed1 {
                child1 = Some(child);
            } else if i == seed2 {
                child2 = Some(child);
            } else {
                remaining.push(child);
            }
        }

        self.children.push(child1.unwrap());
        sibling.children.push(child2.unwrap());

        for child in remaining {
            self.recalculate_bbox();
            sibling.recalculate_bbox();
            let e1 = self.bbox.enlargement(&child.bbox);
            let e2 = sibling.bbox.enlargement(&child.bbox);
            if e1 <= e2 {
                self.children.push(child);
            } else {
                sibling.children.push(child);
            }
        }

        self.recalculate_bbox();
        sibling.recalculate_bbox();
        sibling
    }

    fn remove<F>(&mut self, predicate: &F) -> bool
    where F: Fn(&T) -> bool {
        if self.is_leaf {
            if let Some(idx) = self.entries.iter().position(|e| predicate(&e.data)) {
                self.entries.remove(idx);
                self.recalculate_bbox();
                return true;
            }
            return false;
        }

        let mut removed = false;
        let mut i = 0;
        while i < self.children.len() {
            if self.children[i].remove(predicate) {
                if self.children[i].count() == 0 {
                    self.children.remove(i);
                }
                self.recalculate_bbox();
                removed = true;
                break;
            } else {
                i += 1;
            }
        }
        removed
    }
}

pub struct RTree<T> {
    max_entries: usize,
    root: Option<Box<RTreeNode<T>>>,
    size: usize,
}

impl<T> RTree<T> {
    pub fn new(max_entries: usize) -> Self {
        Self { max_entries, root: None, size: 0 }
    }

    pub fn size(&self) -> usize {
        self.size
    }

    pub fn is_empty(&self) -> bool {
        self.size == 0
    }

    pub fn insert(&mut self, lat: f64, lng: f64, radius: f64, data: T) {
        let entry = RTreeEntry::new(lat, lng, radius, data);
        if let Some(ref mut root) = self.root {
            if let Some(sibling) = root.insert(entry, self.max_entries) {
                let mut new_root = RTreeNode::new(false);
                let old_root = self.root.take().unwrap();
                new_root.children.push(old_root);
                new_root.children.push(sibling);
                new_root.recalculate_bbox();
                self.root = Some(Box::new(new_root));
            }
        } else {
            let mut root = RTreeNode::new(true);
            root.entries.push(entry);
            root.recalculate_bbox();
            self.root = Some(Box::new(root));
        }
        self.size += 1;
    }

    pub fn remove<F>(&mut self, predicate: F) -> bool
    where F: Fn(&T) -> bool {
        if let Some(ref mut root) = self.root {
            if root.remove(&predicate) {
                self.size -= 1;
                if self.size == 0 {
                    self.root = None;
                } else if !root.is_leaf && root.children.len() == 1 {
                    self.root = Some(root.children.remove(0));
                }
                return true;
            }
        }
        false
    }

    pub fn query_circle<'a>(&'a self, lat: f64, lng: f64, radius_meters: f64) -> Vec<&'a T> {
        let mut results = Vec::new();
        if let Some(ref root) = self.root {
            let lat_offset = radius_meters / 111320.0;
            let lng_offset = radius_meters / (111320.0 * (lat * f64::consts::PI / 180.0).cos());
            let search_bbox = RTreeBBox::new(
                lat - lat_offset,
                lng - lng_offset,
                lat + lat_offset,
                lng + lng_offset,
            );

            self.query_bbox_recursive(root, &search_bbox, &mut |entry| {
                let dist = crate::algorithms::geo_utils::haversine(lat, lng, entry.lat, entry.lng);
                if dist <= radius_meters + entry.radius {
                    results.push(&entry.data);
                }
            });
        }
        results
    }

    fn query_bbox_recursive<'a, F>(&'a self, node: &'a RTreeNode<T>, search_bbox: &RTreeBBox, callback: &mut F)
    where F: FnMut(&'a RTreeEntry<T>) {
        if !node.bbox.intersects(search_bbox) { return; }

        if node.is_leaf {
            for entry in &node.entries {
                if entry.bbox.intersects(search_bbox) {
                    callback(entry);
                }
            }
        } else {
            for child in &node.children {
                self.query_bbox_recursive(child, search_bbox, callback);
            }
        }
    }

    pub fn clear(&mut self) {
        self.root = None;
        self.size = 0;
    }
}
