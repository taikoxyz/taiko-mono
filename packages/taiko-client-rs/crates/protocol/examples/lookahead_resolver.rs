//! Minimal demo: start `LookaheadResolver` with the built-in event scanner (three-epoch backfill)
//! and query a committer.
//!
//! Run with a WebSocket L1 endpoint and Inbox address:
//! `cargo run -p protocol --example lookahead_resolver -- \
//!     --ws wss://l1.example/ws \
//!     --inbox 0x0000000000000000000000000000000000000000`
//!
//! Known chains inferred by `new`: mainnet (1), Holesky (17_000), Hoodi (560_048).
//! For custom or unknown networks, pass `--genesis <beacon_timestamp>` to use
//! `LookaheadResolver::new_with_genesis`; the default `new` infers genesis only for the known IDs.

use std::{env, time::SystemTime};

use alloy_primitives::{Address, U256};
use anyhow::{Context, Result, anyhow};
use protocol::{
    preconfirmation::lookahead::{LookaheadBroadcast, LookaheadResolverWithDefaultProvider},
    subscription_source::SubscriptionSource,
};

#[tokio::main]
async fn main() -> Result<()> {
    let ws = arg("--ws").context("--ws wss://... is required")?;
    let inbox = arg("--inbox")
        .context("--inbox <address> is required")?
        .parse::<Address>()
        .context("invalid inbox address")?;

    let source: SubscriptionSource = ws.as_str().try_into().map_err(|e: String| anyhow!(e))?;

    // Build resolver and start background scanner; hold the handle so the scanner keeps running
    // for the lifetime of the example (it aborts on drop).
    let (mut resolver, _scanner_handle) =
        LookaheadResolverWithDefaultProvider::new(inbox, source).await?;

    // Optionally, enable an update channel to observe cached epochs and blacklist changes.
    let mut updates_rx = resolver.enable_broadcast_channel(16);
    tokio::spawn(async move {
        while let Ok(update) = updates_rx.recv().await {
            match update {
                LookaheadBroadcast::Epoch(update) => {
                    println!(
                        "cached epoch {} with {} slots (whitelist fallback: {:?})",
                        update.epoch_start,
                        update.epoch.slots().len(),
                        update.epoch.fallback_whitelist(),
                    );
                }
                LookaheadBroadcast::Blacklisted { root } => {
                    println!("operator blacklisted: {root:?}");
                }
                LookaheadBroadcast::Unblacklisted { root } => {
                    println!("operator unblacklisted: {root:?}");
                }
            }
        }
    });

    // Query the committer for "now".
    // Note: committer_for_timestamp accepts timestamps in the valid window
    // [earliest_allowed_timestamp, latest_allowed_timestamp), from start of previous epoch through
    // end of current epoch, and returns TooOld/TooNew otherwise.
    let now = SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map_err(|_| anyhow!("clock before UNIX_EPOCH"))?
        .as_secs();
    let signer = resolver
        .committer_for_timestamp(U256::from(now))
        .await
        .context("failed to resolve committer")?;

    println!("Committer for timestamp {now}: {signer:?}");

    Ok(())
}

// Simple command-line argument parser for demo purposes.
fn arg(flag: &str) -> Option<String> {
    let mut args = env::args().skip(1).peekable();
    while let Some(next) = args.next() {
        if next == flag {
            return args.next();
        }
    }
    None
}
