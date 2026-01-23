use std::time::Duration;

use alloy::primitives::{B256, U256};
use alloy_provider::Provider;
use proposer::{config::ProposerConfigs, proposer::Proposer};
use serial_test::serial;
use test_context::test_context;
use test_harness::{ShastaEnv, evm_mine, shasta::get_proposal_hash};

fn base_proposer_config(env: &ShastaEnv) -> ProposerConfigs {
    ProposerConfigs {
        l1_provider_source: env.l1_source.clone(),
        l2_provider_url: env.l2_http_0.clone(),
        l2_auth_provider_url: env.l2_auth_0.clone(),
        jwt_secret: env.jwt_secret.clone(),
        inbox_address: env.inbox_address,
        l2_suggested_fee_recipient: env.l2_suggested_fee_recipient,
        propose_interval: Duration::from_secs(0),
        l1_proposer_private_key: env.l1_proposer_private_key,
        gas_limit: None,
        use_engine_mode: false,
    }
}

#[test_context(ShastaEnv)]
#[serial]
#[test_log::test(tokio::test)]
async fn propose_shasta_batches(env: &mut ShastaEnv) -> anyhow::Result<()> {
    let proposer_config = base_proposer_config(env);

    let proposer = Proposer::new(proposer_config).await?;
    let provider = proposer.rpc_client();

    for i in 0..3 {
        assert_eq!(B256::ZERO, get_proposal_hash(&provider, U256::from(i + 1)).await?);

        evm_mine(&provider).await?;
        proposer.fetch_and_propose().await?;

        assert_ne!(B256::ZERO, get_proposal_hash(&provider, U256::from(i + 1)).await?);
    }

    Ok(())
}

/// Test that engine mode can successfully propose batches using the FCU + get_payload flow.
#[test_context(ShastaEnv)]
#[serial]
#[test_log::test(tokio::test)]
async fn propose_shasta_batches_engine_mode(env: &mut ShastaEnv) -> anyhow::Result<()> {
    let mut proposer_config = base_proposer_config(env);
    proposer_config.use_engine_mode = true;

    let proposer = Proposer::new(proposer_config).await?;
    let provider = proposer.rpc_client();

    for i in 0..3 {
        assert_eq!(B256::ZERO, get_proposal_hash(&provider, U256::from(i + 1)).await?);

        evm_mine(&provider).await?;
        proposer.fetch_and_propose().await?;

        assert_ne!(B256::ZERO, get_proposal_hash(&provider, U256::from(i + 1)).await?);
    }

    Ok(())
}
