//! Peer reputation and rate limiting.
//!
//! This module provides mechanisms for scoring and managing the reputation of peers
//! in the preconfirmation P2P network. It includes:
//! - `PeerAction`: Discrete events that influence a peer's score.
//! - `RequestRateLimiter`: Prevents individual peers from overwhelming the service with requests.
//! - `ReputationBackend` trait: Allows for pluggable reputation systems.
//! - `RethReputationAdapter`: Sole backend, reusing reth reputation weights/thresholds and
//!   mirroring ban/greylist state to libp2p `PeerId`s.
//!
//! The Kona connection gater from `kona_gossip` is used for low-level connection
//! management, while this module focuses on application-level reputation.

use libp2p::PeerId;
use reth_network_types::peers::reputation::{BANNED_REPUTATION, ReputationChangeWeights};
use std::{
    collections::{HashMap, HashSet},
    time::{Duration, Instant},
};

/// Discrete actions that affect peer score.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum PeerAction {
    /// Peer provided a valid gossip message.
    GossipValid,
    /// Peer provided an invalid gossip message.
    GossipInvalid,
    /// Peer responded successfully to a request.
    ReqRespSuccess,
    /// Peer responded with an error or invalid response to a request.
    ReqRespError,
    /// A request to the peer timed out.
    Timeout,
    /// A dial attempt to the peer failed.
    DialFailure,
}

pub type PeerScore = f64;
const DEFAULT_BAN_THRESHOLD: PeerScore = BANNED_REPUTATION as PeerScore;
const DEFAULT_GREYLIST_THRESHOLD: PeerScore = DEFAULT_BAN_THRESHOLD / 2.0;
const SUCCESS_REWARD: PeerScore = 1.0;

/// Represents the current reputation score of a peer.
#[derive(Debug, Clone)]
pub struct PeerReputation {
    /// The numerical score of the peer. Higher is better.
    score: PeerScore,
    /// The last `Instant` at which the score was updated. Used for decay calculation.
    last_updated: Instant,
}

impl PeerReputation {
    /// Creates a new `PeerReputation` with a default score of 0.0 at the given `now` timestamp.
    ///
    /// # Arguments
    ///
    /// * `now` - The current `Instant`.
    ///
    /// # Returns
    ///
    /// A new `PeerReputation` instance.
    pub fn new(now: Instant) -> Self {
        Self { score: 0.0, last_updated: now }
    }

    /// Returns the current score of the peer.
    pub fn score(&self) -> PeerScore {
        self.score
    }
}

/// Configuration for the peer reputation system.
#[derive(Debug, Clone)]
pub struct ReputationConfig {
    /// Score at or below which a peer is greylisted (soft drop).
    pub greylist_threshold: PeerScore,
    /// Score at or below which a peer is banned (hard drop).
    pub ban_threshold: PeerScore,
    /// Exponential decay halflife applied to scores. Scores decay towards zero.
    pub halflife: Duration,
    /// Weights mapping actions into reputation deltas (reth defaults).
    pub weights: ReputationChangeWeights,
}

/// Stores and manages the reputation of peers.
///
/// This struct keeps track of individual peer scores, applies actions to update
/// these scores, and maintains lists of banned and greylisted peers.
pub(crate) struct PeerReputationStore {
    /// Mapping of `PeerId` to their `PeerReputation`.
    scores: HashMap<PeerId, PeerReputation>,
    /// Set of `PeerId`s that are currently banned.
    banned: HashSet<PeerId>,
    /// Set of `PeerId`s that are currently greylisted.
    greylisted: HashSet<PeerId>,
    /// Configuration for reputation thresholds and decay.
    cfg: ReputationConfig,
}

impl Default for PeerReputationStore {
    fn default() -> Self {
        Self::new(ReputationConfig {
            greylist_threshold: DEFAULT_GREYLIST_THRESHOLD,
            ban_threshold: DEFAULT_BAN_THRESHOLD,
            halflife: Duration::from_secs(600),
            weights: ReputationChangeWeights::default(),
        })
    }
}

impl PeerReputationStore {
    /// Creates a new `PeerReputationStore` with the given configuration.
    ///
    /// # Arguments
    ///
    /// * `cfg` - The `ReputationConfig` to use.
    ///
    /// # Returns
    ///
    /// A new `PeerReputationStore` instance.
    pub fn new(cfg: ReputationConfig) -> Self {
        Self { scores: HashMap::new(), banned: HashSet::new(), greylisted: HashSet::new(), cfg }
    }

    /// Applies a `PeerAction` to a specific peer, updating its score and ban status.
    ///
    /// This is the primary method for updating a peer's reputation. It calculates
    /// score decay, applies the action delta, and then updates the internal
    /// banned/greylisted sets.
    ///
    /// # Arguments
    ///
    /// * `peer` - The `PeerId` of the peer to apply the action to.
    /// * `action` - The `PeerAction` to apply.
    ///
    /// # Returns
    ///
    /// A `ReputationEvent` describing the outcome of the action.
    pub fn apply(&mut self, peer: PeerId, action: PeerAction) -> ReputationEvent {
        let now = Instant::now();
        let was_banned = self.banned.contains(&peer);
        let was_grey = self.greylisted.contains(&peer);
        let entry = self.scores.entry(peer).or_insert_with(|| PeerReputation::new(now));
        // Split borrows: compute new score then update.
        // Decay ensures older infractions fade so recent behavior dominates decisions.
        let mut score = entry.score;
        score = Self::decayed(score, entry.last_updated, now, self.cfg.halflife);
        score += action_delta(action, &self.cfg.weights);
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

    /// Checks if a peer is currently banned.
    ///
    /// # Arguments
    ///
    /// * `peer` - A reference to the `PeerId` to check.
    ///
    /// # Returns
    ///
    /// `true` if the peer is banned, `false` otherwise.
    pub fn is_banned(&self, peer: &PeerId) -> bool {
        self.banned.contains(peer)
    }

    /// Calculates the decayed score of a peer.
    ///
    /// Applies an exponential decay to the score based on the time elapsed
    /// since the last update and the configured halflife.
    ///
    /// # Arguments
    ///
    /// * `score` - The current raw score.
    /// * `last` - The `Instant` of the last score update.
    /// * `now` - The current `Instant`.
    /// * `halflife` - The `Duration` representing the decay halflife.
    ///
    /// # Returns
    ///
    /// The decayed `PeerScore`.
    fn decayed(score: PeerScore, last: Instant, now: Instant, halflife: Duration) -> PeerScore {
        let dt = now.saturating_duration_since(last).as_secs_f64();
        if dt == 0.0 {
            return score;
        }
        let lambda = std::f64::consts::LN_2 / halflife.as_secs_f64().max(1.0);
        score * (-lambda * dt).exp()
    }

    /// Updates the internal banned and greylisted sets based on the peer's score.
    ///
    /// # Arguments
    ///
    /// * `peer` - The `PeerId` of the peer to update.
    /// * `score` - The peer's current score.
    fn update_lists(&mut self, peer: PeerId, score: PeerScore) {
        if score <= self.cfg.ban_threshold {
            // Ban takes precedence: ensure greylist entry is cleared to avoid conflicting states.
            self.banned.insert(peer);
            self.greylisted.remove(&peer);
        } else if score <= self.cfg.greylist_threshold {
            // Greylist allows recovery via decay while still throttling interaction.
            self.greylisted.insert(peer);
            self.banned.remove(&peer);
        } else {
            // Score healed: clear any prior penalties so the peer can fully participate again.
            self.greylisted.remove(&peer);
            self.banned.remove(&peer);
        }
    }
}

#[derive(Debug, Clone)]
/// Represents an event generated by the reputation system after an action is applied.
pub struct ReputationEvent {
    /// The `PeerId` of the peer affected by the action.
    pub peer: PeerId,
    /// The peer's new score after the action and decay.
    pub new_score: PeerScore,
    /// The `PeerAction` that was applied.
    pub action: PeerAction,
    /// `true` if the peer is currently banned after this event.
    pub is_banned: bool,
    /// `true` if the peer is currently greylisted after this event.
    pub is_greylisted: bool,
    /// `true` if the peer was banned *before* this event.
    pub was_banned: bool,
    /// `true` if the peer was greylisted *before* this event.
    pub was_greylisted: bool,
}

fn action_delta(action: PeerAction, weights: &ReputationChangeWeights) -> PeerScore {
    match action {
        // Gossip scoring is handled by Kona gossipsub; ignore locally to avoid double-counting.
        PeerAction::GossipValid | PeerAction::GossipInvalid => 0.0,
        // Reward successful RPCs modestly so decay can heal peers.
        PeerAction::ReqRespSuccess => SUCCESS_REWARD,
        PeerAction::ReqRespError => weights
            .change(reth_network_types::peers::reputation::ReputationChangeKind::BadMessage)
            .as_i32() as PeerScore,
        PeerAction::Timeout => weights
            .change(reth_network_types::peers::reputation::ReputationChangeKind::Timeout)
            .as_i32() as PeerScore,
        PeerAction::DialFailure => weights
            .change(reth_network_types::peers::reputation::ReputationChangeKind::FailedToConnect)
            .as_i32() as PeerScore,
    }
}

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

/// Request/response rate limiter built on reth's `RateLimit` (token bucket, per peer/protocol).
pub struct RequestRateLimiter {
    rate: reth_tokio_util::ratelimit::Rate,
    horizon: tokio::time::Duration,
    // (peer, protocol) -> limiter state
    state: HashMap<(PeerId, ReqRespKind), LimiterState>,
}

#[derive(Debug)]
struct LimiterState {
    limiter: reth_tokio_util::ratelimit::RateLimit,
    last_used: tokio::time::Instant,
}

/// Req/resp protocol kind used for per-protocol buckets.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum ReqRespKind {
    Commitments,
    RawTxList,
    Head,
}

impl RequestRateLimiter {
    /// Creates a new `RequestRateLimiter` with a specified period and max requests.
    pub fn new(window: Duration, max_requests: u32) -> Self {
        debug_assert!(window > Duration::ZERO, "RequestRateLimiter window must be > 0");
        debug_assert!(max_requests > 0, "RequestRateLimiter max_requests must be > 0");
        let rate = reth_tokio_util::ratelimit::Rate::new(max_requests as u64, window);
        let horizon = window * 4;
        Self { rate, horizon, state: HashMap::new() }
    }

    fn evict_idle(&mut self, now: tokio::time::Instant) {
        self.state.retain(|_, entry| now.saturating_duration_since(entry.last_used) < self.horizon);
    }

    /// Polls whether a request is allowed for the given peer/protocol.
    ///
    /// Returns `Poll::Ready(true)` when the request can proceed, `Poll::Ready(false)` when it
    /// should be dropped as rate-limited, and `Poll::Pending` while waiting for the bucket to
    /// refill (callers typically treat `Pending` as limited to avoid blocking the driver).
    pub fn poll_allow(
        &mut self,
        peer: PeerId,
        kind: ReqRespKind,
        cx: &mut std::task::Context<'_>,
    ) -> std::task::Poll<bool> {
        let now = tokio::time::Instant::now();
        self.evict_idle(now);

        let entry = self.state.entry((peer, kind)).or_insert_with(|| LimiterState {
            limiter: reth_tokio_util::ratelimit::RateLimit::new(self.rate),
            last_used: now,
        });
        entry.last_used = now;

        match entry.limiter.poll_ready(cx) {
            std::task::Poll::Ready(()) => {
                entry.limiter.tick();
                std::task::Poll::Ready(true)
            }
            std::task::Poll::Pending => std::task::Poll::Pending,
        }
    }
}

/// Pluggable scoring/gating backend used by the network driver.
///
/// Implement this trait to delegate scoring, bans, and optional dial gating
/// to a custom engine without changing public APIs.
pub trait ReputationBackend: Send {
    /// Applies an action to a peer and returns the resulting `ReputationEvent`.
    ///
    /// # Arguments
    ///
    /// * `peer` - The `PeerId` of the peer.
    /// * `action` - The `PeerAction` to apply.
    ///
    /// # Returns
    ///
    /// A `ReputationEvent` describing the outcome.
    fn apply(&mut self, peer: PeerId, action: PeerAction) -> ReputationEvent;

    /// Checks if a peer is currently banned.
    ///
    /// # Arguments
    ///
    /// * `peer` - A reference to the `PeerId` to check.
    ///
    /// # Returns
    ///
    /// `true` if the peer is banned, `false` otherwise.
    fn is_banned(&self, peer: &PeerId) -> bool;

    /// Optional dial gating hook; defaults to checking if the peer is banned.
    ///
    /// Override this method to enforce subnet/IP rules or external allow/deny lists.
    ///
    /// # Arguments
    ///
    /// * `peer` - A reference to the `PeerId` of the peer to dial.
    /// * `_addr` - An optional `Multiaddr` of the peer.
    ///
    /// # Returns
    ///
    /// `true` if the dial is allowed, `false` otherwise.
    fn allow_dial(&mut self, peer: &PeerId, _addr: Option<&libp2p::Multiaddr>) -> bool {
        !self.is_banned(peer)
    }
}

/// Reth-network-peers adapter surface.
///
/// This module provides an adapter to integrate the reputation system with
/// `reth-network-peers`, allowing the use of reth's peer identifiers and
/// node records while retaining the local scoring logic.
pub mod reth_adapter {
    use super::*;

    /// Reth peer identifier type (B512-backed).
    pub type RethPeerId = reth_network_peers::PeerId;
    /// Converts a libp2p `PeerId` (multihash) into an optional reth peer id.
    ///
    /// This conversion extracts the multihash digest. It returns `None` if the digest
    /// is not 64 bytes, as reth expects 512-bit keys.
    ///
    /// # Arguments
    ///
    /// * `peer` - A reference to the libp2p `PeerId`.
    ///
    /// # Returns
    ///
    /// An `Option<RethPeerId>` containing the reth peer ID if conversion is successful,
    /// otherwise `None`.
    pub fn libp2p_to_reth(peer: &libp2p::PeerId) -> Option<RethPeerId> {
        let digest = peer.as_ref().digest();
        let bytes = digest;
        if bytes.len() != 64 {
            return None;
        }
        Some(RethPeerId::from_slice(bytes))
    }

    /// Reth-flavoured reputation backend.
    ///
    /// This adapter stores scores keyed by reth `PeerId` while mirroring ban
    /// state onto libp2p `PeerId`s for gating. It reuses the local decay/threshold
    /// logic. If conversion to `RethPeerId` fails, it falls back to the inner
    /// `PeerReputationStore` to preserve behaviour.
    pub struct RethReputationAdapter {
        /// The inner `PeerReputationStore` used as a fallback.
        inner: PeerReputationStore,
        /// Stores scores keyed by `RethPeerId`.
        reth_scores: HashMap<RethPeerId, PeerReputation>,
        /// A set of libp2p `PeerId`s that are currently banned.
        banned_l2p: HashSet<PeerId>,
        /// Configuration for reputation thresholds and decay.
        cfg: ReputationConfig,
    }

    impl RethReputationAdapter {
        /// Creates a new `RethReputationAdapter` with the given configuration.
        ///
        /// # Arguments
        ///
        /// * `cfg` - The `ReputationConfig` to use.
        ///
        /// # Returns
        ///
        /// A new `RethReputationAdapter` instance.
        pub fn new(cfg: ReputationConfig) -> Self {
            let inner_cfg = cfg.clone();
            Self {
                inner: PeerReputationStore::new(inner_cfg),
                reth_scores: HashMap::new(),
                banned_l2p: HashSet::new(),
                cfg,
            }
        }

        /// Applies a `PeerAction` to a reth peer ID, updating its score and ban status.
        ///
        /// # Arguments
        ///
        /// * `peer` - The libp2p `PeerId` associated with the reth peer.
        /// * `rid` - The `RethPeerId` of the peer.
        /// * `action` - The `PeerAction` to apply.
        ///
        /// # Returns
        ///
        /// A `ReputationEvent` describing the outcome of the action.
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
            score += super::action_delta(action, &self.cfg.weights);
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

        #[cfg(test)]
        pub(crate) fn apply_reth_for_test(
            &mut self,
            peer: PeerId,
            rid: RethPeerId,
            action: PeerAction,
        ) -> ReputationEvent {
            self.apply_reth(peer, rid, action)
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

#[cfg(test)]
mod tests {
    use super::*;
    use futures::future::poll_fn;
    use libp2p::{PeerId, identity};
    use std::task::Poll;

    fn cfg() -> ReputationConfig {
        ReputationConfig {
            greylist_threshold: DEFAULT_GREYLIST_THRESHOLD,
            ban_threshold: DEFAULT_BAN_THRESHOLD,
            halflife: Duration::from_secs(600),
            weights: ReputationChangeWeights::default(),
        }
    }

    #[test]
    fn peer_store_reaches_ban_threshold() {
        let mut adapter = reth_adapter::RethReputationAdapter::new(cfg());
        let peer = PeerId::random();
        for _ in 0..20 {
            let ev = adapter.apply(peer, PeerAction::ReqRespError);
            if ev.is_banned {
                assert!(adapter.is_banned(&peer));
                return;
            }
        }
        panic!("peer was not banned after repeated errors");
    }

    #[test]
    fn reth_adapter_falls_back_when_conversion_fails() {
        let mut adapter = reth_adapter::RethReputationAdapter::new(cfg());
        let peer = identity::Keypair::generate_ed25519().public().to_peer_id();
        // Conversion fails -> falls back to inner store; ban after repeated errors.
        for _ in 0..20 {
            let ev = adapter.apply(peer, PeerAction::ReqRespError);
            if ev.is_banned {
                break;
            }
        }
        assert!(adapter.is_banned(&peer));
    }

    #[test]
    fn reth_adapter_uses_reth_key_when_convertible() {
        // Directly exercise the reth-keyed path by applying with an explicit reth peer id.
        let cfg = ReputationConfig {
            greylist_threshold: DEFAULT_GREYLIST_THRESHOLD,
            ban_threshold: DEFAULT_BAN_THRESHOLD,
            halflife: Duration::from_secs(600),
            weights: ReputationChangeWeights::default(),
        };
        let mut adapter = reth_adapter::RethReputationAdapter::new(cfg);
        let rid = reth_adapter::RethPeerId::from_slice(&[0u8; 64]);
        let peer = PeerId::random();

        let mut banned = false;
        for _ in 0..20 {
            let ev = adapter.apply_reth_for_test(peer, rid, PeerAction::ReqRespError);
            if ev.is_banned || adapter.is_banned(&peer) {
                banned = true;
                break;
            }
        }
        assert!(banned, "reth-keyed path should ban and mirror to libp2p");
    }

    #[test]
    fn decay_heals_greylist_over_time() {
        // Start well below greylist and ensure decay moves score toward zero.
        let score = -5.0;
        let last = Instant::now() - Duration::from_secs(600);
        let halflife = Duration::from_secs(60);
        let healed = decayed(score, last, Instant::now(), halflife);
        assert!(healed > score, "decay should move score toward zero");
        assert!(healed > -1.0, "should clear greylist over long decay period");
    }

    #[test]
    fn allow_dial_respects_ban() {
        let mut adapter = reth_adapter::RethReputationAdapter::new(cfg());
        let peer = PeerId::random();
        // Fresh peer allowed.
        assert!(adapter.allow_dial(&peer, None));
        // Ban via repeated errors.
        for _ in 0..20 {
            let ev = adapter.apply(peer, PeerAction::ReqRespError);
            if ev.is_banned {
                break;
            }
        }
        assert!(!adapter.allow_dial(&peer, None));
    }

    #[tokio::test]
    async fn request_rate_limiter_under_and_over_limit() {
        let mut rl = RequestRateLimiter::new(Duration::from_secs(1), 2);
        let peer = PeerId::random();

        for _ in 0..2 {
            poll_fn(|cx| {
                assert!(matches!(
                    rl.poll_allow(peer, ReqRespKind::Commitments, cx),
                    Poll::Ready(true)
                ));
                Poll::Ready(())
            })
            .await;
        }

        poll_fn(|cx| match rl.poll_allow(peer, ReqRespKind::Commitments, cx) {
            Poll::Ready(true) => panic!("should be limited"),
            Poll::Ready(false) | Poll::Pending => Poll::Ready(()),
        })
        .await;

        tokio::time::sleep(Duration::from_secs(1)).await;

        poll_fn(|cx| {
            assert!(matches!(rl.poll_allow(peer, ReqRespKind::Commitments, cx), Poll::Ready(true)));
            Poll::Ready(())
        })
        .await;
    }

    #[tokio::test]
    async fn request_rate_limiter_is_per_peer() {
        let mut rl = RequestRateLimiter::new(Duration::from_secs(5), 1);
        let a = PeerId::random();
        let b = PeerId::random();

        poll_fn(|cx| {
            assert!(matches!(rl.poll_allow(a, ReqRespKind::RawTxList, cx), Poll::Ready(true)));
            Poll::Ready(())
        })
        .await;

        poll_fn(|cx| match rl.poll_allow(a, ReqRespKind::RawTxList, cx) {
            Poll::Ready(true) => panic!("peer a should be limited"),
            _ => Poll::Ready(()),
        })
        .await;

        poll_fn(|cx| {
            assert!(matches!(rl.poll_allow(b, ReqRespKind::RawTxList, cx), Poll::Ready(true)));
            Poll::Ready(())
        })
        .await;
    }

    #[tokio::test]
    async fn request_rate_limiter_evicts_idle_entries() {
        let window = Duration::from_millis(100);
        let mut rl = RequestRateLimiter::new(window, 2);
        let a = PeerId::random();
        let b = PeerId::random();

        for peer in [a, b] {
            poll_fn(|cx| {
                assert!(matches!(rl.poll_allow(peer, ReqRespKind::Head, cx), Poll::Ready(true)));
                Poll::Ready(())
            })
            .await;
        }
        assert_eq!(rl.state.len(), 2);

        tokio::time::sleep(window * 5).await;

        poll_fn(|cx| {
            assert!(matches!(rl.poll_allow(b, ReqRespKind::Head, cx), Poll::Ready(true)));
            Poll::Ready(())
        })
        .await;

        assert_eq!(rl.state.len(), 1);
        assert!(rl.state.contains_key(&(b, ReqRespKind::Head)));
    }
}
