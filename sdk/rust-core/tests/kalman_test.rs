use serde::Deserialize;
use std::fs::File;
use std::io::BufReader;
use tracelet_core::algorithms::kalman::KalmanLocationFilter;

#[derive(Deserialize, Debug)]
struct TestVector {
    sequences: Vec<Sequence>,
}

#[derive(Deserialize, Debug)]
struct Sequence {
    description: String,
    action: Option<String>,
    inputs: Option<Vec<Input>>,
    expected_outputs: Option<Vec<ExpectedOutput>>,
    inputs_before_reset: Option<Vec<Input>>,
    inputs_after_reset: Option<Vec<Input>>,
    expected_after_reset: Option<ExpectedOutput>,
}

#[derive(Deserialize, Debug, Clone)]
struct Input {
    latitude: f64,
    longitude: f64,
    accuracy: f64,
    speed: f64,
    timestamp_ms: i64,
}

#[derive(Deserialize, Debug)]
struct ExpectedOutput {
    latitude: Option<f64>,
    longitude: Option<f64>,
    latitude_range: Option<[f64; 2]>,
    longitude_range: Option<[f64; 2]>,
    latitude_should_not_exceed: Option<f64>,
}

#[test]
fn test_kalman_vectors() {
    let file = File::open("../../algorithms/kalman_test_vectors.json").unwrap();
    let reader = BufReader::new(file);
    let test_vector: TestVector = serde_json::from_reader(reader).unwrap();

    for seq in test_vector.sequences {
        println!("Running sequence: {}", seq.description);
        let filter = KalmanLocationFilter::new();

        if seq.action.as_deref() == Some("reset_before_second_sequence") {
            for input in seq.inputs_before_reset.unwrap() {
                filter.process(
                    input.latitude,
                    input.longitude,
                    input.accuracy,
                    input.timestamp_ms,
                );
            }
            filter.reset();
            let input = seq.inputs_after_reset.unwrap()[0].clone();
            let out = filter.process(
                input.latitude,
                input.longitude,
                input.accuracy,
                input.timestamp_ms,
            );
            let expected = seq.expected_after_reset.unwrap();
            assert!((out.latitude - expected.latitude.unwrap()).abs() < 0.000005);
            assert!((out.longitude - expected.longitude.unwrap()).abs() < 0.000005);
        } else {
            let inputs = seq.inputs.unwrap();
            let expected_outputs = seq.expected_outputs.unwrap();

            for (input, expected) in inputs.iter().zip(expected_outputs.iter()) {
                let out = filter.process(
                    input.latitude,
                    input.longitude,
                    input.accuracy,
                    input.timestamp_ms,
                );

                if let Some(lat) = expected.latitude {
                    assert!((out.latitude - lat).abs() < 0.000005);
                }
                if let Some(lng) = expected.longitude {
                    assert!((out.longitude - lng).abs() < 0.000005);
                }
                if let Some(lat_range) = expected.latitude_range {
                    assert!(out.latitude >= lat_range[0] && out.latitude <= lat_range[1]);
                }
                if let Some(lng_range) = expected.longitude_range {
                    assert!(out.longitude >= lng_range[0] && out.longitude <= lng_range[1]);
                }
                if let Some(max_lat) = expected.latitude_should_not_exceed {
                    assert!(out.latitude <= max_lat);
                }
            }
        }
    }
}
