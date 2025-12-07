//! Minimal demo: start `LookaheadResolver` with the built-in event scanner and query a committer.
//!
//! Run with a WebSocket L1 endpoint and Inbox address:
//! `cargo run -p protocol --example lookahead_resolver -- \
//!     --ws wss://l1.example/ws \
//!     --inbox 0x0000000000000000000000000000000000000000 \
//!     --latest 128`

use std::{env, time::SystemTime};

use alloy_primitives::{Address, U256};
use anyhow::{anyhow, Context, Result};
use alloy_provider::{
    RootProvider,
    fillers::FillProvider,
    utils::JoinedRecommendedFillers,
};
use protocol::{
    preconfirmation::lookahead::LookaheadResolver,
    subscription_source::SubscriptionSource,
};

#[tokio::main]
async fn main() -> Result<()> {
    let ws = arg("--ws").context("--ws wss://... is required")?;
    let inbox = arg("--inbox")
        .context("--inbox <address> is required")?
        .parse::<Address>()
        .context("invalid inbox address")?;
    let latest: usize = arg("--latest")
        .unwrap_or_else(|| "128".to_string())
        .parse()
        .context("--latest must be a number")?;

    let source: SubscriptionSource = ws
        .as_str()
        .try_into()
        .map_err(|e: String| anyhow!(e))?;

    // Build resolver and start background scanner from latest N blocks.
    let (resolver, handle): (
        LookaheadResolver<FillProvider<JoinedRecommendedFillers, RootProvider>>,
        _,
    ) = LookaheadResolver::<FillProvider<JoinedRecommendedFillers, RootProvider>>::new_with_scanner_from_latest(
        inbox,
        source,
        latest,
    )
    .await?;

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
