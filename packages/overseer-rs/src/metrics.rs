use std::{net::SocketAddr, sync::Arc};

use anyhow::Result;
use hyper::{
    body::Body,
    service::{make_service_fn, service_fn},
    Response, Server, StatusCode,
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
                async move {
                    if req.uri().path() == "/metrics" {
                        match metrics.encode() {
                            Ok(body) => Response::builder()
                                .status(StatusCode::OK)
                                .header(
                                    hyper::header::CONTENT_TYPE,
                                    TextEncoder::new().format_type(),
                                )
                                .body(Body::from(body))
                                .map_err(|err| {
                                    error!(target: "overseer::metrics", error = ?err, "failed to build metrics response");
                                    err
                                }),
                            Err(err) => {
                                error!(
                                    target: "overseer::metrics",
                                    error = ?err,
                                    "failed to encode metrics"
                                );
                                Response::builder()
                                    .status(StatusCode::INTERNAL_SERVER_ERROR)
                                    .body(Body::from("failed to encode metrics"))
                                    .map_err(|err| {
                                        error!(target: "overseer::metrics", error = ?err, "failed to build error response");
                                        err
                                    })
                            }
                        }
                    } else {
                        Response::builder()
                            .status(StatusCode::NOT_FOUND)
                            .body(Body::from("not found"))
                            .map_err(|err| {
                                error!(target: "overseer::metrics", error = ?err, "failed to build not-found response");
                                err
                            })
                    }
                }
            }))
        }
    });

    Server::bind(&addr).serve(make_service).await?;
    Ok(())
}
