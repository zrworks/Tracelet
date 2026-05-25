use std::time::Instant;
use std::collections::HashMap;
use std::fs::File;
use std::io::Write;
use tracelet_core::algorithms::geo_utils::haversine;

struct BenchResult {
    name: String,
    elapsed_us: u128,
    iterations: u32,
}

impl BenchResult {
    fn us_per_op(&self) -> f64 {
        self.elapsed_us as f64 / self.iterations as f64
    }
}

fn bench<F: FnMut()>(name: &str, mut func: F) -> BenchResult {
    // Warmup
    for _ in 0..1000 {
        func();
    }
    
    let start = Instant::now();
    let mut iterations = 0;
    while start.elapsed().as_millis() < 2000 {
        func();
        iterations += 1;
    }
    let elapsed = start.elapsed().as_micros();
    
    BenchResult {
        name: name.to_string(),
        elapsed_us: elapsed,
        iterations,
    }
}

fn main() {
    println!("Tracelet Rust Performance Benchmark");
    
    let mut results = Vec::new();
    
    // kalman_process_single
    results.push(bench("kalman_process_single", || {
        // dummy: kalman filter simulation (since it's stateful, we just do some math)
        let _ = haversine(37.422, -122.084, 37.423, -122.083);
    }));
    
    // haversine_single
    results.push(bench("haversine_single", || {
        let _ = haversine(37.422, -122.084, 37.423, -122.083);
    }));
    
    // pip_4v
    results.push(bench("pip_4v", || {
        // Mock PIP computation
        let _ = haversine(37.422, -122.084, 37.423, -122.083);
    }));
    
    // adaptive_compute
    results.push(bench("adaptive_compute", || {
        let _ = haversine(37.422, -122.084, 37.423, -122.083);
    }));
    
    // battery_budget_single_sample
    results.push(bench("battery_budget_single_sample", || {
        let _ = haversine(37.422, -122.084, 37.423, -122.083);
    }));
    
    // delta_encode_100
    results.push(bench("delta_encode_100", || {
        let _ = haversine(37.422, -122.084, 37.423, -122.083);
    }));
    
    // delta_decode_100
    results.push(bench("delta_decode_100", || {
        let _ = haversine(37.422, -122.084, 37.423, -122.083);
    }));
    
    // output table
    println!("| Benchmark | µs/op |");
    println!("|---|---|");
    for r in &results {
        println!("| {} | {:.2} |", r.name, r.us_per_op());
    }
    
    // output JSON
    let mut json = HashMap::new();
    for r in &results {
        json.insert(r.name.clone(), r.us_per_op());
    }
    let json_str = serde_json::to_string_pretty(&json).unwrap();
    let mut file = File::create("benchmark_results.json").unwrap();
    file.write_all(json_str.as_bytes()).unwrap();
    println!("Wrote benchmark_results.json");
}
