use std::{
    sync::OnceLock,
    time::{Duration, Instant},
};

use alloy_primitives::{Address, Bytes, hex};
use alloy_provider::Provider;
use alloy_rpc_client::BatchRequest;
use alloy_sol_types::SolCall;
use bindings::preconf_whitelist::PreconfWhitelist::{
    epochStartTimestampCall, getOperatorForCurrentEpochCall, getOperatorForNextEpochCall,
    operatorsCall, operatorsReturn,
};
use serde_json::json;
use tracing::debug;

use crate::error::{Result, WhitelistPreconfirmationDriverError};

use super::WhitelistPreconfirmationImporter;

/// Maximum age for stale-cache fallback when node timing data lags epoch start.
const MAX_STALE_FALLBACK_SECS: u64 = 12 * 64;
/// Retry once when batch pinning detects a transient reorg/load-balancer inconsistency.
const SNAPSHOT_FETCH_MAX_ATTEMPTS: usize = 2;

/// ABI-encoded call data for `getOperatorForCurrentEpoch()` (selector + empty params).
fn current_operator_call_data() -> &'static Bytes {
    static DATA: OnceLock<Bytes> = OnceLock::new();
    DATA.get_or_init(|| Bytes::from(getOperatorForCurrentEpochCall.abi_encode()))
}

/// ABI-encoded call data for `getOperatorForNextEpoch()` (selector + empty params).
fn next_operator_call_data() -> &'static Bytes {
    static DATA: OnceLock<Bytes> = OnceLock::new();
    DATA.get_or_init(|| Bytes::from(getOperatorForNextEpochCall.abi_encode()))
}

/// ABI-encoded call data for `epochStartTimestamp(0)` (selector + zero offset).
fn epoch_start_timestamp_call_data() -> &'static Bytes {
    static DATA: OnceLock<Bytes> = OnceLock::new();
    DATA.get_or_init(|| {
        Bytes::from(epochStartTimestampCall { _offset: Default::default() }.abi_encode())
    })
}

/// Result of a cached sequencer lookup, including whether values came from cache.
struct CachedSequencers {
    current: Address,
    next: Address,
    /// True when at least one value was served from cache rather than freshly fetched.
    any_from_cache: bool,
}

/// Snapshot of sequencer addresses used for signer validation.
struct WhitelistSequencerSnapshot {
    current: Address,
    next: Address,
    current_epoch_start_timestamp: u64,
    block_timestamp: u64,
}

impl<P> WhitelistPreconfirmationImporter<P>
where
    P: Provider + Clone + Send + Sync + 'static,
{
    /// Ensure the signer is allowed in the whitelist.
    ///
    /// First checks cache. On a cache miss (signer not in cached set), only re-fetches
    /// from L1 if cached values were returned. When values were freshly fetched, rejects
    /// immediately to prevent spam from bypassing cache.
    pub(super) async fn ensure_signer_allowed(&mut self, signer: Address) -> Result<()> {
        let now = Instant::now();
        let result = self.cached_whitelist_sequencers(now).await?;

        if signer == result.current || signer == result.next {
            return Ok(());
        }

        // If values were freshly fetched already, reject immediately.
        if !result.any_from_cache {
            return Err(WhitelistPreconfirmationDriverError::InvalidSignature(format!(
                "signer {signer} is not current ({}) or next ({}) whitelist sequencer",
                result.current, result.next
            )));
        }

        if !self.sequencer_cache.allow_miss_refresh(now) {
            debug!(
                %signer,
                cached_current = %result.current,
                cached_next = %result.next,
                "signer mismatch refresh cooldown active; rejecting without L1 re-fetch"
            );
            return Err(WhitelistPreconfirmationDriverError::InvalidSignature(format!(
                "signer {signer} is not current ({}) or next ({}) whitelist sequencer",
                result.current, result.next
            )));
        }

        debug!(
            %signer,
            cached_current = %result.current,
            cached_next = %result.next,
            "signer not in cached whitelist; re-fetching from L1"
        );
        self.sequencer_cache.invalidate();
        let fresh = self.cached_whitelist_sequencers(now).await?;

        if signer == fresh.current || signer == fresh.next {
            return Ok(());
        }

        Err(WhitelistPreconfirmationDriverError::InvalidSignature(format!(
            "signer {signer} is not current ({}) or next ({}) whitelist sequencer",
            fresh.current, fresh.next
        )))
    }

    /// Return (current, next) sequencer addresses, using cache when fresh.
    async fn cached_whitelist_sequencers(&mut self, now: Instant) -> Result<CachedSequencers> {
        // Access here is serialized by `&mut self` on the importer's event loop,
        // so a single importer instance cannot stampede concurrent L1 lookups.
        if let (Some(current), Some(next)) =
            (self.sequencer_cache.get_current(now), self.sequencer_cache.get_next(now))
        {
            return Ok(CachedSequencers { current, next, any_from_cache: true });
        }

        let snapshot = self.fetch_whitelist_sequencers_snapshot_with_retry().await?;

        // If the node is behind and reports a block before the current epoch start, keep serving
        // stale cache values when available instead of failing open/closed on inconsistent timing.
        if let Err(err) = ensure_not_too_early_for_epoch(
            snapshot.block_timestamp,
            snapshot.current_epoch_start_timestamp,
        ) {
            if let Some((current, next)) = self
                .sequencer_cache
                .get_stale_pair_within(now, Duration::from_secs(MAX_STALE_FALLBACK_SECS))
            {
                debug!(
                    block_timestamp = snapshot.block_timestamp,
                    current_epoch_start_timestamp = snapshot.current_epoch_start_timestamp,
                    "using stale whitelist snapshot because latest block is before epoch start"
                );
                return Ok(CachedSequencers { current, next, any_from_cache: true });
            }
            return Err(err);
        }

        // If a lagging node answers after we already cached a newer epoch snapshot,
        // keep the previous snapshot instead of regressing.
        if !self.sequencer_cache.should_accept_block_timestamp(snapshot.block_timestamp) &&
            let Some((current, next)) = self
                .sequencer_cache
                .get_stale_pair_within(now, Duration::from_secs(MAX_STALE_FALLBACK_SECS))
        {
            debug!(
                block_timestamp = snapshot.block_timestamp,
                "ignoring regressive whitelist snapshot from lagging RPC node"
            );
            return Ok(CachedSequencers { current, next, any_from_cache: true });
        }

        self.sequencer_cache.set_pair(
            snapshot.current,
            snapshot.next,
            snapshot.current_epoch_start_timestamp,
            now,
        );

        Ok(CachedSequencers {
            current: snapshot.current,
            next: snapshot.next,
            any_from_cache: false,
        })
    }

    /// Fetch current/next sequencer addresses in two batches pinned to the same block.
    ///
    /// **Batch 1** retrieves the latest block header, both operator proposer addresses,
    /// and the current epoch start timestamp. **Batch 2** fetches both sequencer addresses via
    /// `operators()`
    /// lookups at the block number from batch 1, ensuring all six calls share one
    /// consistent view of state.
    async fn fetch_whitelist_sequencers_snapshot_with_retry(
        &self,
    ) -> Result<WhitelistSequencerSnapshot> {
        for attempt in 1..=SNAPSHOT_FETCH_MAX_ATTEMPTS {
            match self.fetch_whitelist_sequencers_snapshot().await {
                Ok(snapshot) => return Ok(snapshot),
                Err(err)
                    if attempt < SNAPSHOT_FETCH_MAX_ATTEMPTS &&
                        should_retry_snapshot_fetch(&err) =>
                {
                    debug!(
                        attempt,
                        max_attempts = SNAPSHOT_FETCH_MAX_ATTEMPTS,
                        error = %err,
                        "retrying whitelist snapshot fetch after transient inconsistency"
                    );
                }
                Err(err) => return Err(err),
            }
        }

        unreachable!("snapshot fetch loop must return on success or final error")
    }

    async fn fetch_whitelist_sequencers_snapshot(&self) -> Result<WhitelistSequencerSnapshot> {
        // ── Batch 1: latest block + operator proposers + epoch timing ───────
        let whitelist_addr = self.whitelist.address();

        let current_op_params = json!([
            { "to": whitelist_addr, "data": current_operator_call_data().to_string() },
            "latest",
        ]);
        let next_op_params = json!([
            { "to": whitelist_addr, "data": next_operator_call_data().to_string() },
            "latest",
        ]);
        let epoch_ts_params = json!([
            { "to": whitelist_addr, "data": epoch_start_timestamp_call_data().to_string() },
            "latest",
        ]);

        let mut batch1 = BatchRequest::new(self.rpc.l1_provider.client());
        let latest_block_waiter = batch1
            .add_call::<_, serde_json::Value>("eth_getBlockByNumber", &("latest", false))
            .map_err(|err| {
                WhitelistPreconfirmationDriverError::WhitelistLookup(format!(
                    "failed to add latest block call to batch: {err}"
                ))
            })?;
        let current_op_waiter =
            batch1.add_call::<_, String>("eth_call", &current_op_params).map_err(|err| {
                WhitelistPreconfirmationDriverError::WhitelistLookup(format!(
                    "failed to add current operator call to batch: {err}"
                ))
            })?;
        let next_op_waiter =
            batch1.add_call::<_, String>("eth_call", &next_op_params).map_err(|err| {
                WhitelistPreconfirmationDriverError::WhitelistLookup(format!(
                    "failed to add next operator call to batch: {err}"
                ))
            })?;
        let epoch_ts_waiter =
            batch1.add_call::<_, String>("eth_call", &epoch_ts_params).map_err(|err| {
                WhitelistPreconfirmationDriverError::WhitelistLookup(format!(
                    "failed to add epochStartTimestamp call to batch: {err}"
                ))
            })?;

        batch1.send().await.map_err(|err| {
            WhitelistPreconfirmationDriverError::WhitelistLookup(format!(
                "failed to send whitelist batch 1 request: {err}"
            ))
        })?;

        let latest_block: serde_json::Value = latest_block_waiter.await.map_err(|err| {
            WhitelistPreconfirmationDriverError::WhitelistLookup(format!(
                "failed to read latest block from whitelist batch: {err}"
            ))
        })?;
        let current_op_hex: String = current_op_waiter.await.map_err(|err| {
            WhitelistPreconfirmationDriverError::WhitelistLookup(format!(
                "failed to read current operator from whitelist batch: {err}"
            ))
        })?;
        let next_op_hex: String = next_op_waiter.await.map_err(|err| {
            WhitelistPreconfirmationDriverError::WhitelistLookup(format!(
                "failed to read next operator from whitelist batch: {err}"
            ))
        })?;
        let epoch_ts_hex: String = epoch_ts_waiter.await.map_err(|err| {
            WhitelistPreconfirmationDriverError::WhitelistLookup(format!(
                "failed to read epochStartTimestamp from whitelist batch: {err}"
            ))
        })?;

        let block_number = parse_hex_field_u64(&latest_block, "number")?;
        let block_hash = parse_hex_field_string(&latest_block, "hash", "latest block result")?;
        let block_timestamp = parse_hex_field_u64(&latest_block, "timestamp")?;

        let current_proposer = decode_sol_returns::<getOperatorForCurrentEpochCall>(
            &current_op_hex,
            "current whitelist proposer",
        )?;
        let next_proposer = decode_sol_returns::<getOperatorForNextEpochCall>(
            &next_op_hex,
            "next whitelist proposer",
        )?;
        let current_epoch_start_timestamp =
            u64::from(decode_sol_returns::<epochStartTimestampCall>(
                &epoch_ts_hex,
                "current epoch start timestamp",
            )?);

        // ── Batch 2: operators() lookups pinned to batch 1's block ──────────
        let block_hex = format!("0x{block_number:x}");
        let current_operators_data =
            Bytes::from(operatorsCall { proposer: current_proposer }.abi_encode());
        let next_operators_data =
            Bytes::from(operatorsCall { proposer: next_proposer }.abi_encode());

        let current_seq_params = json!([
            { "to": whitelist_addr, "data": current_operators_data.to_string() },
            block_hex,
        ]);
        let next_seq_params = json!([
            { "to": whitelist_addr, "data": next_operators_data.to_string() },
            block_hex,
        ]);

        let mut batch2 = BatchRequest::new(self.rpc.l1_provider.client());
        let current_seq_waiter =
            batch2.add_call::<_, String>("eth_call", &current_seq_params).map_err(|err| {
                WhitelistPreconfirmationDriverError::WhitelistLookup(format!(
                    "failed to add current operators() call to batch: {err}"
                ))
            })?;
        let next_seq_waiter =
            batch2.add_call::<_, String>("eth_call", &next_seq_params).map_err(|err| {
                WhitelistPreconfirmationDriverError::WhitelistLookup(format!(
                    "failed to add next operators() call to batch: {err}"
                ))
            })?;
        let pinned_block_waiter = batch2
            .add_call::<_, serde_json::Value>("eth_getBlockByNumber", &(block_hex.as_str(), false))
            .map_err(|err| {
                WhitelistPreconfirmationDriverError::WhitelistLookup(format!(
                    "failed to add pinned-block verification call to batch: {err}"
                ))
            })?;

        batch2.send().await.map_err(|err| {
            WhitelistPreconfirmationDriverError::WhitelistLookup(format!(
                "failed to send whitelist batch 2 request: {err}"
            ))
        })?;

        let current_seq_hex: String = current_seq_waiter.await.map_err(|err| {
            WhitelistPreconfirmationDriverError::WhitelistLookup(format!(
                "failed to read current sequencer from whitelist batch: {err}"
            ))
        })?;
        let next_seq_hex: String = next_seq_waiter.await.map_err(|err| {
            WhitelistPreconfirmationDriverError::WhitelistLookup(format!(
                "failed to read next sequencer from whitelist batch: {err}"
            ))
        })?;
        let pinned_block: serde_json::Value = pinned_block_waiter.await.map_err(|err| {
            WhitelistPreconfirmationDriverError::WhitelistLookup(format!(
                "failed to read pinned-block verification result from whitelist batch: {err}"
            ))
        })?;
        if pinned_block.is_null() {
            return Err(WhitelistPreconfirmationDriverError::WhitelistLookup(format!(
                "missing pinned block {block_number} while verifying whitelist batches"
            )));
        }
        let pinned_block_hash =
            parse_hex_field_string(&pinned_block, "hash", "pinned block result")?;
        if pinned_block_hash != block_hash {
            return Err(WhitelistPreconfirmationDriverError::WhitelistLookup(format!(
                "block hash changed between whitelist batches at block {block_number}"
            )));
        }

        let current_seq: operatorsReturn =
            decode_sol_returns::<operatorsCall>(&current_seq_hex, "current whitelist sequencer")?;
        let next_seq: operatorsReturn =
            decode_sol_returns::<operatorsCall>(&next_seq_hex, "next whitelist sequencer")?;
        if current_seq.sequencerAddress == Address::ZERO ||
            next_seq.sequencerAddress == Address::ZERO
        {
            return Err(WhitelistPreconfirmationDriverError::WhitelistLookup(
                "received zero address for whitelist sequencer".to_string(),
            ));
        }

        Ok(WhitelistSequencerSnapshot {
            current: current_seq.sequencerAddress,
            next: next_seq.sequencerAddress,
            current_epoch_start_timestamp,
            block_timestamp,
        })
    }
}

/// Decode an `eth_call` hex response using alloy's type-safe `SolCall::abi_decode_returns`.
fn decode_sol_returns<C: SolCall>(raw: &str, field_name: &str) -> Result<C::Return> {
    let bytes = hex::decode(raw.strip_prefix("0x").unwrap_or(raw)).map_err(|err| {
        WhitelistPreconfirmationDriverError::WhitelistLookup(format!(
            "failed to decode `{field_name}` hex response (length {}): {err}",
            raw.len()
        ))
    })?;
    C::abi_decode_returns(&bytes).map_err(|err| {
        WhitelistPreconfirmationDriverError::WhitelistLookup(format!(
            "failed to ABI-decode `{field_name}` returns: {err}"
        ))
    })
}

fn parse_hex_field_string(value: &serde_json::Value, key: &str, context: &str) -> Result<String> {
    let raw = value.get(key).and_then(|v| v.as_str()).ok_or_else(|| {
        WhitelistPreconfirmationDriverError::WhitelistLookup(format!(
            "missing hex field `{key}` in {context}"
        ))
    })?;
    if raw.strip_prefix("0x").unwrap_or(raw).is_empty() {
        return Err(WhitelistPreconfirmationDriverError::WhitelistLookup(format!(
            "empty hex field `{key}` in {context}"
        )));
    }
    Ok(raw.to_string())
}

fn parse_hex_field_u64(value: &serde_json::Value, key: &str) -> Result<u64> {
    let raw = value.get(key).and_then(|v| v.as_str()).ok_or_else(|| {
        WhitelistPreconfirmationDriverError::WhitelistLookup(format!(
            "missing hex field `{key}` in latest block result"
        ))
    })?;
    parse_hex_u64(raw, key)
}

fn parse_hex_u64(raw: &str, field_name: &str) -> Result<u64> {
    let value = raw.strip_prefix("0x").unwrap_or(raw);
    if value.is_empty() {
        return Err(WhitelistPreconfirmationDriverError::WhitelistLookup(format!(
            "empty `{field_name}` hex value"
        )));
    }
    u64::from_str_radix(value, 16).map_err(|err| {
        WhitelistPreconfirmationDriverError::WhitelistLookup(format!(
            "failed to parse `{field_name}` hex value `{raw}`: {err}"
        ))
    })
}

fn ensure_not_too_early_for_epoch(
    block_timestamp: u64,
    current_epoch_start_timestamp: u64,
) -> Result<()> {
    if block_timestamp < current_epoch_start_timestamp {
        return Err(WhitelistPreconfirmationDriverError::WhitelistLookup(format!(
            "whitelist batch returned block timestamp {block_timestamp} before epoch start {current_epoch_start_timestamp}"
        )));
    }

    Ok(())
}

fn should_retry_snapshot_fetch(err: &WhitelistPreconfirmationDriverError) -> bool {
    match err {
        WhitelistPreconfirmationDriverError::WhitelistLookup(message) => {
            message.contains("block hash changed between whitelist batches") ||
                message.contains("missing pinned block")
        }
        _ => false,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parse_hex_field_u64_reads_block_number() {
        let value = serde_json::json!({ "number": "0x2a" });
        let parsed = parse_hex_field_u64(&value, "number").expect("parse block number");
        assert_eq!(parsed, 42);
    }

    #[test]
    fn parse_hex_field_u64_errors_on_missing_key() {
        let value = serde_json::json!({ "number": "0x2a" });
        let err = parse_hex_field_u64(&value, "timestamp").expect_err("missing key should fail");
        assert!(err.to_string().contains("missing hex field `timestamp`"));
    }

    #[test]
    fn parse_hex_field_string_reads_hash() {
        let value = serde_json::json!({ "hash": "0xabc123" });
        let parsed =
            parse_hex_field_string(&value, "hash", "latest block result").expect("parse hash");
        assert_eq!(parsed, "0xabc123");
    }

    #[test]
    fn parse_hex_field_string_rejects_empty_hex() {
        let value = serde_json::json!({ "hash": "0x" });
        let err = parse_hex_field_string(&value, "hash", "latest block result")
            .expect_err("empty hash should fail");
        assert!(err.to_string().contains("empty hex field `hash`"));
    }

    #[test]
    fn parse_hex_u64_rejects_empty_hex() {
        let err = parse_hex_u64("0x", "timestamp").expect_err("empty hex should fail");
        assert!(err.to_string().contains("empty `timestamp` hex value"));
    }

    #[test]
    fn decode_sol_returns_decodes_address() {
        let raw = "0x0000000000000000000000001111111111111111111111111111111111111111";
        let parsed =
            decode_sol_returns::<getOperatorForCurrentEpochCall>(raw, "current whitelist proposer")
                .expect("decode address");
        assert_eq!(parsed, Address::from([0x11u8; 20]));
    }

    #[test]
    fn decode_sol_returns_decodes_u32() {
        let raw = "0x0000000000000000000000000000000000000000000000000000000000000041";
        let parsed =
            decode_sol_returns::<epochStartTimestampCall>(raw, "current epoch start timestamp")
                .expect("decode u32");
        assert_eq!(parsed, 65);
    }

    #[test]
    fn decode_sol_returns_rejects_invalid_hex() {
        let err = decode_sol_returns::<epochStartTimestampCall>("0xZZZZ", "bad field")
            .expect_err("invalid hex should fail");
        assert!(err.to_string().contains("failed to decode"));
    }

    #[test]
    fn decode_sol_returns_error_redacts_raw_hex() {
        let err = decode_sol_returns::<epochStartTimestampCall>("0xZZZZ", "bad field")
            .expect_err("invalid hex should fail");
        let message = err.to_string();
        assert!(message.contains("length"));
        assert!(!message.contains("0xZZZZ"));
    }

    #[test]
    fn decode_sol_returns_rejects_short_abi_data() {
        let err = decode_sol_returns::<epochStartTimestampCall>("0x1234", "short field")
            .expect_err("short ABI data should fail");
        assert!(err.to_string().contains("failed to ABI-decode"));
    }

    #[test]
    fn decode_sol_returns_decodes_operators_return() {
        // Encode: activeSince=100, deprecatedInactiveSince=0, index=1, sequencerAddress
        let addr = Address::from([0xAAu8; 20]);
        let mut abi = Vec::with_capacity(128);
        // activeSince: uint32 padded to 32 bytes
        abi.extend_from_slice(&[0u8; 28]);
        abi.extend_from_slice(&100u32.to_be_bytes());
        // deprecatedInactiveSince: uint32 padded to 32 bytes
        abi.extend_from_slice(&[0u8; 32]);
        // index: uint8 padded to 32 bytes
        abi.extend_from_slice(&[0u8; 31]);
        abi.push(1);
        // sequencerAddress: address padded to 32 bytes
        abi.extend_from_slice(&[0u8; 12]);
        abi.extend_from_slice(addr.as_slice());

        let raw = format!("0x{}", hex::encode(&abi));
        let result: operatorsReturn =
            decode_sol_returns::<operatorsCall>(&raw, "test operators").expect("decode operators");
        assert_eq!(result.activeSince, 100);
        assert_eq!(result.deprecatedInactiveSince, 0);
        assert_eq!(result.index, 1);
        assert_eq!(result.sequencerAddress, addr);
    }

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
    fn static_call_data_is_consistent_across_invocations() {
        let first = current_operator_call_data().clone();
        let second = current_operator_call_data().clone();
        assert_eq!(first, second);
        // Should start with the 4-byte selector for getOperatorForCurrentEpoch()
        assert_eq!(&first[..4], &[52u8, 63u8, 10u8, 104u8]);
    }

    #[test]
    fn static_call_data_has_correct_selectors() {
        assert_eq!(&current_operator_call_data()[..4], &getOperatorForCurrentEpochCall::SELECTOR);
        assert_eq!(&next_operator_call_data()[..4], &getOperatorForNextEpochCall::SELECTOR);
        assert_eq!(&epoch_start_timestamp_call_data()[..4], &epochStartTimestampCall::SELECTOR);
    }

    #[test]
    fn should_retry_snapshot_fetch_for_reorg_like_hash_change() {
        let err = WhitelistPreconfirmationDriverError::WhitelistLookup(
            "block hash changed between whitelist batches at block 123".to_string(),
        );
        assert!(should_retry_snapshot_fetch(&err));
    }

    #[test]
    fn should_retry_snapshot_fetch_for_missing_pinned_block() {
        let err = WhitelistPreconfirmationDriverError::WhitelistLookup(
            "missing pinned block 123 while verifying whitelist batches".to_string(),
        );
        assert!(should_retry_snapshot_fetch(&err));
    }

    #[test]
    fn should_retry_snapshot_fetch_ignores_non_retryable_lookup_errors() {
        let err = WhitelistPreconfirmationDriverError::WhitelistLookup(
            "failed to decode `current whitelist proposer` hex response".to_string(),
        );
        assert!(!should_retry_snapshot_fetch(&err));
    }
}
