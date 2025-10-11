use axum::{Router, http::StatusCode, response::IntoResponse};
use once_cell::sync::Lazy;
use prometheus::{Encoder, IntCounter, IntCounterVec, Registry};

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

pub fn inc_eject_success(addr: &str) {
    EJECTIONS_TOTAL.with_label_values(&["success", addr]).inc();
}
pub fn inc_eject_error(addr: &str) {
    EJECTIONS_TOTAL.with_label_values(&["error", addr]).inc();
}

pub fn inc_ws_reconnections() {
    WS_RECONNECTIONS_TOTAL.inc();
}
