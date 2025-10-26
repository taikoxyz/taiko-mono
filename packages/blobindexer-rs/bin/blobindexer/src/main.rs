use blobindexer::{
    beacon::BeaconClient, config::Config, errors::Result, http, indexer::Indexer, storage::Storage,
};
use clap::{Parser, Subcommand};
use tokio::signal;
use tokio_util::sync::CancellationToken;

#[derive(Debug, Parser)]
#[command(
    name = "blobindexer",
    author,
    version,
    about = "Taiko blob sidecar indexer"
)]
struct Cli {
    #[command(flatten)]
    config: Config,
    #[command(subcommand)]
    command: Option<Commands>,
}

#[derive(Clone, Debug, Subcommand)]
enum Commands {
    /// Run both the indexer and API server (default behaviour)
    Run,
    /// Run only the background indexer loop
    Indexer,
    /// Run only the HTTP API server
    Api,
}

#[tokio::main]
async fn main() -> Result<()> {
    dotenvy::dotenv().ok();

    let Cli { config, command } = Cli::parse();
    blobindexer::utils::telemetry::init_tracing(&config)?;

    match command.unwrap_or(Commands::Run) {
        Commands::Run => run_all(config).await,
        Commands::Indexer => run_indexer_only(config).await,
        Commands::Api => run_api_only(config).await,
    }
}

async fn run_all(config: Config) -> Result<()> {
    let shutdown = CancellationToken::new();
    let shutdown_signal = shutdown.clone();

    let (storage, beacon) = init_dependencies(&config).await?;

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
        _ = signal::ctrl_c() => {
            tracing::info!("Received shutdown signal");
            shutdown.cancel();
        }
    }

    tracing::info!("Blob indexer shut down gracefully");

    Ok(())
}

async fn run_indexer_only(config: Config) -> Result<()> {
    let shutdown = CancellationToken::new();
    let (storage, beacon) = init_dependencies(&config).await?;

    let indexer = Indexer::new(config, storage, beacon, shutdown.clone());
    let indexer_task = tokio::spawn(indexer.run());

    tokio::select! {
        res = indexer_task => {
            if let Err(err) = res? {
                tracing::error!(error = ?err, "Indexer task exited with error");
                shutdown.cancel();
            }
        }
        _ = signal::ctrl_c() => {
            tracing::info!("Received shutdown signal");
            shutdown.cancel();
        }
    }

    tracing::info!("Indexer shut down gracefully");

    Ok(())
}

async fn run_api_only(config: Config) -> Result<()> {
    let shutdown = CancellationToken::new();
    let (storage, beacon) = init_dependencies(&config).await?;

    let server_task = tokio::spawn(http::serve(config, storage, beacon, shutdown.clone()));

    tokio::select! {
        res = server_task => {
            if let Err(err) = res? {
                tracing::error!(error = ?err, "HTTP server task exited with error");
                shutdown.cancel();
            }
        }
        _ = signal::ctrl_c() => {
            tracing::info!("Received shutdown signal");
            shutdown.cancel();
        }
    }

    tracing::info!("HTTP server shut down gracefully");

    Ok(())
}

async fn init_dependencies(config: &Config) -> Result<(Storage, BeaconClient)> {
    let storage = Storage::connect(&config.database_url).await?;
    storage.run_migrations().await?;

    let beacon = BeaconClient::new(config.beacon_api.clone(), config.http_timeout)?;

    Ok((storage, beacon))
}
