use axum::{Router, http::StatusCode, response::IntoResponse};
use once_cell::sync::Lazy;
use prometheus::{Encoder, IntCounter, IntCounterVec, IntGauge, Registry};
use std::convert::TryFrom;

// registry we can re-use
static REGISTRY: Lazy<Registry> = Lazy::new(Registry::new);

// metrics handles
static L2_BLOCKS_TOTAL: Lazy<IntCounter> = Lazy::new(|| {
    IntCounter::new("l2_blocks_total", "Total number of l2 blocks observed")
        .expect("l2_blocks_total metric can be created")
});

static EJECTIONS_TOTAL: Lazy<IntCounterVec> = Lazy::new(|| {
    IntCounterVec::new(
        prometheus::opts!("ejections_total", "total number of ejections attempted"),
        &["status", "addr"],
    )
    .expect("ejections_total metric can be created")
});

static WS_RECONNECTIONS_TOTAL: Lazy<IntCounter> = Lazy::new(|| {
    IntCounter::new("ws_reconnections_total", "Total number of websocket reconnections")
        .expect("ws_reconnections_total metric can be created")
});

static LAST_SEEN_DRIFT_SECONDS: Lazy<IntGauge> = Lazy::new(|| {
    IntGauge::new(
        "last_seen_drift_seconds",
        "Seconds since the ejector watchdog last reset its timer",
    )
    .expect("last_seen_drift_seconds metric can be created")
});

static LAST_BLOCK_AGE_SECONDS: Lazy<IntGauge> = Lazy::new(|| {
    IntGauge::new("last_block_age_seconds", "Seconds since the ejector observed an L2 block header")
        .expect("last_block_age_seconds metric can be created")
});

static REORG_COUNT_TOTAL: Lazy<IntCounter> = Lazy::new(|| {
    IntCounter::new("reorg_count_total", "Total number of L2 reorg events observed")
        .expect("reorg_count_total metric can be created")
});

static REORG_SKIPPED_TOTAL: Lazy<IntCounter> = Lazy::new(|| {
    IntCounter::new("reorg_skipped_total", "Reorg events observed but below the eject threshold")
        .expect("reorg_skipped_total metric can be created")
});

static REORG_DEPTH_BLOCKS: Lazy<IntGauge> = Lazy::new(|| {
    IntGauge::new("reorg_depth_blocks", "Number of blocks replaced in the most recent reorg event")
        .expect("reorg_depth_blocks metric can be created")
});

static LAST_REORGED_TO: Lazy<IntGauge> = Lazy::new(|| {
    IntGauge::new("last_reorged_to", "Revert height of the latest reorg")
        .expect("last_reorged_to metric can be created")
});

pub fn init() {
    REGISTRY
        .register(Box::new(L2_BLOCKS_TOTAL.clone()))
        .expect("l2_blocks_total metric can be registered");
    REGISTRY
        .register(Box::new(EJECTIONS_TOTAL.clone()))
        .expect("ejections_total metric can be registered");
    REGISTRY
        .register(Box::new(WS_RECONNECTIONS_TOTAL.clone()))
        .expect("ws_reconnections_total metric can be registered");
    REGISTRY
        .register(Box::new(LAST_SEEN_DRIFT_SECONDS.clone()))
        .expect("last_seen_drift_seconds metric can be registered");
    REGISTRY
        .register(Box::new(LAST_BLOCK_AGE_SECONDS.clone()))
        .expect("last_block_age_seconds metric can be registered");
    REGISTRY
        .register(Box::new(REORG_COUNT_TOTAL.clone()))
        .expect("reorg_count_total metric can be registered");
    REGISTRY
        .register(Box::new(REORG_SKIPPED_TOTAL.clone()))
        .expect("reorg_skipped_total metric can be registered");
    REGISTRY
        .register(Box::new(REORG_DEPTH_BLOCKS.clone()))
        .expect("reorg_depth_blocks metric can be registered");
    REGISTRY
        .register(Box::new(LAST_REORGED_TO.clone()))
        .expect("last_reorged_to metric can be registered");
}

pub fn router() -> axum::Router {
    init();
    Router::new().route("/metrics", axum::routing::get(metrics_handler))
}

async fn metrics_handler() -> impl IntoResponse {
    let metrics = REGISTRY.gather();
    let encoder = prometheus::TextEncoder::new();
    let mut buffer = Vec::new();
    if let Err(e) = encoder.encode(&metrics, &mut buffer) {
        tracing::error!("could not encode prometheus metrics: {}", e);
        return (StatusCode::INTERNAL_SERVER_ERROR, "could not encode metrics").into_response();
    }

    (StatusCode::OK, [(axum::http::header::CONTENT_TYPE, encoder.format_type())], buffer)
        .into_response()
}

// public functions to increment metrics
pub fn inc_l2_blocks() {
    L2_BLOCKS_TOTAL.inc();
}

pub fn ensure_eject_metric_labels(addr: &str) {
    let addr = addr.to_ascii_lowercase();
    let _ = EJECTIONS_TOTAL.with_label_values(&["success", &addr]);
    let _ = EJECTIONS_TOTAL.with_label_values(&["error", &addr]);
}

pub fn inc_eject_success(addr: &str) {
    let addr = addr.to_ascii_lowercase();
    EJECTIONS_TOTAL.with_label_values(&["success", &addr]).inc();
}
pub fn inc_eject_error(addr: &str) {
    let addr = addr.to_ascii_lowercase();
    EJECTIONS_TOTAL.with_label_values(&["error", &addr]).inc();
}

pub fn inc_ws_reconnections() {
    WS_RECONNECTIONS_TOTAL.inc();
}

pub fn set_last_seen_drift_seconds(seconds: u64) {
    let clamped_seconds = i64::try_from(seconds).unwrap_or(i64::MAX);
    LAST_SEEN_DRIFT_SECONDS.set(clamped_seconds);
}

pub fn set_last_block_age_seconds(seconds: u64) {
    let clamped_seconds = i64::try_from(seconds).unwrap_or(i64::MAX);
    LAST_BLOCK_AGE_SECONDS.set(clamped_seconds);
}

pub fn note_reorg(depth: usize, reorg_height: u64) {
    REORG_COUNT_TOTAL.inc();
    let clamped_depth = i64::try_from(depth).unwrap_or(i64::MAX);
    REORG_DEPTH_BLOCKS.set(clamped_depth);
    let clamped_height = i64::try_from(reorg_height).unwrap_or(i64::MAX);
    LAST_REORGED_TO.set(clamped_height);
}

pub fn inc_reorg_skipped() {
    REORG_SKIPPED_TOTAL.inc();
}
