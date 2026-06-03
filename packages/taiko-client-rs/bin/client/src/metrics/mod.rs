//! Client metrics definitions.

use std::net::SocketAddr;

use axum::{
    Router,
    http::{StatusCode, header},
    response::IntoResponse,
    routing::get,
};
use prometheus::{Encoder, TextEncoder};

pub mod version;

/// Build the HTTP router exposing direct Prometheus metrics.
pub fn router() -> Router {
    Router::new().route("/", get(health_handler)).route("/metrics", get(metrics_handler))
}

/// Start the Prometheus metrics server on the configured socket.
pub fn spawn_server(socket_addr: SocketAddr) -> std::io::Result<()> {
    let listener = std::net::TcpListener::bind(socket_addr)?;
    listener.set_nonblocking(true)?;
    let listener = tokio::net::TcpListener::from_std(listener)?;

    tokio::spawn(async move {
        if let Err(error) = axum::serve(listener, router()).await {
            tracing::error!(%error, "Prometheus metrics server exited");
        }
    });

    Ok(())
}

/// Encode and return metrics from the process-wide Prometheus registry.
async fn metrics_handler() -> impl IntoResponse {
    let encoder = TextEncoder::new();
    let mut buffer = Vec::new();
    if let Err(error) = encoder.encode(&prometheus::gather(), &mut buffer) {
        tracing::error!(%error, "could not encode Prometheus metrics");
        return (StatusCode::INTERNAL_SERVER_ERROR, "could not encode metrics").into_response();
    }

    (StatusCode::OK, [(header::CONTENT_TYPE, encoder.format_type())], buffer).into_response()
}

/// Return service health for the metrics HTTP server.
async fn health_handler() -> (StatusCode, &'static str) {
    (StatusCode::OK, "taiko-client is running")
}

#[cfg(test)]
mod tests {
    use axum::{
        body::Body,
        http::{Request, StatusCode},
    };
    use http_body_util::BodyExt;
    use prometheus::IntCounter;
    use tower::ServiceExt;

    use super::router;

    #[tokio::test]
    async fn metrics_route_returns_default_registry_collectors() {
        let counter = IntCounter::new("taiko_client_metrics_route_test_total", "Route test")
            .expect("valid counter");
        prometheus::register(Box::new(counter)).expect("counter should register");

        let response = router()
            .oneshot(Request::builder().uri("/metrics").body(Body::empty()).unwrap())
            .await
            .expect("metrics route should respond");

        assert_eq!(response.status(), StatusCode::OK);
        let body = response.into_body().collect().await.expect("valid body").to_bytes();
        let body = String::from_utf8(body.to_vec()).expect("metrics body should be UTF-8");
        assert!(body.contains("taiko_client_metrics_route_test_total 0"));
    }

    #[tokio::test]
    async fn health_route_reports_client_status() {
        let response = router()
            .oneshot(Request::builder().uri("/").body(Body::empty()).unwrap())
            .await
            .expect("health route should respond");

        assert_eq!(response.status(), StatusCode::OK);
        let body = response.into_body().collect().await.expect("valid body").to_bytes();

        assert_eq!(body.as_ref(), b"taiko-client is running");
    }
}
