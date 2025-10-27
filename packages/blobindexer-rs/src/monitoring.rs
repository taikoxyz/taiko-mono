use std::net::SocketAddr;

use axum::{
    Router,
    body::Body,
    extract::State,
    http::{self, StatusCode},
    response::Response,
    routing::get,
};
use metrics_exporter_prometheus::{PrometheusBuilder, PrometheusHandle};
use tokio::net::TcpListener;
use tokio_util::sync::CancellationToken;

use crate::errors::{BlobIndexerError, Result};

#[derive(Clone)]
struct AppState {
    handle: PrometheusHandle,
}

pub fn init_metrics() -> Result<PrometheusHandle> {
    let builder = PrometheusBuilder::new();
    let handle = builder.install_recorder().map_err(|err| {
        BlobIndexerError::Configuration(format!("failed to install Prometheus recorder: {err}"))
    })?;

    metrics::describe_counter!(
        "blobindexer_blocks_stored_total",
        "Total number of blocks persisted to storage"
    );
    metrics::describe_counter!(
        "blobindexer_blobs_stored_total",
        "Total number of blob records persisted to storage"
    );
    metrics::describe_counter!(
        "blobindexer_watched_blobs_stored_total",
        "Total number of blobs matching watch addresses persisted to storage"
    );

    Ok(handle)
}

pub async fn serve(
    bind: SocketAddr,
    shutdown: CancellationToken,
    handle: PrometheusHandle,
) -> Result<()> {
    let state = AppState { handle };
    let app = Router::new()
        .route("/healthz", get(health))
        .route("/metrics", get(metrics_endpoint))
        .with_state(state);

    let listener = TcpListener::bind(bind).await?;

    tracing::info!(address = %bind, "starting monitoring server");

    axum::serve(listener, app)
        .with_graceful_shutdown(async move {
            shutdown.cancelled().await;
        })
        .await?;

    Ok(())
}

async fn health() -> &'static str {
    "ok"
}

async fn metrics_endpoint(State(state): State<AppState>) -> Response {
    let body = state.handle.render();

    match Response::builder()
        .status(StatusCode::OK)
        .header(
            http::header::CONTENT_TYPE,
            "text/plain; version=0.0.4; charset=utf-8",
        )
        .body(Body::from(body))
    {
        Ok(response) => response,
        Err(error) => {
            tracing::error!(error = ?error, "failed to build metrics response");
            Response::builder()
                .status(StatusCode::INTERNAL_SERVER_ERROR)
                .body(Body::from("failed to render metrics"))
                .unwrap_or_else(|_| Response::new(Body::from(String::new())))
        }
    }
}
