use std::{
    net::{IpAddr, Ipv4Addr, SocketAddr},
    sync::{
        Arc,
        atomic::{AtomicU64, Ordering},
    },
    time::{Duration, SystemTime, UNIX_EPOCH},
};

use axum::{Router, extract::State, http::StatusCode, routing::get};
use tracing::info;

use crate::metrics;

#[derive(Debug)]
pub struct HealthState {
    max_stale_seconds: u64,
    last_successful_scan_unix_seconds: AtomicU64,
}

impl HealthState {
    pub fn new(max_stale: Duration) -> Arc<Self> {
        Arc::new(Self {
            max_stale_seconds: max_stale.as_secs().max(1),
            last_successful_scan_unix_seconds: AtomicU64::new(current_unix_seconds()),
        })
    }

    pub fn mark_successful_scan(&self) {
        self.mark_successful_scan_at(current_unix_seconds());
    }

    fn mark_successful_scan_at(&self, timestamp: u64) {
        self.last_successful_scan_unix_seconds.store(timestamp, Ordering::Relaxed);
    }

    fn is_fresh(&self) -> bool {
        let last_scan = self.last_successful_scan_unix_seconds.load(Ordering::Relaxed);
        current_unix_seconds().saturating_sub(last_scan) <= self.max_stale_seconds
    }
}

fn current_unix_seconds() -> u64 {
    SystemTime::now().duration_since(UNIX_EPOCH).map_or(0, |duration| duration.as_secs())
}

pub async fn spawn_server(
    port: u16,
    health: Arc<HealthState>,
    shutdown: impl std::future::Future<Output = ()> + Send + 'static,
) -> eyre::Result<()> {
    let router = router(health);

    let socket = SocketAddr::new(IpAddr::V4(Ipv4Addr::new(0, 0, 0, 0)), port);

    let listener = tokio::net::TcpListener::bind(socket)
        .await
        .map_err(|error| eyre::eyre!("failed to bind {socket}: {error}"))?;

    info!("Server listening on http://{}", socket);

    axum::serve(listener, router)
        .with_graceful_shutdown(shutdown)
        .await
        .map_err(|error| eyre::eyre!("failed to start server: {error}"))?;

    Ok(())
}

pub fn router(health: Arc<HealthState>) -> Router {
    Router::new().route("/healthz", get(health_handler)).with_state(health).merge(metrics::router())
}

async fn health_handler(State(health): State<Arc<HealthState>>) -> (StatusCode, &'static str) {
    if health.is_fresh() {
        (StatusCode::OK, "rollup-monitor is running")
    } else {
        (StatusCode::SERVICE_UNAVAILABLE, "rollup-monitor scan loop is stale")
    }
}

#[cfg(test)]
mod tests {
    use axum::{
        body::{Body, to_bytes},
        http::{Request, StatusCode},
    };
    use tower::ServiceExt;

    use super::{HealthState, router};

    #[tokio::test]
    async fn healthz_route_returns_ok() {
        let health = HealthState::new(std::time::Duration::from_secs(30));
        let response = router(health)
            .oneshot(
                Request::builder()
                    .uri("/healthz")
                    .body(Body::empty())
                    .expect("request should build"),
            )
            .await
            .expect("response should succeed");

        assert_eq!(response.status(), StatusCode::OK);
        let body = to_bytes(response.into_body(), usize::MAX).await.expect("body should decode");
        assert_eq!(body.as_ref(), b"rollup-monitor is running");
    }

    #[tokio::test]
    async fn healthz_route_returns_unavailable_when_scan_is_stale() {
        let health = HealthState::new(std::time::Duration::from_secs(30));
        health.mark_successful_scan_at(0);

        let response = router(health)
            .oneshot(
                Request::builder()
                    .uri("/healthz")
                    .body(Body::empty())
                    .expect("request should build"),
            )
            .await
            .expect("response should succeed");

        assert_eq!(response.status(), StatusCode::SERVICE_UNAVAILABLE);
        let body = to_bytes(response.into_body(), usize::MAX).await.expect("body should decode");
        assert_eq!(body.as_ref(), b"rollup-monitor scan loop is stale");
    }

    #[tokio::test]
    async fn metrics_route_returns_prometheus_text() {
        crate::metrics::inc_scan_error("l1", "test");

        let response = router(HealthState::new(std::time::Duration::from_secs(30)))
            .oneshot(
                Request::builder()
                    .uri("/metrics")
                    .body(Body::empty())
                    .expect("request should build"),
            )
            .await
            .expect("response should succeed");

        assert_eq!(response.status(), StatusCode::OK);
        let body = to_bytes(response.into_body(), usize::MAX).await.expect("body should decode");
        let text = String::from_utf8(body.to_vec()).expect("metrics should be utf8");
        assert!(text.contains("rollup_monitor_scan_errors_total"));
    }
}
