//! Lock-free, periodically refreshed set of whitelisted sequencer addresses.
//!
//! [`OperatorSetPoller`] reads the full operator roster from the on-chain
//! `PreconfWhitelist` contract, builds a [`HashSet<Address>`], and publishes
//! it through an [`ArcSwap`] so that hot-path readers never block.

use std::{collections::HashSet, sync::Arc, time::Duration};

use alloy_primitives::{Address, U256};
use alloy_provider::Provider;
use arc_swap::ArcSwap;
use bindings::preconf_whitelist::PreconfWhitelist::PreconfWhitelistInstance;
use futures::future::try_join_all;
use tokio::time::sleep;
use tracing::{info, warn};

use crate::{
    cache::L1_EPOCH_DURATION_SECS,
    error::{Result, WhitelistPreconfirmationDriverError},
    metrics::WhitelistPreconfirmationDriverMetrics,
};

/// Shared, atomically swappable set of whitelisted sequencer addresses.
///
/// Readers clone the outer [`Arc`] and load the inner snapshot via
/// [`ArcSwap::load`] without locking.
pub(crate) type SharedOperatorSet = Arc<ArcSwap<HashSet<Address>>>;

/// Periodically polls the `PreconfWhitelist` contract and publishes an
/// up-to-date snapshot of all registered sequencer addresses.
pub(crate) struct OperatorSetPoller<P> {
    /// Contract binding used for on-chain reads.
    whitelist: PreconfWhitelistInstance<P>,
    /// Shared handle that readers use to access the latest operator set.
    operator_set: SharedOperatorSet,
}

impl<P> OperatorSetPoller<P>
where
    P: Provider + Clone + Send + Sync + 'static,
{
    /// Bootstrap the poller by reading the full operator roster from L1.
    ///
    /// The initial set is published into `operator_set` before this
    /// constructor returns so that callers can start validating immediately.
    pub(crate) async fn new(whitelist_address: Address, l1_provider: P) -> Result<Self> {
        let whitelist = PreconfWhitelistInstance::new(whitelist_address, l1_provider);
        let initial = Self::fetch_all_operators_from(&whitelist).await?;

        info!(count = initial.len(), operators = ?initial, "bootstrapped operator set from L1");

        let operator_set = Arc::new(ArcSwap::from_pointee(initial));
        Ok(Self { whitelist, operator_set })
    }

    /// Return a cheaply cloneable handle to the shared operator set.
    ///
    /// The returned [`SharedOperatorSet`] can be sent across threads and
    /// loaded lock-free on the hot path.
    pub(crate) fn shared_set(&self) -> SharedOperatorSet {
        Arc::clone(&self.operator_set)
    }

    /// Run an infinite loop that refreshes the operator set once per L1 epoch.
    ///
    /// The refresh interval is **not** aligned to real L1 epoch boundaries.
    /// Operator changes are admin-only (`addOperator`/`removeOperator`) and
    /// not tied to epoch transitions, so precise alignment provides no
    /// benefit while requiring a `BeaconClient` dependency to compute the
    /// offset to the next epoch start. A simple fixed-interval sleep keeps
    /// the poller self-contained and guarantees detection within one epoch.
    ///
    /// On refresh failure the previous set remains visible to readers and a
    /// warning metric is emitted. This method consumes `self` because it is
    /// intended to be spawned as a long-lived background task.
    pub(crate) async fn run_refresh_loop(self) {
        let interval = Duration::from_secs(L1_EPOCH_DURATION_SECS);

        loop {
            sleep(interval).await;
            info!("refreshing operator set from L1");

            match Self::fetch_all_operators_from(&self.whitelist).await {
                Ok(set) => {
                    info!(count = set.len(), operators = ?set, "refreshed operator set from L1");
                    self.operator_set.store(Arc::new(set));
                }
                Err(err) => {
                    warn!(%err, "failed to refresh operator set from L1");
                    metrics::counter!(
                        WhitelistPreconfirmationDriverMetrics::WHITELIST_LOOKUP_FAILURES_TOTAL
                    )
                    .increment(1);
                }
            }
        }
    }

    /// Read every registered operator from the whitelist contract and collect
    /// their sequencer addresses into a [`HashSet`].
    ///
    /// Fetches `operatorCount()` first, then resolves all `operatorMapping`
    /// indices in parallel, followed by all `operators(proposer)` lookups in
    /// parallel. This reduces the total number of sequential RPC round trips
    /// from 2N+1 to 3 regardless of operator count.
    /// Zero-address sequencers are silently excluded.
    async fn fetch_all_operators_from(
        whitelist: &PreconfWhitelistInstance<P>,
    ) -> Result<HashSet<Address>> {
        let count: u8 = whitelist.operatorCount().call().await.map_err(|err| {
            metrics::counter!(
                WhitelistPreconfirmationDriverMetrics::WHITELIST_LOOKUP_FAILURES_TOTAL
            )
            .increment(1);
            WhitelistPreconfirmationDriverError::WhitelistLookup(format!(
                "failed to fetch operatorCount: {err}"
            ))
        })?;

        // Fetch all proposer addresses in parallel.
        let proposer_futs = (0..count).map(|i| async move {
            whitelist.operatorMapping(U256::from(i)).call().await.map_err(|err| {
                metrics::counter!(
                    WhitelistPreconfirmationDriverMetrics::WHITELIST_LOOKUP_FAILURES_TOTAL
                )
                .increment(1);
                WhitelistPreconfirmationDriverError::WhitelistLookup(format!(
                    "failed to fetch operatorMapping({i}): {err}"
                ))
            })
        });
        let proposers: Vec<Address> = try_join_all(proposer_futs).await?;

        // Fetch all sequencer addresses in parallel.
        let sequencer_futs = proposers.iter().map(|proposer| {
            let proposer = *proposer;
            async move {
                whitelist
                    .operators(proposer)
                    .call()
                    .await
                    .map(|info| info.sequencerAddress)
                    .map_err(|err| {
                        metrics::counter!(
                            WhitelistPreconfirmationDriverMetrics::WHITELIST_LOOKUP_FAILURES_TOTAL
                        )
                        .increment(1);
                        WhitelistPreconfirmationDriverError::WhitelistLookup(format!(
                            "failed to fetch operators({proposer}): {err}"
                        ))
                    })
            }
        });
        let sequencers: Vec<Address> = try_join_all(sequencer_futs).await?;

        let set: HashSet<Address> =
            sequencers.into_iter().filter(|addr| *addr != Address::ZERO).collect();

        Ok(set)
    }
}

#[cfg(test)]
mod tests {
    use std::{collections::HashSet, sync::Arc};

    use alloy_primitives::Address;
    use arc_swap::ArcSwap;

    use super::SharedOperatorSet;

    /// Helper to build a [`SharedOperatorSet`] pre-loaded with the given addresses.
    fn shared_set_from(addrs: impl IntoIterator<Item = Address>) -> SharedOperatorSet {
        Arc::new(ArcSwap::from_pointee(addrs.into_iter().collect()))
    }

    #[test]
    fn shared_set_contains_inserted_addresses() {
        let a1 = Address::from([0x01u8; 20]);
        let a2 = Address::from([0x02u8; 20]);
        let set = shared_set_from([a1, a2]);

        let snapshot = set.load();
        assert!(snapshot.contains(&a1));
        assert!(snapshot.contains(&a2));
        assert!(!snapshot.contains(&Address::from([0x03u8; 20])));
    }

    #[test]
    fn store_replaces_set_atomically() {
        let a1 = Address::from([0x11u8; 20]);
        let a2 = Address::from([0x22u8; 20]);
        let set = shared_set_from([a1]);

        assert!(set.load().contains(&a1));
        assert!(!set.load().contains(&a2));

        let mut replacement = HashSet::new();
        replacement.insert(a2);
        set.store(Arc::new(replacement));

        assert!(!set.load().contains(&a1));
        assert!(set.load().contains(&a2));
    }

    #[test]
    fn empty_set_rejects_all_addresses() {
        let set = shared_set_from(std::iter::empty());
        let snapshot = set.load();

        assert!(!snapshot.contains(&Address::from([0xffu8; 20])));
        assert!(snapshot.is_empty());
    }
}
