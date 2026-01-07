use std::{net::SocketAddr, sync::Arc};

use anyhow::Result;
use hyper::{
    body::Body,
    header::HeaderValue,
    service::{make_service_fn, service_fn},
    Request, Response, Server, StatusCode,
};
use prometheus::{Encoder, IntCounter, Registry, TextEncoder};
use tracing::error;

/// Collects Prometheus metrics and exposes helpers for updating counters.
#[derive(Clone)]
pub struct Metrics {
    registry: Registry,
    blacklist_calls: IntCounter,
    blacklist_errors: IntCounter,
    observation_errors: IntCounter,
    criterion_errors: IntCounter,
}

impl Metrics {
    /// Builds a metrics registry with the overseer's counters registered.
    pub fn new() -> Result<Self> {
        let registry = Registry::new();

        let blacklist_calls = IntCounter::new(
            "overseer_blacklist_calls_total",
            "Total number of blacklist invocations",
        )?;
        let blacklist_errors = IntCounter::new(
            "overseer_blacklist_errors_total",
            "Total number of blacklist invocation errors",
        )?;
        let observation_errors = IntCounter::new(
            "overseer_observation_errors_total",
            "Total number of observation collection errors",
        )?;
        let criterion_errors = IntCounter::new(
            "overseer_criterion_errors_total",
            "Total number of blacklist criterion evaluation errors",
        )?;

        registry.register(Box::new(blacklist_calls.clone()))?;
        registry.register(Box::new(blacklist_errors.clone()))?;
        registry.register(Box::new(observation_errors.clone()))?;
        registry.register(Box::new(criterion_errors.clone()))?;

        Ok(Self {
            registry,
            blacklist_calls,
            blacklist_errors,
            observation_errors,
            criterion_errors,
        })
    }

    /// Records a successful blacklist invocation.
    pub fn inc_blacklist_calls(&self) {
        self.blacklist_calls.inc();
    }

    /// Records a failed blacklist invocation.
    pub fn inc_blacklist_errors(&self) {
        self.blacklist_errors.inc();
    }

    /// Records a failed observation collection.
    pub fn inc_observation_errors(&self) {
        self.observation_errors.inc();
    }

    /// Records a criterion evaluation error.
    pub fn inc_criterion_errors(&self) {
        self.criterion_errors.inc();
    }

    /// Gathers metrics and encodes them using the Prometheus text exposition format.
    fn encode(&self) -> Result<Vec<u8>> {
        let metric_families = self.registry.gather();
        let mut buffer = Vec::new();
        TextEncoder::new().encode(&metric_families, &mut buffer)?;
        Ok(buffer)
    }
}

/// Starts an HTTP server serving Prometheus metrics at `/metrics`.
pub async fn serve(metrics: Arc<Metrics>, addr: SocketAddr) -> Result<()> {
    let make_service = make_service_fn(move |_| {
        let metrics = Arc::clone(&metrics);
        async move {
            Ok::<_, hyper::Error>(service_fn(move |req| {
                let metrics = Arc::clone(&metrics);
                async move { respond(metrics, req).await }
            }))
        }
    });

    Server::bind(&addr).serve(make_service).await?;
    Ok(())
}

async fn respond(
    metrics: Arc<Metrics>,
    req: Request<Body>,
) -> Result<Response<Body>, hyper::Error> {
    match req.uri().path() {
        "/healthz" => {
            let mut response = Response::new(Body::from("ok"));
            *response.status_mut() = StatusCode::OK;
            Ok(response)
        }
        "/metrics" => match metrics.encode() {
            Ok(body) => {
                let mut response = Response::new(Body::from(body));
                *response.status_mut() = StatusCode::OK;

                match HeaderValue::from_str(TextEncoder::new().format_type()) {
                    Ok(value) => {
                        response
                            .headers_mut()
                            .insert(hyper::header::CONTENT_TYPE, value);
                    }
                    Err(err) => {
                        error!(
                            target: "overseer::metrics",
                            error = ?err,
                            "failed to set metrics content-type header"
                        );
                        *response.status_mut() = StatusCode::INTERNAL_SERVER_ERROR;
                        *response.body_mut() = Body::from("failed to encode metrics");
                    }
                }

                Ok(response)
            }
            Err(err) => {
                error!(
                    target: "overseer::metrics",
                    error = ?err,
                    "failed to encode metrics"
                );
                let mut response = Response::new(Body::from("failed to encode metrics"));
                *response.status_mut() = StatusCode::INTERNAL_SERVER_ERROR;
                Ok(response)
            }
        },
        other => {
            let mut response = Response::new(Body::from("not found"));
            *response.status_mut() = StatusCode::NOT_FOUND;
            error!(
                target: "overseer::metrics",
                path = %other,
                "failed to build not-found response"
            );
            Ok(response)
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use hyper::{body::to_bytes, Body, Request};

    #[test]
    fn metrics_encode_contains_registered_counters() {
        let metrics = Metrics::new().expect("metrics should construct");
        let buffer = metrics.encode().expect("encode should succeed");
        let text = String::from_utf8(buffer).expect("metrics output must be utf8");

        assert!(text.contains("overseer_blacklist_calls_total"));
        assert!(text.contains("overseer_blacklist_errors_total"));
    }

    #[test]
    fn counter_increment_reflected_in_encode() {
        let metrics = Metrics::new().expect("metrics should construct");
        metrics.inc_blacklist_calls();
        let buffer = metrics.encode().expect("encode should succeed");
        let text = String::from_utf8(buffer).expect("metrics output must be utf8");

        assert!(text.contains("overseer_blacklist_calls_total 1"));
    }

    #[tokio::test]
    async fn healthz_route_returns_ok() {
        let metrics = Arc::new(Metrics::new().expect("metrics should construct"));
        let req = Request::builder()
            .uri("/healthz")
            .body(Body::empty())
            .expect("request should build");

        let response = respond(metrics, req)
            .await
            .expect("response should succeed");
        assert_eq!(response.status(), StatusCode::OK);
        let body = to_bytes(response.into_body())
            .await
            .expect("body should be readable");
        assert_eq!(body.as_ref(), b"ok");
    }

    #[tokio::test]
    async fn metrics_route_returns_scraped_metrics() {
        let metrics = Arc::new(Metrics::new().expect("metrics should construct"));
        metrics.inc_observation_errors();

        let req = Request::builder()
            .uri("/metrics")
            .body(Body::empty())
            .expect("request should build");
        let response = respond(Arc::clone(&metrics), req)
            .await
            .expect("response should succeed");

        assert_eq!(response.status(), StatusCode::OK);
        let body = to_bytes(response.into_body())
            .await
            .expect("body should be readable");
        let text = String::from_utf8(body.to_vec()).expect("body should be utf8");
        assert!(text.contains("overseer_observation_errors_total 1"));
    }

    #[tokio::test]
    async fn unknown_route_returns_not_found() {
        let metrics = Arc::new(Metrics::new().expect("metrics should construct"));
        let req = Request::builder()
            .uri("/does-not-exist")
            .body(Body::empty())
            .expect("request should build");

        let response = respond(metrics, req)
            .await
            .expect("response should succeed");
        assert_eq!(response.status(), StatusCode::NOT_FOUND);
    }
}
