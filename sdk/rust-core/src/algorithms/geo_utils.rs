use std::f64::consts::PI;

/// Represents a 2D geographical coordinate using latitude and longitude.
#[derive(uniffi::Record, Clone, Debug)]
pub struct Coordinate {
    pub lat: f64,
    pub lng: f64,
}

#[uniffi::export]
/// Uses the ray-casting algorithm to determine if a point is strictly inside a polygon.
pub fn is_point_in_polygon(lat: f64, lng: f64, vertices: Vec<Coordinate>) -> bool {
    let n = vertices.len();
    if n < 3 {
        return false;
    }

    let mut inside = false;
    let mut j = n - 1;

    for i in 0..n {
        let vi = &vertices[i];
        let vj = &vertices[j];

        if (vi.lat > lat) != (vj.lat > lat)
            && lng < (vj.lng - vi.lng) * (lat - vi.lat) / (vj.lat - vi.lat) + vi.lng
        {
            inside = !inside;
        }
        j = i;
    }

    inside
}

#[uniffi::export]
/// Calculates the great-circle distance between two points on the Earth's surface using the Haversine formula.
/// Returns the distance in meters.
pub fn haversine(lat1: f64, lon1: f64, lat2: f64, lon2: f64) -> f64 {
    let r = 6371000.0;
    let d_lat = (lat2 - lat1) * (PI / 180.0);
    let d_lon = (lon2 - lon1) * (PI / 180.0);
    
    let sin_d_lat = (d_lat * 0.5).sin();
    let sin_d_lon = (d_lon * 0.5).sin();
    
    let a = sin_d_lat * sin_d_lat
        + (lat1 * (PI / 180.0)).cos() * (lat2 * (PI / 180.0)).cos() * sin_d_lon * sin_d_lon;
    
    let clamped_a = if a < 0.0 {
        0.0
    } else if a > 1.0 {
        1.0
    } else {
        a
    };

    r * 2.0 * clamped_a.sqrt().asin()
}
