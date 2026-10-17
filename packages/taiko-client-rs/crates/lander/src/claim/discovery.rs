//! Bounded chronological discovery of fixed-Inbox historical landing commitments.
//! Logs and persisted cursors are liveness hints only. Authority is the exact receipt MPT under
//! own finalized L1, followed by independently hashed EL parents to our successful claim block.
use super::source::{MAX_ANCESTRY, RpcClaimSource, anchor_error, rpc_error, verify_receipt};
use crate::{
    LanderError, Result,
    contracts::BatchRewardRecorded,
    rewards::{self, Receipt},
    tx::LandingReceipt,
};
use abci::{RawL1Header, l1::source::L1Source};
use alloy::sol_types::SolEvent;
use alloy_consensus::Header;
use alloy_primitives::B256;
use alloy_provider::Provider;
use alloy_rpc_types::{Filter, Log};
use serde::{Deserialize, Serialize};

/// Maximum L1 blocks requested by one log page.
const PAGE_BLOCKS: u64 = 1024;
/// Maximum pages completed during one operation, independent of total chain age.
const MAX_PAGES: usize = 16;
/// Maximum decoded log responses accepted per page.
const MAX_LOGS: usize = 256;
/// Maximum total event data and topics accepted per page, in bytes.
const MAX_LOG_BYTES: usize = 512 * 1024;

/// Optional version-1 journal hint, never a proof or part of signed calldata.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct DiscoveryProgress {
    /// Original own signed transaction whose finality is being investigated.
    pub transaction_hash: B256,
    /// Canonical own inclusion; a reorg invalidates all hints.
    pub inclusion_hash: B256,
    /// Earliest causally possible landing discovery block.
    pub start: u64,
    /// Canonical hash of the original entitlement landing.
    pub start_hash: B256,
    /// Next unfinished chronological L1 page.
    pub next: u64,
    /// Finalized boundary against which this scan was acquired.
    pub finalized_number: u64,
    /// Canonical finalized boundary hash; reorgs invalidate the scan.
    pub finalized_hash: B256,
    /// Candidate persisted before expensive proof/ancestry work; always reauthenticated.
    pub candidate: Option<Candidate>,
}

/// Untrusted full event hint, retained across unavailable ancestry and operation timeouts.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct Candidate {
    /// Exact typed receipt; generation is authenticated without filtering by old entitlement.
    #[serde(with = "crate::contracts::abi_serde")]
    pub receipt: Receipt,
    /// L1 event block number, bounded by the pinned finalized header.
    pub number: u64,
    /// Event block hash checked against own canonical L1 before proof acquisition.
    pub hash: B256,
}

/// Bounded operation work and the first retryable candidate failure, never finality evidence.
struct SearchBudget {
    /// Shared remaining EL header count across all candidate branches.
    remaining_headers: u64,
    /// Report availability if no other fully authenticated candidate succeeds this operation.
    unavailable: Option<LanderError>,
}

impl RpcClaimSource {
    /// Scan bounded L1 pages and prove each covering endpoint without assuming height monotonicity.
    pub(super) async fn finalized_inner(
        &self,
        inclusion: &LandingReceipt,
        progress: &mut Option<DiscoveryProgress>,
    ) -> Result<bool> {
        if !inclusion.success || inclusion.block_hash.is_zero() {
            return Err(LanderError::Safety(
                "finality requires successful own claim inclusion".into(),
            ));
        }
        let number = self.anchors.finalized_number().await.map_err(anchor_error)?;
        let finalized = self.anchors.header_hash_pinned(number).await.map_err(anchor_error)?;
        let landing = self.discover().await?;
        if landing.number > number {
            return Err(LanderError::Unavailable(
                "reward landing is not finalized on own L1".into(),
            ));
        }
        // Disk metadata is untrusted and may be stale. Invalid hints restart discovery;
        // they cannot strand old v1 signed jobs or change their original transaction bytes.
        let valid = match progress.as_ref() {
            Some(p)
                if p.transaction_hash == inclusion.transaction_hash &&
                    p.inclusion_hash == inclusion.block_hash &&
                    p.start == landing.number &&
                    p.start_hash == landing.hash &&
                    p.next >= p.start &&
                    p.next <= p.finalized_number.saturating_add(1) &&
                    p.finalized_number <= number =>
            {
                self.anchors.canonical_hash(p.finalized_number).await.map_err(anchor_error)? ==
                    p.finalized_hash
            }
            _ => false,
        };
        if !valid {
            *progress = Some(DiscoveryProgress {
                transaction_hash: inclusion.transaction_hash,
                inclusion_hash: inclusion.block_hash,
                start: landing.number,
                start_hash: landing.hash,
                next: landing.number,
                finalized_number: number,
                finalized_hash: finalized.hash(),
                candidate: None,
            });
        }
        let mut budget = SearchBudget { remaining_headers: MAX_ANCESTRY, unavailable: None };
        let scan = progress.as_mut().expect("initialized discovery context");
        scan.finalized_number = number;
        scan.finalized_hash = finalized.hash();
        if let Some(candidate) = scan.candidate.clone() {
            if candidate.number >= scan.start &&
                candidate.number <= number &&
                self.covers(&candidate.receipt, inclusion) &&
                self.anchors.canonical_hash(candidate.number).await.map_err(anchor_error)? ==
                    candidate.hash
            {
                if self.try_candidate(&candidate, inclusion, &finalized, scan, &mut budget).await? {
                    self.recheck(inclusion, &finalized).await?;
                    return Ok(true);
                }
            } else {
                scan.candidate = None;
            }
        }
        for _ in 0..MAX_PAGES {
            if scan.next > number {
                break;
            }
            let end = scan.next.saturating_add(PAGE_BLOCKS - 1).min(number);
            let filter = Filter::new()
                .address(self.identity.inbox)
                .event_signature(BatchRewardRecorded::SIGNATURE_HASH)
                .from_block(scan.next)
                .to_block(end);
            let logs = self.l1.get_logs(&filter).await.map_err(rpc_error)?;
            if logs.len() > MAX_LOGS ||
                logs.iter()
                    .try_fold(0usize, |sum, l| {
                        sum.checked_add(l.data().data.len())?
                            .checked_add(l.topics().len().checked_mul(32)?)
                    })
                    .is_none_or(|bytes| bytes > MAX_LOG_BYTES)
            {
                return Err(LanderError::Capacity(
                    "claim discovery log page exceeds response limits".into(),
                ));
            }
            let mut ordered = logs;
            ordered.sort_by_key(|l| (l.block_number, l.log_index));
            for log in ordered {
                let candidate = self.candidate(log, scan.next, end)?;
                if !self.covers(&candidate.receipt, inclusion) {
                    continue;
                }
                if self.anchors.canonical_hash(candidate.number).await.map_err(anchor_error)? !=
                    candidate.hash
                {
                    return Err(LanderError::Unavailable(
                        "claim discovery event changed branch".into(),
                    ));
                }
                // The retained unavailable hint was already retried at this operation's start.
                if scan.candidate.as_ref() == Some(&candidate) {
                    continue;
                }
                if self.try_candidate(&candidate, inclusion, &finalized, scan, &mut budget).await? {
                    self.recheck(inclusion, &finalized).await?;
                    return Ok(true);
                }
                // Wrong branches and unavailable old endpoints never authorize finality, but
                // neither prevents searching later candidates under the same bounded budget.
            }
            self.recheck(inclusion, &finalized).await?;
            scan.next = end
                .checked_add(1)
                .ok_or_else(|| LanderError::Capacity("L1 discovery height overflow".into()))?;
        }
        self.recheck(inclusion, &finalized).await?;
        if scan.next > number {
            // Log indexing/completeness is not authenticated. Retry complete passes so an
            // omitted/delayed event never becomes a permanent cursor-induced absence verdict.
            scan.next = scan.start;
        }
        budget.unavailable.map_or(Ok(false), Err)
    }

    /// Retain one unavailable hint while continuing other candidates; full passes revisit all.
    /// A later success replaces the hint with the actual authenticated finality endpoint.
    async fn try_candidate(
        &self,
        candidate: &Candidate,
        inclusion: &LandingReceipt,
        finalized: &RawL1Header,
        scan: &mut DiscoveryProgress,
        budget: &mut SearchBudget,
    ) -> Result<bool> {
        if scan.candidate.is_none() {
            scan.candidate = Some(candidate.clone());
        }
        match self
            .authenticate_candidate(candidate, inclusion, finalized, &mut budget.remaining_headers)
            .await
        {
            Ok(true) => {
                scan.candidate = Some(candidate.clone());
                Ok(true)
            }
            Ok(false) => {
                if scan.candidate.as_ref() == Some(candidate) {
                    scan.candidate = None;
                }
                Ok(false)
            }
            Err(error @ (LanderError::Unavailable(_) | LanderError::Temporary(_))) => {
                if budget.unavailable.is_none() {
                    budget.unavailable = Some(error);
                }
                Ok(false)
            }
            Err(error) => Err(error),
        }
    }

    /// Validate event context and exact typed identities before considering its untrusted range.
    fn candidate(&self, log: Log, start: u64, end: u64) -> Result<Candidate> {
        let number = log
            .block_number
            .ok_or_else(|| LanderError::Safety("claim discovery event lacks height".into()))?;
        let hash = log
            .block_hash
            .ok_or_else(|| LanderError::Safety("claim discovery event lacks hash".into()))?;
        if log.address() != self.identity.inbox ||
            log.topic0() != Some(&BatchRewardRecorded::SIGNATURE_HASH) ||
            log.removed ||
            number < start ||
            number > end ||
            hash.is_zero() ||
            log.transaction_hash.is_none_or(|h| h.is_zero()) ||
            log.log_index.is_none()
        {
            return Err(LanderError::Safety("claim discovery event context mismatch".into()));
        }
        let e = BatchRewardRecorded::decode_log_data_validate(&log.inner.data)
            .map_err(|_| LanderError::Safety("malformed covering reward event".into()))?;
        let receipt = Receipt {
            l1ChainId: self.identity.l1_chain_id,
            l2ChainId: self.identity.l2_chain_id,
            inbox: self.identity.inbox,
            generation: e.generation,
            parentHeight: e.parentHeight,
            parentHash: e.parentHash,
            lastHeight: e.lastHeight,
            lastBlockHash: e.lastBlockHash,
            l2RewardRecipient: e.l2RewardRecipient,
            baseFeeAmount: e.baseFeeAmount,
        };
        let mut context = self.identity.clone();
        context.batch_id = e.batchId;
        context.validate_receipt(&receipt)?;
        Ok(Candidate { receipt, number, hash })
    }

    /// A range is a discovery hint; exact ancestry ultimately distinguishes recovery branches.
    fn covers(&self, receipt: &Receipt, inclusion: &LandingReceipt) -> bool {
        receipt.parentHeight < inclusion.block_number &&
            inclusion.block_number <= receipt.lastHeight
    }

    /// Authenticate exact historical mapping283 and every EL hash link to the actual claim block.
    async fn authenticate_candidate(
        &self,
        candidate: &Candidate,
        inclusion: &LandingReceipt,
        finalized: &RawL1Header,
        remaining: &mut u64,
    ) -> Result<bool> {
        let r = &candidate.receipt;
        let slot = rewards::receipt_slot(rewards::batch_id(r));
        let witness = self
            .anchors
            .account_witness_hash_canonical(self.identity.inbox, &[slot], finalized.hash())
            .await
            .map_err(anchor_error)?;
        verify_receipt(&self.identity, r, finalized.state_root(), &witness)?;
        if r.lastHeight - inclusion.block_number >= MAX_ANCESTRY {
            return Err(LanderError::Capacity(
                "covering landing exceeds claim EL ancestry limit; operator review required".into(),
            ));
        }
        let mut expected = r.lastBlockHash;
        for height in (inclusion.block_number..=r.lastHeight).rev() {
            *remaining = remaining.checked_sub(1).ok_or_else(|| {
                LanderError::Capacity(
                    "claim finality operation exceeds total EL header budget".into(),
                )
            })?;
            let h = self.execution_by_hash(expected).await?;
            if h.number != height {
                return Err(LanderError::Safety("covering claim EL parent height mismatch".into()));
            }
            if height == inclusion.block_number {
                return Ok(expected == inclusion.block_hash);
            }
            expected = h.parent_hash;
        }
        Ok(false)
    }

    /// Fetch by the proven/parent hash, independently hashing each header including fork headers.
    async fn execution_by_hash(&self, hash: B256) -> Result<Header> {
        let value: Option<serde_json::Value> = self
            .l2
            .raw_request("eth_getBlockByHash".into(), (hash, false))
            .await
            .map_err(rpc_error)?;
        let value = value.ok_or_else(|| {
            LanderError::Unavailable("covering claim EL header unavailable".into())
        })?;
        let reported: B256 = serde_json::from_value(value.get("hash").cloned().unwrap_or_default())
            .map_err(|_| LanderError::Safety("malformed covering EL hash".into()))?;
        let header: Header = serde_json::from_value(value)
            .map_err(|_| LanderError::Safety("malformed covering EL header".into()))?;
        if reported != hash || header.hash_slow() != hash {
            return Err(LanderError::Safety("covering EL header hash mismatch".into()));
        }
        Ok(header)
    }

    /// Recheck finalized authority and own inclusion after acquiring an observation or page.
    async fn recheck(&self, inclusion: &LandingReceipt, finalized: &RawL1Header) -> Result<()> {
        use super::source::ClaimSource;
        if self.anchors.canonical_hash(finalized.number()).await.map_err(anchor_error)? !=
            finalized.hash() ||
            self.canonical_hash(inclusion.block_number).await? != inclusion.block_hash
        {
            return Err(LanderError::Unavailable(
                "claim finality context changed during authentication".into(),
            ));
        }
        Ok(())
    }
}
