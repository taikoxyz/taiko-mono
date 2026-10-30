//! Optional archive state reads for committee discovery, with the own L1 as finality authority.

use std::{fmt, future::Future, sync::Arc, time::Duration};

use alloy_primitives::{Address, B256, Bytes, U256};
use async_trait::async_trait;

use super::{L1Error, L1Source, RawL1Header};
use crate::types::AccountWitness;

/// Longest primary-only grace period before starting a committee archive state read.
const MAX_ARCHIVE_HEDGE_DELAY: Duration = Duration::from_millis(100);

/// An own-L1 source with an optional archive fallback solely for staking-registry state reads.
/// Archive answers stay untrusted until the complete committee witness verifies under the fixed
/// committed parent's root. Finality, canonical hashes, headers and other accounts use only
/// `primary`; an archive can never advance the authenticated snapshot or authorize an anchor.
pub struct CommitteeL1Source<L: L1Source> {
    /// Operator's own L1 view, the sole authority for finality and canonical headers.
    primary: L,
    /// Optional provider retaining historical committee registry state.
    archive: Option<Arc<dyn L1Source>>,
    /// The only account whose state reads may use the archive.
    registry: Address,
    /// Primary-only grace period, bounded by half the per-read deadline and 100 milliseconds.
    hedge_delay: Duration,
}

impl<L: L1Source> fmt::Debug for CommitteeL1Source<L> {
    /// Shows routing configuration without provider URLs or credentials.
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.debug_struct("CommitteeL1Source")
            .field("registry", &self.registry)
            .field("has_archive", &self.archive.is_some())
            .field("hedge_delay", &self.hedge_delay)
            .finish_non_exhaustive()
    }
}

impl<L: L1Source> CommitteeL1Source<L> {
    /// Enables committee-only archive reads after a primary error or the shorter of half
    /// `read_timeout` and 100 milliseconds. Pending reads race for the first successful answer
    /// under the caller's unchanged overall read deadline.
    pub fn new(
        primary: L,
        archive: Option<Arc<dyn L1Source>>,
        registry: Address,
        read_timeout: Duration,
    ) -> Self {
        Self {
            primary,
            archive,
            registry,
            hedge_delay: (read_timeout / 2).min(MAX_ARCHIVE_HEDGE_DELAY),
        }
    }

    /// Gives the primary a short head start, then accepts the first successful state response.
    /// One source failing leaves the other in flight. All answers remain untrusted until the
    /// completed witness authenticates under the committed parent's root; the caller's deadline
    /// cancels both pending reads together.
    async fn state_read<T>(
        &self,
        primary: impl Future<Output = Result<T, L1Error>>,
        archive: impl Future<Output = Result<T, L1Error>>,
    ) -> Result<T, L1Error> {
        let mut primary = std::pin::pin!(primary);
        let mut archive = std::pin::pin!(archive);
        tokio::select! {
            biased;
            result = &mut primary => return match result {
                Ok(value) => Ok(value),
                Err(_) => {
                    tracing::debug!("using archive for unavailable committee registry state");
                    archive.await
                }
            },
            _ = tokio::time::sleep(self.hedge_delay) => {}
        }
        tracing::debug!("hedging a slow committee registry read with the archive");
        tokio::select! {
            biased;
            result = &mut primary => match result {
                Ok(value) => Ok(value),
                Err(_) => archive.await,
            },
            result = &mut archive => match result {
                Ok(value) => Ok(value),
                Err(_) => primary.await,
            }
        }
    }
}

#[async_trait]
impl<L: L1Source> L1Source for CommitteeL1Source<L> {
    /// Reads only the own L1's finalized tag, never the archive's.
    async fn finalized_number(&self) -> Result<u64, L1Error> {
        self.primary.finalized_number().await
    }

    /// Reads canonical identity only from the own L1.
    async fn canonical_hash(&self, number: u64) -> Result<B256, L1Error> {
        self.primary.canonical_hash(number).await
    }

    /// Reads authenticated headers only from the own L1.
    async fn header(&self, number: u64) -> Result<RawL1Header, L1Error> {
        self.primary.header(number).await
    }

    /// Reads the exact requested account and block, falling back only for the configured registry.
    async fn account_witness(
        &self,
        address: Address,
        slots: &[B256],
        block: u64,
    ) -> Result<AccountWitness, L1Error> {
        let primary = self.primary.account_witness(address, slots, block);
        match &self.archive {
            Some(archive) if address == self.registry => {
                self.state_read(primary, archive.account_witness(address, slots, block)).await
            }
            _ => primary.await,
        }
    }

    /// Reads forced events only from the primary L1 source, never the committee archive.
    async fn forced_transaction(
        &self,
        inbox: Address,
        index: u64,
        l1_block: u64,
    ) -> Result<Bytes, L1Error> {
        self.primary.forced_transaction(inbox, index, l1_block).await
    }

    /// Discovers raw registry words at the exact requested block; proof verification decides trust.
    async fn storage_at(&self, address: Address, slot: B256, block: u64) -> Result<U256, L1Error> {
        let primary = self.primary.storage_at(address, slot, block);
        match &self.archive {
            Some(archive) if address == self.registry => {
                self.state_read(primary, archive.storage_at(address, slot, block)).await
            }
            _ => primary.await,
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::{
        committee::verify_committee_witness,
        l1::{build_committee_witness, layout::registry},
        test_utils::{Fixture, L1Call, RegistryStorage, sample_entries},
    };

    #[tokio::test]
    async fn forced_tx_events_use_primary_only_even_when_archive_has_data() {
        let fx = Fixture::genesis(3);
        let primary = fx.l1();
        let archive = Arc::new(fx.l1());
        let key = (fx.params.inbox, 42, fx.genesis.l1_0);
        let transaction = Bytes::from_static(&[2, 3]);
        primary.state().forced_transactions.insert(key, transaction.clone());
        archive.state().forced_transactions.insert(key, Bytes::from_static(&[4, 5]));
        archive.state().forced_transactions.insert((key.0, key.1 + 1, key.2), transaction.clone());
        let source = CommitteeL1Source::new(
            primary,
            Some(archive.clone()),
            fx.params.registry,
            Duration::from_secs(3),
        );
        assert_eq!(source.forced_transaction(key.0, key.1, key.2).await.unwrap(), transaction);
        assert!(source.forced_transaction(key.0, key.1 + 1, key.2).await.is_err());
        assert!(archive.calls().is_empty());
    }

    #[tokio::test]
    async fn archive_recovers_pruned_fixed_snapshot_without_becoming_finality_authority() {
        let fx = Fixture::genesis(3);
        let primary = fx.l1();
        let anchor = fx.anchor_state(&primary, fx.genesis.l1_0);
        primary.state().states.clear();
        let archive = Arc::new(fx.l1());
        archive.set_finalized(fx.genesis.l1_0 + 1_000);
        let source = CommitteeL1Source::new(
            primary,
            Some(archive.clone()),
            fx.params.registry,
            Duration::from_secs(3),
        );
        assert_eq!(source.finalized_number().await.unwrap(), fx.genesis.l1_0);
        assert_eq!(source.canonical_hash(fx.genesis.l1_0).await.unwrap(), anchor.hash);
        let witness = build_committee_witness(&source, &fx.params, anchor.number, 0).await.unwrap();
        assert_eq!(witness.record.cutoff_l1_block, anchor.number);
        assert!(verify_committee_witness(&anchor, &fx.params, &witness, 0).is_ok());
        assert!(archive.calls().iter().all(|call| matches!(call,
            L1Call::StorageAt { address, .. } | L1Call::AccountWitness { address, .. }
                if *address == fx.params.registry)));
        assert!(source.account_witness(fx.params.inbox, &[], anchor.number).await.is_err());
        assert!(archive.calls().iter().all(|call| !matches!(call,
            L1Call::AccountWitness { address, .. } if *address == fx.params.inbox)));
    }

    #[tokio::test]
    async fn archive_does_not_replace_failed_primary_finality() {
        let fx = Fixture::genesis(3);
        let primary = fx.l1();
        primary.state().finalized_script.push_back(Err(L1Error::Rpc("own L1 unavailable".into())));
        let archive = Arc::new(fx.l1());
        let source = CommitteeL1Source::new(
            primary,
            Some(archive.clone()),
            fx.params.registry,
            Duration::from_secs(3),
        );
        assert!(source.finalized_number().await.is_err());
        assert!(archive.calls().is_empty(), "archive cannot authorize finality");
    }

    #[tokio::test(start_paused = true)]
    async fn absent_archive_preserves_the_full_primary_read_budget() {
        let fx = Fixture::genesis(3);
        let primary = fx.l1();
        primary.state().delay = Some(Duration::from_secs(2));
        let source =
            CommitteeL1Source::new(primary, None, fx.params.registry, Duration::from_secs(3));
        let word = tokio::time::timeout(
            Duration::from_secs(3),
            source.storage_at(fx.params.registry, registry::length_slot(), fx.genesis.l1_0),
        )
        .await
        .unwrap()
        .unwrap();
        assert_eq!(word, U256::from(1));
    }

    #[tokio::test]
    async fn archive_cannot_substitute_another_state_root_at_the_fixed_block() {
        let fx = Fixture::genesis(3);
        let primary = fx.l1();
        let anchor = fx.anchor_state(&primary, fx.genesis.l1_0);
        primary.state().states.clear();
        let archive = Arc::new(fx.l1());
        let changed =
            RegistryStorage { checkpoints: vec![(fx.genesis.genesis_cutoff, sample_entries(4))] };
        fx.plant_l1_block(&archive, anchor.number, &fx.inbox, &changed);
        let source = CommitteeL1Source::new(
            primary,
            Some(archive),
            fx.params.registry,
            Duration::from_secs(3),
        );
        let witness = build_committee_witness(&source, &fx.params, anchor.number, 0).await.unwrap();
        assert!(verify_committee_witness(&anchor, &fx.params, &witness, 0).is_err());
    }

    #[tokio::test(start_paused = true)]
    async fn failed_archive_keeps_a_slow_successful_primary_in_flight() {
        let fx = Fixture::genesis(3);
        let primary = fx.l1();
        primary.state().delay = Some(Duration::from_millis(400));
        let archive = Arc::new(fx.l1());
        archive.state().fail = Some(L1Error::Rpc("archive unavailable".into()));
        let source = CommitteeL1Source::new(
            primary,
            Some(archive),
            fx.params.registry,
            Duration::from_secs(3),
        );
        let word = tokio::time::timeout(
            Duration::from_secs(1),
            source.storage_at(fx.params.registry, registry::length_slot(), fx.genesis.l1_0),
        )
        .await
        .unwrap()
        .unwrap();
        assert_eq!(word, U256::from(1));
    }

    #[tokio::test(start_paused = true)]
    async fn healthy_archive_read_fits_the_default_prepare_deadline_with_stalled_primary() {
        let fx = Fixture::genesis(3);
        let primary = fx.l1();
        primary.state().delay = Some(Duration::from_secs(10));
        let archive = Arc::new(fx.l1());
        archive.state().delay = Some(Duration::from_secs(1));
        let opts = crate::AppOptions::default();
        let source =
            CommitteeL1Source::new(primary, Some(archive), fx.params.registry, opts.l1_timeout);
        let word = tokio::time::timeout(
            opts.prepare_timeout,
            source.storage_at(fx.params.registry, registry::length_slot(), fx.genesis.l1_0),
        )
        .await
        .expect("the adapter must leave time for a healthy archive in one proposal round")
        .unwrap();
        assert_eq!(word, U256::from(1));
    }

    #[tokio::test(start_paused = true)]
    async fn stalled_primary_does_not_starve_committee_archive() {
        let fx = Fixture::genesis(3);
        let primary = fx.l1();
        primary.state().delay = Some(Duration::from_secs(10));
        let source = CommitteeL1Source::new(
            primary,
            Some(Arc::new(fx.l1())),
            fx.params.registry,
            Duration::from_secs(3),
        );
        let word = tokio::time::timeout(
            Duration::from_secs(3),
            source.storage_at(fx.params.registry, registry::length_slot(), fx.genesis.l1_0),
        )
        .await
        .expect("archive must get part of the read deadline")
        .unwrap();
        assert_eq!(word, U256::from(1));
    }
}
