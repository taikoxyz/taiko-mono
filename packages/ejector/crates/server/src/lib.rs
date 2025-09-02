use std::net::{IpAddr, Ipv4Addr, SocketAddr};

use axum::{Router, http::StatusCode, routing::get};
use tracing::info;

pub async fn spawn_server(
    port: u64,
    shutdown: impl std::future::Future<Output = ()> + Send + 'static,
) -> eyre::Result<()> {
    let health_router = Router::new().route("/", get(health));

    let router = health_router.merge(metrics::router());

    let socket = SocketAddr::new(IpAddr::V4(Ipv4Addr::new(0, 0, 0, 0)), port as u16);

    let listener = tokio::net::TcpListener::bind(socket).await.expect("Could not bind to socket");

    info!("Server listening on http://{}", socket);

    axum::serve(listener, router)
        .with_graceful_shutdown(shutdown)
        .await
        .map_err(|e| eyre::eyre!("Failed to start server: {}", e))?;

    Ok(())
}

async fn health() -> (StatusCode, &'static str) {
    (StatusCode::OK, "ejector is running")
}
