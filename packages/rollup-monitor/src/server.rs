use std::net::{IpAddr, Ipv4Addr, SocketAddr};

use axum::{Router, http::StatusCode, routing::get};
use tracing::info;

use crate::metrics;

pub async fn spawn_server(
    port: u64,
    shutdown: impl std::future::Future<Output = ()> + Send + 'static,
) -> eyre::Result<()> {
    let router = router();

    let port = u16::try_from(port).map_err(|_| eyre::eyre!("port out of range: {port}"))?;
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

pub fn router() -> Router {
    Router::new().route("/healthz", get(health)).merge(metrics::router())
}

async fn health() -> (StatusCode, &'static str) {
    (StatusCode::OK, "rollup-monitor is running")
}

#[cfg(test)]
mod tests {
    use axum::{
        body::{Body, to_bytes},
        http::{Request, StatusCode},
    };
    use tower::ServiceExt;

    use super::router;

    #[tokio::test]
    async fn healthz_route_returns_ok() {
        let response = router()
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
    async fn metrics_route_returns_prometheus_text() {
        crate::metrics::inc_scan_error("l1", "test");

        let response = router()
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
