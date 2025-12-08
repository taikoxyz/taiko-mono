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
    preconfirmation::lookahead::LookaheadResolverDefaultProvider,
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

    // Build resolver and start background scanner, wait till the initial sync is done.
    let (resolver, handle): (LookaheadResolverDefaultProvider, _) =
        LookaheadResolverDefaultProvider::new(inbox, source).await?;

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
    handle.abort();

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
