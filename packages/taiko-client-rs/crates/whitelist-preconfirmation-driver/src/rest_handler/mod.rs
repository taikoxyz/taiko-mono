//! Whitelist preconfirmation REST/WS API handler implementation.

use std::{io::Read, sync::Arc, time::Instant};

use alethia_reth_primitives::payload::{
    attributes::{RpcL1Origin, TaikoBlockMetadata, TaikoPayloadAttributes},
    builder::payload_id_taiko,
};
use alloy_eips::BlockNumberOrTag;
use alloy_primitives::{Address, B256, Bloom, FixedBytes, U256};
use alloy_provider::Provider;
use alloy_rpc_types::SyncStatus;
use alloy_rpc_types_engine::{ExecutionPayloadV1, PayloadAttributes as EthPayloadAttributes};
use async_trait::async_trait;
use driver::{PreconfPayload, sync::event::EventSyncer};
use metrics::histogram;
use protocol::{
    shasta::{PAYLOAD_ID_VERSION_V2, calculate_shasta_difficulty, payload_id_to_bytes},
    signer::FixedKSigner,
};
use rpc::{beacon::BeaconClient, client::Client};
use tokio::sync::{Mutex, RwLock, broadcast, mpsc};
use tracing::{debug, warn};

use crate::{
    cache::SharedPreconfCacheState,
    codec::{WhitelistExecutionPayloadEnvelope, block_signing_hash, encode_envelope_ssz},
    error::{Result, WhitelistPreconfirmationDriverError},
    importer::{
        MAX_COMPRESSED_TX_LIST_BYTES, MAX_DECOMPRESSED_TX_LIST_BYTES,
        validate_execution_payload_for_preconf,
    },
    network::NetworkCommand,
    rest::{
        WhitelistRestApi,
        types::{
            BuildPreconfBlockRequest, BuildPreconfBlockResponse, EndOfSequencingNotification,
            LookaheadStatus, SlotRange, WhitelistStatus,
        },
    },
    whitelist_fetcher::WhitelistSequencerFetcher,
};

mod api_impl;
mod compression;
mod lookahead;
mod payload_build;
mod status;

#[cfg(test)]
mod tests;

/// Go default handover-skip slots used for sequencing window split.
const DEFAULT_HANDOVER_SKIP_SLOTS: u64 = 8;
/// Maximum number of pending EOS notifications retained for `/ws` subscribers.
const EOS_NOTIFICATION_CHANNEL_CAPACITY: usize = 128;

/// Implements the whitelist preconfirmation REST/WS API.
pub(crate) struct WhitelistRestHandler<P>
where
    P: Provider + Clone + Send + Sync + 'static,
{
    /// Event syncer for L1 origin lookups.
    event_syncer: Arc<EventSyncer<P>>,
    /// RPC client for L1/L2 reads.
    rpc: Client<P>,
    /// Chain ID for signature domain separation.
    chain_id: u64,
    /// Deterministic signer for block signing.
    signer: FixedKSigner,
    /// Beacon client used to derive current epoch values for EOS requests.
    beacon_client: Arc<BeaconClient>,
    /// Channel to publish messages to the P2P network.
    network_command_tx: mpsc::Sender<NetworkCommand>,
    /// Serializes build requests to avoid concurrent insertion/signing races.
    build_preconf_lock: Mutex<()>,
    /// Fetcher that provides cached, retry-safe whitelist operator lookups.
    sequencer_fetcher: Mutex<WhitelistSequencerFetcher<P>>,
    /// Local peer ID string.
    local_peer_id: String,
    /// Highest unsafe payload block ID tracked by this node (shared with importer).
    highest_unsafe_l2_payload_block_id: Arc<Mutex<u64>>,
    /// Cached lookahead status used for fee-recipient validation.
    lookahead_status: RwLock<Option<LookaheadStatus>>,
    /// Shared cache state used to back `/status` and EOS visibility.
    cache_state: SharedPreconfCacheState,
    /// Broadcast channel for REST `/ws` end-of-sequencing notifications.
    eos_notification_tx: broadcast::Sender<EndOfSequencingNotification>,
}

/// Dependency bundle for constructing `WhitelistRestHandler`.
pub(crate) struct WhitelistRestHandlerParams<P>
where
    P: Provider + Clone + Send + Sync + 'static,
{
    /// Shared event syncer used to read the current L1 origin.
    pub(crate) event_syncer: Arc<EventSyncer<P>>,
    /// L1/L2 RPC client.
    pub(crate) rpc: Client<P>,
    /// Chain ID used for signing and payload hashing.
    pub(crate) chain_id: u64,
    /// Signer used for block signing operations.
    pub(crate) signer: FixedKSigner,
    /// Beacon client used for epoch calculations.
    pub(crate) beacon_client: Arc<BeaconClient>,
    /// Pre-built fetcher for cached whitelist operator lookups.
    pub(crate) sequencer_fetcher: WhitelistSequencerFetcher<P>,
    /// Shared highest unsafe payload block ID (also updated by importer on P2P import).
    pub(crate) highest_unsafe_l2_payload_block_id: Arc<Mutex<u64>>,
    /// Network command sender for gossip publishing.
    pub(crate) network_command_tx: mpsc::Sender<NetworkCommand>,
    /// Shared preconfirmation cache state.
    pub(crate) cache_state: SharedPreconfCacheState,
    /// Local peer ID string.
    pub(crate) local_peer_id: String,
}

impl<P> WhitelistRestHandler<P>
where
    P: Provider + Clone + Send + Sync + 'static,
{
    /// Create a new REST/WS handler.
    pub(crate) fn new(
        WhitelistRestHandlerParams {
            event_syncer,
            rpc,
            chain_id,
            signer,
            beacon_client,
            sequencer_fetcher,
            highest_unsafe_l2_payload_block_id,
            network_command_tx,
            cache_state,
            local_peer_id,
        }: WhitelistRestHandlerParams<P>,
    ) -> Self {
        let (eos_notification_tx, _) = broadcast::channel(EOS_NOTIFICATION_CHANNEL_CAPACITY);
        Self {
            event_syncer,
            rpc,
            chain_id,
            signer,
            beacon_client,
            sequencer_fetcher: Mutex::new(sequencer_fetcher),
            local_peer_id,
            highest_unsafe_l2_payload_block_id,
            lookahead_status: RwLock::new(None),
            cache_state,
            eos_notification_tx,
            network_command_tx,
            build_preconf_lock: Mutex::new(()),
        }
    }
}
