//! Development CLI entrypoint for the preconfirmation P2P stack.
//!
//! This example mirrors the previous standalone binary but now lives as an example so the
//! workspace remains library-only. It spins up a `P2pService`, logs key events, and exits on
//! Ctrl+C.

use clap::Parser;
use libp2p::PeerId;
use preconfirmation_service::{NetworkConfig, NetworkError, P2pHandler, P2pService};
use std::net::SocketAddr;

/// Minimal CLI arguments.
#[derive(Debug, Parser)]
#[command(name = "p2p-node", about = "Taiko preconfirmation P2P dev node (scaffold)")]
struct Args {
    /// Libp2p listen address (multi-protocols resolved via libp2p)
    #[arg(long, default_value = "0.0.0.0:9000")]
    listen_addr: String,

    /// Discv5 UDP listen address
    #[arg(long, default_value = "0.0.0.0:9001")]
    discv5_listen: String,

    /// Bootnodes as ENR strings (repeatable)
    #[arg(long)]
    bootnode: Vec<String>,

    /// Chain ID for topic/protocol selection
    #[arg(long, default_value_t = 167_000u64)]
    chain_id: u64,

    /// Disable discv5 discovery
    #[arg(long, default_value_t = false)]
    no_discovery: bool,

    /// Reputation greylist threshold (<= triggers greylist)
    #[arg(long, default_value_t = -5.0)]
    reputation_greylist: f64,

    /// Reputation ban threshold (<= triggers ban)
    #[arg(long, default_value_t = -10.0)]
    reputation_ban: f64,

    /// Reputation halflife in seconds
    #[arg(long, default_value_t = 600u64)]
    reputation_halflife_secs: u64,

    /// Request rate-limit window in seconds
    #[arg(long, default_value_t = 10u64)]
    request_window_secs: u64,

    /// Max requests per peer per window
    #[arg(long, default_value_t = 8u32)]
    max_requests_per_window: u32,
}

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    let args = Args::parse();

    // Basic tracing setup; uses env filter when configured.
    tracing_subscriber::fmt()
        .with_env_filter(tracing_subscriber::EnvFilter::from_default_env())
        .init();

    let listen_addr: SocketAddr = args.listen_addr.parse()?;
    let discv5_listen: SocketAddr = args.discv5_listen.parse()?;

    let mut cfg = NetworkConfig::for_chain(167_000);
    cfg.chain_id = args.chain_id;
    cfg.listen_addr = listen_addr;
    cfg.discv5_listen = discv5_listen;
    cfg.bootnodes = args.bootnode.clone();
    cfg.enable_discovery = !args.no_discovery;
    cfg.reputation_greylist = args.reputation_greylist;
    cfg.reputation_ban = args.reputation_ban;
    cfg.reputation_halflife = std::time::Duration::from_secs(args.reputation_halflife_secs);
    cfg.request_window = std::time::Duration::from_secs(args.request_window_secs);
    cfg.max_requests_per_window = args.max_requests_per_window;

    let mut service = P2pService::start(cfg)?;
    let handler = LoggingHandler;
    let handler_task = service.run_with_handler(handler)?;

    tracing::info!(
        listen = %args.listen_addr,
        discv5 = %args.discv5_listen,
        discovery = !args.no_discovery,
        bootnodes = ?args.bootnode,
        "p2p-node started"
    );

    tokio::signal::ctrl_c().await?;
    tracing::info!("ctrl-c received; shutting down");

    service.shutdown().await;
    let _ = handler_task.await;
    Ok(())
}

struct LoggingHandler;

impl P2pHandler for LoggingHandler {
    fn on_signed_commitment(&self, from: PeerId, _msg: preconfirmation_types::SignedCommitment) {
        tracing::info!(target = "p2p-node", %from, "received signed commitment gossip");
    }

    fn on_raw_txlist(&self, from: PeerId, _msg: preconfirmation_types::RawTxListGossip) {
        tracing::info!(target = "p2p-node", %from, "received raw txlist gossip");
    }

    fn on_commitments_response(
        &self,
        from: PeerId,
        _msg: preconfirmation_types::GetCommitmentsByNumberResponse,
        _request_id: Option<u64>,
    ) {
        tracing::info!(target = "p2p-node", %from, "commitments response");
    }

    fn on_raw_txlist_response(
        &self,
        from: PeerId,
        _msg: preconfirmation_types::GetRawTxListResponse,
        _request_id: Option<u64>,
    ) {
        tracing::info!(target = "p2p-node", %from, "raw txlist response");
    }

    fn on_inbound_commitments_request(&self, from: PeerId) {
        tracing::info!(target = "p2p-node", %from, "inbound commitments request");
    }

    fn on_inbound_raw_txlist_request(&self, from: PeerId) {
        tracing::info!(target = "p2p-node", %from, "inbound raw txlist request");
    }

    fn on_peer_connected(&self, peer: PeerId) {
        tracing::info!(target = "p2p-node", %peer, "peer connected");
    }

    fn on_peer_disconnected(&self, peer: PeerId) {
        tracing::info!(target = "p2p-node", %peer, "peer disconnected");
    }

    fn on_error(&self, err: &NetworkError) {
        tracing::warn!(
            target = "p2p-node",
            kind = %err.kind.as_str(),
            detail = %err.detail,
            "network error"
        );
    }
}
