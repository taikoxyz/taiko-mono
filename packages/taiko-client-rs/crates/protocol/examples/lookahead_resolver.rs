//! Minimal demo: start `LookaheadResolver` with the built-in event scanner and query a committer.
//!
//! Run with a WebSocket L1 endpoint and Inbox address:
//! `cargo run -p protocol --example lookahead_resolver -- \
//!     --ws wss://l1.example/ws \
//!     --inbox 0x0000000000000000000000000000000000000000`
//!
//! Known chains inferred by `new`: mainnet (1), Holesky (17_000), Hoodi (560_048).
//! For custom or unknown networks, use `LookaheadResolver::new_with_genesis` and pass the beacon
//! genesis timestamp explicitly; the default `new` infers genesis only for those known IDs.

use std::{env, time::SystemTime};

use alloy_primitives::{Address, U256};
use anyhow::{Context, Result, anyhow};
use protocol::{
    preconfirmation::lookahead::LookaheadResolverWithDefaultProvider,
    subscription_source::SubscriptionSource,
};
use tokio::task::JoinHandle;

#[tokio::main]
async fn main() -> Result<()> {
    let ws = arg("--ws").context("--ws wss://... is required")?;
    let inbox = arg("--inbox")
        .context("--inbox <address> is required")?
        .parse::<Address>()
        .context("invalid inbox address")?;

    let source: SubscriptionSource = ws.as_str().try_into().map_err(|e: String| anyhow!(e))?;

    // Build resolver and start background scanner, wait till the initial sync is done.
    // Enable the optional epoch broadcast channel so we can observe cached epochs as they arrive.
    let (mut resolver, handle): (LookaheadResolverWithDefaultProvider, _) =
        LookaheadResolverWithDefaultProvider::new(inbox, source).await?;

    // Optionally, enable an epoch update channel to observe cached epochs as they are ingested.
    let mut epoch_rx = resolver.enable_epoch_channel(16);
    let resolver_for_epoch = resolver.clone();

    // Spawn a task to log cached epochs and resolve committers for the slots.
    let epoch_logger: JoinHandle<()> = tokio::spawn(async move {
        let resolver = resolver_for_epoch;
        while let Ok(update) = epoch_rx.recv().await {
            println!(
                "cached epoch {} with {} slots ({} blacklisted)",
                update.epoch_start,
                update.epoch.slots().len(),
                update.epoch.blacklist_flags().iter().filter(|b| **b).count()
            );

            // Resolve and print the committer for each slot in the epoch.
            for (idx, slot) in update.epoch.slots().iter().enumerate() {
                let committer = match resolver.committer_for_timestamp(slot.timestamp).await {
                    Ok(committer) => committer,
                    Err(err) => {
                        eprintln!(
                            "slot {idx} failed to resolve committer at {}: {err}",
                            slot.timestamp
                        );
                        continue;
                    }
                };
                println!("slot {idx} committer: {committer:?}");
            }
        }
    });

    // Query the committer for "now".
    let now = SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map_err(|_| anyhow!("clock before UNIX_EPOCH"))?
        .as_secs();
    let signer = resolver
        .committer_for_timestamp(U256::from(now))
        .await
        .context("failed to resolve committer")?;

    println!("Committer for timestamp {now}: {signer:?}");

    // Keep running briefly so the scanner stays alive for demonstration purposes.
    // In real services, you would hold onto `handle` for the process lifetime.
    tokio::time::sleep(std::time::Duration::from_secs(1)).await;

    // Clean up background tasks.
    handle.abort();
    epoch_logger.abort();

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
