use std::time::{SystemTime, UNIX_EPOCH};

use super::super::{LookaheadError, Result};

/// Duration of a single preconfirmation slot in seconds.
pub const SECONDS_IN_SLOT: u64 = 12;
/// Duration of one epoch in seconds (32 slots).
pub const SECONDS_IN_EPOCH: u64 = SECONDS_IN_SLOT * 32;
/// Maximum backward block scans when searching for a block within an epoch. One epoch is ~32 EL
/// blocks on a 12s cadence; 256 (~8 epochs of headroom) provides ample slack while keeping lookup
/// bounded.
pub const MAX_BACKWARD_STEPS: u16 = 256;
/// Maximum number of epochs allowed for lookback when resolving a committer.
pub(crate) const MAX_LOOKBACK_EPOCHS: u64 = 1;

/// Return the epoch start boundary (in seconds) that contains `ts`.
///
/// Assumes the provided `genesis_timestamp` is already aligned to the slot/epoch boundary; we do
/// not snap misaligned timestamps up to the next 12-second multiple. Calculation simply floors to
/// the nearest epoch based on the given genesis.
pub(crate) fn epoch_start_for(ts: u64, genesis_timestamp: u64) -> u64 {
    let elapsed = ts.saturating_sub(genesis_timestamp);
    let epochs = elapsed / SECONDS_IN_EPOCH;
    genesis_timestamp + epochs * SECONDS_IN_EPOCH
}

/// Return the earliest timestamp allowed for lookups based on the configured lookback window,
/// aligned to the epoch boundary that contains "now". Acts as the lower bound for resolver queries.
pub(crate) fn earliest_allowed_timestamp(genesis_timestamp: u64) -> Result<u64> {
    Ok(earliest_allowed_timestamp_at(current_unix_timestamp()?, genesis_timestamp))
}

/// Pure helper to compute the earliest allowed timestamp for a supplied "now" value. Useful for
/// tests. Pairs with `latest_allowed_timestamp_at` to bound valid query timestamps.
pub(crate) fn earliest_allowed_timestamp_at(now: u64, genesis_timestamp: u64) -> u64 {
    epoch_start_for(now, genesis_timestamp)
        .saturating_sub(MAX_LOOKBACK_EPOCHS.saturating_mul(SECONDS_IN_EPOCH))
}

/// Pure helper to compute the latest allowed timestamp (exclusive) for a supplied "now" value.
/// Pairs with `earliest_allowed_timestamp_at` to define the valid window.
pub(crate) fn latest_allowed_timestamp_at(now: u64, genesis_timestamp: u64) -> u64 {
    let current_epoch_start = epoch_start_for(now, genesis_timestamp);
    current_epoch_start.saturating_add(SECONDS_IN_EPOCH)
}

/// Current UNIX timestamp in seconds.
pub(crate) fn current_unix_timestamp() -> Result<u64> {
    Ok(SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map_err(|err| LookaheadError::SystemTime(err.to_string()))?
        .as_secs())
}

#[cfg(test)]
mod tests {
    use super::{
        SECONDS_IN_EPOCH, SECONDS_IN_SLOT, current_unix_timestamp, earliest_allowed_timestamp_at,
        epoch_start_for, genesis_timestamp_for_chain,
    };

    #[test]
    fn epoch_start_floors_relative_to_genesis() {
        let genesis = 1_000;
        assert_eq!(epoch_start_for(genesis, genesis), genesis);
        assert_eq!(epoch_start_for(genesis + 5, genesis), genesis);
        assert_eq!(epoch_start_for(genesis + SECONDS_IN_SLOT, genesis), genesis);
        assert_eq!(epoch_start_for(genesis + SECONDS_IN_EPOCH - 1, genesis), genesis);
        assert_eq!(
            epoch_start_for(genesis + SECONDS_IN_EPOCH + 1, genesis),
            genesis + SECONDS_IN_EPOCH
        );
    }

    #[test]
    fn genesis_timestamp_known_and_unknown() {
        assert_eq!(genesis_timestamp_for_chain(1), Some(1_606_824_023));
        assert_eq!(genesis_timestamp_for_chain(17_000), Some(1_695_902_400));
        assert_eq!(genesis_timestamp_for_chain(99999), None);
    }

    #[test]
    fn earliest_allowed_aligned_to_epoch_boundary() {
        let genesis = 1_000;
        let now = genesis + SECONDS_IN_EPOCH + 10;
        let expected = epoch_start_for(now, genesis) - SECONDS_IN_EPOCH;
        assert_eq!(earliest_allowed_timestamp_at(now, genesis), expected);
    }

    #[test]
    fn current_time_monotonic_non_zero() {
        let now = current_unix_timestamp().unwrap();
        assert!(now > 0);
    }
}

/// Return the beacon genesis timestamp for known chains.
///
/// Mappings are derived from `LibPreconfConstants` and `LibNetwork`:
/// - 1: Ethereum mainnet (1_606_824_023)
/// - 17_000: Holesky (1_695_902_400)
/// - 560_048: Hoodi (1_742_213_400)
///
/// Any other chain ID yields `None` and surfaces as `UnknownChain` to callers.
pub(crate) fn genesis_timestamp_for_chain(chain_id: u64) -> Option<u64> {
    match chain_id {
        1 => Some(1_606_824_023),
        17_000 => Some(1_695_902_400),
        560_048 => Some(1_742_213_400),
        _ => None,
    }
}
