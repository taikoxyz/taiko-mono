//! Development CLI entrypoint for the preconfirmation P2P stack.
//!
//! Starts a `P2pNode`, logs events, requests head on startup, and exits on Ctrl+C.

use clap::Parser;
use futures::StreamExt;
use preconfirmation_net::{
    LookaheadResolver, LookaheadValidationAdapter, NetworkCommand, NetworkEvent, P2pConfig, P2pNode,
};
use std::{net::SocketAddr, sync::Arc, time::Duration};

/// Lookahead resolver that returns a configured signer for all slots.
struct CliLookaheadResolver {
    /// Expected signer returned for every lookup.
    expected_signer: alloy_primitives::Address,
}

impl LookaheadResolver for CliLookaheadResolver {
    /// Returns the expected signer for any submission window end.
    fn signer_for_timestamp(
        &self,
        _submission_window_end: &preconfirmation_types::Uint256,
    ) -> Result<alloy_primitives::Address, String> {
        Ok(self.expected_signer)
    }

    /// Returns the expected slot end as-is.
    fn expected_slot_end(
        &self,
        submission_window_end: &preconfirmation_types::Uint256,
    ) -> Result<preconfirmation_types::Uint256, String> {
        Ok(submission_window_end.clone())
    }
}

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

    /// Expected signer for the current lookahead schedule.
    #[arg(long)]
    expected_signer: String,
}

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    let args = Args::parse();

    tracing_subscriber::fmt()
        .with_env_filter(tracing_subscriber::EnvFilter::from_default_env())
        .init();

    let listen_addr: SocketAddr = args.listen_addr.parse()?;
    let discv5_listen: SocketAddr = args.discv5_listen.parse()?;
    let expected_signer = args.expected_signer.parse()?;

    let mut cfg = P2pConfig::default();
    cfg.chain_id = args.chain_id;
    cfg.listen_addr = listen_addr;
    cfg.discovery_listen = discv5_listen;
    cfg.bootnodes = args.bootnode.clone();
    cfg.enable_discovery = !args.no_discovery;
    cfg.reputation.greylist_threshold = args.reputation_greylist;
    cfg.reputation.ban_threshold = args.reputation_ban;
    cfg.reputation.halflife = Duration::from_secs(args.reputation_halflife_secs);
    cfg.rate_limit.window = Duration::from_secs(args.request_window_secs);
    cfg.rate_limit.max_requests = args.max_requests_per_window;

    let validator = Box::new(LookaheadValidationAdapter::new(
        None,
        Arc::new(CliLookaheadResolver { expected_signer }),
    ));

    let (mut handle, node) = P2pNode::new(cfg, validator)?;
    let node_task = tokio::spawn(async move { node.run().await });

    // Request head from peers on startup.
    let cmd_sender = handle.command_sender();
    cmd_sender.send(NetworkCommand::RequestHead { respond_to: None, peer: None }).await?;
    tracing::info!(target: "p2p-node", "sent initial head request");

    let logger = tokio::spawn(async move {
        let mut events = handle.events();
        while let Some(ev) = events.next().await {
            match ev {
                NetworkEvent::GossipSignedCommitment { from, .. } => {
                    tracing::info!(target: "p2p-node", %from, "received signed commitment gossip");
                }
                NetworkEvent::GossipRawTxList { from, .. } => {
                    tracing::info!(target: "p2p-node", %from, "received raw txlist gossip");
                }
                NetworkEvent::ReqRespCommitments { from, .. } => {
                    tracing::info!(target: "p2p-node", %from, "commitments response");
                }
                NetworkEvent::ReqRespRawTxList { from, .. } => {
                    tracing::info!(target: "p2p-node", %from, "raw txlist response");
                }
                NetworkEvent::ReqRespHead { from, head } => {
                    tracing::info!(
                        target: "p2p-node",
                        %from,
                        block_number = ?head.block_number,
                        "head response"
                    );
                }
                NetworkEvent::InboundCommitmentsRequest { from } => {
                    tracing::info!(target: "p2p-node", %from, "inbound commitments request");
                }
                NetworkEvent::InboundRawTxListRequest { from } => {
                    tracing::info!(target: "p2p-node", %from, "inbound raw txlist request");
                }
                NetworkEvent::InboundHeadRequest { from } => {
                    tracing::info!(target: "p2p-node", %from, "inbound head request");
                }
                NetworkEvent::PeerConnected(peer) => {
                    tracing::info!(target: "p2p-node", %peer, "peer connected");
                }
                NetworkEvent::PeerDisconnected(peer) => {
                    tracing::info!(target: "p2p-node", %peer, "peer disconnected");
                }
                NetworkEvent::NewListenAddr(addr) => {
                    tracing::info!(target: "p2p-node", %addr, "listening on address");
                }
                NetworkEvent::Error(err) => {
                    tracing::warn!(target: "p2p-node", %err, "network error");
                }
                NetworkEvent::Started | NetworkEvent::Stopped => {}
            }
        }
    });

    tracing::info!(
        listen = %args.listen_addr,
        discv5 = %args.discv5_listen,
        discovery = !args.no_discovery,
        bootnodes = ?args.bootnode,
        "p2p-node started"
    );

    tokio::signal::ctrl_c().await?;
    tracing::info!("ctrl-c received; shutting down");
    node_task.abort();
    let _ = node_task.await;
    let _ = logger.await;

    Ok(())
}
