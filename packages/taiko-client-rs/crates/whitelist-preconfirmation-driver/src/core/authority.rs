//! Shared signer and fee-recipient authority for whitelist preconfirmation.

use std::{
    sync::Arc,
    time::{Duration, Instant},
};

use alloy_eips::{BlockId, BlockNumberOrTag};
use alloy_primitives::Address;
use alloy_provider::Provider;
use async_trait::async_trait;
use bindings::preconf_whitelist::PreconfWhitelist::PreconfWhitelistInstance;
use thiserror::Error;
use tokio::sync::Mutex;
use tracing::debug;

use crate::{
    Result,
    cache::{L1_EPOCH_DURATION_SECS, WhitelistSequencerCache},
    error::WhitelistPreconfirmationDriverError,
    metrics::WhitelistPreconfirmationDriverMetrics,
};

/// Maximum age for stale-cache fallback when node timing data lags epoch start.
const MAX_STALE_FALLBACK_SECS: u64 = 12 * 64;
/// Number of slots before epoch end that switch fee-recipient authority to the next operator.
const DEFAULT_HANDOVER_SKIP_SLOTS: u64 = 8;

/// Shared authority interface for signer and fee-recipient validation.
#[async_trait]
pub(crate) trait SignerAuthority: Send + Sync {
    /// Ensure a payload signer matches the current or next whitelist operator.
    async fn ensure_payload_signer_allowed(&self, signer: Address) -> Result<()>;

    /// Ensure the fee recipient matches the operator allowed for the current handover window.
    async fn ensure_fee_recipient_allowed(&self, fee_recipient: Address) -> Result<()>;
}

/// Shared authority implementation backed by cached L1 whitelist lookups.
pub(crate) struct WhitelistSignerAuthority<P>
where
    P: Provider + Clone + Send + Sync + 'static,
{
    /// Contract binding used for operator lookups.
    whitelist: PreconfWhitelistInstance<P>,
    /// L1 provider used for pinned block and timestamp reads.
    l1_provider: P,
    /// Beacon timing source used for fee-recipient handover checks.
    beacon_timing: Arc<dyn BeaconTiming>,
    /// Cached operator state and miss-refresh cooldowns.
    state: Mutex<AuthorityState>,
}

impl<P> WhitelistSignerAuthority<P>
where
    P: Provider + Clone + Send + Sync + 'static,
{
    /// Create a new whitelist authority from the contract address, provider, and beacon client.
    pub(crate) fn new(
        whitelist_address: Address,
        l1_provider: P,
        beacon_client: Arc<rpc::beacon::BeaconClient>,
    ) -> Self {
        Self::new_with_timing(
            whitelist_address,
            l1_provider,
            Arc::new(BeaconClientTiming::new(beacon_client)),
        )
    }

    /// Create an authority with an explicit beacon timing source.
    fn new_with_timing(
        whitelist_address: Address,
        l1_provider: P,
        beacon_timing: Arc<dyn BeaconTiming>,
    ) -> Self {
        let whitelist = PreconfWhitelistInstance::new(whitelist_address, l1_provider.clone());
        Self { whitelist, l1_provider, beacon_timing, state: Mutex::new(AuthorityState::default()) }
    }

    /// Create a deterministic authority clock for unit tests.
    #[cfg(test)]
    pub(crate) fn new_for_test(
        whitelist_address: Address,
        l1_provider: P,
        current_slot: u64,
        slots_per_epoch: u64,
    ) -> Self {
        Self::new_with_timing(
            whitelist_address,
            l1_provider,
            Arc::new(TestBeaconTiming { current_slot, slots_per_epoch }),
        )
    }

    /// Invalidate cached operators when the L1 head moves past the cached epoch boundary.
    pub(crate) async fn maybe_invalidate_for_epoch_advance(&self) -> Result<()> {
        let latest_block = self
            .l1_provider
            .get_block_by_number(BlockNumberOrTag::Latest)
            .await
            .map_err(WhitelistPreconfirmationDriverError::provider)?;

        let Some(block) = latest_block else {
            return Ok(());
        };

        let mut state = self.state.lock().await;
        if state
            .cache
            .should_invalidate_for_l1_timestamp(block.header.timestamp, L1_EPOCH_DURATION_SECS)
        {
            debug!(
                block_timestamp = block.header.timestamp,
                "invalidating signer authority cache after epoch boundary crossing"
            );
            state.cache.invalidate();
        }

        Ok(())
    }

    /// Ensure the fee recipient is authorized for a specific beacon slot.
    async fn ensure_fee_recipient_allowed_for_slot(
        &self,
        fee_recipient: Address,
        current_slot: u64,
    ) -> Result<()> {
        let now = Instant::now();
        let cached = self.cached_operators(now).await?;

        match self.validate_fee_recipient(fee_recipient, current_slot, cached) {
            Ok(()) => return Ok(()),
            Err(AuthorityCheckError::BothSlotsZero) => {
                return Err(AuthorityCheckError::BothSlotsZero.into_whitelist_lookup_error());
            }
            Err(AuthorityCheckError::FeeRecipientMismatch { .. }) => {
                // A pure fee-recipient mismatch should fail from cached state without
                // evicting signer cache that may be hot in other callers.
                return self
                    .validate_fee_recipient(fee_recipient, current_slot, cached)
                    .map_err(AuthorityCheckError::into_fee_recipient_error);
            }
            Err(AuthorityCheckError::SlotOutsideCachedEpoch { .. }) => {}
            Err(AuthorityCheckError::SignerMismatch { .. }) => {
                unreachable!("signer mismatch is not produced by fee-recipient validation")
            }
        }

        if !cached.any_from_cache {
            return self
                .validate_fee_recipient(fee_recipient, current_slot, cached)
                .map_err(AuthorityCheckError::into_fee_recipient_error);
        }

        debug!(
            %fee_recipient,
            current_slot,
            cached_current = %cached.current,
            cached_next = %cached.next,
            "fee recipient not covered by cached operator snapshot; re-fetching from L1"
        );
        self.invalidate_cache().await;
        let fresh = self.cached_operators(now).await?;
        self.validate_fee_recipient(fee_recipient, current_slot, fresh)
            .map_err(AuthorityCheckError::into_fee_recipient_error)
    }

    /// Ensure the payload signer matches the current or next whitelist operator.
    async fn ensure_payload_signer_allowed_inner(&self, signer: Address) -> Result<()> {
        let now = Instant::now();
        let cached = self.cached_operators(now).await?;

        match validate_signer_pair(signer, cached.current, cached.next) {
            Ok(()) => return Ok(()),
            Err(AuthorityCheckError::BothSlotsZero) => {
                return Err(AuthorityCheckError::BothSlotsZero.into_whitelist_lookup_error());
            }
            Err(AuthorityCheckError::SignerMismatch { .. }) => {}
            Err(AuthorityCheckError::FeeRecipientMismatch { .. }) |
            Err(AuthorityCheckError::SlotOutsideCachedEpoch { .. }) => {
                unreachable!("fee-recipient errors are not produced by signer validation")
            }
        }

        if !cached.any_from_cache {
            return validate_signer_pair(signer, cached.current, cached.next)
                .map_err(AuthorityCheckError::into_signer_error);
        }

        let mut state = self.state.lock().await;
        if !state.cache.allow_miss_refresh(now) {
            debug!(
                %signer,
                cached_current = %cached.current,
                cached_next = %cached.next,
                "signer mismatch refresh cooldown active; rejecting without L1 re-fetch"
            );
            return Err(AuthorityCheckError::SignerMismatch {
                signer,
                current: cached.current,
                next: cached.next,
            }
            .into_signer_error());
        }

        debug!(
            %signer,
            cached_current = %cached.current,
            cached_next = %cached.next,
            "signer not in cached whitelist snapshot; re-fetching from L1"
        );
        state.cache.invalidate();
        drop(state);

        let fresh = self.cached_operators(now).await?;
        validate_signer_pair(signer, fresh.current, fresh.next)
            .map_err(AuthorityCheckError::into_signer_error)
    }

    /// Return current and next operators, using cached values when still valid.
    async fn cached_operators(&self, now: Instant) -> Result<CachedOperators> {
        let state = self.state.lock().await;
        if let Some(cached) = state.cached_operators() {
            return Ok(cached);
        }
        let stale_cached =
            state.stale_cached_operators(now, Duration::from_secs(MAX_STALE_FALLBACK_SECS));
        drop(state);

        let snapshot = self.fetch_operator_snapshot().await?;

        if let Err(err) = ensure_not_too_early_for_epoch(
            snapshot.block_timestamp,
            snapshot.current_epoch_start_timestamp,
        ) {
            if let Some(cached) = stale_cached {
                debug!(
                    block_timestamp = snapshot.block_timestamp,
                    current_epoch_start_timestamp = snapshot.current_epoch_start_timestamp,
                    "using stale signer authority snapshot because latest block is before epoch start"
                );
                return Ok(cached);
            }
            return Err(err);
        }

        let mut state = self.state.lock().await;
        if !state.cache.should_accept_block_timestamp(snapshot.block_timestamp) &&
            let Some(cached) =
                state.stale_cached_operators(now, Duration::from_secs(MAX_STALE_FALLBACK_SECS))
        {
            debug!(
                block_timestamp = snapshot.block_timestamp,
                "ignoring regressive signer authority snapshot from lagging RPC node"
            );
            return Ok(cached);
        }

        state.cache.set_pair(
            snapshot.current,
            snapshot.next,
            snapshot.current_epoch_start_timestamp,
            snapshot.block_timestamp,
            now,
        );

        Ok(CachedOperators {
            current: snapshot.current,
            next: snapshot.next,
            current_epoch_start_timestamp: snapshot.current_epoch_start_timestamp,
            any_from_cache: false,
        })
    }

    /// Fetch a fresh current/next operator snapshot pinned to one latest L1 block.
    async fn fetch_operator_snapshot(&self) -> Result<OperatorSnapshot> {
        let latest_block = self
            .l1_provider
            .get_block_by_number(BlockNumberOrTag::Latest)
            .await
            .map_err(|err| {
                whitelist_lookup_err(format!(
                    "failed to fetch latest block for signer authority snapshot: {err}"
                ))
            })?
            .ok_or_else(|| {
                whitelist_lookup_err(
                    "missing latest block while fetching signer authority snapshot".to_string(),
                )
            })?;

        let block_number = latest_block.header.number;
        let block_timestamp = latest_block.header.timestamp;
        let block_hash = latest_block.hash();

        let current_operator_fut = async {
            self.whitelist
                .getOperatorForCurrentEpoch()
                .block(BlockId::Number(block_number.into()))
                .call()
                .await
                .map_err(|err| {
                    whitelist_lookup_err(format!(
                        "failed to fetch current operator at block {block_number}: {err}"
                    ))
                })
        };
        let next_operator_fut = async {
            self.whitelist
                .getOperatorForNextEpoch()
                .block(BlockId::Number(block_number.into()))
                .call()
                .await
                .map_err(|err| {
                    whitelist_lookup_err(format!(
                        "failed to fetch next operator at block {block_number}: {err}"
                    ))
                })
        };
        let epoch_start_timestamp_fut = async {
            self.whitelist
                .epochStartTimestamp(Default::default())
                .block(BlockId::Number(block_number.into()))
                .call()
                .await
                .map_err(|err| {
                    whitelist_lookup_err(format!(
                        "failed to fetch epochStartTimestamp at block {block_number}: {err}"
                    ))
                })
        };

        let (current_proposer, next_proposer, current_epoch_start_timestamp) =
            tokio::try_join!(current_operator_fut, next_operator_fut, epoch_start_timestamp_fut)?;

        let current_sequencer_fut = async {
            self.whitelist
                .operators(current_proposer)
                .block(BlockId::Number(block_number.into()))
                .call()
                .await
                .map_err(|err| {
                    whitelist_lookup_err(format!(
                        "failed to fetch current operators() entry at block {block_number}: {err}"
                    ))
                })
        };
        let next_sequencer_fut = async {
            self.whitelist
                .operators(next_proposer)
                .block(BlockId::Number(block_number.into()))
                .call()
                .await
                .map_err(|err| {
                    whitelist_lookup_err(format!(
                        "failed to fetch next operators() entry at block {block_number}: {err}"
                    ))
                })
        };
        let pinned_block_fut = async {
            self.l1_provider
                .get_block_by_number(BlockNumberOrTag::Number(block_number))
                .await
                .map_err(|err| {
                    whitelist_lookup_err(format!(
                        "failed to re-fetch block {block_number} for hash verification: {err}"
                    ))
                })
        };

        let (current_sequencer, next_sequencer, pinned_block_opt) =
            tokio::try_join!(current_sequencer_fut, next_sequencer_fut, pinned_block_fut)?;

        let pinned_hash = pinned_block_opt
            .ok_or_else(|| {
                whitelist_lookup_err(format!(
                    "block {block_number} disappeared during signer authority snapshot"
                ))
            })?
            .hash();
        if pinned_hash != block_hash {
            return Err(whitelist_lookup_err(format!(
                "block hash changed at height {block_number} during signer authority snapshot \
                 (load-balanced RPC inconsistency or reorg)"
            )));
        }

        Ok(OperatorSnapshot {
            current: current_sequencer.sequencerAddress,
            next: next_sequencer.sequencerAddress,
            current_epoch_start_timestamp: u64::from(current_epoch_start_timestamp),
            block_timestamp,
        })
    }

    /// Validate the fee recipient against the cached operator snapshot and current slot.
    fn validate_fee_recipient(
        &self,
        fee_recipient: Address,
        current_slot: u64,
        cached: CachedOperators,
    ) -> std::result::Result<(), AuthorityCheckError> {
        if cached.current == Address::ZERO && cached.next == Address::ZERO {
            return Err(AuthorityCheckError::BothSlotsZero);
        }

        let current_epoch = self
            .beacon_timing
            .timestamp_to_epoch(cached.current_epoch_start_timestamp)
            .map_err(|err| AuthorityCheckError::SlotOutsideCachedEpoch {
                current_slot,
                epoch_start_slot: 0,
                epoch_end_slot: 0,
                reason: format!(
                    "failed to derive epoch from epoch start timestamp {}: {err}",
                    cached.current_epoch_start_timestamp
                ),
            })?;
        let slots_per_epoch = self.beacon_timing.slots_per_epoch();
        let epoch_start_slot = current_epoch.saturating_mul(slots_per_epoch);
        let epoch_end_slot = epoch_start_slot.saturating_add(slots_per_epoch);
        let handover_skip_slots = DEFAULT_HANDOVER_SKIP_SLOTS.min(slots_per_epoch);
        let handover_boundary = epoch_end_slot.saturating_sub(handover_skip_slots);

        let expected_role = if current_slot >= epoch_start_slot && current_slot < handover_boundary
        {
            ExpectedOperatorRole::Current
        } else if current_slot >= handover_boundary && current_slot < epoch_end_slot {
            ExpectedOperatorRole::Next
        } else {
            return Err(AuthorityCheckError::SlotOutsideCachedEpoch {
                current_slot,
                epoch_start_slot,
                epoch_end_slot,
                reason: format!(
                    "current slot {current_slot} is outside cached operator epoch [{epoch_start_slot}, {epoch_end_slot})"
                ),
            });
        };

        match expected_role {
            ExpectedOperatorRole::Current if fee_recipient == cached.current => Ok(()),
            ExpectedOperatorRole::Next if fee_recipient == cached.next => Ok(()),
            role => Err(AuthorityCheckError::FeeRecipientMismatch {
                fee_recipient,
                current: cached.current,
                next: cached.next,
                current_slot,
                role,
            }),
        }
    }

    /// Clear the cached operator snapshot.
    async fn invalidate_cache(&self) {
        self.state.lock().await.cache.invalidate();
    }
}

#[async_trait]
impl<P> SignerAuthority for WhitelistSignerAuthority<P>
where
    P: Provider + Clone + Send + Sync + 'static,
{
    /// Ensure the payload signer matches the current or next whitelist operator.
    async fn ensure_payload_signer_allowed(&self, signer: Address) -> Result<()> {
        self.ensure_payload_signer_allowed_inner(signer).await
    }

    /// Ensure the fee recipient matches the operator allowed for the current handover window.
    async fn ensure_fee_recipient_allowed(&self, fee_recipient: Address) -> Result<()> {
        self.ensure_fee_recipient_allowed_for_slot(fee_recipient, self.beacon_timing.current_slot())
            .await
    }
}

/// Cached authority state guarded by the shared mutex.
#[derive(Debug, Default)]
struct AuthorityState {
    /// Cached current/next operator pair and refresh cooldowns.
    cache: WhitelistSequencerCache,
}

impl AuthorityState {
    /// Return cached operators when the cached epoch is still valid.
    fn cached_operators(&self) -> Option<CachedOperators> {
        Some(CachedOperators {
            current: self.cache.get_current()?,
            next: self.cache.get_next()?,
            current_epoch_start_timestamp: self.cache.current_epoch_start_timestamp()?,
            any_from_cache: true,
        })
    }

    /// Return stale cached operators when both entries are still within the fallback window.
    fn stale_cached_operators(&self, now: Instant, max_stale: Duration) -> Option<CachedOperators> {
        let (current, next) = self.cache.get_stale_pair_within(now, max_stale)?;
        Some(CachedOperators {
            current,
            next,
            current_epoch_start_timestamp: self.cache.current_epoch_start_timestamp()?,
            any_from_cache: true,
        })
    }
}

/// Cached operator pair returned to validation paths.
#[derive(Clone, Copy, Debug)]
struct CachedOperators {
    /// Current epoch operator sequencer.
    current: Address,
    /// Next epoch operator sequencer.
    next: Address,
    /// Epoch start timestamp tied to the cached operator pair.
    current_epoch_start_timestamp: u64,
    /// Whether the pair came from cache rather than a fresh L1 fetch.
    any_from_cache: bool,
}

/// Fresh operator snapshot tied to a pinned latest L1 block.
#[derive(Clone, Copy, Debug)]
struct OperatorSnapshot {
    /// Current epoch operator sequencer.
    current: Address,
    /// Next epoch operator sequencer.
    next: Address,
    /// Epoch start timestamp for the pinned block.
    current_epoch_start_timestamp: u64,
    /// Timestamp of the pinned latest block.
    block_timestamp: u64,
}

/// Current handover role expected for a fee recipient.
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
enum ExpectedOperatorRole {
    /// The fee recipient must match the current operator.
    Current,
    /// The fee recipient must match the next operator.
    Next,
}

impl ExpectedOperatorRole {
    /// Return the short label used in mismatch error messages.
    const fn label(self) -> &'static str {
        match self {
            Self::Current => "current",
            Self::Next => "next",
        }
    }
}

/// Internal validation errors produced by authority checks.
#[derive(Debug, Error)]
enum AuthorityCheckError {
    /// Both operator slots are empty and cannot authorize any participant.
    #[error("both whitelist sequencer slots are zero")]
    BothSlotsZero,
    /// The payload signer matches neither current nor next operator.
    #[error("signer {signer} is not current ({current}) or next ({next}) whitelist sequencer")]
    SignerMismatch {
        /// Address recovered from the payload signature.
        signer: Address,
        /// Current epoch operator.
        current: Address,
        /// Next epoch operator.
        next: Address,
    },
    /// The fee recipient does not match the operator allowed for the active handover window.
    #[error(
        "fee recipient {fee_recipient} is not allowed as the {} operator for slot {current_slot} (current {current}, next {next})",
        .role.label()
    )]
    FeeRecipientMismatch {
        /// Fee recipient carried by the payload.
        fee_recipient: Address,
        /// Current epoch operator.
        current: Address,
        /// Next epoch operator.
        next: Address,
        /// Beacon slot being validated.
        current_slot: u64,
        /// Expected operator role for the slot.
        role: ExpectedOperatorRole,
    },
    /// The cached epoch metadata does not cover the slot being validated.
    #[error("{reason}")]
    SlotOutsideCachedEpoch {
        /// Beacon slot being validated.
        current_slot: u64,
        /// Inclusive start of the cached epoch window.
        epoch_start_slot: u64,
        /// Exclusive end of the cached epoch window.
        epoch_end_slot: u64,
        /// Detailed reason message.
        reason: String,
    },
}

impl AuthorityCheckError {
    /// Convert a signer validation error into the top-level driver error type.
    fn into_signer_error(self) -> WhitelistPreconfirmationDriverError {
        match self {
            Self::BothSlotsZero | Self::SlotOutsideCachedEpoch { .. } => {
                WhitelistPreconfirmationDriverError::WhitelistLookup(self.to_string())
            }
            Self::SignerMismatch { .. } => {
                WhitelistPreconfirmationDriverError::invalid_signature(self.to_string())
            }
            Self::FeeRecipientMismatch { .. } => unreachable!(
                "fee-recipient mismatches must not be converted through the signer path"
            ),
        }
    }

    /// Convert a fee-recipient validation error into the top-level driver error type.
    fn into_fee_recipient_error(self) -> WhitelistPreconfirmationDriverError {
        match self {
            Self::BothSlotsZero | Self::SlotOutsideCachedEpoch { .. } => {
                WhitelistPreconfirmationDriverError::WhitelistLookup(self.to_string())
            }
            Self::FeeRecipientMismatch { .. } => {
                WhitelistPreconfirmationDriverError::invalid_payload(self.to_string())
            }
            Self::SignerMismatch { .. } => unreachable!(
                "signer mismatches must not be converted through the fee-recipient path"
            ),
        }
    }

    /// Convert a lookup-shape failure into the top-level whitelist lookup error.
    fn into_whitelist_lookup_error(self) -> WhitelistPreconfirmationDriverError {
        WhitelistPreconfirmationDriverError::WhitelistLookup(self.to_string())
    }
}

/// Validate that a signer matches either the current or next operator.
fn validate_signer_pair(
    signer: Address,
    current: Address,
    next: Address,
) -> std::result::Result<(), AuthorityCheckError> {
    if signer == current || signer == next {
        return Ok(());
    }

    if current == Address::ZERO && next == Address::ZERO {
        return Err(AuthorityCheckError::BothSlotsZero);
    }

    Err(AuthorityCheckError::SignerMismatch { signer, current, next })
}

/// Beacon timing operations needed by the authority's fee-recipient handover logic.
trait BeaconTiming: Send + Sync {
    /// Return the current beacon slot.
    fn current_slot(&self) -> u64;

    /// Convert an L1 timestamp into the corresponding beacon epoch.
    fn timestamp_to_epoch(&self, timestamp: u64) -> std::result::Result<u64, String>;

    /// Return the chain's slots-per-epoch configuration.
    fn slots_per_epoch(&self) -> u64;
}

/// Production beacon timing adapter backed by `BeaconClient`.
struct BeaconClientTiming {
    /// Shared beacon client used for slot and epoch calculations.
    beacon_client: Arc<rpc::beacon::BeaconClient>,
}

impl BeaconClientTiming {
    /// Create a new production beacon timing adapter.
    fn new(beacon_client: Arc<rpc::beacon::BeaconClient>) -> Self {
        Self { beacon_client }
    }
}

impl BeaconTiming for BeaconClientTiming {
    /// Return the current beacon slot from the live beacon client.
    fn current_slot(&self) -> u64 {
        self.beacon_client.current_slot()
    }

    /// Convert the timestamp into a beacon epoch using the live beacon client.
    fn timestamp_to_epoch(&self, timestamp: u64) -> std::result::Result<u64, String> {
        self.beacon_client.timestamp_to_epoch(timestamp).map_err(|err| err.to_string())
    }

    /// Return the configured slots-per-epoch from the live beacon client.
    fn slots_per_epoch(&self) -> u64 {
        self.beacon_client.slots_per_epoch()
    }
}

/// Deterministic beacon timing used by unit tests.
#[cfg(test)]
struct TestBeaconTiming {
    /// Slot returned by `current_slot()`.
    current_slot: u64,
    /// Slots per epoch returned by `slots_per_epoch()`.
    slots_per_epoch: u64,
}

#[cfg(test)]
impl BeaconTiming for TestBeaconTiming {
    /// Return the configured test slot.
    fn current_slot(&self) -> u64 {
        self.current_slot
    }

    /// Convert timestamps to epochs assuming one-second slots and genesis at zero.
    fn timestamp_to_epoch(&self, timestamp: u64) -> std::result::Result<u64, String> {
        Ok(timestamp / self.slots_per_epoch)
    }

    /// Return the configured test slots-per-epoch.
    fn slots_per_epoch(&self) -> u64 {
        self.slots_per_epoch
    }
}

/// Map a whitelist lookup failure into a typed driver error and increment metric.
fn whitelist_lookup_err(message: String) -> WhitelistPreconfirmationDriverError {
    metrics::counter!(WhitelistPreconfirmationDriverMetrics::WHITELIST_LOOKUP_FAILURES_TOTAL)
        .increment(1);
    WhitelistPreconfirmationDriverError::WhitelistLookup(message)
}

/// Validate that the fetched block timestamp is not before the epoch start.
fn ensure_not_too_early_for_epoch(
    block_timestamp: u64,
    current_epoch_start_timestamp: u64,
) -> Result<()> {
    if block_timestamp < current_epoch_start_timestamp {
        return Err(whitelist_lookup_err(format!(
            "whitelist batch returned block timestamp {block_timestamp} before epoch start \
             {current_epoch_start_timestamp}"
        )));
    }

    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn epoch_timing_check_rejects_too_early_block() {
        let err = ensure_not_too_early_for_epoch(99, 100).expect_err("must reject too-early block");
        assert!(err.to_string().contains("before epoch start"));
    }

    #[test]
    fn epoch_timing_check_accepts_equal_or_later_block() {
        ensure_not_too_early_for_epoch(100, 100).expect("equal timestamp must pass");
        ensure_not_too_early_for_epoch(101, 100).expect("later timestamp must pass");
    }

    #[test]
    fn validate_signer_pair_reports_explicit_mismatch() {
        let err = validate_signer_pair(
            Address::from([0x11u8; 20]),
            Address::from([0x22u8; 20]),
            Address::from([0x33u8; 20]),
        )
        .expect_err("mismatched signer should fail");
        assert!(matches!(
            err,
            AuthorityCheckError::SignerMismatch { signer, current, next }
                if signer == Address::from([0x11u8; 20])
                    && current == Address::from([0x22u8; 20])
                    && next == Address::from([0x33u8; 20])
        ));
    }
}
