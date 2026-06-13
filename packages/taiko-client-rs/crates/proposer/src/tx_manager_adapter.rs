//! Adapter utilities for translating proposer-owned proposal transactions into tx-manager inputs.

use std::sync::Arc;

use alloy::primitives::U256;
use alloy_provider::RootProvider;
use base_tx_manager::{BaseTxMetrics, SimpleTxManager, TxCandidate, TxManagerError};

use crate::{
    config::ProposerConfigs,
    error::{ProposerError, Result},
    transaction_builder::BuiltProposalTx,
};

/// Build the proposer transaction manager from proposer configuration and an L1 root provider.
pub(crate) async fn build_tx_manager(
    cfg: &ProposerConfigs,
    provider: RootProvider,
) -> Result<SimpleTxManager> {
    let tx_manager_config = cfg.to_tx_manager_config().map_err(|err| {
        ProposerError::from(TxManagerError::InvalidConfig(format!(
            "invalid proposer tx-manager config: {err}"
        )))
    })?;
    let tx_manager = rpc::build_tx_manager(
        provider,
        cfg.l1_proposer_private_key,
        tx_manager_config,
        Arc::new(BaseTxMetrics::new("proposer")),
    )
    .await?;

    Ok(tx_manager)
}

/// Translate a proposer-owned built proposal transaction into a tx-manager candidate.
#[must_use]
pub(crate) fn proposal_candidate(built_tx: BuiltProposalTx) -> TxCandidate {
    let (to, tx_data, gas_limit, sidecar) = built_tx.into_parts();

    TxCandidate {
        tx_data,
        blobs: Arc::new(sidecar.blobs),
        to: Some(to),
        // tx-manager treats 0 as "auto-estimate gas" and will replace it
        // with `max(estimate_gas, gas_limit_floor)` during tx crafting.
        gas_limit: gas_limit.unwrap_or_default(),
        value: U256::ZERO,
    }
}

#[cfg(test)]
mod tests {
    use std::{path::PathBuf, time::Duration};

    use alloy::{
        eips::eip4844::Blob,
        primitives::{Address, Bytes},
        providers::ProviderBuilder,
        rpc::client::RpcClient,
        transports::{http::reqwest::Url, mock::Asserter},
    };
    use base_tx_manager::{ConfigError, TxManagerConfig};
    use rpc::SubscriptionSource;

    use crate::{config::ProposerConfigs, transaction_builder::BuiltProposalTx};

    use super::{build_tx_manager, proposal_candidate};

    #[tokio::test]
    async fn build_tx_manager_accepts_existing_root_provider() {
        let asserter = Asserter::new();
        asserter.push_success(&1u64);
        asserter.push_success(&1u64);
        let provider = ProviderBuilder::default().connect_client(RpcClient::mocked(asserter));

        let config = proposer_config_for_tx_manager_mapping();

        build_tx_manager(&config, provider)
            .await
            .expect("existing root provider should be reusable");
    }

    #[test]
    fn proposal_candidate_carries_call_data_to_inbox_destination() {
        let expected_to = Address::repeat_byte(0x11);
        let expected_data = Bytes::from_static(b"inbox-propose-call");
        let built =
            BuiltProposalTx::from_test_blobs(expected_to, expected_data.clone(), vec![Blob::ZERO])
                .with_gas_limit(210_000);

        let candidate = proposal_candidate(built);

        assert_eq!(candidate.to, Some(expected_to));
        assert_eq!(candidate.tx_data, expected_data);
        assert_eq!(candidate.gas_limit, 210_000);
    }

    #[test]
    fn proposal_candidate_preserves_blob_payload() {
        let built = BuiltProposalTx::from_test_blobs(
            Address::repeat_byte(0x22),
            Bytes::from_static(b"blobbed-proposal"),
            vec![Blob::ZERO, Blob::repeat_byte(0x22)],
        );
        let expected_blobs = built.blobs().to_vec();

        let candidate = proposal_candidate(built);

        assert_eq!(candidate.blobs.as_ref(), &expected_blobs);
        assert_eq!(candidate.gas_limit, 0);
    }

    #[test]
    fn proposer_config_maps_fee_floors_into_tx_manager_config() {
        let config = proposer_config_for_tx_manager_mapping();
        let tx_manager_config = config
            .to_tx_manager_config()
            .expect("fee floor mapping should produce a valid tx-manager config");

        assert_eq!(tx_manager_config.min_tip_cap, 2_000_000_000);
        assert_eq!(tx_manager_config.min_basefee, 3_000_000_000);
        assert_eq!(tx_manager_config.min_blob_fee, 4_000_000_000);
    }

    #[test]
    fn proposer_config_maps_retry_controls_into_resubmission_and_confirmation_timeouts() {
        let config = proposer_config_for_tx_manager_mapping();
        let tx_manager_config = config
            .to_tx_manager_config()
            .expect("retry control mapping should produce a valid tx-manager config");

        assert_eq!(tx_manager_config.resubmission_timeout, Duration::from_secs(45));
        assert_eq!(tx_manager_config.confirmation_timeout, Duration::from_secs(180));
        assert_eq!(tx_manager_config.num_confirmations, 1);
    }

    #[test]
    fn proposer_config_maps_contract_and_leaves_other_tx_manager_defaults_unchanged() {
        let config = proposer_config_for_tx_manager_mapping();
        let tx_manager_config = config
            .to_tx_manager_config()
            .expect("mapping contract should produce a valid tx-manager config");

        let expected = TxManagerConfig {
            num_confirmations: 1,
            min_tip_cap: 2_000_000_000,
            min_basefee: 3_000_000_000,
            resubmission_timeout: Duration::from_secs(45),
            tx_not_in_mempool_timeout: Duration::from_secs(180),
            confirmation_timeout: Duration::from_secs(180),
            min_blob_fee: 4_000_000_000,
            ..TxManagerConfig::default()
        };

        assert_eq!(tx_manager_config, expected);
    }

    #[test]
    fn proposer_config_maps_rejects_zero_retry_interval_when_building_tx_manager_config() {
        let mut config = proposer_config_for_tx_manager_mapping();
        config.retry_interval = Duration::ZERO;

        let err = config
            .to_tx_manager_config()
            .expect_err("zero retry interval should be rejected by tx-manager config validation");

        assert!(matches!(err, ConfigError::OutOfRange { field: "resubmission_timeout", .. }));
    }

    #[test]
    fn proposer_config_maps_receipt_query_interval_when_requested() {
        let mut config = proposer_config_for_tx_manager_mapping();
        config.receipt_query_interval = Some(Duration::from_millis(100));

        let tx_manager_config = config
            .to_tx_manager_config()
            .expect("override should produce a valid tx-manager config");

        assert_eq!(tx_manager_config.receipt_query_interval, Duration::from_millis(100));
    }

    fn proposer_config_for_tx_manager_mapping() -> ProposerConfigs {
        ProposerConfigs {
            l1_provider_source: SubscriptionSource::try_from("http://localhost:8545").unwrap(),
            l2_provider_url: Url::parse("http://localhost:9545").unwrap(),
            l2_auth_provider_url: Url::parse("http://localhost:9551").unwrap(),
            jwt_secret: PathBuf::from("/tmp/jwt.secret"),
            inbox_address: Address::repeat_byte(0x11),
            l2_suggested_fee_recipient: Address::repeat_byte(0x22),
            propose_interval: Duration::from_secs(12),
            l1_proposer_private_key: alloy::primitives::B256::repeat_byte(0x33),
            gas_limit: Some(210_000),
            use_engine_mode: false,
            retry_interval: Duration::from_secs(45),
            confirmation_timeout: Duration::from_secs(180),
            receipt_query_interval: None,
            min_tip_cap_gwei: 2,
            min_base_fee_gwei: 3,
            min_blob_fee_gwei: 4,
        }
    }
}
