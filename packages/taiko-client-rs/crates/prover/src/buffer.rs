//! Fixed-size buffer of contiguous single proofs awaiting aggregation.

use std::{
    sync::{Mutex, MutexGuard, PoisonError},
    time::Instant,
};

use thiserror::Error;

use crate::producer::ProofResponse;

/// Buffer-specific failures.
#[derive(Debug, Error, PartialEq, Eq)]
pub enum BufferError {
    /// The buffer is full; the caller defers the proof to the cache.
    #[error("proof buffer overflow")]
    Overflow,
}

/// Mutex-guarded fixed-size proof buffer (Go `ProofBuffer`,
/// `proof_producer/proof_buffer.go:16-23`).
#[derive(Debug)]
pub struct ProofBuffer {
    /// Maximum number of proofs held before aggregation must fire.
    pub max_length: u64,
    /// Interior state guarded by a mutex.
    inner: Mutex<Inner>,
}

/// Mutable buffer state.
#[derive(Debug, Default)]
struct Inner {
    /// Buffered proofs in insertion (ascending proposal id) order.
    buffer: Vec<ProofResponse>,
    /// Time of the last successful insertion.
    last_item_at: Option<Instant>,
    /// Whether an aggregation over this buffer is in flight.
    is_aggregating: bool,
    /// Proposal id of the most recently inserted proof (0 when empty).
    last_insert_id: u64,
}

impl ProofBuffer {
    /// Create a buffer bounded at `max_length` proofs.
    #[must_use]
    pub fn new(max_length: u64) -> Self {
        Self { max_length, inner: Mutex::new(Inner::default()) }
    }

    /// Insert a proof. Duplicate proposal ids are accepted idempotently without
    /// inserting (Go `proof_buffer.go:43-49`); a full buffer overflows (checked
    /// after the duplicate test, like Go). Returns the buffer length after the
    /// call.
    pub fn write(&self, item: ProofResponse) -> Result<usize, BufferError> {
        let mut inner = self.lock();
        if inner.buffer.iter().any(|existing| existing.proposal_id() == item.proposal_id()) {
            return Ok(inner.buffer.len());
        }
        if inner.buffer.len() as u64 >= self.max_length {
            return Err(BufferError::Overflow);
        }
        inner.last_insert_id = item.proposal_id();
        inner.buffer.push(item);
        inner.last_item_at = Some(Instant::now());
        Ok(inner.buffer.len())
    }

    /// Clone out all buffered proofs without draining them.
    #[must_use]
    pub fn read_all(&self) -> Vec<ProofResponse> {
        self.lock().buffer.clone()
    }

    /// Number of buffered proofs.
    #[must_use]
    pub fn len(&self) -> usize {
        self.lock().buffer.len()
    }

    /// True when no proofs are buffered.
    #[must_use]
    pub fn is_empty(&self) -> bool {
        self.len() == 0
    }

    /// Remaining capacity before the buffer overflows.
    #[must_use]
    pub fn available_capacity(&self) -> u64 {
        self.max_length - self.lock().buffer.len() as u64
    }

    /// Time of the last successful insertion (`None` when never written or
    /// after the buffer empties).
    #[must_use]
    pub fn last_item_at(&self) -> Option<Instant> {
        self.lock().last_item_at
    }

    /// Proposal id of the most recent insertion (0 when empty).
    #[must_use]
    pub fn last_insert_id(&self) -> u64 {
        self.lock().last_insert_id
    }

    /// Remove proofs whose proposal id is in `ids`; returns how many were
    /// removed. Always clears the aggregation mark and recomputes
    /// `last_insert_id` from the new tail (Go `proof_buffer.go:108-139`).
    pub fn clear_items(&self, ids: &[u64]) -> usize {
        let mut inner = self.lock();
        let before = inner.buffer.len();
        inner.buffer.retain(|item| !ids.contains(&item.proposal_id()));
        let cleared = before - inner.buffer.len();
        match inner.buffer.last() {
            Some(last) => inner.last_insert_id = last.proposal_id(),
            None => {
                inner.last_insert_id = 0;
                inner.last_item_at = None;
            }
        }
        inner.is_aggregating = false;
        cleared
    }

    /// Mark the buffer as aggregating; returns false when already marked
    /// (Go `proof_buffer.go:142-151`).
    pub fn mark_aggregating_if_not(&self) -> bool {
        let mut inner = self.lock();
        if inner.is_aggregating {
            return false;
        }
        inner.is_aggregating = true;
        true
    }

    /// Whether an aggregation over this buffer is in flight.
    #[must_use]
    pub fn is_aggregating(&self) -> bool {
        self.lock().is_aggregating
    }

    /// Lock the interior state, recovering from poisoning (every mutation here
    /// is single-assignment, so a panicked holder cannot leave partial state).
    fn lock(&self) -> MutexGuard<'_, Inner> {
        self.inner.lock().unwrap_or_else(PoisonError::into_inner)
    }
}

#[cfg(test)]
mod tests {
    use alloy_primitives::{Address, B256, Bytes};

    use super::{BufferError, ProofBuffer};
    use crate::{
        producer::{ProofRequest, ProofResponse},
        raiko::ProofType,
    };

    /// Build a minimal proof response for the given proposal id.
    fn test_response(proposal_id: u64) -> ProofResponse {
        ProofResponse {
            request: ProofRequest {
                proposal_id,
                proposer: Address::repeat_byte(0x11),
                proposal_timestamp: 1_000,
                event_l1_block_number: 42,
                event_l1_block_hash: B256::repeat_byte(0x22),
                prover_address: Address::repeat_byte(0x33),
                l2_block_numbers: vec![100, 101],
                end_block_number: 101,
                end_block_hash: B256::repeat_byte(0x44),
                end_state_root: B256::repeat_byte(0x55),
                last_anchor_block_number: 40,
                geth_proof_generated: false,
                reth_proof_generated: false,
                geth_aggregation_generated: false,
                reth_aggregation_generated: false,
            },
            proof: Bytes::from_static(&[0xff]),
            proof_type: ProofType::Sgx,
        }
    }

    #[test]
    fn write_is_idempotent_per_proposal_id() {
        let buffer = ProofBuffer::new(10);
        assert_eq!(buffer.write(test_response(5)), Ok(1));
        assert_eq!(buffer.write(test_response(5)), Ok(1));
        assert_eq!(buffer.len(), 1);
        assert_eq!(buffer.last_insert_id(), 5);
    }

    #[test]
    fn write_rejects_overflow() {
        let buffer = ProofBuffer::new(2);
        buffer.write(test_response(1)).unwrap();
        buffer.write(test_response(2)).unwrap();
        assert_eq!(buffer.write(test_response(3)), Err(BufferError::Overflow));
        assert_eq!(buffer.len(), 2);
        // A duplicate of an existing id still succeeds on a full buffer
        // (duplicate check precedes the overflow check, Go proof_buffer.go:43-53).
        assert_eq!(buffer.write(test_response(2)), Ok(2));
    }

    #[test]
    fn clear_items_resets_aggregating_and_recomputes_last_insert_id() {
        let buffer = ProofBuffer::new(10);
        for id in [1, 2, 3] {
            buffer.write(test_response(id)).unwrap();
        }
        assert!(buffer.mark_aggregating_if_not());
        assert_eq!(buffer.clear_items(&[3]), 1);
        assert_eq!(buffer.len(), 2);
        assert_eq!(buffer.last_insert_id(), 2);
        assert!(!buffer.is_aggregating());

        // Clearing a middle item keeps the tail as last_insert_id.
        buffer.write(test_response(3)).unwrap();
        assert_eq!(buffer.clear_items(&[2]), 1);
        assert_eq!(buffer.last_insert_id(), 3);

        // Emptying the buffer resets the cursor and timestamp.
        assert_eq!(buffer.clear_items(&[1, 3]), 2);
        assert_eq!(buffer.last_insert_id(), 0);
        assert_eq!(buffer.last_item_at(), None);
        assert!(buffer.is_empty());
    }

    #[test]
    fn mark_aggregating_if_not_returns_false_when_already_marked() {
        let buffer = ProofBuffer::new(2);
        assert!(buffer.mark_aggregating_if_not());
        assert!(!buffer.mark_aggregating_if_not());
        assert!(buffer.is_aggregating());
    }

    #[test]
    fn read_all_clones_without_draining() {
        let buffer = ProofBuffer::new(4);
        buffer.write(test_response(7)).unwrap();
        buffer.write(test_response(8)).unwrap();
        let snapshot = buffer.read_all();
        assert_eq!(snapshot.len(), 2);
        assert_eq!(snapshot[0].proposal_id(), 7);
        assert_eq!(snapshot[1].proposal_id(), 8);
        assert_eq!(buffer.len(), 2);
        assert_eq!(buffer.available_capacity(), 2);
    }
}
