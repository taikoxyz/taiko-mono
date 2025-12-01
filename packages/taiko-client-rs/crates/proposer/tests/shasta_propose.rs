use alloy::primitives::{B256, aliases::U48};
use serial_test::serial;
use test_context::test_context;
use test_harness::{ShastaEnv, evm_mine, shasta::get_proposal_hash};

#[test_context(ShastaEnv)]
#[serial]
#[tokio::test]
async fn propose_shasta_batches(env: &mut ShastaEnv) -> anyhow::Result<()> {
    let proposer = env.proposer.clone();
    let provider = proposer.rpc_client();

    for i in 0..3 {
        assert_eq!(B256::ZERO, get_proposal_hash(&provider, U48::from(i + 1)).await?);

        evm_mine(&provider).await?;
        proposer.fetch_and_propose().await?;

        assert_ne!(B256::ZERO, get_proposal_hash(&provider, U48::from(i + 1)).await?);
    }

    Ok(())
}
