use blobindexer::config::Config;
use blobindexer::errors::Result;
use blobindexer::http;
use blobindexer::indexer::Indexer;
use blobindexer::storage::Storage;
use clap::Parser;
use tokio_util::sync::CancellationToken;

#[tokio::main]
async fn main() -> Result<()> {
    dotenvy::dotenv().ok();

    let config = Config::parse();
    blobindexer::utils::telemetry::init_tracing(&config)?;

    let shutdown = CancellationToken::new();
    let shutdown_signal = shutdown.clone();

    let storage = Storage::connect(&config.database_url).await?;
    storage.run_migrations().await?;

    let beacon =
        blobindexer::beacon::BeaconClient::new(config.beacon_api.clone(), config.http_timeout)?;

    let indexer = Indexer::new(
        config.clone(),
        storage.clone(),
        beacon.clone(),
        shutdown.clone(),
    );

    let api = http::serve(
        config.clone(),
        storage.clone(),
        beacon.clone(),
        shutdown_signal.clone(),
    );
    let indexer_task = tokio::spawn(indexer.run());

    let server_task = tokio::spawn(api);

    tokio::select! {
        res = indexer_task => {
            if let Err(err) = res? {
                tracing::error!(error = ?err, "Indexer task exited with error");
                shutdown.cancel();
            }
        }
        res = server_task => {
            if let Err(err) = res? {
                tracing::error!(error = ?err, "HTTP server task exited with error");
                shutdown.cancel();
            }
        }
        _ = tokio::signal::ctrl_c() => {
            tracing::info!("Received shutdown signal");
            shutdown.cancel();
        }
    }

    tracing::info!("Blob indexer shut down gracefully");

    Ok(())
}
