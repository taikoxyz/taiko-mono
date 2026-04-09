use std::{collections::VecDeque, time::Duration};

use alloy::{eips::BlockNumberOrTag, network::BlockResponse, providers::Provider};

use crate::monitor_reorg::{MAX_REORG_HISTORY, TrackedBlock};

pub(crate) const L2_BLOCK_POLL_INTERVAL: Duration = Duration::from_secs(1);

#[derive(Clone, Debug, PartialEq, Eq)]
pub(crate) struct ObservedHead {
    pub(crate) block: TrackedBlock,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub(crate) enum PollOutcome {
    StableProgress,
    NoProgress,
    Resynced,
    UncertainBackend,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub(crate) struct PollResult {
    pub(crate) outcome: PollOutcome,
    pub(crate) validated_blocks: Vec<TrackedBlock>,
}

#[derive(Clone, Debug)]
struct ChainValidation {
    outcome: PollOutcome,
    validated_blocks: Vec<TrackedBlock>,
    common_ancestor_hash: Option<alloy::primitives::B256>,
}

fn is_contiguous_desc_chain(candidate_chain_desc: &[TrackedBlock]) -> bool {
    !candidate_chain_desc.windows(2).any(|pair| {
        let newer = &pair[0];
        let older = &pair[1];
        newer.number != older.number + 1 || newer.parent_hash != older.hash
    })
}

pub(crate) fn classify_head_update(
    previous: Option<&ObservedHead>,
    current: Option<ObservedHead>,
) -> PollOutcome {
    match (previous, current) {
        (_, None) => PollOutcome::UncertainBackend,
        (None, Some(_)) => PollOutcome::NoProgress,
        (Some(previous), Some(current)) if previous.block.hash == current.block.hash => {
            PollOutcome::NoProgress
        }
        (Some(previous), Some(current))
            if current.block.number == previous.block.number + 1
                && current.block.parent_hash == previous.block.hash =>
        {
            PollOutcome::StableProgress
        }
        _ => PollOutcome::UncertainBackend,
    }
}

fn numbered_fetch_plan(validated_tip_number: Option<u64>, latest_number: u64, max_depth: usize) -> Vec<u64> {
    match validated_tip_number {
        None => vec![latest_number],
        Some(validated_tip) if latest_number == validated_tip.saturating_add(1) => {
            vec![latest_number, validated_tip]
        }
        _ => {
            let lower_bound = latest_number.saturating_sub(max_depth_lookback(max_depth));
            (lower_bound..=latest_number).rev().collect()
        }
    }
}

fn extension_fetch_plan_for_fast_path_reorg(validated_tip_number: u64, max_depth: usize) -> Vec<u64> {
    if validated_tip_number == 0 {
        return Vec::new();
    }

    let lower_bound = validated_tip_number.saturating_sub(max_depth_lookback(max_depth));
    (lower_bound..validated_tip_number).rev().collect()
}

fn max_depth_lookback(max_depth: usize) -> u64 {
    u64::try_from(max_depth.saturating_sub(1)).unwrap_or(u64::MAX)
}

fn should_reseed_after_lost_tip(
    outcome: PollOutcome,
    latest_number: u64,
    validated_tip_number: u64,
    candidate_chain_desc: &[TrackedBlock],
    max_depth: usize,
) -> bool {
    matches!(outcome, PollOutcome::UncertainBackend) &&
        latest_number.saturating_sub(validated_tip_number) > max_depth_lookback(max_depth) &&
        is_contiguous_desc_chain(candidate_chain_desc)
}

fn validate_candidate_chain(
    validated_history: &[TrackedBlock],
    candidate_chain_desc: &[TrackedBlock],
) -> ChainValidation {
    let Some(validated_tip) = validated_history.last() else {
        return ChainValidation {
            outcome: PollOutcome::UncertainBackend,
            validated_blocks: Vec::new(),
            common_ancestor_hash: None,
        };
    };
    let Some(observed_head) = candidate_chain_desc.first() else {
        return ChainValidation {
            outcome: PollOutcome::UncertainBackend,
            validated_blocks: Vec::new(),
            common_ancestor_hash: None,
        };
    };

    if observed_head.number < validated_tip.number {
        return ChainValidation {
            outcome: PollOutcome::UncertainBackend,
            validated_blocks: Vec::new(),
            common_ancestor_hash: None,
        };
    }

    if observed_head.hash == validated_tip.hash {
        return ChainValidation {
            outcome: PollOutcome::NoProgress,
            validated_blocks: Vec::new(),
            common_ancestor_hash: Some(validated_tip.hash),
        };
    }

    if !is_contiguous_desc_chain(candidate_chain_desc) {
        return ChainValidation {
            outcome: PollOutcome::UncertainBackend,
            validated_blocks: Vec::new(),
            common_ancestor_hash: None,
        };
    }

    let Some((ancestor_idx, ancestor)) = candidate_chain_desc
        .iter()
        .enumerate()
        .find(|(_, block)| validated_history.iter().any(|validated| validated.hash == block.hash))
    else {
        return ChainValidation {
            outcome: PollOutcome::UncertainBackend,
            validated_blocks: Vec::new(),
            common_ancestor_hash: None,
        };
    };

    let validated_blocks: Vec<TrackedBlock> =
        candidate_chain_desc[..ancestor_idx].iter().rev().cloned().collect();
    if validated_blocks.is_empty() {
        ChainValidation {
            outcome: PollOutcome::NoProgress,
            validated_blocks,
            common_ancestor_hash: Some(ancestor.hash),
        }
    } else {
        ChainValidation {
            outcome: PollOutcome::StableProgress,
            validated_blocks,
            common_ancestor_hash: Some(ancestor.hash),
        }
    }
}

#[derive(Clone, Debug)]
struct ValidatedHistory {
    blocks: VecDeque<TrackedBlock>,
    max_depth: usize,
}

impl ValidatedHistory {
    fn new(max_depth: usize) -> Self {
        Self { blocks: VecDeque::with_capacity(max_depth.max(1)), max_depth: max_depth.max(1) }
    }

    fn tip(&self) -> Option<&TrackedBlock> {
        self.blocks.back()
    }

    fn seed_if_empty(&mut self, block: TrackedBlock) -> bool {
        if self.blocks.is_empty() {
            self.push(block);
            true
        } else {
            false
        }
    }

    fn push(&mut self, block: TrackedBlock) {
        self.blocks.push_back(block);
        while self.blocks.len() > self.max_depth {
            self.blocks.pop_front();
        }
    }

    fn apply_stable_progress(
        &mut self,
        validated_blocks: &[TrackedBlock],
        common_ancestor_hash: alloy::primitives::B256,
    ) {
        while self.blocks.back().map(|block| block.hash != common_ancestor_hash).unwrap_or(false) {
            self.blocks.pop_back();
        }

        for block in validated_blocks {
            self.push(block.clone());
        }
    }

    fn reseed_from_desc_chain(&mut self, candidate_chain_desc: &[TrackedBlock]) {
        self.blocks.clear();
        for block in candidate_chain_desc.iter().rev() {
            self.push(block.clone());
        }
    }

    fn classify_candidate_head(
        &mut self,
        observed_head: TrackedBlock,
        candidate_chain_desc: Vec<TrackedBlock>,
    ) -> PollResult {
        if self.seed_if_empty(observed_head.clone()) {
            return PollResult { outcome: PollOutcome::NoProgress, validated_blocks: Vec::new() };
        }

        let validation = validate_candidate_chain(
            self.blocks.make_contiguous(),
            &candidate_chain_desc,
        );
        if matches!(validation.outcome, PollOutcome::StableProgress) {
            self.apply_stable_progress(
                &validation.validated_blocks,
                validation.common_ancestor_hash.expect("stable progress requires ancestor"),
            );
        }

        PollResult { outcome: validation.outcome, validated_blocks: validation.validated_blocks }
    }

    #[cfg(test)]
    fn from_blocks_for_test(blocks: Vec<TrackedBlock>) -> Self {
        let mut history = Self::new(blocks.len().max(1));
        for block in blocks {
            history.push(block);
        }
        history
    }

    #[cfg(test)]
    fn tip_for_test(&self) -> Option<TrackedBlock> {
        self.tip().cloned()
    }
}

pub(crate) struct L2BlockPoller<P> {
    provider: P,
    validated_history: ValidatedHistory,
}

impl<P> L2BlockPoller<P>
where
    P: Provider + Clone + Send + Sync + 'static,
{
    pub(crate) fn new(provider: P) -> Self {
        Self { provider, validated_history: ValidatedHistory::new(MAX_REORG_HISTORY) }
    }

    pub(crate) async fn poll_latest(&mut self) -> PollResult {
        let latest_number = match self.provider.get_block_number().await {
            Ok(latest_number) => latest_number,
            Err(_) => {
                return PollResult {
                    outcome: PollOutcome::UncertainBackend,
                    validated_blocks: Vec::new(),
                };
            }
        };

        let fetch_plan = numbered_fetch_plan(
            self.validated_history.tip().map(|block| block.number),
            latest_number,
            self.validated_history.max_depth,
        );

        let mut candidate_chain_desc = Vec::with_capacity(fetch_plan.len());
        for block_number in fetch_plan {
            let Some(block) = self.fetch_block(block_number).await else {
                return PollResult {
                    outcome: PollOutcome::UncertainBackend,
                    validated_blocks: Vec::new(),
                };
            };
            candidate_chain_desc.push(block);
        }

        let Some(observed_head) = candidate_chain_desc.first().cloned() else {
            return PollResult {
                outcome: PollOutcome::UncertainBackend,
                validated_blocks: Vec::new(),
            };
        };

        let Some(validated_tip) = self.validated_history.tip().cloned() else {
            self.validated_history.seed_if_empty(observed_head.clone());
            return PollResult { outcome: PollOutcome::NoProgress, validated_blocks: Vec::new() };
        };
        self.consume_polled_chain(latest_number, candidate_chain_desc, validated_tip).await
    }

    async fn consume_polled_chain(
        &mut self,
        latest_number: u64,
        mut candidate_chain_desc: Vec<TrackedBlock>,
        validated_tip: TrackedBlock,
    ) -> PollResult {
        let observed_head = match candidate_chain_desc.first().cloned() {
            Some(observed_head) => observed_head,
            None => {
                return PollResult {
                    outcome: PollOutcome::UncertainBackend,
                    validated_blocks: Vec::new(),
                };
            }
        };
        let validated_tip_number = validated_tip.number;

        let transition = classify_head_update(
            Some(&ObservedHead { block: validated_tip.clone() }),
            Some(ObservedHead { block: observed_head.clone() }),
        );
        if matches!(transition, PollOutcome::NoProgress) {
            return PollResult { outcome: PollOutcome::NoProgress, validated_blocks: Vec::new() };
        }
        if observed_head.number < validated_tip.number {
            return PollResult {
                outcome: PollOutcome::UncertainBackend,
                validated_blocks: Vec::new(),
            };
        }

        if matches!(transition, PollOutcome::StableProgress) && candidate_chain_desc.len() == 1 {
            candidate_chain_desc.push(validated_tip.clone());
        }

        let initial_result =
            self.validated_history.classify_candidate_head(observed_head.clone(), candidate_chain_desc.clone());

        let needs_fast_path_extension =
            matches!(initial_result.outcome, PollOutcome::UncertainBackend)
                && latest_number == validated_tip_number.saturating_add(1)
                && candidate_chain_desc.len() == 2;

        if needs_fast_path_extension {
            for block_number in extension_fetch_plan_for_fast_path_reorg(
                validated_tip_number,
                self.validated_history.max_depth,
            ) {
                let Some(block) = self.fetch_block(block_number).await else {
                    return PollResult {
                        outcome: PollOutcome::UncertainBackend,
                        validated_blocks: Vec::new(),
                    };
                };
                candidate_chain_desc.push(block);
            }

            return self.validated_history.classify_candidate_head(observed_head, candidate_chain_desc);
        }

        if should_reseed_after_lost_tip(
            initial_result.outcome,
            latest_number,
            validated_tip_number,
            &candidate_chain_desc,
            self.validated_history.max_depth,
        ) {
            self.validated_history.reseed_from_desc_chain(&candidate_chain_desc);
            return PollResult { outcome: PollOutcome::Resynced, validated_blocks: Vec::new() };
        }

        initial_result
    }

    async fn fetch_block(&self, number: u64) -> Option<TrackedBlock> {
        match self.provider.get_block_by_number(BlockNumberOrTag::Number(number)).await {
            Ok(Some(block)) => Some(TrackedBlock {
                number: block.header().number,
                hash: block.hash(),
                parent_hash: block.header().parent_hash,
                coinbase: block.header().beneficiary,
            }),
            Ok(None) | Err(_) => None,
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use alloy::primitives::{Address, B256};

    fn block(number: u64, hash_id: u8, parent_id: u8) -> TrackedBlock {
        TrackedBlock {
            number,
            hash: B256::with_last_byte(hash_id),
            parent_hash: B256::with_last_byte(parent_id),
            coinbase: Address::with_last_byte(hash_id),
        }
    }

    #[test]
    fn latest_only_same_height_hash_change_is_uncertain() {
        let validated = vec![block(99, 9, 8), block(100, 10, 9)];
        let result = super::validate_candidate_chain(&validated, &[block(100, 42, 9)]);
        assert_eq!(result.outcome, PollOutcome::UncertainBackend);
        assert!(result.validated_blocks.is_empty());
    }

    #[test]
    fn backward_head_is_uncertain() {
        let validated = vec![block(99, 9, 8), block(100, 10, 9)];
        let result = super::validate_candidate_chain(&validated, &[block(99, 9, 8)]);
        assert_eq!(result.outcome, PollOutcome::UncertainBackend);
        assert!(result.validated_blocks.is_empty());
    }

    #[test]
    fn missing_intermediates_without_chain_proof_is_uncertain() {
        let validated = vec![block(100, 10, 9)];
        let result = super::validate_candidate_chain(&validated, &[block(102, 12, 11)]);
        assert_eq!(result.outcome, PollOutcome::UncertainBackend);
        assert!(result.validated_blocks.is_empty());
    }

    #[test]
    fn contiguous_forward_chain_is_stable_progress() {
        let validated = vec![block(100, 10, 9)];
        let result = super::validate_candidate_chain(
            &validated,
            &[block(102, 12, 11), block(101, 11, 10), block(100, 10, 9)],
        );
        assert_eq!(result.outcome, PollOutcome::StableProgress);
        assert_eq!(result.validated_blocks, vec![block(101, 11, 10), block(102, 12, 11)]);
    }

    #[test]
    fn validated_reorg_with_common_ancestor_is_stable_progress() {
        let validated = vec![block(98, 8, 7), block(99, 9, 8), block(100, 10, 9)];
        let result = super::validate_candidate_chain(
            &validated,
            &[block(101, 41, 40), block(100, 40, 9), block(99, 9, 8)],
        );
        assert_eq!(result.outcome, PollOutcome::StableProgress);
        assert_eq!(result.validated_blocks, vec![block(100, 40, 9), block(101, 41, 40)]);
    }

    #[test]
    fn uncertain_transition_does_not_advance_validated_tip() {
        let mut history =
            super::ValidatedHistory::from_blocks_for_test(vec![block(99, 9, 8), block(100, 10, 9)]);
        let result = history.classify_candidate_head(block(100, 42, 9), vec![block(100, 42, 9)]);

        assert_eq!(result.outcome, PollOutcome::UncertainBackend);
        assert_eq!(history.tip_for_test(), Some(block(100, 10, 9)));
    }

    #[test]
    fn fetch_plan_starts_from_eth_block_number_and_latest_numbered_header() {
        let plan = super::numbered_fetch_plan(None, 105, MAX_REORG_HISTORY);
        assert_eq!(plan, vec![105]);
    }

    #[test]
    fn fetch_plan_for_direct_forward_progress_fetches_latest_and_ancestor() {
        let plan = super::numbered_fetch_plan(Some(100), 101, MAX_REORG_HISTORY);
        assert_eq!(plan, vec![101, 100]);
    }

    #[test]
    fn fetch_plan_for_ambiguous_tip_fetches_validation_window_by_number() {
        let plan = super::numbered_fetch_plan(Some(100), 100, 4);
        assert_eq!(plan, vec![100, 99, 98, 97]);
    }

    #[test]
    fn direct_forward_reorg_fast_path_extends_below_current_numbered_pair() {
        let extension = super::extension_fetch_plan_for_fast_path_reorg(100, 4);
        assert_eq!(extension, vec![99, 98, 97]);
    }

    #[test]
    fn lost_tip_outside_window_resyncs_to_recent_contiguous_chain() {
        let candidate_chain_desc =
            vec![block(10, 10, 9), block(9, 9, 8), block(8, 8, 7), block(7, 7, 6)];
        let initial_result = PollResult {
            outcome: PollOutcome::UncertainBackend,
            validated_blocks: Vec::new(),
        };

        assert!(super::should_reseed_after_lost_tip(
            initial_result.outcome,
            10,
            3,
            &candidate_chain_desc,
            4,
        ));

        let mut history =
            super::ValidatedHistory::from_blocks_for_test(vec![block(1, 1, 0), block(2, 2, 1), block(3, 3, 2)]);
        history.reseed_from_desc_chain(&candidate_chain_desc);
        assert_eq!(history.tip_for_test(), Some(block(10, 10, 9)));
    }
}
