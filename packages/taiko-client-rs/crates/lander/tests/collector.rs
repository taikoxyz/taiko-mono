//! The production collector against stock CometBFT, independently of actual-contract landing.
use std::time::Duration;

use abci::{EtnaEnvelope, Member};
use alloy_eips::BlockNumberOrTag;
use alloy_primitives::U256;
use alloy_provider::Provider;
use anyhow::{Context, Result};
use lander::{
    codec,
    comet::{CometSource, HttpCometSource},
    committee::Validators,
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
    assert_eq!(
        status.chain_id,
        abci::domain::chain_id(&abci::domain::DeploymentDomain {
            l1_chain_id: devnet.params().l1_chain_id,
            l2_chain_id: U256::from(devnet.params().l2_chain_id),
            inbox: devnet.params().inbox,
            generation: 0
        })?
    );
    assert!(status.height >= 5);
    // The genesis set signs every height.
    let members = devnet
        .cmt(0)
        .validators(Some(1))
        .await?
        .into_iter()
        .map(|v| Member { pubkey: v.pubkey, eff_stake: U256::ZERO, power: v.power })
        .collect::<Vec<_>>();
    let validators = Validators::from_members(&members)?;
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
        let direct: tendermint::block::Header =
            serde_json::from_value(raw["block"]["header"].clone())?;
        assert_eq!(pair.block.header, direct);
        assert!(
            pair.commit
                .signatures
                .iter()
                .filter_map(|s| match s {
                    lander::native::CommitSig::BlockIdFlagCommit { signature, .. } =>
                        signature.as_ref(),
                    _ => None,
                })
                .all(|s| s.as_bytes().len() == 65)
        );
        verify_commit(&pair.commit, &pair.block.header, &validators, &status.chain_id)?;
        let envelope = verify_structure(&pair, previous.as_ref(), height, parent)
            .with_context(|| format!("live block {height} structure"))?;
        assert_eq!(envelope, EtnaEnvelope::decode(&pair.block.data[0])?);
        parent = envelope.block.header.hash_slow();
        previous = Some(pair.clone());
        blocks.push(pair);
    }
    let published = blocks
        .iter()
        .map(|pair| codec::PublishedBlock::try_from(pair).unwrap())
        .collect::<Vec<_>>();
    let executions = published.iter().map(|published| &published.block).collect::<Vec<_>>();
    let payload =
        [vec![codec::VERSION], lander::compression::zlib_compress(&alloy_rlp::encode(executions))]
            .concat();
    assert_eq!(
        codec::decode_landed(
            &payload,
            &codec::LandedRange {
                parent_height: 0,
                parent_hash: genesis.header.hash,
                last_height: 5,
                last_block_hash: parent,
                last_state_root: published.last().unwrap().block.header.state_root
            }
        )?,
        published
    );
    devnet.stop().await
}
