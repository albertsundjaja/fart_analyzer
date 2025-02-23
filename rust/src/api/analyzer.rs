use hound;
use rustfft::{FftPlanner, num_complex::Complex};
use std::iter::repeat;
use flutter_rust_bridge::frb;

/// Compute RMS (Root Mean Square) Loudness in dB
fn compute_loudness(samples: &[f32]) -> f32 {
    let sum_of_squares: f32 = samples.iter().map(|&s| s * s).sum();
    let rms = (sum_of_squares / samples.len() as f32).sqrt();
    20.0 * rms.log10()  // Convert to decibels (dB)
}

/// Compute FFT and find the dominant frequency
fn compute_dominant_frequency(samples: &[f32], sample_rate: f32) -> f32 {
    let fft_size = samples.len().next_power_of_two();
    let mut input: Vec<Complex<f32>> = samples.iter().map(|&s| Complex::new(s, 0.0)).collect();
    input.extend(repeat(Complex::new(0.0, 0.0)).take(fft_size - input.len()));

    // Perform FFT
    let mut planner = FftPlanner::new();
    let fft = planner.plan_fft_forward(fft_size);
    fft.process(&mut input);

    // Compute magnitudes
    let magnitudes: Vec<f32> = input.iter().map(|c| c.norm()).collect();

    // Find peak frequency index
    let max_index = magnitudes.iter().enumerate().max_by(|a, b| a.1.partial_cmp(b.1).unwrap()).unwrap().0;

    // Convert index to frequency
    (max_index as f32) * (sample_rate / fft_size as f32)
}

/// Structure to return analysis results
#[frb(sync)]  // Make this function callable from Dart synchronously
#[derive(Debug, Clone)]
pub struct FartAnalysisResult {
    pub loudness_db: f32,
    pub duration: f32,
    pub dominant_freq: f32,
}

#[frb(sync)]
pub fn analyze_fart(samples: Vec<f32>, sample_rate: f32) -> FartAnalysisResult {
    let loudness_db = compute_loudness(&samples);
    let dominant_freq = compute_dominant_frequency(&samples, sample_rate);
    let duration = samples.len() as f32 / sample_rate;

    FartAnalysisResult {
        loudness_db,
        duration,
        dominant_freq,
    }
}

// fn main() {
//     // Load WAV file
//     let mut reader = hound::WavReader::open("output.wav").expect("Failed to open file");
//     let spec = reader.spec();
//     let sample_rate = spec.sample_rate as f32;

//     // Convert samples to f32
//     let samples: Vec<f32> = reader.samples::<i16>().map(|s| s.unwrap() as f32).collect();

//     // Compute features
//     let loudness_db = compute_loudness(&samples);
//     let dominant_freq = compute_dominant_frequency(&samples, sample_rate);
//     let duration = samples.len() as f32 / sample_rate;

//     // Print results
//     println!("Fart Analysis:");
//     println!("  Loudness: {:.2} dB", loudness_db);
//     println!("  Duration: {:.2} seconds", duration);
//     println!("  Dominant Frequency: {:.2} Hz", dominant_freq);
// }
