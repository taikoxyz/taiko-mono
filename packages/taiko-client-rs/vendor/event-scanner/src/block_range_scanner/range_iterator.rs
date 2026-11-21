use alloy::primitives::BlockNumber;
use std::{marker::PhantomData, ops::RangeInclusive};

pub struct Forward;
pub struct Reverse;

/// An iterator that yields block ranges of a configurable size.
#[derive(Debug, Clone)]
pub struct RangeIterator<D> {
    current: BlockNumber,
    end: BlockNumber,
    range_size: u64,
    batch_count: u64,
    total_batches: u64,
    _direction: PhantomData<D>,
}

impl RangeIterator<Forward> {
    /// Creates a forward iterator (oldest to newest).
    ///
    /// Yields ranges from `start` toward `end`, inclusive.
    ///
    /// # Panics
    ///
    /// Panics if `max_block_range` is 0.
    #[must_use]
    pub const fn forward(start: BlockNumber, end: BlockNumber, max_block_range: u64) -> Self {
        assert!(max_block_range >= 1, "max_block_range must be at least 1");
        let total_batches = if start > end { 0 } else { (end - start) / max_block_range + 1 };
        Self {
            current: start,
            end,
            range_size: max_block_range,
            batch_count: 0,
            total_batches,
            _direction: PhantomData,
        }
    }

    /// Resets the iterator to continue from a new position.
    ///
    /// Useful after detecting a reorg to rescan from a common ancestor.
    pub fn reset_to(&mut self, block: BlockNumber) {
        self.current = block;
        self.total_batches = if block > self.end {
            self.batch_count
        } else {
            self.batch_count + (self.end - block) / self.range_size + 1
        };
    }
}

impl RangeIterator<Reverse> {
    /// Creates a reverse iterator (newest to oldest).
    ///
    /// Yields ranges from `start` (higher) toward `end` (lower), inclusive.
    /// Each yielded range is still formatted as `low..=high`.
    ///
    /// # Panics
    ///
    /// Panics if `max_block_range` is 0.
    #[must_use]
    pub const fn reverse(start: BlockNumber, end: BlockNumber, max_block_range: u64) -> Self {
        assert!(max_block_range >= 1, "max_block_range must be at least 1");
        let total_batches = if start < end { 0 } else { (start - end) / max_block_range + 1 };
        Self {
            current: start,
            end,
            range_size: max_block_range,
            batch_count: 0,
            total_batches,
            _direction: PhantomData,
        }
    }
}

impl Iterator for RangeIterator<Forward> {
    type Item = RangeInclusive<BlockNumber>;

    fn next(&mut self) -> Option<Self::Item> {
        if self.batch_count >= self.total_batches {
            return None;
        }

        let batch_start = self.current;
        let batch_end = batch_start.saturating_add(self.range_size - 1).min(self.end);
        self.current = batch_end + 1;
        self.batch_count += 1;

        Some(batch_start..=batch_end)
    }

    fn size_hint(&self) -> (usize, Option<usize>) {
        let remaining =
            usize::try_from(self.total_batches - self.batch_count).unwrap_or(usize::MAX);
        (remaining, None)
    }
}

impl Iterator for RangeIterator<Reverse> {
    type Item = RangeInclusive<BlockNumber>;

    fn next(&mut self) -> Option<Self::Item> {
        if self.batch_count >= self.total_batches {
            return None;
        }

        let batch_high = self.current;
        let batch_low = batch_high.saturating_sub(self.range_size - 1).max(self.end);
        self.current = batch_low.saturating_sub(1);
        self.batch_count += 1;

        Some(batch_low..=batch_high)
    }

    fn size_hint(&self) -> (usize, Option<usize>) {
        match usize::try_from(self.total_batches - self.batch_count) {
            Ok(remaining) => (remaining, Some(remaining)),
            Err(_) => (usize::MAX, None),
        }
    }
}
