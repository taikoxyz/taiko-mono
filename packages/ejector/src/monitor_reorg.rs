use std::collections::VecDeque;

use alloy::primitives::{Address, B256};

pub const MAX_REORG_HISTORY: usize = 768;

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct TrackedBlock {
    pub number: u64,
    pub hash: B256,
    pub parent_hash: B256,
    pub coinbase: Address,
}

#[derive(Clone, Default, Debug)]
pub struct ApplyOutcome {
    pub reorged: Vec<TrackedBlock>,
    pub parent_not_found: bool,
    pub duplicate: bool,
    pub reverted_to: Option<u64>,
}

impl ApplyOutcome {
    pub fn duplicate() -> Self {
        Self { duplicate: true, ..Self::default() }
    }
}

#[derive(Debug)]
pub struct ChainReorgTracker {
    history: VecDeque<TrackedBlock>,
    max_depth: usize,
}

impl ChainReorgTracker {
    pub fn new(max_depth: usize) -> Self {
        Self { history: VecDeque::with_capacity(max_depth.max(1)), max_depth: max_depth.max(1) }
    }

    pub fn apply(&mut self, block: TrackedBlock) -> ApplyOutcome {
        if self.history.iter().any(|stored| stored.hash == block.hash) {
            return ApplyOutcome::duplicate();
        }

        let mut outcome = ApplyOutcome::default();

        while let Some(last) = self.history.back() {
            if last.number >= block.number {
                let removed = self.history.pop_back().expect("history.pop_back failed");
                if removed.hash == block.hash {
                    self.history.push_back(removed);
                    return ApplyOutcome::duplicate();
                }
                outcome.reorged.push(removed);
                continue;
            }

            if last.hash != block.parent_hash {
                let removed = self.history.pop_back().expect("history.pop_back failed");
                outcome.reorged.push(removed);
                continue;
            }

            break;
        }

        let parent_missing = match self.history.back() {
            Some(last) => last.hash != block.parent_hash,
            None => !outcome.reorged.is_empty(),
        };

        if parent_missing {
            outcome.parent_not_found = true;
            self.history.clear();
            self.history.push_back(block);
            return outcome;
        }
        // If a reorg happened, record the latest reorg height.
        if !outcome.reorged.is_empty() {
            outcome.reverted_to = self.history.back().map(|b| b.number);
        }
        self.history.push_back(block);

        while self.history.len() > self.max_depth {
            self.history.pop_front();
        }

        outcome
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn hash(id: u64) -> B256 {
        let mut bytes = [0u8; 32];
        bytes[24..].copy_from_slice(&id.to_be_bytes());
        B256::from(bytes)
    }

    fn addr(id: u64) -> Address {
        let mut bytes = [0u8; 20];
        bytes[12..].copy_from_slice(&id.to_be_bytes());
        Address::from(bytes)
    }

    fn block(number: u64, parent_id: u64, hash_id: u64, proposer_id: u64) -> TrackedBlock {
        TrackedBlock {
            number,
            parent_hash: hash(parent_id),
            hash: hash(hash_id),
            coinbase: addr(proposer_id),
        }
    }

    #[test]
    fn tracker_accepts_linear_progression() {
        let mut tracker = ChainReorgTracker::new(8);

        let genesis = block(1, 0, 1, 10);
        let outcome = tracker.apply(genesis.clone());
        assert!(outcome.reorged.is_empty());
        assert!(!outcome.parent_not_found);
        assert!(!outcome.duplicate);

        let second = block(2, 1, 2, 11);
        let outcome = tracker.apply(second.clone());
        assert!(outcome.reorged.is_empty());
        assert!(!outcome.parent_not_found);
        assert!(!outcome.duplicate);

        let third = block(3, 2, 3, 12);
        let outcome = tracker.apply(third);
        assert!(outcome.reorged.is_empty());
        assert!(!outcome.parent_not_found);
        assert!(!outcome.duplicate);
    }

    #[test]
    fn tracker_detects_single_block_reorg() {
        let mut tracker = ChainReorgTracker::new(8);

        let genesis = block(1, 0, 1, 10);
        tracker.apply(genesis.clone());
        let block2 = block(2, 1, 2, 11);
        tracker.apply(block2.clone());
        let block3_old = block(3, 2, 30, 12);
        tracker.apply(block3_old.clone());

        let block3_new = block(3, 2, 31, 99);
        let outcome = tracker.apply(block3_new);

        assert_eq!(outcome.reorged.len(), 1);
        assert_eq!(outcome.reorged[0].hash, block3_old.hash);
        assert_eq!(outcome.reorged[0].coinbase, block3_old.coinbase);
        assert_eq!(outcome.reverted_to.expect("should not be none"), block2.number);
        assert!(!outcome.parent_not_found);
        assert!(!outcome.duplicate);
    }

    #[test]
    fn tracker_detects_multi_block_reorg() {
        let mut tracker = ChainReorgTracker::new(8);

        let genesis = block(1, 0, 1, 10);
        tracker.apply(genesis.clone());
        let block2_old = block(2, 1, 20, 11);
        tracker.apply(block2_old.clone());
        let block3_old = block(3, 20, 30, 12);
        tracker.apply(block3_old.clone());

        let block2_new = block(2, 1, 21, 55);
        let outcome = tracker.apply(block2_new.clone());

        assert_eq!(outcome.reorged.len(), 2);
        assert_eq!(outcome.reorged[0].hash, block3_old.hash);
        assert_eq!(outcome.reorged[1].hash, block2_old.hash);
        assert_eq!(outcome.reverted_to.expect("should not be none"), genesis.number);
        assert!(!outcome.parent_not_found);

        let block3_new = block(3, 21, 31, 56);
        let outcome = tracker.apply(block3_new);
        assert!(outcome.reorged.is_empty());
        assert!(!outcome.parent_not_found);
    }

    #[test]
    fn tracker_marks_parent_not_found_when_history_missing() {
        let mut tracker = ChainReorgTracker::new(2);

        let genesis = block(1, 0, 1, 10);
        tracker.apply(genesis.clone());
        let block2 = block(2, 1, 2, 11);
        tracker.apply(block2.clone());
        let block3 = block(3, 2, 3, 12);
        tracker.apply(block3.clone());

        let block4 = block(4, 999, 4, 13);
        let outcome = tracker.apply(block4);

        assert!(outcome.parent_not_found);
        let numbers: Vec<u64> = outcome.reorged.iter().map(|b| b.number).collect();
        assert_eq!(numbers, vec![3, 2]);

        let next = block(5, 4, 5, 14);
        let outcome_next = tracker.apply(next);
        assert!(outcome_next.reorged.is_empty());
        assert!(!outcome_next.parent_not_found);
    }

    #[test]
    fn tracker_reverted_to_none_when_no_reorg() {
        let mut tracker = ChainReorgTracker::new(8);
        let genesis = block(1, 0, 1, 10);
        let outcome = tracker.apply(genesis);
        assert!(outcome.reverted_to.is_none());
    }
}
