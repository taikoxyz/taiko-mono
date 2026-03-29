//! Adapter utilities for translating proposer-owned proposal transactions into tx-manager inputs.

use std::sync::Arc;

use alloy::{
    network::EthereumWallet, primitives::U256, providers::Provider,
    signers::local::PrivateKeySigner,
};
use alloy_provider::RootProvider;
use alloy_rpc_types::TransactionReceipt;
use base_tx_manager::{
    BaseTxMetrics, RpcErrorClassifier, SimpleTxManager, TxCandidate, TxManager, TxManagerError,
};
use tokio::time::timeout;

use crate::{
    config::ProposerConfigs,
    error::{ProposerError, Result},
    proposer::ProposalSendOutcome,
    transaction_builder::BuiltProposalTx,
};

/// Proposer-owned adapter that translates built proposal transactions into tx-manager sends.
#[derive(Debug)]
pub(crate) struct ProposalTxManager<M = SimpleTxManager> {
    /// Tx-manager instance responsible for nonce, fee bump, and confirmation handling.
    tx_manager: M,
}

impl ProposalTxManager<SimpleTxManager> {
    /// Build the proposer tx-manager adapter from proposer configuration.
    pub(crate) async fn new(cfg: &ProposerConfigs, provider: RootProvider) -> Result<Self> {
        let tx_manager_config = cfg.to_tx_manager_config().map_err(|err| {
            ProposerError::from(TxManagerError::InvalidConfig(format!(
                "invalid proposer tx-manager config: {err}"
            )))
        })?;
        Self::new_with_provider(cfg, provider, tx_manager_config).await
    }

    /// Build the proposer tx-manager adapter from proposer configuration and an existing L1 root
    /// provider.
    async fn new_with_provider(
        cfg: &ProposerConfigs,
        provider: RootProvider,
        tx_manager_config: base_tx_manager::TxManagerConfig,
    ) -> Result<Self> {
        let chain_id = timeout(tx_manager_config.network_timeout, provider.get_chain_id())
            .await
            .map_err(|_| ProposerError::from(TxManagerError::Rpc("get_chain_id timed out".into())))?
            .map_err(|err| {
                ProposerError::from(RpcErrorClassifier::classify_rpc_error(&err.to_string()))
            })?;
        let signer = PrivateKeySigner::from_bytes(&cfg.l1_proposer_private_key).map_err(|err| {
            ProposerError::from(TxManagerError::Sign(format!(
                "failed to build proposer signer from configured private key: {err}"
            )))
        })?;
        let wallet = EthereumWallet::from(signer);
        let tx_manager = SimpleTxManager::new(
            provider,
            wallet,
            tx_manager_config,
            chain_id,
            Arc::new(BaseTxMetrics::new("proposer")),
        )
        .await?;

        Ok(Self { tx_manager })
    }
}

impl<M: TxManager> ProposalTxManager<M> {
    /// Send a proposer-owned built transaction through the tx-manager and classify its outcome.
    pub(crate) async fn send_proposal(
        &self,
        proposal: BuiltProposalTx,
    ) -> Result<ProposalSendOutcome> {
        let candidate = proposal_candidate(proposal);
        classify_send_result(self.tx_manager.send(candidate).await)
    }
}

/// Translate a proposer-owned built proposal transaction into a tx-manager candidate.
#[must_use]
fn proposal_candidate(built_tx: BuiltProposalTx) -> TxCandidate {
    let (to, tx_data, gas_limit, blob_payload) = built_tx.into_parts();

    TxCandidate {
        tx_data,
        blobs: Arc::new(blob_payload.into_blobs()),
        to: Some(to),
        // tx-manager treats 0 as "auto-estimate gas" and will replace it
        // with `max(estimate_gas, gas_limit_floor)` during tx crafting.
        gas_limit: gas_limit.unwrap_or_default(),
        value: U256::ZERO,
    }
}

/// Classify the tx-manager send result into proposer-level outcomes or errors.
fn classify_send_result(
    result: base_tx_manager::TxManagerResult<TransactionReceipt>,
) -> Result<ProposalSendOutcome> {
    match result {
        Ok(receipt) => Ok(ProposalSendOutcome::ConfirmedReceipt { receipt: Box::new(receipt) }),
        Err(err) if is_retry_exhausted(&err) => Ok(ProposalSendOutcome::RetryExhausted),
        Err(err) => Err(err.into()),
    }
}

/// Return `true` when the tx-manager exhausted a bounded retry path and the outer proposer loop
/// should continue.
fn is_retry_exhausted(err: &TxManagerError) -> bool {
    matches!(err, TxManagerError::SendTimeout | TxManagerError::MempoolDeadlineExpired)
}

#[cfg(test)]
mod tests {
    use std::{path::PathBuf, time::Duration};

    use alloy::{
        consensus::{Eip658Value, Receipt, ReceiptEnvelope, ReceiptWithBloom},
        eips::eip4844::Blob,
        primitives::{Address, B256, Bloom, Bytes},
        providers::ProviderBuilder,
        rpc::client::RpcClient,
        transports::{http::reqwest::Url, mock::Asserter},
    };
    use alloy_rpc_types::TransactionReceipt;
    use base_tx_manager::{
        ConfigError, SendHandle, SendResponse, TxManager, TxManagerConfig, TxManagerError,
    };
    use rpc::SubscriptionSource;
    use tokio::sync::oneshot;

    use crate::{
        config::ProposerConfigs,
        error::ProposerError,
        proposer::ProposalSendOutcome,
        transaction_builder::{BuiltProposalTx, ProposalBlobPayload},
    };

    use super::{ProposalTxManager, proposal_candidate};

    impl<M: TxManager> ProposalTxManager<M> {
        /// Construct the adapter directly from a test tx-manager implementation.
        fn from_tx_manager_for_tests(tx_manager: M) -> Self {
            Self { tx_manager }
        }
    }

    #[tokio::test]
    async fn new_with_provider_accepts_existing_root_provider() {
        let asserter = Asserter::new();
        asserter.push_success(&1u64);
        asserter.push_success(&1u64);
        let provider = ProviderBuilder::default().connect_client(RpcClient::mocked(asserter));

        let config = proposal_tx_manager_config_for_tests();
        let tx_manager_config = config
            .to_tx_manager_config()
            .expect("test config should produce a valid tx-manager config");

        ProposalTxManager::new_with_provider(&config, provider, tx_manager_config)
            .await
            .expect("existing root provider should be reusable");
    }

    /// Build a test blob payload without exposing production-side constructors.
    fn proposal_blob_payload_from_blobs(blobs: Vec<Blob>) -> ProposalBlobPayload {
        ProposalBlobPayload::new(
            alloy::consensus::BlobTransactionSidecar::try_from_blobs_with_settings(
                blobs,
                alloy::eips::eip4844::env_settings::EnvKzgSettings::Default.get(),
            )
            .expect("test blobs should produce a blob sidecar"),
        )
    }

    #[test]
    fn proposal_candidate_carries_call_data_to_inbox_destination() {
        let built = BuiltProposalTx::new(
            Address::repeat_byte(0x11),
            Bytes::from_static(b"inbox-propose-call"),
            proposal_blob_payload_from_blobs(vec![Blob::ZERO]),
        )
        .with_gas_limit(210_000);
        let expected_to = built.to();
        let expected_data = built.call_data().clone();

        let candidate = proposal_candidate(built);

        assert_eq!(candidate.to, Some(expected_to));
        assert_eq!(candidate.tx_data, expected_data);
        assert_eq!(candidate.gas_limit, 210_000);
    }

    #[test]
    fn proposal_candidate_preserves_blob_payload() {
        let blob_payload =
            proposal_blob_payload_from_blobs(vec![Blob::ZERO, Blob::repeat_byte(0x22)]);
        let built = BuiltProposalTx::new(
            Address::repeat_byte(0x22),
            Bytes::from_static(b"blobbed-proposal"),
            blob_payload.clone(),
        );

        let candidate = proposal_candidate(built);

        assert_eq!(candidate.blobs.as_ref(), blob_payload.blobs());
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

    #[tokio::test]
    async fn tx_manager_timeout_maps_to_retry_exhausted() {
        let adapter = ProposalTxManager::from_tx_manager_for_tests(MockTxManager::new(Err(
            TxManagerError::SendTimeout,
        )));

        let outcome = adapter
            .send_proposal(sample_built_proposal())
            .await
            .expect("send timeout should stay on the proposer retry path");

        assert_eq!(outcome, ProposalSendOutcome::RetryExhausted);
    }

    #[tokio::test]
    async fn tx_manager_mempool_deadline_maps_to_retry_exhausted() {
        let adapter = ProposalTxManager::from_tx_manager_for_tests(MockTxManager::new(Err(
            TxManagerError::MempoolDeadlineExpired,
        )));

        let outcome = adapter
            .send_proposal(sample_built_proposal())
            .await
            .expect("bounded retry exhaustion should stay on the proposer retry path");

        assert_eq!(outcome, ProposalSendOutcome::RetryExhausted);
    }

    #[tokio::test]
    async fn tx_manager_successful_send_maps_to_confirmed_receipt_outcome() {
        let receipt = receipt_with_status(true, B256::repeat_byte(0x77));
        let adapter =
            ProposalTxManager::from_tx_manager_for_tests(MockTxManager::new(Ok(receipt.clone())));

        let outcome = adapter
            .send_proposal(sample_built_proposal())
            .await
            .expect("mined proposal should return a proposer success outcome");

        assert_eq!(outcome, ProposalSendOutcome::ConfirmedReceipt { receipt: Box::new(receipt) });
    }

    #[tokio::test]
    async fn tx_manager_confirmed_receipt_outcome_preserves_reverted_receipt_status() {
        let receipt = receipt_with_status(false, B256::repeat_byte(0x55));
        let adapter =
            ProposalTxManager::from_tx_manager_for_tests(MockTxManager::new(Ok(receipt.clone())));

        let outcome = adapter
            .send_proposal(sample_built_proposal())
            .await
            .expect("confirmed reverted receipts should still be surfaced to the caller");

        assert_eq!(
            outcome,
            ProposalSendOutcome::ConfirmedReceipt { receipt: Box::new(receipt.clone()) }
        );
        assert!(!receipt.inner.status(), "caller still needs to inspect receipt.status()");
    }

    #[tokio::test]
    async fn tx_manager_retryable_rpc_error_surfaces_to_proposer_error() {
        let adapter = ProposalTxManager::from_tx_manager_for_tests(MockTxManager::new(Err(
            TxManagerError::Rpc("bounded retries exhausted on provider errors".into()),
        )));

        let err = adapter
            .send_proposal(sample_built_proposal())
            .await
            .expect_err("retryable rpc errors should surface so callers can distinguish them");

        assert!(matches!(err, ProposerError::TxManager(TxManagerError::Rpc(_))));
    }

    #[tokio::test]
    async fn tx_manager_non_retryable_error_maps_to_proposer_error() {
        let adapter = ProposalTxManager::from_tx_manager_for_tests(MockTxManager::new(Err(
            TxManagerError::NonceTooLow,
        )));

        let err = adapter
            .send_proposal(sample_built_proposal())
            .await
            .expect_err("non-retryable tx-manager errors should surface to the proposer");

        assert!(matches!(err, ProposerError::TxManager(TxManagerError::NonceTooLow)));
    }

    #[tokio::test]
    async fn send_proposal_translates_built_proposal_into_tx_candidate() {
        let (tx_manager, sent_candidate) =
            MockTxManager::new_with_capture(Ok(receipt_with_status(true, B256::repeat_byte(0x99))));
        let adapter = ProposalTxManager::from_tx_manager_for_tests(tx_manager);
        let proposal = sample_built_proposal();

        let _outcome = adapter
            .send_proposal(proposal.clone())
            .await
            .expect("capturing mock should return its configured receipt");
        let candidate = sent_candidate
            .lock()
            .expect("poisoned sent-candidate state")
            .clone()
            .expect("adapter should send one tx candidate");

        assert_eq!(candidate.to, Some(proposal.to()));
        assert_eq!(candidate.tx_data, proposal.call_data().clone());
        assert_eq!(candidate.gas_limit, proposal.gas_limit().expect("sample has a gas limit"));
        assert_eq!(candidate.value, alloy::primitives::U256::ZERO);
        assert_eq!(candidate.blobs.as_ref(), proposal.blob_payload().blobs());
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

    fn proposal_tx_manager_config_for_tests() -> ProposerConfigs {
        proposer_config_for_tx_manager_mapping()
    }

    fn sample_built_proposal() -> BuiltProposalTx {
        BuiltProposalTx::new(
            Address::repeat_byte(0x33),
            Bytes::from_static(b"propose-call"),
            proposal_blob_payload_from_blobs(vec![Blob::ZERO]),
        )
        .with_gas_limit(210_000)
    }

    /// Builds a minimal receipt with the requested execution status.
    fn receipt_with_status(success: bool, tx_hash: B256) -> TransactionReceipt {
        let inner = ReceiptEnvelope::Legacy(ReceiptWithBloom {
            receipt: Receipt {
                status: Eip658Value::Eip658(success),
                cumulative_gas_used: 21_000,
                logs: vec![],
            },
            logs_bloom: Bloom::ZERO,
        });

        TransactionReceipt {
            inner,
            transaction_hash: tx_hash,
            transaction_index: Some(0),
            block_hash: Some(B256::ZERO),
            block_number: Some(1),
            gas_used: 21_000,
            effective_gas_price: 1_000_000_000,
            blob_gas_used: None,
            blob_gas_price: None,
            from: Address::ZERO,
            to: Some(Address::ZERO),
            contract_address: None,
        }
    }

    /// Minimal tx-manager stub for adapter result-mapping tests.
    #[derive(Debug)]
    struct MockTxManager {
        response: std::sync::Mutex<Option<SendResponse>>,
        sent_candidate: std::sync::Arc<std::sync::Mutex<Option<base_tx_manager::TxCandidate>>>,
    }

    impl MockTxManager {
        fn new(response: SendResponse) -> Self {
            Self {
                response: std::sync::Mutex::new(Some(response)),
                sent_candidate: std::sync::Arc::new(std::sync::Mutex::new(None)),
            }
        }

        fn new_with_capture(
            response: SendResponse,
        ) -> (Self, std::sync::Arc<std::sync::Mutex<Option<base_tx_manager::TxCandidate>>>)
        {
            let sent_candidate = std::sync::Arc::new(std::sync::Mutex::new(None));
            (
                Self {
                    response: std::sync::Mutex::new(Some(response)),
                    sent_candidate: sent_candidate.clone(),
                },
                sent_candidate,
            )
        }
    }

    impl TxManager for MockTxManager {
        async fn send(&self, candidate: base_tx_manager::TxCandidate) -> SendResponse {
            *self.sent_candidate.lock().expect("poisoned sent-candidate state") = Some(candidate);
            self.response.lock().expect("poisoned mock state").take().expect("response consumed")
        }

        async fn send_async(&self, candidate: base_tx_manager::TxCandidate) -> SendHandle {
            let (tx, rx) = oneshot::channel();
            *self.sent_candidate.lock().expect("poisoned sent-candidate state") = Some(candidate);
            let response = self
                .response
                .lock()
                .expect("poisoned mock state")
                .take()
                .expect("response consumed");
            tx.send(response).expect("mock receiver not dropped");
            SendHandle::new(rx)
        }

        fn sender_address(&self) -> Address {
            Address::ZERO
        }
    }
}
