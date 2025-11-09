//! Event sync logic.

use std::{sync::Arc, time::Duration};

use alloy::{
    eips::BlockNumberOrTag,
    primitives::{Address, U256},
    sol_types::SolEvent,
};
use alloy_consensus::{TxEnvelope, transaction::Transaction as _};
use alloy_provider::Provider;
use alloy_rpc_types::{Transaction as RpcTransaction, eth::Block as RpcBlock};
use alloy_sol_types::SolCall;
use bindings::{anchor::Anchor::anchorV4Call, i_inbox::IInbox::Proposed};
use event_scanner::{EventFilter, ScannerMessage};
use protocol::shasta::constants::BOND_PROCESSING_DELAY;
use tokio::spawn;
use tokio_retry::{Retry, strategy::ExponentialBackoff};
use tokio_stream::StreamExt;
use tracing::{debug, error, info, instrument, warn};

use super::{SyncError, SyncStage};
use crate::{
    config::DriverConfig,
    derivation::{DerivationPipeline, ShastaDerivationPipeline},
};
use rpc::{blob::BlobDataSource, client::Client};

/// Responsible for following inbox events and updating the L2 execution engine accordingly.
pub struct EventSyncer<P>
where
    P: Provider + Clone,
{
    /// RPC client shared with derivation pipeline.
    rpc: Client<P>,
    /// Static driver configuration.
    cfg: DriverConfig,
    /// Shared blob data source used for manifest fetches.
    blob_source: Arc<BlobDataSource>,
}

impl<P> EventSyncer<P>
where
    P: Provider + Clone + Send + Sync + 'static,
{
    /// Construct a new event syncer from the provided configuration and RPC client.
    #[instrument(skip(cfg, rpc))]
    pub async fn new(cfg: &DriverConfig, rpc: Client<P>) -> Result<Self, SyncError> {
        let blob_source = Arc::new(
            BlobDataSource::new(
                Some(cfg.l1_beacon_endpoint.clone()),
                cfg.blob_server_endpoint.clone(),
                false,
            )
            .await
            .map_err(|err| SyncError::Other(err.into()))?,
        );
        Ok(Self { rpc, cfg: cfg.clone(), blob_source })
    }

    /// Determine the L1 block height used to resume event consumption after beacon sync.
    ///
    /// Mirrors the Go driver's `SetUpEventSync` behaviour by querying the execution engine's head,
    /// looking up the corresponding anchor state, and falling back to the cached head L1 origin
    /// if the anchor has not been set yet (e.g. genesis).
    #[instrument(skip(self), level = "debug")]
    async fn event_stream_start_block(&self) -> Result<(u64, U256), SyncError> {
        let latest_block: RpcBlock<TxEnvelope> = self
            .rpc
            .l2_provider
            .get_block_by_number(BlockNumberOrTag::Latest)
            .full()
            .await
            .map_err(|err| SyncError::Rpc(rpc::RpcClientError::Provider(err.to_string())))?
            .ok_or(SyncError::MissingLatestExecutionBlock)?
            .map_transactions(|tx: RpcTransaction| tx.into());

        let anchor_address = *self.rpc.shasta.anchor.address();
        let latest_proposal_id_value = decode_anchor_proposal_id(&latest_block, anchor_address)?;
        let latest_proposal_id = U256::from(latest_proposal_id_value);
        info!(
            latest_proposal_id = latest_proposal_id_value,
            latest_hash = ?latest_block.hash(),
            latest_number = latest_block.number(),
            "derived latest proposal id from latest anchorV4 transaction",
        );

        // Determine the target block to extract the anchor block number from.
        let target_block: RpcBlock<TxEnvelope> = if latest_proposal_id_value > BOND_PROCESSING_DELAY
        {
            let delayed_proposal_id = latest_proposal_id_value - BOND_PROCESSING_DELAY;
            let target_block_number = self
                .rpc
                .last_block_id_by_batch_id(U256::from(delayed_proposal_id))
                .await
                .map_err(|err| SyncError::Rpc(rpc::RpcClientError::Provider(err.to_string())))?
                .ok_or(SyncError::MissingExecutionBlock {
                    number: latest_block.number().saturating_sub(BOND_PROCESSING_DELAY),
                })?;
            self.rpc
                .l2_provider
                .get_block_by_number(BlockNumberOrTag::Number(target_block_number.to()))
                .full()
                .await
                .map_err(|err| SyncError::Rpc(rpc::RpcClientError::Provider(err.to_string())))?
                .ok_or(SyncError::MissingExecutionBlock { number: target_block_number.to() })?
                .map_transactions(|tx: RpcTransaction| tx.into())
        } else {
            latest_block
        };

        info!(
            target_hash = ?target_block.hash(),
            target_block_number = target_block.number(),
            "determined target block for anchor extraction",
        );

        if target_block.header.number == 0 {
            return Ok((0, latest_proposal_id));
        }

        let anchor_block_number = decode_anchor_block_number(&target_block, anchor_address)?;
        info!(
            anchor_block_number,
            latest_hash = ?target_block.hash(),
            latest_number = target_block.number(),
            latest_proposal_id = latest_proposal_id_value,
            "derived anchor block number from latest anchorV4 transaction",
        );
        Ok((anchor_block_number, latest_proposal_id))
    }
}

/// Parse the first transaction in `block` and recover the anchor block number from the
/// `anchorV4` calldata emitted by the goldentouch transaction.
fn decode_anchor_block_number(
    block: &RpcBlock<TxEnvelope>,
    anchor_address: Address,
) -> Result<u64, SyncError> {
    // TODO(David): maybe we can hardcode the deployment height of the inbox contract here.
    if block.header.number == 0 {
        return Ok(0);
    }
    Ok(decode_anchor_call(block, anchor_address)?._blockParams.anchorBlockNumber.to::<u64>())
}

/// Parse the first transaction in `block` and recover the proposal id from the `anchorV4`
/// calldata emitted by the goldentouch transaction.
fn decode_anchor_proposal_id(
    block: &RpcBlock<TxEnvelope>,
    anchor_address: Address,
) -> Result<u64, SyncError> {
    if block.header.number == 0 {
        return Ok(0);
    }
    Ok(decode_anchor_call(block, anchor_address)?._proposalParams.proposalId.to::<u64>())
}

/// Parse the first transaction in `block` and recover the `anchorV4` call data.
fn decode_anchor_call(
    block: &RpcBlock<TxEnvelope>,
    anchor_address: Address,
) -> Result<anchorV4Call, SyncError> {
    let block_number = block.header.number;
    let missing =
        |reason: &'static str| SyncError::MissingAnchorTransaction { block_number, reason };

    let txs = block
        .transactions
        .as_transactions()
        .ok_or_else(|| missing("block body returned only transaction hashes"))?;
    let first_tx = txs.first().ok_or_else(|| missing("block contains no transactions"))?;
    // Anchor transactions are injected as the first transaction for every non-genesis block.
    let destination =
        first_tx.to().ok_or_else(|| missing("unable to determine anchor transaction recipient"))?;
    if destination != anchor_address {
        return Err(missing("first transaction is not the anchor contract"));
    }

    anchorV4Call::abi_decode(first_tx.input())
        .map_err(|_| missing("failed to decode anchorV4 calldata"))
}

#[async_trait::async_trait]
impl<P> SyncStage for EventSyncer<P>
where
    P: Provider + Clone + Send + Sync + 'static,
{
    /// Start the event syncer.
    #[instrument(skip(self), name = "event_syncer_run")]
    async fn run(&self) -> Result<(), SyncError> {
        let (anchor_block_number, latest_proposal_id) = self.event_stream_start_block().await?;
        let start_tag = BlockNumberOrTag::Number(anchor_block_number);

        info!(start_tag = ?start_tag, "starting shasta event processing from L1 block");

        let derivation_pipeline = ShastaDerivationPipeline::new(
            self.rpc.clone(),
            self.blob_source.clone(),
            latest_proposal_id,
        )
        .await?;
        let derivation: Arc<
            dyn DerivationPipeline<
                Manifest = <ShastaDerivationPipeline<P> as DerivationPipeline>::Manifest,
            >,
        > = Arc::new(derivation_pipeline);

        let mut scanner = self
            .cfg
            .client
            .l1_provider_source
            .to_event_scanner_from_tag(start_tag)
            .await
            .map_err(|err| SyncError::EventScannerInit(err.to_string()))?;
        let filter = EventFilter::new()
            .contract_address(self.cfg.client.inbox_address)
            .event(Proposed::SIGNATURE);

        let mut stream = scanner.subscribe(filter);
        debug!("subscribed to inbox proposal event filter");

        spawn(async move {
            if let Err(err) = scanner.start().await {
                error!(?err, "event scanner terminated unexpectedly");
            }
        });

        info!("event scanner started; listening for inbox proposals");

        while let Some(message) = stream.next().await {
            debug!(?message, "received inbox proposal message from event scanner");
            let logs = match message {
                ScannerMessage::Data(logs) => logs,
                ScannerMessage::Error(err) => {
                    error!(?err, "error receiving proposal logs from event scanner");
                    continue;
                }
                ScannerMessage::Status(status) => {
                    info!(?status, "event scanner status update");
                    continue;
                }
            };

            debug!(log_batch_size = logs.len(), "processing proposal log batch");
            for log in logs {
                debug!(
                    block_number = log.block_number,
                    transaction_hash = ?log.transaction_hash,
                    "dispatching proposal log to derivation pipeline"
                );
                let retry_strategy =
                    ExponentialBackoff::from_millis(10).max_delay(Duration::from_secs(12));

                let derivation = derivation.clone();
                let rpc = self.rpc.clone();
                let proposal_log = log.clone();
                let outcomes = Retry::spawn(retry_strategy, move || {
                    let derivation = derivation.clone();
                    let rpc = rpc.clone();
                    let log = proposal_log.clone();
                    async move {
                        derivation.process_proposal(&log, &rpc).await.map_err(|err| {
                            warn!(
                                ?err,
                                tx_hash = ?log.transaction_hash,
                                block_number = log.block_number,
                                "proposal derivation failed; retrying"
                            );
                            err
                        })
                    }
                })
                .await?;

                info!(
                    block_count = outcomes.len(),
                    last_block = outcomes.last().map(|outcome| outcome.block_number()),
                    last_hash = ?outcomes.last().map(|outcome| outcome.block_hash()),
                    "successfully processed proposal into L2 blocks",
                );
            }
        }
        Ok(())
    }
}
