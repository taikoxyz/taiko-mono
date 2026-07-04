//! Shared Prometheus registration helpers used by the client crates.

use prometheus::{
    Gauge, Histogram, HistogramOpts, HistogramVec, IntCounter, IntCounterVec, Opts, core::Collector,
};

/// Histogram buckets for operation durations expressed in seconds.
pub const DURATION_SECONDS_BUCKETS: &[f64] =
    &[0.01, 0.05, 0.1, 0.25, 0.5, 1.0, 2.5, 5.0, 10.0, 30.0, 60.0, 120.0];

/// Construct and register an integer counter with the process-wide registry.
pub fn counter(name: &str, help: &str) -> IntCounter {
    let metric = IntCounter::new(name, help)
        .unwrap_or_else(|error| panic!("failed to create Prometheus counter {name}: {error}"));
    register(metric.clone());
    metric
}

/// Construct and register a labelled integer counter family with the process-wide registry.
pub fn counter_vec(name: &str, help: &str, labels: &[&str]) -> IntCounterVec {
    let metric = IntCounterVec::new(Opts::new(name, help), labels).unwrap_or_else(|error| {
        panic!("failed to create Prometheus counter vector {name}: {error}")
    });
    register(metric.clone());
    metric
}

/// Construct and register a floating-point gauge with the process-wide registry.
pub fn gauge(name: &str, help: &str) -> Gauge {
    let metric = Gauge::new(name, help)
        .unwrap_or_else(|error| panic!("failed to create Prometheus gauge {name}: {error}"));
    register(metric.clone());
    metric
}

/// Construct and register a histogram with the process-wide registry.
pub fn histogram(name: &str, help: &str, buckets: &[f64]) -> Histogram {
    let metric = Histogram::with_opts(HistogramOpts::new(name, help).buckets(buckets.to_vec()))
        .unwrap_or_else(|error| panic!("failed to create Prometheus histogram {name}: {error}"));
    register(metric.clone());
    metric
}

/// Construct and register a labelled histogram family with the process-wide registry.
pub fn histogram_vec(name: &str, help: &str, labels: &[&str], buckets: &[f64]) -> HistogramVec {
    let metric =
        HistogramVec::new(HistogramOpts::new(name, help).buckets(buckets.to_vec()), labels)
            .unwrap_or_else(|error| {
                panic!("failed to create Prometheus histogram vector {name}: {error}")
            });
    register(metric.clone());
    metric
}

/// Register one collector with the process-wide Prometheus registry.
fn register<C>(collector: C)
where
    C: Collector + Clone + 'static,
{
    prometheus::register(Box::new(collector))
        .unwrap_or_else(|error| panic!("failed to register Prometheus collector: {error}"));
}
