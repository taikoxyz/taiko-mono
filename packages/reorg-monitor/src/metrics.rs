use std::{convert::TryFrom, sync::Once};

use axum::{Router, http::StatusCode, response::IntoResponse};
use once_cell::sync::Lazy;
use prometheus::{Encoder, IntCounter, IntGauge, Registry, core::Collector};

static REGISTRY: Lazy<Registry> = Lazy::new(Registry::new);
static METRICS_INIT: Once = Once::new();

static L2_BLOCKS_TOTAL: Lazy<IntCounter> =
    Lazy::new(|| new_int_counter("l2_blocks_total", "Total number of L2 blocks observed"));

static WS_RECONNECTIONS_TOTAL: Lazy<IntCounter> = Lazy::new(|| {
    new_int_counter("ws_reconnections_total", "Total number of websocket reconnections")
});

static REORG_COUNT_TOTAL: Lazy<IntCounter> =
    Lazy::new(|| new_int_counter("reorg_count_total", "Total number of L2 reorg events observed"));

static REORG_BLOCKS_REPLACED_TOTAL: Lazy<IntCounter> = Lazy::new(|| {
    new_int_counter(
        "reorg_blocks_replaced_total",
        "Total number of blocks replaced across all reorg events",
    )
});

static TRACKER_PARENT_NOT_FOUND_TOTAL: Lazy<IntCounter> = Lazy::new(|| {
    new_int_counter(
        "reorg_tracker_parent_not_found_total",
        "Reorg tracker resets triggered because parent block was not found in local history",
    )
});

static DUPLICATE_BLOCK_NOTIFICATIONS_TOTAL: Lazy<IntCounter> = Lazy::new(|| {
    new_int_counter(
        "duplicate_block_notifications_total",
        "Duplicate block notifications ignored by the reorg monitor",
    )
});

static LAST_BLOCK_AGE_SECONDS: Lazy<IntGauge> = Lazy::new(|| {
    new_int_gauge("last_block_age_seconds", "Seconds since the monitor observed an L2 block header")
});

static LAST_BLOCK_NUMBER: Lazy<IntGauge> = Lazy::new(|| {
    new_int_gauge("last_block_number", "Latest L2 block number observed by the monitor")
});

static REORG_DEPTH_BLOCKS: Lazy<IntGauge> = Lazy::new(|| {
    new_int_gauge("reorg_depth_blocks", "Number of blocks replaced in the most recent reorg event")
});

static LAST_REORGED_TO: Lazy<IntGauge> = Lazy::new(|| {
    new_int_gauge("last_reorged_to", "Revert height of the latest reorg (-1 when unknown)")
});

fn new_int_counter(name: &str, help: &str) -> IntCounter {
    match IntCounter::new(name, help) {
        Ok(metric) => metric,
        Err(error) => panic!("failed to create metric {name}: {error}"),
    }
}

fn new_int_gauge(name: &str, help: &str) -> IntGauge {
    match IntGauge::new(name, help) {
        Ok(metric) => metric,
        Err(error) => panic!("failed to create metric {name}: {error}"),
    }
}

fn register_metric(name: &str, collector: Box<dyn Collector>) {
    if let Err(error) = REGISTRY.register(collector) {
        panic!("failed to register metric {name}: {error}");
    }
}

fn clamp_u64_to_i64(value: u64) -> i64 {
    i64::try_from(value).unwrap_or(i64::MAX)
}

fn clamp_usize_to_i64(value: usize) -> i64 {
    i64::try_from(value).unwrap_or(i64::MAX)
}

fn clamp_usize_to_u64(value: usize) -> u64 {
    u64::try_from(value).unwrap_or(u64::MAX)
}

pub fn init() {
    METRICS_INIT.call_once(|| {
        register_metric("l2_blocks_total", Box::new(L2_BLOCKS_TOTAL.clone()));
        register_metric("ws_reconnections_total", Box::new(WS_RECONNECTIONS_TOTAL.clone()));
        register_metric("reorg_count_total", Box::new(REORG_COUNT_TOTAL.clone()));
        register_metric(
            "reorg_blocks_replaced_total",
            Box::new(REORG_BLOCKS_REPLACED_TOTAL.clone()),
        );
        register_metric(
            "reorg_tracker_parent_not_found_total",
            Box::new(TRACKER_PARENT_NOT_FOUND_TOTAL.clone()),
        );
        register_metric(
            "duplicate_block_notifications_total",
            Box::new(DUPLICATE_BLOCK_NOTIFICATIONS_TOTAL.clone()),
        );
        register_metric("last_block_age_seconds", Box::new(LAST_BLOCK_AGE_SECONDS.clone()));
        register_metric("last_block_number", Box::new(LAST_BLOCK_NUMBER.clone()));
        register_metric("reorg_depth_blocks", Box::new(REORG_DEPTH_BLOCKS.clone()));
        register_metric("last_reorged_to", Box::new(LAST_REORGED_TO.clone()));
    });
}

pub fn router() -> Router {
    init();
    Router::new().route("/metrics", axum::routing::get(metrics_handler))
}

async fn metrics_handler() -> impl IntoResponse {
    let metrics = REGISTRY.gather();
    let encoder = prometheus::TextEncoder::new();
    let mut buffer = Vec::new();

    if let Err(error) = encoder.encode(&metrics, &mut buffer) {
        tracing::error!("could not encode prometheus metrics: {error}");
        return (StatusCode::INTERNAL_SERVER_ERROR, "could not encode metrics").into_response();
    }

    (StatusCode::OK, [(axum::http::header::CONTENT_TYPE, encoder.format_type())], buffer)
        .into_response()
}

pub fn inc_l2_blocks() {
    L2_BLOCKS_TOTAL.inc();
}

pub fn inc_ws_reconnections() {
    WS_RECONNECTIONS_TOTAL.inc();
}

pub fn inc_parent_not_found() {
    TRACKER_PARENT_NOT_FOUND_TOTAL.inc();
}

pub fn inc_duplicate_block_notifications() {
    DUPLICATE_BLOCK_NOTIFICATIONS_TOTAL.inc();
}

pub fn set_last_block_age_seconds(seconds: u64) {
    LAST_BLOCK_AGE_SECONDS.set(clamp_u64_to_i64(seconds));
}

pub fn set_last_block_number(block_number: u64) {
    LAST_BLOCK_NUMBER.set(clamp_u64_to_i64(block_number));
}

pub fn note_reorg(depth: usize, reverted_to: Option<u64>) {
    REORG_COUNT_TOTAL.inc();
    REORG_BLOCKS_REPLACED_TOTAL.inc_by(clamp_usize_to_u64(depth));
    REORG_DEPTH_BLOCKS.set(clamp_usize_to_i64(depth));
    match reverted_to {
        Some(height) => LAST_REORGED_TO.set(clamp_u64_to_i64(height)),
        None => LAST_REORGED_TO.set(-1),
    }
}
