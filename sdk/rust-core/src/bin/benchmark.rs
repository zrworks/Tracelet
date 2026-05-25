use std::time::Instant;
use std::collections::HashMap;
use std::fs::File;
use std::io::Write;
use tracelet_core::state::battery_budget::BatteryBudgetEngine;
use tracelet_core::state::smart_motion_coordinator::{SmartMotionCoordinator, TrackingMode};

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
    
    results.push(bench("battery_budget_single_sample", || {
        let engine = BatteryBudgetEngine::new(5.0, 10.0, 1, None);
        engine.process_sample(0.75, 1000);
    }));

    results.push(bench("battery_budget_60_samples", || {
        let engine = BatteryBudgetEngine::new(5.0, 10.0, 1, None);
        for i in 0..60 {
            engine.process_sample(1.0 - (i as f64) * 0.01, (i as i64) * 60_000);
        }
    }));

    results.push(bench("battery_budget_heavy_drain", || {
        let engine = BatteryBudgetEngine::new(3.0, 10.0, 1, None);
        for i in 0..120 {
            engine.process_sample(1.0 - (i as f64) * 0.005, (i as i64) * 60_000);
        }
    }));

    results.push(bench("smart_motion_accel_change", || {
        let coordinator = SmartMotionCoordinator::new(false);
        coordinator.on_accel_state_change(true);
        coordinator.on_accel_state_change(false);
    }));

    results.push(bench("smart_motion_speed_change", || {
        let coordinator = SmartMotionCoordinator::new(false);
        coordinator.on_speed_state_change(false);
        coordinator.on_speed_state_change(true);
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
