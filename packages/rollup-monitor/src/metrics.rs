use axum::{Router, http::StatusCode, response::IntoResponse};
use once_cell::sync::Lazy;
use prometheus::{Encoder, IntCounterVec, IntGaugeVec, Opts, Registry, core::Collector};

static REGISTRY: Lazy<Registry> = Lazy::new(Registry::new);
static METRICS_INIT: std::sync::Once = std::sync::Once::new();

static PROXY_UPGRADES_TOTAL: Lazy<IntCounterVec> = Lazy::new(|| {
    new_int_counter_vec(
        "rollup_monitor_proxy_upgrades_total",
        "Unexpected and expected proxy upgrade events observed",
        &["chain", "target", "expected"],
    )
});

static OWNERSHIP_TRANSFERS_TOTAL: Lazy<IntCounterVec> = Lazy::new(|| {
    new_int_counter_vec(
        "rollup_monitor_ownership_transfers_total",
        "Ownership transfer events observed",
        &["chain", "target", "expected"],
    )
});

static ROLE_CHANGES_TOTAL: Lazy<IntCounterVec> = Lazy::new(|| {
    new_int_counter_vec(
        "rollup_monitor_role_changes_total",
        "Role grant and revoke events observed",
        &["chain", "target", "action"],
    )
});

static PAUSE_EVENTS_TOTAL: Lazy<IntCounterVec> = Lazy::new(|| {
    new_int_counter_vec(
        "rollup_monitor_pause_events_total",
        "Pause and unpause events observed",
        &["chain", "target", "action"],
    )
});

static SAFE_TRANSACTIONS_TOTAL: Lazy<IntCounterVec> = Lazy::new(|| {
    new_int_counter_vec(
        "rollup_monitor_safe_transactions_total",
        "Safe transaction events observed",
        &["chain", "safe", "operation"],
    )
});

static UNEXPECTED_EOA_TRANSACTIONS_TOTAL: Lazy<IntCounterVec> = Lazy::new(|| {
    new_int_counter_vec(
        "rollup_monitor_unexpected_eoa_transactions_total",
        "Unexpected watched EOA transactions observed",
        &["chain", "allowed"],
    )
});

static LARGE_WITHDRAWALS_TOTAL: Lazy<IntCounterVec> = Lazy::new(|| {
    new_int_counter_vec(
        "rollup_monitor_large_withdrawals_total",
        "Bridge or vault withdrawals over configured threshold",
        &["chain", "target"],
    )
});

static NON_WHITELISTED_PROVERS_TOTAL: Lazy<IntCounterVec> = Lazy::new(|| {
    new_int_counter_vec(
        "rollup_monitor_non_whitelisted_provers_total",
        "Proof events from non-whitelisted provers",
        &["chain"],
    )
});

static NON_WHITELISTED_PROPOSERS_TOTAL: Lazy<IntCounterVec> = Lazy::new(|| {
    new_int_counter_vec(
        "rollup_monitor_non_whitelisted_proposers_total",
        "Proposal events from non-whitelisted proposers",
        &["chain"],
    )
});

static VERIFIER_CHANGES_TOTAL: Lazy<IntCounterVec> = Lazy::new(|| {
    new_int_counter_vec(
        "rollup_monitor_verifier_changes_total",
        "Verifier configuration changes observed",
        &["chain", "target", "expected"],
    )
});

static SGX_ANOMALIES_TOTAL: Lazy<IntCounterVec> = Lazy::new(|| {
    new_int_counter_vec(
        "rollup_monitor_sgx_anomalies_total",
        "SGX or TEE registration anomalies observed",
        &["chain", "reason"],
    )
});

static PROPOSAL_REORGS_TOTAL: Lazy<IntCounterVec> = Lazy::new(|| {
    new_int_counter_vec(
        "rollup_monitor_proposal_reorgs_total",
        "Inbox proposal observations that changed block or transaction after being seen",
        &["chain"],
    )
});

static SCAN_ERRORS_TOTAL: Lazy<IntCounterVec> = Lazy::new(|| {
    new_int_counter_vec(
        "rollup_monitor_scan_errors_total",
        "Rollup monitor scan errors",
        &["chain", "check"],
    )
});

static LAST_SCANNED_BLOCK: Lazy<IntGaugeVec> = Lazy::new(|| {
    new_int_gauge_vec(
        "rollup_monitor_last_scanned_block",
        "Last block scanned by rollup monitor",
        &["chain"],
    )
});

static SAFE_HEAD_BLOCK: Lazy<IntGaugeVec> = Lazy::new(|| {
    new_int_gauge_vec(
        "rollup_monitor_safe_head_block",
        "Latest safe head block used by rollup monitor",
        &["chain"],
    )
});

static SCAN_LAG_BLOCKS: Lazy<IntGaugeVec> = Lazy::new(|| {
    new_int_gauge_vec(
        "rollup_monitor_scan_lag_blocks",
        "Rollup monitor lag between safe head and last scanned block",
        &["chain"],
    )
});

fn new_int_counter_vec(name: &str, help: &str, labels: &[&str]) -> IntCounterVec {
    IntCounterVec::new(Opts::new(name, help), labels)
        .unwrap_or_else(|error| panic!("failed to create metric {name}: {error}"))
}

fn new_int_gauge_vec(name: &str, help: &str, labels: &[&str]) -> IntGaugeVec {
    IntGaugeVec::new(Opts::new(name, help), labels)
        .unwrap_or_else(|error| panic!("failed to create metric {name}: {error}"))
}

fn register_metric(name: &str, collector: Box<dyn Collector>) {
    if let Err(error) = REGISTRY.register(collector) {
        panic!("failed to register metric {name}: {error}");
    }
}

fn clamp_u64_to_i64(value: u64) -> i64 {
    i64::try_from(value).unwrap_or(i64::MAX)
}

pub fn init() {
    METRICS_INIT.call_once(|| {
        register_metric(
            "rollup_monitor_proxy_upgrades_total",
            Box::new(PROXY_UPGRADES_TOTAL.clone()),
        );
        register_metric(
            "rollup_monitor_ownership_transfers_total",
            Box::new(OWNERSHIP_TRANSFERS_TOTAL.clone()),
        );
        register_metric("rollup_monitor_role_changes_total", Box::new(ROLE_CHANGES_TOTAL.clone()));
        register_metric("rollup_monitor_pause_events_total", Box::new(PAUSE_EVENTS_TOTAL.clone()));
        register_metric(
            "rollup_monitor_safe_transactions_total",
            Box::new(SAFE_TRANSACTIONS_TOTAL.clone()),
        );
        register_metric(
            "rollup_monitor_unexpected_eoa_transactions_total",
            Box::new(UNEXPECTED_EOA_TRANSACTIONS_TOTAL.clone()),
        );
        register_metric(
            "rollup_monitor_large_withdrawals_total",
            Box::new(LARGE_WITHDRAWALS_TOTAL.clone()),
        );
        register_metric(
            "rollup_monitor_non_whitelisted_provers_total",
            Box::new(NON_WHITELISTED_PROVERS_TOTAL.clone()),
        );
        register_metric(
            "rollup_monitor_non_whitelisted_proposers_total",
            Box::new(NON_WHITELISTED_PROPOSERS_TOTAL.clone()),
        );
        register_metric(
            "rollup_monitor_verifier_changes_total",
            Box::new(VERIFIER_CHANGES_TOTAL.clone()),
        );
        register_metric(
            "rollup_monitor_sgx_anomalies_total",
            Box::new(SGX_ANOMALIES_TOTAL.clone()),
        );
        register_metric(
            "rollup_monitor_proposal_reorgs_total",
            Box::new(PROPOSAL_REORGS_TOTAL.clone()),
        );
        register_metric("rollup_monitor_scan_errors_total", Box::new(SCAN_ERRORS_TOTAL.clone()));
        register_metric("rollup_monitor_last_scanned_block", Box::new(LAST_SCANNED_BLOCK.clone()));
        register_metric("rollup_monitor_safe_head_block", Box::new(SAFE_HEAD_BLOCK.clone()));
        register_metric("rollup_monitor_scan_lag_blocks", Box::new(SCAN_LAG_BLOCKS.clone()));
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

pub fn inc_scan_error(chain: &str, check: &str) {
    SCAN_ERRORS_TOTAL.with_label_values(&[chain, check]).inc();
}

pub fn inc_non_whitelisted_prover(chain: &str) {
    NON_WHITELISTED_PROVERS_TOTAL.with_label_values(&[chain]).inc();
}

pub fn inc_non_whitelisted_proposer(chain: &str) {
    NON_WHITELISTED_PROPOSERS_TOTAL.with_label_values(&[chain]).inc();
}

pub fn inc_large_withdrawal(chain: &str, target: &str) {
    LARGE_WITHDRAWALS_TOTAL.with_label_values(&[chain, target]).inc();
}

pub fn inc_pause_event(chain: &str, target: &str, action: &str) {
    PAUSE_EVENTS_TOTAL.with_label_values(&[chain, target, action]).inc();
}

pub fn inc_proxy_upgrade(chain: &str, target: &str, expected: bool) {
    PROXY_UPGRADES_TOTAL.with_label_values(&[chain, target, bool_label(expected)]).inc();
}

pub fn inc_ownership_transfer(chain: &str, target: &str, expected: bool) {
    OWNERSHIP_TRANSFERS_TOTAL.with_label_values(&[chain, target, bool_label(expected)]).inc();
}

pub fn inc_role_change(chain: &str, target: &str, action: &str) {
    ROLE_CHANGES_TOTAL.with_label_values(&[chain, target, action]).inc();
}

pub fn inc_safe_transaction(chain: &str, safe: &str, operation: &str) {
    SAFE_TRANSACTIONS_TOTAL.with_label_values(&[chain, safe, operation]).inc();
}

pub fn inc_unexpected_eoa_transaction(chain: &str, allowed: bool) {
    UNEXPECTED_EOA_TRANSACTIONS_TOTAL.with_label_values(&[chain, bool_label(allowed)]).inc();
}

pub fn inc_verifier_change(chain: &str, target: &str, expected: bool) {
    VERIFIER_CHANGES_TOTAL.with_label_values(&[chain, target, bool_label(expected)]).inc();
}

pub fn inc_sgx_anomaly(chain: &str, reason: &str) {
    SGX_ANOMALIES_TOTAL.with_label_values(&[chain, reason]).inc();
}

pub fn inc_proposal_reorg(chain: &str) {
    PROPOSAL_REORGS_TOTAL.with_label_values(&[chain]).inc();
}

fn bool_label(value: bool) -> &'static str {
    if value { "true" } else { "false" }
}

pub fn set_scan_position(chain: &str, last_scanned: u64, safe_head: u64) {
    LAST_SCANNED_BLOCK.with_label_values(&[chain]).set(clamp_u64_to_i64(last_scanned));
    SAFE_HEAD_BLOCK.with_label_values(&[chain]).set(clamp_u64_to_i64(safe_head));
    SCAN_LAG_BLOCKS
        .with_label_values(&[chain])
        .set(clamp_u64_to_i64(safe_head.saturating_sub(last_scanned)));
}

#[cfg(test)]
mod tests {
    use super::{inc_pause_event, init, set_scan_position};
    use prometheus::Encoder;

    #[test]
    fn metrics_encode_contains_registered_metrics() {
        init();
        inc_pause_event("l1", "bridge", "paused");
        set_scan_position("l1", 100, 120);

        let metrics = super::REGISTRY.gather();
        let encoder = prometheus::TextEncoder::new();
        let mut buffer = Vec::new();
        encoder.encode(&metrics, &mut buffer).expect("metrics should encode");
        let text = String::from_utf8(buffer).expect("metrics should be utf8");

        assert!(text.contains("rollup_monitor_pause_events_total"));
        assert!(text.contains("rollup_monitor_scan_lag_blocks"));
    }
}
