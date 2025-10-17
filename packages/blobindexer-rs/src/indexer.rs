use std::{cmp, collections::HashSet};

use alloy_primitives::Address;
use sqlx::{MySql, Transaction};
use tokio::time::sleep;
use tokio_util::sync::CancellationToken;
use tracing::{debug, info, warn};

use crate::{
    beacon::BeaconClient,
    config::Config,
    errors::{BlobIndexerError, Result},
    models::{BeaconBlockSummary, BlobRecord, BlobSidecar, BlockRecord},
    storage::Storage,
    utils::kzg::kzg_to_versioned_hash,
};

pub struct Indexer {
    config: Config,
    storage: Storage,
    beacon: BeaconClient,
    shutdown: CancellationToken,
    watch_addresses: HashSet<Address>,
}

fn build_blob_records(
    summary: &BeaconBlockSummary,
    sidecars: &[BlobSidecar],
    watch_addresses: &HashSet<Address>,
) -> Result<Vec<BlobRecord>> {
    let commitment_count = summary.blob_commitments.len();
    let slot_i64 = u64_to_i64(summary.slot, "blob slot")?;
    let mut seen_indices = HashSet::new();

    let mut records = Vec::with_capacity(sidecars.len());
    let filter_active = !watch_addresses.is_empty();

    for sidecar in sidecars {
        let index = i32::try_from(sidecar.index).map_err(|err| {
            BlobIndexerError::InvalidData(format!(
                "blob index overflow for slot {}: {err}",
                summary.slot
            ))
        })?;

        let index_usize = usize::try_from(sidecar.index).map_err(|_| {
            BlobIndexerError::InvalidData(format!(
                "blob sidecar index {} invalid for slot {}",
                sidecar.index, summary.slot
            ))
        })?;

        if index_usize >= commitment_count {
            return Err(BlobIndexerError::InvalidData(format!(
                "blob sidecar index {} out of range for slot {}",
                sidecar.index, summary.slot
            )));
        }

        if seen_indices.contains(&index) {
            return Err(BlobIndexerError::InvalidData(format!(
                "duplicate blob sidecar index {index} for slot {}",
                summary.slot
            )));
        }

        let expected_commitment = summary.blob_commitments[index_usize];
        if expected_commitment != sidecar.commitment {
            return Err(BlobIndexerError::InvalidData(format!(
                "commitment mismatch for slot {} index {}",
                summary.slot, sidecar.index
            )));
        }

        let target_address = summary
            .blob_targets
            .get(index_usize)
            .and_then(|target| *target);

        seen_indices.insert(index);

        if filter_active
            && !target_address
                .map(|address| watch_addresses.contains(&address))
                .unwrap_or(false)
        {
            continue;
        }

        let versioned_hash = kzg_to_versioned_hash(&sidecar.commitment);

        records.push(BlobRecord {
            slot: slot_i64,
            block_root: summary.block_root,
            index,
            versioned_hash,
            commitment: sidecar.commitment,
            proof: sidecar.proof,
            blob: sidecar.blob.clone(),
            canonical: false,
        });
    }

    Ok(records)
}

fn summary_to_block_record(summary: &BeaconBlockSummary) -> Result<BlockRecord> {
    let slot = u64_to_i64(summary.slot, "block slot")?;
    Ok(BlockRecord {
        slot,
        block_root: summary.block_root,
        parent_root: summary.parent_root,
        timestamp: summary.timestamp,
        canonical: false,
    })
}

fn u64_to_i64(value: u64, context: &'static str) -> Result<i64> {
    i64::try_from(value)
        .map_err(|_| BlobIndexerError::InvalidData(format!("{context} {value} exceeds i64 range")))
}

fn i64_to_u64(value: i64, context: &'static str) -> Result<u64> {
    u64::try_from(value)
        .map_err(|_| BlobIndexerError::InvalidData(format!("{context} {value} is negative")))
}

fn has_watched_blobs(summary: &BeaconBlockSummary, watch_addresses: &HashSet<Address>) -> bool {
    watch_addresses.is_empty()
        || summary
            .blob_targets
            .iter()
            .flatten()
            .any(|address| watch_addresses.contains(address))
}

impl Indexer {
    pub fn new(
        config: Config,
        storage: Storage,
        beacon: BeaconClient,
        shutdown: CancellationToken,
    ) -> Self {
        let watch_addresses = config.watch_addresses.iter().copied().collect();
        Self {
            config,
            storage,
            beacon,
            shutdown,
            watch_addresses,
        }
    }

    pub async fn run(self) -> Result<()> {
        let poll_interval = self.config.poll_interval;

        loop {
            if self.shutdown.is_cancelled() {
                break;
            }

            if let Err(err) = self.tick().await {
                tracing::error!(error = ?err, "indexer tick failed");
            }

            sleep(poll_interval).await;
        }

        Ok(())
    }

    async fn tick(&self) -> Result<()> {
        let head_slot = self.beacon.get_head_slot().await?;
        let finalized_slot = self.beacon.get_finalized_slot().await?.unwrap_or_default();
        let last_processed = self
            .storage
            .get_last_processed_slot()
            .await?
            .map(|slot| i64_to_u64(slot, "last processed slot"))
            .transpose()?;

        info!(
            head_slot,
            finalized_slot, last_processed, "tick snapshot with latest beacon readings"
        );

        let mut next_slot = self.compute_next_slot(head_slot, last_processed);

        debug!(next_slot, "starting backfill loop");

        while next_slot <= head_slot && !self.shutdown.is_cancelled() {
            let upper = cmp::min(next_slot + self.config.backfill_batch - 1, head_slot);
            debug!(
                range = format!("{}-{}", next_slot, upper),
                "processing slot batch"
            );
            for slot in next_slot..=upper {
                if self.shutdown.is_cancelled() {
                    break;
                }
                debug!(slot, "processing slot");
                self.process_slot(slot).await.map_err(|err| {
                    // Surface the slot that failed so the outer tick error log is actionable.
                    tracing::error!(slot, error = ?err, "processing slot failed");
                    err
                })?;
            }
            next_slot = upper.saturating_add(1);
        }

        // Reconcile recent slots to handle reorgs safely.
        let reorg_start = head_slot.saturating_sub(self.config.reorg_lookback);
        debug!(
            start = reorg_start,
            end = head_slot,
            "refreshing slots for reorg protection"
        );
        for slot in reorg_start..=head_slot {
            if self.shutdown.is_cancelled() {
                break;
            }
            debug!(slot, "refreshing slot");
            self.refresh_slot(slot).await.map_err(|err| {
                tracing::error!(slot, error = ?err, "refreshing slot failed");
                err
            })?;
        }

        // Prune stale non-canonical data beyond the lookback window.
        if finalized_slot > self.config.reorg_lookback {
            let prune_slot = finalized_slot - self.config.reorg_lookback;
            let prune_before = u64_to_i64(prune_slot, "prune slot")?;
            debug!(
                prune_before,
                finalized_slot, "pruning non-canonical data below finalized checkpoint"
            );
            self.storage
                .prune_non_canonical_before_slot(prune_before)
                .await?;
        }

        Ok(())
    }

    fn compute_next_slot(&self, head_slot: u64, last_processed: Option<u64>) -> u64 {
        if last_processed.is_none()
            && let Some(start) = self.config.start_slot
        {
            return cmp::min(start, head_slot);
        }

        match last_processed {
            Some(slot) => slot.saturating_add(1),
            None => head_slot.saturating_sub(self.config.reorg_lookback),
        }
    }

    async fn process_slot(&self, slot: u64) -> Result<()> {
        let slot_i64 = u64_to_i64(slot, "processed slot")?;
        if let Some(summary) = self.beacon.get_block_summary(slot).await? {
            info!(slot, block_root = ?summary.block_root, "storing new block summary");
            self.store_block(&summary).await?;
        } else {
            debug!(slot, "no block returned, updating processed cursor");
            let mut tx = self.storage.begin().await?;
            self.storage
                .set_last_processed_slot(&mut tx, slot_i64)
                .await?;
            tx.commit().await?;
        }

        Ok(())
    }

    async fn refresh_slot(&self, slot: u64) -> Result<()> {
        if let Some(summary) = self.beacon.get_block_summary(slot).await? {
            let slot_i64 = u64_to_i64(summary.slot, "refreshed slot")?;
            if let Some(existing_block) = self
                .storage
                .get_block_by_slot(self.storage.pool(), slot_i64)
                .await?
                .filter(|block| block.block_root == summary.block_root)
            {
                // Ensure canonical flag is set correctly and metadata updated.
                debug!(
                    slot = summary.slot,
                    "found matching canonical block, promoting branch only"
                );
                let mut tx = self.storage.begin().await?;
                self.promote_branch(&mut tx, &existing_block).await?;
                self.storage
                    .set_last_processed_slot(&mut tx, slot_i64)
                    .await?;
                tx.commit().await?;
                return Ok(());
            }

            self.store_block(&summary).await?;
        }

        Ok(())
    }

    async fn store_block(&self, summary: &BeaconBlockSummary) -> Result<()> {
        let mut tx = self.storage.begin().await?;
        let block_record = summary_to_block_record(summary)?;
        let slot_i64 = block_record.slot;

        debug!(slot = summary.slot, "upserting block record");
        self.storage
            .insert_or_update_block(&mut tx, &block_record)
            .await?;

        let sidecars = if has_watched_blobs(summary, &self.watch_addresses) {
            debug!(
                slot = summary.slot,
                "fetching blob sidecars for watched addresses"
            );
            self.beacon
                .get_blob_sidecars(&summary.block_root, Some(summary.slot))
                .await?
        } else {
            debug!(
                slot = summary.slot,
                "watch set empty or no matches; skipping blob sidecars"
            );
            Vec::new()
        };
        let blob_records = build_blob_records(summary, &sidecars, &self.watch_addresses)?;

        debug!(
            slot = summary.slot,
            count = blob_records.len(),
            "replacing blob records"
        );

        for record in &blob_records {
            info!(
                slot = summary.slot,
                blob_index = record.index,
                versioned_hash = %record.versioned_hash,
                "storing blob versioned hash"
            );
        }
        self.storage
            .replace_blobs(&mut tx, slot_i64, &blob_records)
            .await?;

        debug!(slot = summary.slot, "promoting branch for new head");
        self.promote_branch(&mut tx, &block_record).await?;

        self.storage
            .set_last_processed_slot(&mut tx, slot_i64)
            .await?;

        info!(
            slot = summary.slot,
            promoted = blob_records.len(),
            "block persisted successfully"
        );
        tx.commit().await?;

        Ok(())
    }

    async fn promote_branch(
        &self,
        tx: &mut Transaction<'_, MySql>,
        head_block: &BlockRecord,
    ) -> Result<()> {
        let mut branch = Vec::new();
        branch.push(head_block.clone());

        let mut cursor = head_block.parent_root;
        let mut fork_slot: Option<i64> = None;
        let mut depth = 0u64;

        while depth < self.config.reorg_lookback {
            if let Some(parent) = self.storage.get_block_by_root(&mut **tx, &cursor).await? {
                branch.push(parent.clone());
                if parent.canonical {
                    fork_slot = Some(parent.slot);
                    break;
                }
                cursor = parent.parent_root;
                depth += 1;
                continue;
            }

            // Parent missing locally, fetch from beacon by root and store it.
            if let Some(fetched) = self.beacon.get_block_summary_by_root(&cursor).await? {
                debug!(?cursor, depth, "backfilling missing ancestor by root");
                let record = summary_to_block_record(&fetched)?;
                self.storage.insert_or_update_block(tx, &record).await?;
                let sidecars = if has_watched_blobs(&fetched, &self.watch_addresses) {
                    debug!(
                        slot = fetched.slot,
                        "fetching sidecars while backfilling parent"
                    );
                    self.beacon
                        .get_blob_sidecars(&record.block_root, Some(fetched.slot))
                        .await?
                } else {
                    Vec::new()
                };
                let blob_records = build_blob_records(&fetched, &sidecars, &self.watch_addresses)?;
                self.storage
                    .replace_blobs(tx, record.slot, &blob_records)
                    .await?;
                cursor = record.parent_root;
                branch.push(record);
                depth += 1;
            } else {
                warn!(
                    ?cursor,
                    depth, "ancestor missing on beacon node; stopping traversal"
                );
                break;
            }
        }

        if let Some(fork_slot) = fork_slot {
            debug!(fork_slot, "marking older branch as non-canonical");
            self.storage
                .mark_non_canonical_after_slot(tx, fork_slot)
                .await?;
        }

        let slots_to_promote: Vec<i64> = branch
            .iter()
            .filter(|block| !block.canonical || block.slot == head_block.slot)
            .map(|block| block.slot)
            .collect();

        debug!(
            count = slots_to_promote.len(),
            "promoting branch slots to canonical"
        );
        self.storage
            .set_canonical_for_slots(tx, &slots_to_promote, true)
            .await?;

        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::collections::HashSet;

    use alloy_primitives::{Address, B256, FixedBytes};

    fn fixed_bytes<const N: usize>(value: u8) -> FixedBytes<N> {
        FixedBytes::from([value; N])
    }

    #[test]
    fn build_blob_records_happy_path() {
        let commitment = fixed_bytes::<48>(1);
        let proof = fixed_bytes::<48>(2);
        let block_root = B256::from([3u8; 32]);

        let summary = BeaconBlockSummary {
            slot: 42,
            block_root,
            parent_root: B256::from([4u8; 32]),
            timestamp: None,
            blob_commitments: vec![commitment],
            blob_targets: vec![None],
        };

        let sidecar = BlobSidecar {
            slot: 42,
            block_root,
            index: 0,
            commitment,
            proof,
            blob: vec![5u8; 10],
        };

        let empty = HashSet::new();
        let blobs =
            build_blob_records(&summary, &[sidecar], &empty).expect("conversion should succeed");
        assert_eq!(blobs.len(), 1);
        let blob = &blobs[0];
        assert_eq!(blob.index, 0);
        assert_eq!(blob.slot, 42);
        assert_eq!(blob.block_root, block_root);
        assert_eq!(blob.commitment, commitment);
        assert_eq!(blob.versioned_hash, kzg_to_versioned_hash(&commitment));
    }

    #[test]
    fn build_blob_records_rejects_duplicate_index() {
        let commitment = fixed_bytes::<48>(1);
        let proof = fixed_bytes::<48>(2);
        let block_root = B256::from([3u8; 32]);
        let summary = BeaconBlockSummary {
            slot: 1,
            block_root,
            parent_root: B256::from([4u8; 32]),
            timestamp: None,
            blob_commitments: vec![commitment],
            blob_targets: vec![None],
        };

        let sidecar = BlobSidecar {
            slot: 1,
            block_root,
            index: 0,
            commitment,
            proof,
            blob: vec![0u8; 2],
        };

        let empty = HashSet::new();
        let err = build_blob_records(&summary, &[sidecar.clone(), sidecar], &empty)
            .expect_err("duplicate indices should fail");
        assert!(matches!(err, BlobIndexerError::InvalidData(_)));
    }

    #[test]
    fn build_blob_records_filters_addresses() {
        let commitment = fixed_bytes::<48>(1);
        let proof = fixed_bytes::<48>(2);
        let block_root = B256::from([3u8; 32]);
        let watched = Address::from([0x11u8; 20]);

        let summary = BeaconBlockSummary {
            slot: 11,
            block_root,
            parent_root: B256::from([4u8; 32]),
            timestamp: None,
            blob_commitments: vec![commitment],
            blob_targets: vec![Some(watched)],
        };

        let sidecar = BlobSidecar {
            slot: 11,
            block_root,
            index: 0,
            commitment,
            proof,
            blob: vec![7u8; 3],
        };

        let mut watched_set = HashSet::new();
        watched_set.insert(watched);
        let blobs = build_blob_records(&summary, std::slice::from_ref(&sidecar), &watched_set)
            .expect("filter should keep");
        assert_eq!(blobs.len(), 1);

        let empty = HashSet::new();
        let blobs = build_blob_records(&summary, std::slice::from_ref(&sidecar), &empty)
            .expect("no filter keeps all");
        assert_eq!(blobs.len(), 1);

        let other = Address::from([0x22u8; 20]);
        let mut other_set = HashSet::new();
        other_set.insert(other);
        let blobs =
            build_blob_records(&summary, &[sidecar], &other_set).expect("filter should drop");
        assert!(blobs.is_empty());
    }
}
