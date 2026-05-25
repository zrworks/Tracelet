use serde_json::{json, Value};

#[uniffi::export]
pub fn encode_deltas(batch_json: String, precision: i32) -> String {
    let locations: Vec<Value> = match serde_json::from_str(&batch_json) {
        Ok(locs) => locs,
        Err(_) => return "[]".to_string(), // Invalid JSON
    };

    if locations.is_empty() {
        return "[]".to_string();
    }

    if locations.len() == 1 {
        let mut first = locations[0].as_object().unwrap().clone();
        first.insert("ref".to_string(), json!(true));
        return serde_json::to_string(&vec![json!(first)]).unwrap_or_else(|_| "[]".to_string());
    }

    let factor = 10_f64.powi(precision);
    let mut result = Vec::new();

    // First location: full reference.
    let mut first = locations[0].as_object().unwrap().clone();
    first.insert("ref".to_string(), json!(true));
    result.push(json!(first));

    let mut prev = &locations[0];
    for i in 1..locations.len() {
        let curr = &locations[i];
        let delta = encode_delta(prev, curr, factor);
        result.push(json!({ "d": delta }));
        prev = curr;
    }

    serde_json::to_string(&result).unwrap_or_else(|_| "[]".to_string())
}

fn encode_delta(prev: &Value, curr: &Value, factor: f64) -> Value {
    let mut delta = serde_json::Map::new();

    // UUID — always full.
    if let Some(u) = curr.get("uuid") {
        delta.insert("u".to_string(), u.clone());
    }

    // Δ timestamp (seconds).
    if let (Some(prev_ts_str), Some(curr_ts_str)) = (
        prev.get("timestamp").and_then(|v| v.as_str()),
        curr.get("timestamp").and_then(|v| v.as_str()),
    ) {
        if let (Ok(prev_ts), Ok(curr_ts)) = (
            chrono::DateTime::parse_from_rfc3339(prev_ts_str),
            chrono::DateTime::parse_from_rfc3339(curr_ts_str),
        ) {
            let diff = curr_ts.timestamp() - prev_ts.timestamp();
            delta.insert("t".to_string(), json!(diff));
        }
    }

    // Coordinates.
    if let (Some(prev_coords), Some(curr_coords)) = (prev.get("coords"), curr.get("coords")) {
        let prev_lat = prev_coords.get("latitude").and_then(to_f64).unwrap_or(0.0);
        let curr_lat = curr_coords.get("latitude").and_then(to_f64).unwrap_or(0.0);
        delta.insert("la".to_string(), json!(((curr_lat - prev_lat) * factor).round() as i64));

        let prev_lng = prev_coords.get("longitude").and_then(to_f64).unwrap_or(0.0);
        let curr_lng = curr_coords.get("longitude").and_then(to_f64).unwrap_or(0.0);
        delta.insert("lo".to_string(), json!(((curr_lng - prev_lng) * factor).round() as i64));

        let prev_speed = prev_coords.get("speed").and_then(to_f64).unwrap_or(0.0);
        let curr_speed = curr_coords.get("speed").and_then(to_f64).unwrap_or(0.0);
        delta.insert("s".to_string(), json!(round_2(curr_speed - prev_speed)));

        let prev_heading = prev_coords.get("heading").and_then(to_f64).unwrap_or(0.0);
        let curr_heading = curr_coords.get("heading").and_then(to_f64).unwrap_or(0.0);
        delta.insert("h".to_string(), json!(round_2(shortest_arc(prev_heading, curr_heading))));

        let prev_acc = prev_coords.get("accuracy").and_then(to_f64).unwrap_or(0.0);
        let curr_acc = curr_coords.get("accuracy").and_then(to_f64).unwrap_or(0.0);
        delta.insert("a".to_string(), json!(round_2(curr_acc - prev_acc)));

        let prev_alt = prev_coords.get("altitude").and_then(to_f64).unwrap_or(0.0);
        let curr_alt = curr_coords.get("altitude").and_then(to_f64).unwrap_or(0.0);
        delta.insert("al".to_string(), json!(round_2(curr_alt - prev_alt)));
    }

    // Battery delta.
    if let (Some(prev_batt), Some(curr_batt)) = (prev.get("battery"), curr.get("battery")) {
        let prev_lvl = prev_batt.get("level").and_then(to_f64).unwrap_or(0.0);
        let curr_lvl = curr_batt.get("level").and_then(to_f64).unwrap_or(0.0);
        delta.insert("b".to_string(), json!(round_n(curr_lvl - prev_lvl, 4)));
    }

    Value::Object(delta)
}

fn to_f64(v: &Value) -> Option<f64> {
    v.as_f64().or_else(|| v.as_i64().map(|i| i as f64))
}

fn round_2(val: f64) -> f64 {
    (val * 100.0).round() / 100.0
}

fn round_n(val: f64, places: i32) -> f64 {
    let f = 10_f64.powi(places);
    (val * f).round() / f
}

fn shortest_arc(from: f64, to: f64) -> f64 {
    let mut diff = to - from;
    while diff > 180.0 {
        diff -= 360.0;
    }
    while diff < -180.0 {
        diff += 360.0;
    }
    diff
}
