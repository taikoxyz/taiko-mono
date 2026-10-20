//! The production collector against stock CometBFT, independently of actual-contract landing.
use std::time::Duration;

use abci::{EtnaEnvelope, committee::record_hash, l1::layout::inbox};
use alloy_eips::BlockNumberOrTag;
use alloy_primitives::U256;
use alloy_provider::Provider;
use anyhow::{Context, Result};
use lander::{
    codec,
    comet::{CometSource, HttpCometSource},
    committee::authenticate,
    validate::{verify_commit, verify_structure},
};
use test_harness::{Devnet, DevnetSpec};

#[tokio::test]
#[ignore = "requires Docker: live stock CometBFT and Etna ABCI devnet"]
async fn lander_live_comet_collector_preserves_and_authenticates_certificates() -> Result<()> {
    test_harness::init_tracing();
    let devnet = Devnet::start(DevnetSpec::default()).await?;
    devnet.wait_for_height(0, 5, Duration::from_secs(90)).await?;
    let source =
        HttpCometSource::new(devnet.cmt(0).url(), Duration::from_secs(10), 16 * 1024 * 1024)?;
    let status = source.status().await?;
    assert_eq!(status.chain_id, "taiko-etna-167001-g0");
    assert!(status.height >= 5);
    let committee = source.committee(0).await?;
    assert_eq!(Some(committee.clone()), devnet.cmt(0).committee(0).await?);
    let onchain = devnet
        .l1()
        .get_storage_at(
            devnet.params().inbox,
            U256::from_be_bytes(inbox::slot(inbox::GENESIS_COMMITTEE_HASH).0),
        )
        .await?;
    let hash = record_hash(devnet.params().l2_chain_id, &committee.record);
    assert_eq!(U256::from_be_bytes(hash.0), onchain);
    let authenticated = authenticate(committee, 0, hash, devnet.params())?;
    let genesis = devnet
        .l2_provider(0)
        .get_block_by_number(BlockNumberOrTag::Number(0))
        .await?
        .context("L2 genesis")?;
    let mut parent = genesis.header.hash;
    let mut previous = None;
    let mut blocks = Vec::new();
    for height in 1..=5 {
        let pair = source.block(height).await?;
        let raw = devnet.cmt(0).call("block", &[("height", height.to_string())]).await?;
        let direct: tendermint::Block = serde_json::from_value(raw["block"].clone())?;
        assert_eq!(pair.block, direct);
        verify_commit(&pair.commit, &pair.block.header, &authenticated, &status.chain_id)?;
        let envelope = verify_structure(&pair, previous.as_ref(), height, parent)
            .with_context(|| format!("live block {height} structure"))?;
        assert_eq!(envelope, EtnaEnvelope::decode(&pair.block.data[0])?);
        parent = envelope.block.header.hash_slow();
        previous = Some(pair.clone());
        blocks.push(pair);
    }
    let limits = lander::Limits {
        max_blocks: 5,
        max_blobs: 6,
        max_payload_bytes: 700_000,
        max_message_bytes: 700_000,
        max_decompressed_bytes: 5 * 700_000,
    };
    let payload = codec::encode(&blocks, &limits)?;
    let published = blocks
        .iter()
        .map(|pair| codec::PublishedBlock::try_from(pair).unwrap())
        .collect::<Vec<_>>();
    assert_eq!(codec::decode(&payload, &limits)?, published);
    assert!(devnet.cmt(0).committee(1).await?.is_none(), "no switch witness exists by height 5");
    devnet.stop().await
}
