//! Configuration types for the prover.

use std::{path::PathBuf, time::Duration};

use alloy_primitives::{Address, B256};
use base_tx_manager::{ConfigError, TxManagerConfig};
use rpc::{SubscriptionSource, TxManagerConfigParams};
use url::Url;

/// Configuration for the prover (CLI flags map 1:1 onto these fields).
#[derive(Debug, Clone)]
pub struct ProverConfigs {
    /// L1 provider source (HTTP or WebSocket); event-scanner handles either.
    pub l1_provider_source: SubscriptionSource,
    /// L2 public provider URL.
    pub l2_provider_url: Url,
    /// L2 authenticated (engine) provider URL.
    pub l2_auth_provider_url: Url,
    /// Path to the engine JWT secret.
    pub jwt_secret: PathBuf,
    /// Shasta inbox address.
    pub inbox_address: Address,
    /// L1 prover private key (signs `Inbox.prove` transactions).
    pub l1_prover_private_key: B256,
    /// raiko base host (sgx compose path).
    pub raiko_host: Url,
    /// Optional raiko ZKVM host; enables the zk_any-first path.
    pub raiko_zkvm_host: Option<Url>,
    /// Optional raiko API key (from `--raiko.apiKeyPath`, trimmed).
    pub raiko_api_key: Option<String>,
    /// raiko per-request timeout (Go default: 10m).
    pub raiko_request_timeout: Duration,
    /// Optional override for the first proposal id to prove.
    pub starting_proposal_id: Option<u64>,
    /// Prove proposals whose designated prover is someone else, after their
    /// proving window expires.
    pub prove_unassigned_proposals: bool,
    /// Allowed proving range above last finalized (0 = unlimited). Go
    /// `--prover.proposal.window.size`.
    pub proposal_window_size: u64,
    /// Maximum proposal distance above the last finalized proposal for which a
    /// ZK proof is requested; beyond it the prover falls back to the base proof
    /// so a slow ZK proof does not block catch-up.
    ///
    /// Rust-only catch-up optimization (default 30); the Go prover has no
    /// proposal-distance gate. `--prover.maxZKProofProposalDistance`.
    pub max_zk_proof_proposal_distance: u64,
    /// Produce filler proofs instead of calling raiko (tests/devnet).
    pub dummy: bool,
    /// raiko polling interval (Go default: 10s).
    pub proof_polling_interval: Duration,
    /// Extra proposer addresses this prover proves for.
    pub local_proposer_addresses: Vec<Address>,
    /// L1 confirmations before handling a `Proposed` event (Go default: 6).
    pub block_confirmations: u64,
    /// Force aggregation of a non-empty buffer after this interval
    /// (Go default: 30m).
    pub force_batch_proving_interval: Duration,
    /// SGX proof buffer size (Go default: 1).
    pub sgx_batch_size: u64,
    /// ZK proof buffer size (Go default: 1).
    pub zkvm_batch_size: u64,
    /// Run the full pipeline but skip L1 submission (rollout shadow gate).
    pub shadow_mode: bool,
    /// Interval between tx-manager resubmissions for an unconfirmed prove
    /// transaction.
    pub retry_interval: Duration,
    /// Maximum time to keep retrying and polling before giving up on a prove
    /// transaction; also bounds not-in-mempool waiting.
    pub confirmation_timeout: Duration,
    /// Optional override for tx-manager receipt polling (integration tests).
    pub receipt_query_interval: Option<Duration>,
    /// Minimum priority fee floor in gwei for prove transactions.
    pub min_tip_cap_gwei: u64,
    /// Minimum EIP-1559 base fee floor in gwei for prove transactions.
    pub min_base_fee_gwei: u64,
}

impl ProverConfigs {
    /// Translate the prover-facing retry and fee-floor knobs into a tx-manager
    /// config via the shared [`rpc::base_tx_manager_config`] builder, passing no
    /// blob fee floor since prove transactions carry no blobs.
    ///
    /// # Errors
    ///
    /// Returns [`ConfigError`] when the derived tx-manager config violates
    /// upstream invariants, such as zero resubmission or confirmation windows.
    pub fn to_tx_manager_config(&self) -> Result<TxManagerConfig, ConfigError> {
        rpc::base_tx_manager_config(&TxManagerConfigParams {
            min_tip_cap_gwei: self.min_tip_cap_gwei,
            min_base_fee_gwei: self.min_base_fee_gwei,
            min_blob_fee_gwei: None,
            retry_interval: self.retry_interval,
            confirmation_timeout: self.confirmation_timeout,
            receipt_query_interval: self.receipt_query_interval,
        })
    }
}

#[cfg(test)]
pub(crate) mod tests {
    use std::{path::PathBuf, time::Duration};

    use alloy_primitives::{Address, B256};
    use base_tx_manager::{ConfigError, TxManagerConfig};
    use rpc::SubscriptionSource;

    use super::ProverConfigs;

    pub(crate) fn test_configs() -> ProverConfigs {
        ProverConfigs {
            l1_provider_source: SubscriptionSource::try_from("http://localhost:8545").unwrap(),
            l2_provider_url: "http://localhost:9545".parse().unwrap(),
            l2_auth_provider_url: "http://localhost:9551".parse().unwrap(),
            jwt_secret: PathBuf::from("/tmp/jwt.secret"),
            inbox_address: Address::repeat_byte(0x11),
            l1_prover_private_key: B256::repeat_byte(0x33),
            raiko_host: "http://localhost:9999".parse().unwrap(),
            raiko_zkvm_host: None,
            raiko_api_key: None,
            raiko_request_timeout: Duration::from_secs(600),
            starting_proposal_id: None,
            prove_unassigned_proposals: false,
            proposal_window_size: 0,
            max_zk_proof_proposal_distance: 30,
            dummy: false,
            proof_polling_interval: Duration::from_secs(10),
            local_proposer_addresses: vec![],
            block_confirmations: 6,
            force_batch_proving_interval: Duration::from_secs(1_800),
            sgx_batch_size: 1,
            zkvm_batch_size: 1,
            shadow_mode: false,
            // Matches the shipping `--prove.retryInterval` default so the
            // fixture exercises the real value.
            retry_interval: Duration::from_secs(48),
            confirmation_timeout: Duration::from_secs(180),
            receipt_query_interval: None,
            min_tip_cap_gwei: 2,
            min_base_fee_gwei: 3,
        }
    }

    #[test]
    fn config_maps_fee_floors_into_tx_manager_config() {
        let tx_manager_config = test_configs().to_tx_manager_config().unwrap();
        assert_eq!(tx_manager_config.min_tip_cap, 2_000_000_000);
        assert_eq!(tx_manager_config.min_basefee, 3_000_000_000);
        // No blob fee floor: prove transactions carry no blobs.
        assert_eq!(tx_manager_config.min_blob_fee, TxManagerConfig::default().min_blob_fee);
        // Fee-bump ceiling pinned to Go's `--tx.feeLimitMultiplier` default (10),
        // not the base tx-manager default of 5.
        assert_eq!(tx_manager_config.fee_limit_multiplier, 10);
    }

    #[test]
    fn config_maps_retry_controls_into_resubmission_and_confirmation_timeouts() {
        let tx_manager_config = test_configs().to_tx_manager_config().unwrap();
        assert_eq!(tx_manager_config.resubmission_timeout, Duration::from_secs(48));
        assert_eq!(tx_manager_config.tx_not_in_mempool_timeout, Duration::from_secs(180));
        assert_eq!(tx_manager_config.confirmation_timeout, Duration::from_secs(180));
        assert_eq!(tx_manager_config.num_confirmations, 1);
    }

    #[test]
    fn config_rejects_zero_retry_interval() {
        let mut configs = test_configs();
        configs.retry_interval = Duration::ZERO;
        let err = configs.to_tx_manager_config().unwrap_err();
        assert!(matches!(err, ConfigError::OutOfRange { field: "resubmission_timeout", .. }));
    }

    #[test]
    fn config_maps_receipt_query_interval_when_requested() {
        let mut configs = test_configs();
        configs.receipt_query_interval = Some(Duration::from_millis(100));
        let tx_manager_config = configs.to_tx_manager_config().unwrap();
        assert_eq!(tx_manager_config.receipt_query_interval, Duration::from_millis(100));
    }
}
