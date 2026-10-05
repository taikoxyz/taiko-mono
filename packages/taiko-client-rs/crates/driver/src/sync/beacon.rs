//! Checkpoint-assisted execution engine sync toward the proof-finalized L2 block.
//!
//! The sync target is read trustlessly from the L1 inbox core state
//! (`lastFinalizedProposalId` / `lastFinalizedBlockHash`) at the finalized L1 block, so the
//! target is final on both layers. The optional checkpoint node only serves block bodies and is
//! consulted only when the target body is not already stored locally: every fetched block is
//! verified against the L1-recorded hash before submission, and the execution engine backfills
//! its hash-linked ancestors over P2P.

use std::{sync::Arc, time::Duration};

use alloy::providers::Provider;
use alloy_consensus::{self, Block, TxEnvelope};
use alloy_eips::{BlockId, BlockNumberOrTag};
use alloy_primitives::B256;
use alloy_provider::RootProvider;
use alloy_rpc_types::{Transaction as RpcTransaction, eth::Block as RpcBlock};
use alloy_rpc_types_engine::{ExecutionPayloadV3, ForkchoiceState, PayloadStatusEnum};
use anyhow::anyhow;
use protocol::shasta::{etna_fork_timestamp_for_chain, is_etna_at};
use rpc::{
    client::{Client, connect_http_with_timeout},
    error::RpcClientError,
};
use tokio::time::{MissedTickBehavior, interval};
use tracing::{debug, info, instrument, warn};

use super::{
    SyncError, SyncStage, checkpoint_resume_head::CheckpointResumeHead, contract_rpc_error,
    is_finalized_block_not_found, is_historical_state_unavailable,
};
use crate::{config::DriverConfig, error::DriverError, metrics::DriverMetrics};

/// Default polling interval used when no retry interval is configured.
const DEFAULT_BEACON_SYNC_POLL_INTERVAL: Duration = Duration::from_secs(12);

/// Proof-finalized sync target read from the L1 inbox core state.
#[derive(Debug, Clone, Copy)]
struct FinalizedSyncTarget {
    /// Last proposal id finalized by proof on L1.
    proposal_id: u64,
    /// L2 block hash recorded on L1 for that finalized proposal.
    block_hash: B256,
}

/// Drives the L2 execution engine toward the proof-finalized block recorded on L1.
pub struct BeaconSyncer {
    /// Interval between beacon sync retries.
    retry_interval: Duration,
    /// RPC client used for L1 inbox reads and local engine calls.
    rpc: Client,
    /// Optional untrusted provider used to fetch catch-up block bodies.
    checkpoint: Option<RootProvider>,
    /// Shared resume head consumed by event sync after this stage completes.
    checkpoint_resume_head: Arc<CheckpointResumeHead>,
    /// Etna activation time of the chain, resolved once at construction (`None` while Etna is
    /// not scheduled); decides which checkpoint heads must carry a nonzero beacon root.
    etna_fork_timestamp: Option<u64>,
}

impl BeaconSyncer {
    /// Construct a new beacon syncer from the provided configuration and RPC client, resolving
    /// the chain's Etna activation time once.
    #[instrument(skip(config, rpc))]
    pub fn new(
        config: &DriverConfig,
        rpc: Client,
        checkpoint_resume_head: Arc<CheckpointResumeHead>,
    ) -> Result<Self, DriverError> {
        let chain_id = rpc.chain_id;
        let etna_fork_timestamp = etna_fork_timestamp_for_chain(chain_id)
            .map_err(|source| DriverError::EtnaScheduleUnresolved { chain_id, source })?;
        let checkpoint =
            config.l2_checkpoint_url.as_ref().map(|url| connect_http_with_timeout(url.clone()));

        Ok(Self {
            retry_interval: config.retry_interval,
            rpc,
            checkpoint,
            checkpoint_resume_head,
            etna_fork_timestamp,
        })
    }

    /// Read the proof-finalized sync target from the L1 inbox core state.
    ///
    /// The core state is queried at the finalized L1 block so the returned checkpoint cannot be
    /// reorged away on either layer. Chains without L1 finality yet (fresh devnets) fall back to
    /// the latest block.
    #[instrument(skip(self), level = "debug")]
    async fn finalized_sync_target(&self) -> Result<FinalizedSyncTarget, SyncError> {
        let core_state = match self
            .rpc
            .shasta
            .inbox
            .getCoreState()
            .block(BlockId::Number(BlockNumberOrTag::Finalized))
            .call()
            .await
        {
            Ok(core_state) => core_state,
            Err(err)
                if contract_rpc_error(&err)
                    .is_some_and(|(code, message)| is_finalized_block_not_found(code, message)) =>
            {
                self.rpc
                    .shasta
                    .inbox
                    .getCoreState()
                    .call()
                    .await
                    .map_err(|err| SyncError::Rpc(RpcClientError::Provider(err.to_string())))?
            }
            Err(err) => {
                let historical_state_message = contract_rpc_error(&err)
                    .filter(|(code, message)| is_historical_state_unavailable(*code, message))
                    .map(|(_, message)| message.to_owned());
                if let Some(message) = historical_state_message {
                    return Err(SyncError::HistoricalStateUnavailable { message });
                }
                return Err(SyncError::Rpc(RpcClientError::Provider(err.to_string())));
            }
        };

        Ok(FinalizedSyncTarget {
            proposal_id: core_state.lastFinalizedProposalId.to::<u64>(),
            block_hash: core_state.lastFinalizedBlockHash,
        })
    }

    /// Submit a proof-finalized block body (from either the local store or the checkpoint node)
    /// to the execution engine, starting or advancing the engine's backfill toward it.
    #[instrument(skip(self, block), level = "debug")]
    async fn submit_target_block(&self, block: RpcBlock<TxEnvelope>) -> Result<(), DriverError> {
        let block_number = block.header.number;
        let block_hash = block.hash();
        debug!(block_number, ?block_hash, "submitting checkpoint block to execution engine");

        let CheckpointPayload { payload, header_difficulty, parent_beacon_block_root } =
            checkpoint_payload(block, self.etna_fork_timestamp)?;
        let payload_status = self
            .rpc
            .engine_new_payload_v4(&payload, header_difficulty, parent_beacon_block_root)
            .await?;
        match payload_status.status {
            PayloadStatusEnum::Valid | PayloadStatusEnum::Accepted => {}
            PayloadStatusEnum::Syncing => {
                info!(
                    block_number,
                    "execution engine reported SYNCING for submitted payload; continuing beacon sync"
                );
            }
            PayloadStatusEnum::Invalid { validation_error } => {
                return Err(DriverError::EngineInvalidPayload(validation_error));
            }
        }

        // The submitted block is proof-finalized on L1 and read at a finalized L1 block, so
        // advertising it as finalized to the engine is sound.
        let forkchoice_state = ForkchoiceState {
            head_block_hash: block_hash,
            safe_block_hash: block_hash,
            finalized_block_hash: block_hash,
        };

        let forkchoice = self.rpc.engine_forkchoice_updated_v3(forkchoice_state, None).await?;
        resolve_checkpoint_forkchoice_status(&forkchoice.payload_status.status, block_number)?;

        info!(
            block_number,
            ?block_hash,
            forkchoice_status = ?forkchoice.payload_status.status,
            "checkpoint block submitted"
        );
        Ok(())
    }
}

/// Arguments of the `engine_newPayloadV4` call that imports a sealed checkpoint block.
#[derive(Debug)]
struct CheckpointPayload {
    /// Standard V3 payload of the sealed block.
    payload: ExecutionPayloadV3,
    /// The sealed header's difficulty, i.e. the block's zk gas (0 for an empty block).
    header_difficulty: u64,
    /// The sealed header's `parentBeaconBlockRoot`, zero when absent.
    parent_beacon_block_root: B256,
}

/// Prepare a sealed checkpoint block for `engine_newPayloadV4`.
///
/// Checkpoint import bypasses the local getPayload/newPayload round trip, so the sealed header's
/// difficulty and beacon root are passed through explicitly. A non-genesis head must follow the
/// beacon-root rule of its fork, decided by its own timestamp against `etna_fork_timestamp`: an
/// Etna head carries a nonzero root, a pre-Etna head a zero or missing one. A head that breaks
/// the rule is refused before any engine call, since it is canonical and the client's Etna
/// activation time then disagrees with the execution engine's.
fn checkpoint_payload(
    block: RpcBlock<TxEnvelope>,
    etna_fork_timestamp: Option<u64>,
) -> Result<CheckpointPayload, DriverError> {
    let block_number = block.header.number;
    let timestamp = block.header.timestamp;
    let block_hash = block.hash();
    let difficulty = block.header.difficulty;
    let header_difficulty = u64::try_from(difficulty)
        .map_err(|_| DriverError::CheckpointDifficultyOverflow { block_number, difficulty })?;
    let parent_beacon_block_root = block.header.parent_beacon_block_root.unwrap_or_default();
    if block_number != 0 {
        let is_etna = is_etna_at(etna_fork_timestamp, timestamp);
        if is_etna && parent_beacon_block_root.is_zero() {
            return Err(DriverError::EtnaCheckpointWithoutBeaconRoot { block_number, timestamp });
        }
        if !is_etna && !parent_beacon_block_root.is_zero() {
            return Err(DriverError::PreEtnaCheckpointWithBeaconRoot {
                block_number,
                timestamp,
                root: parent_beacon_block_root,
            });
        }
    }

    let consensus_block: Block<TxEnvelope> = block.into();
    let payload = ExecutionPayloadV3::from_block_unchecked(block_hash, &consensus_block);

    Ok(CheckpointPayload { payload, header_difficulty, parent_beacon_block_root })
}

/// Classify the forkchoice status returned while importing a checkpoint block.
///
/// `SYNCING` means the engine started backfilling toward the submitted head; `VALID` means the
/// head connected to the local chain immediately (small gap or final catch-up tick). Both are
/// successful imports. `INVALID` is a hard rejection, and `ACCEPTED` is never returned by
/// forkchoice updates per the engine API spec.
fn resolve_checkpoint_forkchoice_status(
    status: &PayloadStatusEnum,
    block_number: u64,
) -> Result<(), DriverError> {
    match status {
        PayloadStatusEnum::Valid | PayloadStatusEnum::Syncing => Ok(()),
        PayloadStatusEnum::Invalid { validation_error } => {
            Err(DriverError::EngineInvalidPayload(validation_error.clone()))
        }
        PayloadStatusEnum::Accepted => Err(DriverError::Other(anyhow!(
            "unexpected forkchoice status ACCEPTED for block {block_number}"
        ))),
    }
}

#[async_trait::async_trait]
impl SyncStage for BeaconSyncer {
    /// Run the beacon sync stage, steering the local execution engine toward the proof-finalized
    /// block recorded on L1 until the local canonical chain contains it.
    #[instrument(skip(self), name = "beacon_syncer_run")]
    async fn run(&self) -> Result<(), SyncError> {
        // Always clear stale state from previous attempts so event sync cannot accidentally
        // consume an old checkpoint head after a failed or skipped beacon sync run.
        self.checkpoint_resume_head.clear();

        let Some(checkpoint_provider) = &self.checkpoint else {
            info!("no checkpoint endpoint configured; skipping beacon sync stage");
            return Ok(());
        };

        let poll_interval = if self.retry_interval.is_zero() {
            DEFAULT_BEACON_SYNC_POLL_INTERVAL
        } else {
            self.retry_interval
        };

        let mut ticker = interval(poll_interval);
        ticker.set_missed_tick_behavior(MissedTickBehavior::Skip);

        info!(interval_secs = poll_interval.as_secs(), "beacon sync stage started");

        // Fail-fast gates: each flips once its endpoint has answered successfully, so startup
        // misconfiguration still aborts while mid-catch-up blips retry. The first tick fires
        // immediately, preserving fail-fast timing at startup.
        let mut target_seen_once = false;
        let mut checkpoint_seen_once = false;

        loop {
            ticker.tick().await;

            let local_head =
                match self.rpc.l2_provider.get_block_number().await.map_err(RpcClientError::from) {
                    Ok(block_id) => {
                        DriverMetrics::beacon_sync_local_head_block().set(block_id as f64);
                        block_id
                    }
                    Err(err) => {
                        warn!(error = %err, "failed to query execution engine head");
                        continue;
                    }
                };

            let target = match self.finalized_sync_target().await {
                Ok(target) => {
                    target_seen_once = true;
                    target
                }
                Err(err @ SyncError::HistoricalStateUnavailable { .. }) => {
                    DriverMetrics::beacon_sync_finalized_state_unavailable_total().inc();
                    warn!(error = %err, "finalized L1 state is temporarily unavailable; retrying");
                    continue;
                }
                Err(err) => {
                    let err = super::retryable_after_first_success(target_seen_once, err)?;
                    warn!(error = %err, "failed to read finalized sync target from L1; retrying");
                    continue;
                }
            };

            // A zero hash means the inbox has finalized nothing and recorded no genesis
            // checkpoint yet; event sync will derive everything from the activation block.
            if target.block_hash == B256::ZERO {
                self.checkpoint_resume_head.set(0);
                info!("no proof-finalized checkpoint on L1 yet; skipping checkpoint catch-up");
                break Ok(());
            }

            // Prefer a locally stored body: after a routine restart the target is usually
            // already canonical, and any locally available copy keeps this stage independent
            // of checkpoint availability. Trust comes from hashing to the L1-recorded value,
            // not from the body's source.
            let local_body =
                match self.rpc.l2_provider.get_block_by_hash(target.block_hash).full().await {
                    Ok(block) => {
                        block.map(|block| block.map_transactions(|tx: RpcTransaction| tx.into()))
                    }
                    Err(err) => {
                        warn!(
                            target_hash = ?target.block_hash,
                            error = %err,
                            "failed to query local engine for the finalized target body; retrying"
                        );
                        continue;
                    }
                };

            let block = match local_body {
                Some(block) => block,
                None => match checkpoint_provider.get_block_by_hash(target.block_hash).full().await
                {
                    Ok(Some(block)) => {
                        checkpoint_seen_once = true;
                        block.map_transactions(|tx: RpcTransaction| tx.into())
                    }
                    Ok(None) => {
                        checkpoint_seen_once = true;
                        warn!(
                            target_proposal_id = target.proposal_id,
                            target_hash = ?target.block_hash,
                            "checkpoint node does not have the finalized target block; retrying"
                        );
                        continue;
                    }
                    Err(err) => {
                        let err = super::retryable_after_first_success(
                            checkpoint_seen_once,
                            SyncError::CheckpointQuery(RpcClientError::from(err)),
                        )?;
                        warn!(
                            error = %err,
                            "failed to fetch finalized target block from checkpoint node; retrying"
                        );
                        continue;
                    }
                },
            };

            // Never trust the body source: it must hash to the L1-recorded value. The engine
            // re-checks this on newPayload, but verifying here keeps a bad source a retryable
            // condition instead of a fatal INVALID.
            if block.header.inner.hash_slow() != target.block_hash {
                warn!(
                    target_proposal_id = target.proposal_id,
                    target_hash = ?target.block_hash,
                    "fetched target block does not hash to the L1 checkpoint; retrying"
                );
                continue;
            }

            let target_block_number = block.header.number;
            DriverMetrics::beacon_sync_checkpoint_head_block().set(target_block_number as f64);
            DriverMetrics::beacon_sync_head_lag_blocks()
                .set(target_block_number.saturating_sub(local_head) as f64);

            // Done once the local canonical chain contains the finalized target. Checking the
            // hash at the target height (rather than comparing heights) also catches a local
            // chain that diverges from the proof-finalized one.
            match self
                .rpc
                .l2_provider
                .get_block_by_number(BlockNumberOrTag::Number(target_block_number))
                .await
            {
                Ok(Some(local_block)) if local_block.header.hash == target.block_hash => {
                    // Persist the finalized block number event sync uses as its authoritative
                    // resume source when checkpoint mode is enabled.
                    self.checkpoint_resume_head.set(target_block_number);
                    info!(
                        target_proposal_id = target.proposal_id,
                        target_block_number,
                        target_hash = ?target.block_hash,
                        local_head,
                        "local engine contains the proof-finalized target; done"
                    );
                    break Ok(());
                }
                Ok(_) => {}
                Err(err) => {
                    warn!(
                        target_block_number,
                        error = %err,
                        "failed to query local block at finalized target height; retrying"
                    );
                    continue;
                }
            }

            info!(
                target_proposal_id = target.proposal_id,
                target_block_number, local_head, "syncing execution engine toward finalized target"
            );

            match self.submit_target_block(block).await {
                Ok(()) => DriverMetrics::beacon_sync_remote_submissions_total().inc(),
                // An INVALID verdict is not transient: the block hashes to the L1 checkpoint yet
                // the engine rejects it, which needs operator attention rather than retries. A
                // verified head that breaks its fork's beacon-root rule, in either direction, is
                // just as deterministic: the client's Etna schedule disagrees with the execution
                // engine's.
                Err(
                    err @ (DriverError::EngineInvalidPayload(_) |
                    DriverError::EtnaCheckpointWithoutBeaconRoot { .. } |
                    DriverError::PreEtnaCheckpointWithBeaconRoot { .. }),
                ) => {
                    return Err(SyncError::RemoteBlockSubmit {
                        block_number: target_block_number,
                        error: err.into(),
                    });
                }
                Err(err) => {
                    warn!(
                        target_block_number,
                        error = %err,
                        "failed to submit finalized target block; retrying"
                    );
                }
            }
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use alloy::{
        primitives::Bytes, rpc::types::eth::BlockTransactions, sol_types::SolCall,
        transports::http::reqwest::Url,
    };
    use alloy_primitives::U256;
    use alloy_provider::ProviderBuilder;
    use alloy_rpc_types_engine::{ForkchoiceUpdated, PayloadStatus};
    use alloy_transport::mock::Asserter;
    use bindings::inbox::{IInbox::CoreState, Inbox::getCoreStateCall};
    use protocol::shasta::constants::TAIKO_MAINNET_CHAIN_ID;
    use rpc::{SubscriptionSource, client::ClientConfig};
    use std::path::PathBuf;

    use crate::test_support::{mock_client_with_asserters, mock_client_with_l1_asserter};

    fn push_geth_server_error(asserter: &Asserter, message: &str) {
        asserter.push_failure(alloy_json_rpc::ErrorPayload {
            code: -32000,
            message: message.to_owned().into(),
            data: None,
        });
    }

    fn empty_core_state() -> CoreState {
        CoreState {
            nextProposalId: Default::default(),
            lastProposalBlockId: Default::default(),
            lastFinalizedProposalId: Default::default(),
            lastFinalizedTimestamp: Default::default(),
            lastCheckpointTimestamp: Default::default(),
            lastFinalizedBlockHash: B256::ZERO,
        }
    }

    #[test_log::test(tokio::test(start_paused = true))]
    async fn run_retries_historical_state_gap_before_first_finalized_target() {
        let unavailable_before =
            DriverMetrics::beacon_sync_finalized_state_unavailable_total().get();
        let l1_asserter = Asserter::new();
        let l2_asserter = Asserter::new();
        l2_asserter.push_success(&0u64);
        push_geth_server_error(
            &l1_asserter,
            concat!(
                "historical state ",
                "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
                " is not available"
            ),
        );
        l2_asserter.push_success(&0u64);
        l1_asserter
            .push_success(&Bytes::from(getCoreStateCall::abi_encode_returns(&empty_core_state())));

        let checkpoint_resume_head = Arc::new(CheckpointResumeHead::default());
        let syncer = BeaconSyncer {
            retry_interval: Duration::from_secs(1),
            rpc: mock_client_with_asserters(
                l1_asserter.clone(),
                l2_asserter.clone(),
                Asserter::new(),
                Default::default(),
            ),
            checkpoint: Some(
                ProviderBuilder::new()
                    .disable_recommended_fillers()
                    .connect_mocked_client(Asserter::new()),
            ),
            checkpoint_resume_head: checkpoint_resume_head.clone(),
            etna_fork_timestamp: None,
        };
        let run = syncer.run();
        tokio::pin!(run);

        assert!(
            tokio::time::timeout(Duration::from_millis(100), &mut run).await.is_err(),
            "known historical-state gap must remain pending before the first successful target"
        );
        tokio::time::advance(Duration::from_secs(1)).await;
        tokio::time::timeout(Duration::from_millis(100), &mut run)
            .await
            .expect("beacon sync should retry on the next poll")
            .expect("beacon sync should accept the retried finalized target");

        assert_eq!(checkpoint_resume_head.get(), Some(0));
        assert!(
            DriverMetrics::beacon_sync_finalized_state_unavailable_total().get() >
                unavailable_before,
            "beacon sync must expose the degraded finalized-state read"
        );
        assert!(l1_asserter.read_q().is_empty());
        assert!(l2_asserter.read_q().is_empty());
    }

    #[test_log::test(tokio::test(start_paused = true))]
    async fn run_fails_fast_on_unrelated_error_before_first_finalized_target() {
        let l1_asserter = Asserter::new();
        let l2_asserter = Asserter::new();
        l2_asserter.push_success(&0u64);
        push_geth_server_error(&l1_asserter, "historical state database is not available");

        let syncer = BeaconSyncer {
            retry_interval: Duration::from_secs(1),
            rpc: mock_client_with_asserters(
                l1_asserter,
                l2_asserter,
                Asserter::new(),
                Default::default(),
            ),
            checkpoint: Some(
                ProviderBuilder::new()
                    .disable_recommended_fillers()
                    .connect_mocked_client(Asserter::new()),
            ),
            checkpoint_resume_head: Arc::new(CheckpointResumeHead::default()),
            etna_fork_timestamp: None,
        };

        let err = tokio::time::timeout(Duration::from_millis(100), syncer.run())
            .await
            .expect("unrelated startup error must not enter the retry loop")
            .expect_err("unrelated startup error must fail fast");

        assert!(matches!(err, SyncError::Rpc(RpcClientError::Provider(_))));
    }

    #[tokio::test]
    async fn finalized_target_uses_latest_only_before_first_l1_finality() {
        let l1_asserter = Asserter::new();
        push_geth_server_error(&l1_asserter, crate::sync::FINALIZED_BLOCK_NOT_FOUND);
        l1_asserter
            .push_success(&Bytes::from(getCoreStateCall::abi_encode_returns(&empty_core_state())));
        let syncer = BeaconSyncer {
            retry_interval: Duration::from_secs(1),
            rpc: mock_client_with_l1_asserter(l1_asserter.clone()),
            checkpoint: None,
            checkpoint_resume_head: Arc::new(CheckpointResumeHead::default()),
            etna_fork_timestamp: None,
        };

        let target = syncer
            .finalized_sync_target()
            .await
            .expect("fresh devnet should use latest until its first finalized block exists");

        assert_eq!(target.proposal_id, 0);
        assert_eq!(target.block_hash, B256::ZERO);
        assert!(l1_asserter.read_q().is_empty());
    }

    #[test]
    fn checkpoint_forkchoice_accepts_syncing_and_valid() {
        assert!(resolve_checkpoint_forkchoice_status(&PayloadStatusEnum::Syncing, 7).is_ok());
        assert!(resolve_checkpoint_forkchoice_status(&PayloadStatusEnum::Valid, 7).is_ok());
    }

    #[test]
    fn checkpoint_forkchoice_rejects_invalid_with_engine_error() {
        let status = PayloadStatusEnum::Invalid { validation_error: "bad state root".into() };
        assert!(matches!(
            resolve_checkpoint_forkchoice_status(&status, 7),
            Err(DriverError::EngineInvalidPayload(message)) if message == "bad state root"
        ));
    }

    #[test]
    fn checkpoint_forkchoice_rejects_accepted_as_unexpected() {
        assert!(resolve_checkpoint_forkchoice_status(&PayloadStatusEnum::Accepted, 7).is_err());
    }

    /// Timestamp of [`sample_checkpoint_block`].
    const SAMPLE_CHECKPOINT_TIMESTAMP: u64 = 100;

    /// Sealed checkpoint block 9 with the given header difficulty and beacon root.
    fn sample_checkpoint_block(difficulty: U256, root: Option<B256>) -> RpcBlock<TxEnvelope> {
        let mut block = RpcBlock::<TxEnvelope>::default();
        block.header.hash = B256::with_last_byte(0x09);
        block.header.inner.number = 9;
        block.header.inner.timestamp = SAMPLE_CHECKPOINT_TIMESTAMP;
        block.header.inner.difficulty = difficulty;
        block.header.inner.parent_beacon_block_root = root;
        block.transactions = BlockTransactions::Full(Vec::new());
        block.withdrawals = Some(Default::default());
        block
    }

    /// An Unzen head keeps its zero root and difficulty, whether Etna is unscheduled or
    /// scheduled after it.
    #[test]
    fn unzen_checkpoint_head_uses_new_payload_v4_with_zero_root_and_its_difficulty() {
        for etna_fork_timestamp in [None, Some(SAMPLE_CHECKPOINT_TIMESTAMP + 1)] {
            let payload = checkpoint_payload(
                sample_checkpoint_block(U256::from(7u64), Some(B256::ZERO)),
                etna_fork_timestamp,
            )
            .expect("Unzen checkpoint payload");

            assert_eq!(
                payload.payload.payload_inner.payload_inner.block_hash,
                B256::with_last_byte(0x09)
            );
            assert_eq!(payload.payload.payload_inner.payload_inner.block_number, 9);
            assert!(payload.payload.payload_inner.withdrawals.is_empty());
            assert_eq!(payload.header_difficulty, 7);
            assert_eq!(payload.parent_beacon_block_root, B256::ZERO);
        }
    }

    #[test]
    fn etna_checkpoint_head_passes_its_own_header_root_and_zero_difficulty() {
        let root = B256::with_last_byte(0xaa);
        let payload = checkpoint_payload(
            sample_checkpoint_block(U256::ZERO, Some(root)),
            Some(SAMPLE_CHECKPOINT_TIMESTAMP),
        )
        .expect("Etna checkpoint payload");

        assert_eq!(payload.header_difficulty, 0, "an empty Etna block keeps its zero zk gas");
        assert_eq!(payload.parent_beacon_block_root, root);
    }

    /// A non-genesis Etna head must carry the nonzero L1 state root of its anchor block.
    #[test]
    fn etna_checkpoint_head_without_root_is_rejected() {
        for root in [None, Some(B256::ZERO)] {
            let err = checkpoint_payload(
                sample_checkpoint_block(U256::ZERO, root),
                Some(SAMPLE_CHECKPOINT_TIMESTAMP),
            )
            .expect_err("an Etna head needs a nonzero root");

            assert!(
                matches!(
                    err,
                    DriverError::EtnaCheckpointWithoutBeaconRoot {
                        block_number: 9,
                        timestamp: SAMPLE_CHECKPOINT_TIMESTAMP,
                    }
                ),
                "root {root:?}: unexpected error {err:?}"
            );
        }
    }

    /// A non-genesis head that the client places before Etna, whether Etna is unscheduled or
    /// scheduled after it, must not carry a nonzero root: the execution engine built it as an
    /// Etna block.
    #[test]
    fn pre_etna_checkpoint_head_with_root_is_rejected() {
        let root = B256::with_last_byte(0xaa);
        for etna_fork_timestamp in [None, Some(SAMPLE_CHECKPOINT_TIMESTAMP + 1)] {
            let err = checkpoint_payload(
                sample_checkpoint_block(U256::ZERO, Some(root)),
                etna_fork_timestamp,
            )
            .expect_err("a pre-Etna head needs a zero or missing root");

            assert!(
                matches!(
                    err,
                    DriverError::PreEtnaCheckpointWithBeaconRoot {
                        block_number: 9,
                        timestamp: SAMPLE_CHECKPOINT_TIMESTAMP,
                        root: r,
                    } if r == root
                ),
                "Etna at {etna_fork_timestamp:?}: unexpected error {err:?}"
            );
        }
    }

    /// The L2 genesis header keeps a zero (or no) root even when Etna is active from genesis.
    #[test]
    fn genesis_checkpoint_head_without_root_is_accepted_with_etna_from_genesis() {
        for root in [None, Some(B256::ZERO)] {
            let mut genesis = sample_checkpoint_block(U256::ZERO, root);
            genesis.header.inner.number = 0;
            genesis.header.inner.timestamp = 0;

            let payload = checkpoint_payload(genesis, Some(0))
                .unwrap_or_else(|err| panic!("root {root:?}: genesis head rejected: {err:?}"));

            assert_eq!(payload.parent_beacon_block_root, B256::ZERO, "root {root:?}");
        }
    }

    #[test]
    fn checkpoint_head_without_root_sends_zero_root() {
        let payload = checkpoint_payload(sample_checkpoint_block(U256::from(7u64), None), None)
            .expect("checkpoint payload");

        assert_eq!(payload.parent_beacon_block_root, B256::ZERO);
    }

    #[test]
    fn checkpoint_head_difficulty_beyond_u64_is_rejected() {
        let difficulty = U256::from(u64::MAX) + U256::from(1u64);
        let err = checkpoint_payload(sample_checkpoint_block(difficulty, Some(B256::ZERO)), None)
            .expect_err("difficulty beyond u64 has no headerDifficulty encoding");

        assert!(matches!(
            err,
            DriverError::CheckpointDifficultyOverflow { block_number: 9, difficulty: d }
                if d == difficulty
        ));
    }

    /// Checkpoint import submits the block with `newPayloadV4`, then promotes it with an
    /// attribute-less `forkchoiceUpdatedV3`, consuming exactly those two engine replies.
    #[tokio::test]
    async fn submit_target_block_imports_then_promotes_the_checkpoint_head() {
        let l2_auth_asserter = Asserter::new();
        l2_auth_asserter.push_success(&PayloadStatus::from_status(PayloadStatusEnum::Syncing));
        l2_auth_asserter.push_success(&ForkchoiceUpdated::from_status(PayloadStatusEnum::Syncing));
        let syncer = BeaconSyncer {
            retry_interval: Duration::from_secs(1),
            rpc: mock_client_with_asserters(
                Asserter::new(),
                Asserter::new(),
                l2_auth_asserter.clone(),
                Default::default(),
            ),
            checkpoint: None,
            checkpoint_resume_head: Arc::new(CheckpointResumeHead::default()),
            etna_fork_timestamp: None,
        };

        syncer
            .submit_target_block(sample_checkpoint_block(U256::from(7u64), Some(B256::ZERO)))
            .await
            .expect("SYNCING import and promotion are accepted");

        assert!(l2_auth_asserter.read_q().is_empty());
    }

    /// An Etna head without a root is refused before any engine call: the auth asserter has no
    /// scripted reply, so a call would surface as an RPC error instead.
    #[tokio::test]
    async fn submit_target_block_rejects_etna_head_without_root_before_engine_calls() {
        let l2_auth_asserter = Asserter::new();
        let syncer = BeaconSyncer {
            retry_interval: Duration::from_secs(1),
            rpc: mock_client_with_asserters(
                Asserter::new(),
                Asserter::new(),
                l2_auth_asserter,
                Default::default(),
            ),
            checkpoint: None,
            checkpoint_resume_head: Arc::new(CheckpointResumeHead::default()),
            etna_fork_timestamp: Some(SAMPLE_CHECKPOINT_TIMESTAMP),
        };

        let err = syncer
            .submit_target_block(sample_checkpoint_block(U256::ZERO, Some(B256::ZERO)))
            .await
            .expect_err("an Etna head without a root must not reach the engine");

        assert!(matches!(
            err,
            DriverError::EtnaCheckpointWithoutBeaconRoot { block_number: 9, .. }
        ));
    }

    /// A pre-Etna head with a nonzero root is refused before any engine call: the auth asserter
    /// has no scripted reply, so a call would surface as an RPC error instead.
    #[tokio::test]
    async fn submit_target_block_rejects_pre_etna_head_with_root_before_engine_calls() {
        let l2_auth_asserter = Asserter::new();
        let syncer = BeaconSyncer {
            retry_interval: Duration::from_secs(1),
            rpc: mock_client_with_asserters(
                Asserter::new(),
                Asserter::new(),
                l2_auth_asserter,
                Default::default(),
            ),
            checkpoint: None,
            checkpoint_resume_head: Arc::new(CheckpointResumeHead::default()),
            etna_fork_timestamp: Some(SAMPLE_CHECKPOINT_TIMESTAMP + 1),
        };

        let err = syncer
            .submit_target_block(sample_checkpoint_block(
                U256::ZERO,
                Some(B256::with_last_byte(0xaa)),
            ))
            .await
            .expect_err("a pre-Etna head with a root must not reach the engine");

        assert!(matches!(
            err,
            DriverError::PreEtnaCheckpointWithBeaconRoot { block_number: 9, .. }
        ));
    }

    /// Run beacon sync toward `head`, stored locally and recorded on L1 as the proof-finalized
    /// checkpoint but not yet canonical, and return the error that stops the stage. The stage
    /// must stop on the first tick instead of entering the retry loop.
    async fn run_until_checkpoint_head_stops_the_stage(
        mut head: RpcBlock<TxEnvelope>,
        etna_fork_timestamp: Option<u64>,
    ) -> SyncError {
        head.header.hash = head.header.inner.hash_slow();
        let head_hash = head.header.hash;

        let l1_asserter = Asserter::new();
        let mut core_state = empty_core_state();
        core_state.lastFinalizedProposalId = alloy_primitives::aliases::U48::from(1u64);
        core_state.lastFinalizedBlockHash = head_hash;
        l1_asserter.push_success(&Bytes::from(getCoreStateCall::abi_encode_returns(&core_state)));
        let l2_asserter = Asserter::new();
        l2_asserter.push_success(&0u64); // local head
        l2_asserter.push_success(&Some(head)); // locally stored target body
        l2_asserter.push_success(&None::<RpcBlock<TxEnvelope>>); // nothing at the target height

        let syncer = BeaconSyncer {
            retry_interval: Duration::from_secs(1),
            rpc: mock_client_with_asserters(
                l1_asserter,
                l2_asserter.clone(),
                Asserter::new(),
                Default::default(),
            ),
            checkpoint: Some(
                ProviderBuilder::new()
                    .disable_recommended_fillers()
                    .connect_mocked_client(Asserter::new()),
            ),
            checkpoint_resume_head: Arc::new(CheckpointResumeHead::default()),
            etna_fork_timestamp,
        };

        let err = tokio::time::timeout(Duration::from_millis(100), syncer.run())
            .await
            .expect("a misconfigured Etna schedule must not enter the retry loop")
            .expect_err("a misconfigured Etna schedule must stop beacon sync");
        assert!(l2_asserter.read_q().is_empty());
        err
    }

    /// A verified checkpoint head that the client places in Etna but that carries a zero root
    /// stops the stage instead of retrying forever, and the error tells the operator to align
    /// the Etna schedules.
    #[test_log::test(tokio::test(start_paused = true))]
    async fn run_stops_on_etna_checkpoint_head_without_root() {
        let err = run_until_checkpoint_head_stops_the_stage(
            sample_checkpoint_block(U256::ZERO, Some(B256::ZERO)),
            Some(SAMPLE_CHECKPOINT_TIMESTAMP),
        )
        .await;

        let SyncError::RemoteBlockSubmit { block_number: 9, error } = err else {
            panic!("unexpected error: {err:?}");
        };
        assert!(matches!(
            error.downcast_ref::<DriverError>(),
            Some(DriverError::EtnaCheckpointWithoutBeaconRoot { block_number: 9, .. })
        ));
        assert!(
            error.to_string().contains("set --devnet-etna-timestamp to the execution engine's"),
            "missing operator hint: {error}"
        );
    }

    /// A verified checkpoint head that the client places before Etna but that carries a nonzero
    /// root stops the stage the same way: the client's Etna time is later than the engine's.
    #[test_log::test(tokio::test(start_paused = true))]
    async fn run_stops_on_pre_etna_checkpoint_head_with_root() {
        let err = run_until_checkpoint_head_stops_the_stage(
            sample_checkpoint_block(U256::ZERO, Some(B256::with_last_byte(0xaa))),
            Some(SAMPLE_CHECKPOINT_TIMESTAMP + 1),
        )
        .await;

        let SyncError::RemoteBlockSubmit { block_number: 9, error } = err else {
            panic!("unexpected error: {err:?}");
        };
        assert!(matches!(
            error.downcast_ref::<DriverError>(),
            Some(DriverError::PreEtnaCheckpointWithBeaconRoot { block_number: 9, .. })
        ));
        assert!(
            error.to_string().contains("set --devnet-etna-timestamp to the execution engine's"),
            "missing operator hint: {error}"
        );
    }

    /// The syncer resolves the Etna time once from the client's chain id; a chain without a fork
    /// schedule fails construction.
    #[test]
    fn new_resolves_the_etna_schedule_from_the_chain_id() {
        let config = DriverConfig::new(
            ClientConfig {
                l1_provider_source: SubscriptionSource::Http(
                    Url::parse("http://localhost:8545").expect("valid http url"),
                ),
                l2_provider_url: Url::parse("http://localhost:8545").expect("valid http url"),
                l2_auth_provider_url: Url::parse("http://localhost:8551").expect("valid http url"),
                jwt_secret: PathBuf::from("/dev/null"),
                inbox_address: Default::default(),
            },
            Duration::from_secs(1),
            Url::parse("http://localhost:5052").expect("valid beacon url"),
            None,
            None,
            false,
        );

        let mut rpc = mock_client_with_l1_asserter(Asserter::new());
        let err = BeaconSyncer::new(&config, rpc.clone(), Default::default())
            .err()
            .expect("chain 0 has no fork schedule");
        assert!(matches!(err, DriverError::EtnaScheduleUnresolved { chain_id: 0, .. }));

        rpc.chain_id = TAIKO_MAINNET_CHAIN_ID;
        let syncer = BeaconSyncer::new(&config, rpc, Default::default())
            .expect("mainnet has a fork schedule");
        assert_eq!(syncer.etna_fork_timestamp, None, "mainnet does not schedule Etna");
    }
}
