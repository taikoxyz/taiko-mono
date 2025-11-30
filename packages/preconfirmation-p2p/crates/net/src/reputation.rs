//! Peer reputation and rate limiting.
//!
//! Note on upstream reuse: Kona exposes a [`ConnectionGater`] and related structs in
//! `kona_gossip`, but direct reuse is not yet practical here because that implementation pulls
//! in extra deps (`libp2p-stream`, `openssl`) and is coupled to Kona-specific metrics/RPC wiring
//! and libp2p executor assumptions. Once libp2p and dependency versions converge we can revisit
//! a `kona-gater` feature that swaps our lightweight gating for Kona's fuller gate; for now we
//! keep the local, minimal gating to avoid dragging those transitive requirements into
//! taiko-client-rs.

use libp2p::PeerId;
use std::{
    collections::{HashMap, HashSet},
    time::{Duration, Instant},
};

/// Discrete actions that affect peer score.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum PeerAction {
    GossipValid,
    GossipInvalid,
    ReqRespSuccess,
    ReqRespError,
    Timeout,
    DialFailure,
}

pub type PeerScore = f64;

#[derive(Debug, Clone, Copy)]
pub struct PeerReputation {
    score: PeerScore,
    last_updated: Instant,
}

impl PeerReputation {
    pub fn new(now: Instant) -> Self {
        Self { score: 0.0, last_updated: now }
    }

    pub fn score(&self) -> PeerScore {
        self.score
    }
}

#[derive(Debug, Clone, Copy)]
pub struct ReputationConfig {
    /// Score at or below which a peer is greylisted (soft drop).
    pub greylist_threshold: PeerScore,
    /// Score at or below which a peer is banned (hard drop).
    pub ban_threshold: PeerScore,
    /// Exponential decay halflife applied to scores.
    pub halflife: Duration,
}

pub struct PeerReputationStore {
    scores: HashMap<PeerId, PeerReputation>,
    banned: HashSet<PeerId>,
    greylisted: HashSet<PeerId>,
    cfg: ReputationConfig,
}

impl Default for PeerReputationStore {
    fn default() -> Self {
        Self::new(ReputationConfig {
            greylist_threshold: -5.0,
            ban_threshold: -10.0,
            halflife: Duration::from_secs(600),
        })
    }
}

impl PeerReputationStore {
    pub fn new(cfg: ReputationConfig) -> Self {
        Self { scores: HashMap::new(), banned: HashSet::new(), greylisted: HashSet::new(), cfg }
    }

    pub fn apply(&mut self, peer: PeerId, action: PeerAction) -> ReputationEvent {
        let now = Instant::now();
        let was_banned = self.banned.contains(&peer);
        let was_grey = self.greylisted.contains(&peer);
        let entry = self.scores.entry(peer).or_insert_with(|| PeerReputation::new(now));
        // Split borrows: compute new score then update.
        let mut score = entry.score;
        score = Self::decayed(score, entry.last_updated, now, self.cfg.halflife);
        score += action_delta(action);
        entry.score = score;
        entry.last_updated = now;
        self.update_lists(peer, score);
        let is_banned = self.banned.contains(&peer);
        let is_greylisted = self.greylisted.contains(&peer);
        ReputationEvent {
            peer,
            new_score: score,
            action,
            is_banned,
            is_greylisted,
            was_banned,
            was_greylisted: was_grey,
        }
    }

    pub fn is_banned(&self, peer: &PeerId) -> bool {
        self.banned.contains(peer)
    }

    #[allow(dead_code)]
    pub fn is_greylisted(&self, peer: &PeerId) -> bool {
        self.greylisted.contains(peer)
    }

    #[allow(dead_code)]
    pub fn score_of(&self, peer: &PeerId) -> Option<PeerScore> {
        self.scores.get(peer).map(|p| p.score)
    }

    fn decayed(score: PeerScore, last: Instant, now: Instant, halflife: Duration) -> PeerScore {
        let dt = now.saturating_duration_since(last).as_secs_f64();
        if dt == 0.0 {
            return score;
        }
        let lambda = std::f64::consts::LN_2 / halflife.as_secs_f64().max(1.0);
        score * (-lambda * dt).exp()
    }

    fn update_lists(&mut self, peer: PeerId, score: PeerScore) {
        if score <= self.cfg.ban_threshold {
            self.banned.insert(peer);
            self.greylisted.remove(&peer);
        } else if score <= self.cfg.greylist_threshold {
            self.greylisted.insert(peer);
            self.banned.remove(&peer);
        } else {
            self.greylisted.remove(&peer);
            self.banned.remove(&peer);
        }
    }
}

#[derive(Debug, Clone)]
pub struct ReputationEvent {
    pub peer: PeerId,
    pub new_score: PeerScore,
    pub action: PeerAction,
    pub is_banned: bool,
    pub is_greylisted: bool,
    pub was_banned: bool,
    pub was_greylisted: bool,
}

fn action_delta(action: PeerAction) -> PeerScore {
    match action {
        PeerAction::GossipValid | PeerAction::ReqRespSuccess => 1.0,
        PeerAction::GossipInvalid | PeerAction::ReqRespError => -2.0,
        PeerAction::Timeout => -0.5,
        PeerAction::DialFailure => -1.0,
    }
}

#[allow(dead_code)]
pub(crate) fn decayed(
    score: PeerScore,
    last: Instant,
    now: Instant,
    halflife: Duration,
) -> PeerScore {
    let dt = now.saturating_duration_since(last).as_secs_f64();
    if dt == 0.0 {
        return score;
    }
    let lambda = std::f64::consts::LN_2 / halflife.as_secs_f64().max(1.0);
    score * (-lambda * dt).exp()
}

/// Sliding-window request limiter per peer.
#[derive(Default)]
pub struct RequestRateLimiter {
    window: Duration,
    max_requests: u32,
    state: HashMap<PeerId, (Instant, u32)>,
}

impl RequestRateLimiter {
    pub fn new(window: Duration, max_requests: u32) -> Self {
        Self { window, max_requests, state: HashMap::new() }
    }

    /// Returns true if the request is allowed; false if rate limited.
    pub fn allow(&mut self, peer: PeerId, now: Instant) -> bool {
        let entry = self.state.entry(peer).or_insert((now, 0));
        let (start, count) = entry;
        if now.duration_since(*start) >= self.window {
            *start = now;
            *count = 0;
        }
        if *count >= self.max_requests {
            return false;
        }
        *count += 1;
        true
    }
}

// Defaults for rate limiting
#[allow(dead_code)]
pub const REQUEST_WINDOW: Duration = Duration::from_secs(10);
#[allow(dead_code)]
pub const MAX_REQUESTS_PER_WINDOW: u32 = 8;

/// Pluggable scoring/gating backend used by the network driver. Implement this to delegate
/// scoring, bans, and optional dial gating to a custom engine without changing public APIs.
#[allow(dead_code)]
pub trait ReputationBackend: Send {
    /// Apply an action and return the resulting event (with score delta and ban flags).
    fn apply(&mut self, peer: PeerId, action: PeerAction) -> ReputationEvent;
    /// True if the peer is currently banned.
    fn is_banned(&self, peer: &PeerId) -> bool;
    /// Optional dial gating hook; defaults to banning check. Override to enforce subnet/IP rules
    /// or external allow/deny lists.
    fn allow_dial(&mut self, peer: &PeerId, _addr: Option<&libp2p::Multiaddr>) -> bool {
        !self.is_banned(peer)
    }
}

impl ReputationBackend for PeerReputationStore {
    fn apply(&mut self, peer: PeerId, action: PeerAction) -> ReputationEvent {
        PeerReputationStore::apply(self, peer, action)
    }

    fn is_banned(&self, peer: &PeerId) -> bool {
        PeerReputationStore::is_banned(self, peer)
    }
}

/// Optional reth-network-peers adapter surface. When the `reth-peers` feature is enabled we expose
/// peer/node record types from reth so downstreams can bridge libp2p `PeerId` to reth’s peer
/// representation. This keeps reuse opt-in without changing our public API.
#[cfg(feature = "reth-peers")]
pub mod reth_adapter {
    use super::*;

    /// Reth peer identifier type (B512-backed).
    pub type RethPeerId = reth_network_peers::PeerId;
    /// Reth node record type (IP + ports + id).
    #[allow(dead_code)]
    pub type RethNodeRecord = reth_network_peers::NodeRecord;

    /// Convert a libp2p `PeerId` (multihash) into an optional reth peer id by extracting the
    /// multihash digest. Returns `None` if the digest is not 64 bytes (reth expects 512-bit keys).
    #[allow(dead_code)]
    pub fn libp2p_to_reth(peer: &libp2p::PeerId) -> Option<RethPeerId> {
        let digest = peer.as_ref().digest();
        let bytes = digest;
        if bytes.len() != 64 {
            return None;
        }
        Some(RethPeerId::from_slice(bytes))
    }

    /// Reth-flavoured reputation backend: stores scores keyed by reth `PeerId` while mirroring ban
    /// state onto libp2p `PeerId`s for gating. The upstream `reth-network-peers` crate currently
    /// exposes peer identity/records but no scoring model, so we reuse the local decay/threshold
    /// logic and only swap the key type; if conversion fails we fall back to the local store to
    /// preserve behaviour.
    pub struct RethReputationAdapter {
        inner: PeerReputationStore,
        reth_scores: HashMap<RethPeerId, PeerReputation>,
        banned_l2p: HashSet<PeerId>,
        cfg: ReputationConfig,
    }

    impl RethReputationAdapter {
        pub fn new(cfg: ReputationConfig) -> Self {
            Self {
                inner: PeerReputationStore::new(cfg),
                reth_scores: HashMap::new(),
                banned_l2p: HashSet::new(),
                cfg,
            }
        }

        fn apply_reth(
            &mut self,
            peer: PeerId,
            rid: RethPeerId,
            action: PeerAction,
        ) -> ReputationEvent {
            let now = Instant::now();
            let entry = self.reth_scores.entry(rid).or_insert_with(|| PeerReputation::new(now));
            let mut score = entry.score;
            score = super::decayed(score, entry.last_updated, now, self.cfg.halflife);
            score += super::action_delta(action);
            entry.score = score;
            entry.last_updated = now;

            let was_banned = self.banned_l2p.contains(&peer);
            let mut is_banned = was_banned;
            let mut is_greylisted = false;
            if score <= self.cfg.ban_threshold {
                self.banned_l2p.insert(peer);
                is_banned = true;
            } else if score <= self.cfg.greylist_threshold {
                is_greylisted = true;
                self.banned_l2p.remove(&peer);
            } else {
                self.banned_l2p.remove(&peer);
            }

            ReputationEvent {
                peer,
                new_score: score,
                action,
                is_banned,
                is_greylisted,
                was_banned,
                was_greylisted: false,
            }
        }
    }

    impl ReputationBackend for RethReputationAdapter {
        fn apply(&mut self, peer: PeerId, action: PeerAction) -> ReputationEvent {
            if let Some(rid) = libp2p_to_reth(&peer) {
                self.apply_reth(peer, rid, action)
            } else {
                self.inner.apply(peer, action)
            }
        }

        fn is_banned(&self, peer: &PeerId) -> bool {
            if self.banned_l2p.contains(peer) {
                return true;
            }
            self.inner.is_banned(peer)
        }
    }
}
