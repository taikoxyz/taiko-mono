//! Parent-indexed pending envelope state for whitelist preconfirmation import.

use std::{
    collections::{HashMap, HashSet, VecDeque},
    sync::Arc,
    time::{Duration, Instant},
};

use alloy_primitives::B256;
use hashlink::LinkedHashMap;

use crate::codec::WhitelistExecutionPayloadEnvelope;

/// Default maximum number of pending envelopes retained while waiting for parent availability.
const DEFAULT_PENDING_ENVELOPE_CAPACITY: usize = 768;
/// Default maximum number of recent envelopes retained for request/response serving.
const DEFAULT_RECENT_ENVELOPE_CAPACITY: usize = 1024;
/// Default cooldown, in seconds, between duplicate missing-parent requests.
const DEFAULT_REQUEST_COOLDOWN_SECS: u64 = 10;

/// Parent-indexed pending graph plus recent-response cache and request cooldown tracking.
#[derive(Debug)]
pub(crate) struct PendingEnvelopeGraph {
    /// Pending envelopes keyed by payload block hash.
    by_hash: LinkedHashMap<B256, Arc<WhitelistExecutionPayloadEnvelope>>,
    /// Child payload hashes keyed by their declared parent hash.
    children_by_parent: HashMap<B256, Vec<B256>>,
    /// Recently accepted envelopes retained for gossip request/response serving.
    recent: LinkedHashMap<B256, Arc<WhitelistExecutionPayloadEnvelope>>,
    /// FIFO queue of pending hashes that should be reconsidered for import.
    ready_queue: VecDeque<B256>,
    /// Deduplicates hashes already staged in [`Self::ready_queue`].
    ready_set: HashSet<B256>,
    /// Minimum time between repeated requests for the same missing parent hash.
    request_cooldown: Duration,
    /// Timestamp of the most recent request per missing parent hash.
    requested_at: HashMap<B256, Instant>,
    /// Maximum number of pending envelopes to retain.
    pending_capacity: usize,
    /// Maximum number of recent envelopes to retain.
    recent_capacity: usize,
}

impl Default for PendingEnvelopeGraph {
    /// Build a pending graph using the standard bounded capacities and request cooldown.
    fn default() -> Self {
        Self::new(
            DEFAULT_PENDING_ENVELOPE_CAPACITY,
            DEFAULT_RECENT_ENVELOPE_CAPACITY,
            Duration::from_secs(DEFAULT_REQUEST_COOLDOWN_SECS),
        )
    }
}

impl PendingEnvelopeGraph {
    /// Construct a pending graph with explicit capacities and request cooldown.
    pub(crate) fn new(
        pending_capacity: usize,
        recent_capacity: usize,
        request_cooldown: Duration,
    ) -> Self {
        Self {
            by_hash: LinkedHashMap::new(),
            children_by_parent: HashMap::new(),
            recent: LinkedHashMap::new(),
            ready_queue: VecDeque::new(),
            ready_set: HashSet::new(),
            request_cooldown,
            requested_at: HashMap::new(),
            pending_capacity: pending_capacity.max(1),
            recent_capacity: recent_capacity.max(1),
        }
    }

    /// Insert or refresh a pending envelope and stage it for import evaluation.
    pub(crate) fn insert(&mut self, envelope: Arc<WhitelistExecutionPayloadEnvelope>) {
        let hash = envelope.execution_payload.block_hash;
        let parent_hash = envelope.execution_payload.parent_hash;

        if let Some(previous) = self.by_hash.remove(&hash) {
            self.detach_child(previous.execution_payload.parent_hash, hash);
        }

        self.by_hash.insert(hash, envelope.clone());
        self.attach_child(parent_hash, hash);
        self.insert_recent(envelope);
        self.enqueue(hash);
        self.evict_oldest_pending();
    }

    /// Return a pending envelope by block hash, if it is still retained.
    pub(crate) fn get(&self, hash: &B256) -> Option<Arc<WhitelistExecutionPayloadEnvelope>> {
        self.by_hash.get(hash).cloned()
    }

    /// Remove a pending envelope by block hash and detach its parent/child bookkeeping.
    pub(crate) fn remove(&mut self, hash: &B256) -> Option<Arc<WhitelistExecutionPayloadEnvelope>> {
        let envelope = self.by_hash.remove(hash)?;
        self.detach_child(envelope.execution_payload.parent_hash, *hash);
        self.ready_set.remove(hash);
        Some(envelope)
    }

    /// Queue a pending hash for reconsideration if it is still retained.
    pub(crate) fn enqueue(&mut self, hash: B256) {
        if self.by_hash.contains_key(&hash) && self.ready_set.insert(hash) {
            self.ready_queue.push_back(hash);
        }
    }

    /// Queue multiple pending hashes for reconsideration.
    pub(crate) fn enqueue_many<I>(&mut self, hashes: I)
    where
        I: IntoIterator<Item = B256>,
    {
        for hash in hashes {
            self.enqueue(hash);
        }
    }

    /// Queue all currently pending children of the imported parent hash.
    pub(crate) fn enqueue_children(&mut self, parent_hash: B256) {
        let children = self.children_by_parent.get(&parent_hash).cloned().unwrap_or_default();
        for child_hash in children {
            self.enqueue(child_hash);
        }
    }

    /// Pop the next pending hash staged for import reconsideration.
    pub(crate) fn pop_ready(&mut self) -> Option<B256> {
        while let Some(hash) = self.ready_queue.pop_front() {
            self.ready_set.remove(&hash);
            if self.by_hash.contains_key(&hash) {
                return Some(hash);
            }
        }
        None
    }

    /// Return a recent envelope by block hash for request/response serving.
    pub(crate) fn get_recent(&self, hash: &B256) -> Option<Arc<WhitelistExecutionPayloadEnvelope>> {
        self.recent.get(hash).cloned()
    }

    /// Insert or refresh an envelope in the recent-response cache without affecting pending state.
    pub(crate) fn insert_recent_only(&mut self, envelope: Arc<WhitelistExecutionPayloadEnvelope>) {
        self.insert_recent(envelope);
    }

    /// Return `true` when the given parent hash may be requested now, then record the request.
    pub(crate) fn should_request_parent(&mut self, hash: B256, now: Instant) -> bool {
        self.prune_expired_requests(now);

        match self.requested_at.get(&hash) {
            Some(last_request)
                if now.saturating_duration_since(*last_request) < self.request_cooldown =>
            {
                false
            }
            _ => {
                self.requested_at.insert(hash, now);
                true
            }
        }
    }

    /// Return `true` when no pending envelopes remain.
    pub(crate) fn is_empty(&self) -> bool {
        self.by_hash.is_empty()
    }

    /// Return the number of pending envelopes currently retained.
    pub(crate) fn pending_len(&self) -> usize {
        self.by_hash.len()
    }

    /// Return the number of recent envelopes currently retained.
    pub(crate) fn recent_len(&self) -> usize {
        self.recent.len()
    }

    /// Insert or refresh a recent envelope entry.
    fn insert_recent(&mut self, envelope: Arc<WhitelistExecutionPayloadEnvelope>) {
        let hash = envelope.execution_payload.block_hash;
        self.recent.remove(&hash);
        self.recent.insert(hash, envelope);
        while self.recent.len() > self.recent_capacity {
            let _ = self.recent.pop_front();
        }
    }

    /// Record that `child_hash` currently waits on `parent_hash`.
    fn attach_child(&mut self, parent_hash: B256, child_hash: B256) {
        let children = self.children_by_parent.entry(parent_hash).or_default();
        if !children.contains(&child_hash) {
            children.push(child_hash);
        }
    }

    /// Remove the `parent_hash -> child_hash` edge if it still exists.
    fn detach_child(&mut self, parent_hash: B256, child_hash: B256) {
        let mut remove_parent = false;
        if let Some(children) = self.children_by_parent.get_mut(&parent_hash) {
            children.retain(|hash| *hash != child_hash);
            remove_parent = children.is_empty();
        }

        if remove_parent {
            self.children_by_parent.remove(&parent_hash);
        }
    }

    /// Evict oldest pending envelopes until the configured capacity is satisfied.
    fn evict_oldest_pending(&mut self) {
        while self.by_hash.len() > self.pending_capacity {
            if let Some((hash, envelope)) = self.by_hash.pop_front() {
                self.detach_child(envelope.execution_payload.parent_hash, hash);
                self.ready_set.remove(&hash);
            }
        }
    }

    /// Drop parent-request timestamps whose cooldown window has already elapsed.
    fn prune_expired_requests(&mut self, now: Instant) {
        let cooldown = self.request_cooldown;
        self.requested_at
            .retain(|_, last_request| now.saturating_duration_since(*last_request) < cooldown);
    }
}
