//! Peer reputation and rate limiting.
//!
//! This module provides mechanisms for scoring and managing the reputation of peers
//! in the preconfirmation P2P network. It includes:
//! - `PeerAction`: Discrete events that influence a peer's score.
//! - `RequestRateLimiter`: Prevents individual peers from overwhelming the service with requests.
//! - `PeerReputationStore`: Maintains per-peer scores, bans, and greylists.
//!
//! The Kona connection gater from `kona_gossip` is used for low-level connection
//! management, while this module focuses on application-level reputation.

use libp2p::PeerId;
use reth_network_types::peers::reputation::ReputationChangeWeights;
use std::{
    collections::{HashMap, HashSet},
    task::{Context, Poll},
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
/// Default ban threshold from the spec.
const DEFAULT_BAN_THRESHOLD: PeerScore = -5.0; // spec ban threshold
/// Default greylist/prune threshold from the spec.
const DEFAULT_GREYLIST_THRESHOLD: PeerScore = -2.0; // spec prune/grey threshold
/// Reputation delta applied on successful responses.
const SUCCESS_REWARD: PeerScore = 0.05; // acceptance delta

/// Represents the current reputation score of a peer.
#[derive(Debug, Clone)]
pub struct PeerReputation {
    /// The numerical score of the peer. Higher is better.
    score: PeerScore,
    /// The last `Instant` at which the score was updated. Used for decay calculation.
    last_updated: Instant,
}

impl PeerReputation {
    /// Creates a new `PeerReputation` with a default score of 0.0.
    pub fn new(now: Instant) -> Self {
        Self { score: 0.0, last_updated: now }
    }

    /// Returns the current score of the peer.
    pub fn score(&self) -> PeerScore {
        self.score
    }
}

/// Configuration for the peer reputation system.
///
/// ```compile_fail
/// use preconfirmation_net::ReputationConfig;
///
/// let _cfg = ReputationConfig {
///     greylist_threshold: -5.0,
///     ban_threshold: -10.0,
///     halflife: std::time::Duration::from_secs(600),
///     weights: Default::default(),
/// };
/// ```
#[derive(Debug, Clone)]
pub struct ReputationConfig {
    /// Score at or below which a peer is greylisted (soft drop).
    pub greylist_threshold: PeerScore,
    /// Score at or below which a peer is banned (hard drop).
    pub ban_threshold: PeerScore,
    /// Exponential decay halflife applied to scores. Scores decay towards zero.
    pub halflife: Duration,
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
    /// Weights mapping actions into reputation deltas.
    weights: ReputationChangeWeights,
}

impl Default for PeerReputationStore {
    /// Build a store with default thresholds and weights.
    fn default() -> Self {
        Self::new(ReputationConfig {
            greylist_threshold: DEFAULT_GREYLIST_THRESHOLD,
            ban_threshold: DEFAULT_BAN_THRESHOLD,
            halflife: Duration::from_secs(600),
        })
    }
}

impl PeerReputationStore {
    /// Creates a new `PeerReputationStore` with the given configuration.
    pub fn new(cfg: ReputationConfig) -> Self {
        Self {
            scores: HashMap::new(),
            banned: HashSet::new(),
            greylisted: HashSet::new(),
            cfg,
            weights: ReputationChangeWeights::default(),
        }
    }

    /// Applies a `PeerAction` to a peer, updating its score and ban/greylist status.
    pub fn apply(&mut self, peer: PeerId, action: PeerAction) -> ReputationEvent {
        let now = Instant::now();
        let was_banned = self.banned.contains(&peer);
        let was_grey = self.greylisted.contains(&peer);
        let entry = self.scores.entry(peer).or_insert_with(|| PeerReputation::new(now));
        // Split borrows: compute new score then update.
        // Decay ensures older infractions fade so recent behavior dominates decisions.
        let mut score = entry.score;
        score = Self::decayed(score, entry.last_updated, now, self.cfg.halflife);
        score += action_delta(action, &self.weights);
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

    /// Returns true if the peer is currently banned.
    pub fn is_banned(&self, peer: &PeerId) -> bool {
        self.banned.contains(peer)
    }

    /// Applies exponential decay to a score based on elapsed time and halflife.
    fn decayed(score: PeerScore, last: Instant, now: Instant, halflife: Duration) -> PeerScore {
        let dt = now.saturating_duration_since(last).as_secs_f64();
        if dt == 0.0 {
            return score;
        }
        let lambda = std::f64::consts::LN_2 / halflife.as_secs_f64().max(1.0);
        score * (-lambda * dt).exp()
    }

    /// Updates banned/greylisted sets based on the peer's score.
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

/// Map a `PeerAction` into a reputation delta using configured weights.
fn action_delta(action: PeerAction, weights: &ReputationChangeWeights) -> PeerScore {
    match action {
        // Apply lightweight app feedback per spec §7.1
        PeerAction::GossipValid => SUCCESS_REWARD,
        PeerAction::GossipInvalid => -1.0,
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

/// Request/response rate limiter built on reth's `RateLimit` (token bucket, per peer/protocol).
pub struct RequestRateLimiter {
    /// Token bucket rate shared by per-peer/per-protocol limiters.
    rate: reth_tokio_util::ratelimit::Rate,
    /// Duration after which idle buckets are evicted.
    horizon: tokio::time::Duration,
    /// Per-peer/per-protocol limiter state.
    state: HashMap<(PeerId, ReqRespKind), LimiterState>,
}

/// Cached limiter state for a peer/protocol bucket.
#[derive(Debug)]
struct LimiterState {
    /// Token bucket instance for the peer/protocol pair.
    limiter: reth_tokio_util::ratelimit::RateLimit,
    /// Timestamp of last request, used for eviction.
    last_used: tokio::time::Instant,
}

/// Req/resp protocol kind used for per-protocol buckets.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum ReqRespKind {
    /// Commitments request/response protocol.
    Commitments,
    /// Raw tx list request/response protocol.
    RawTxList,
    /// Head request/response protocol.
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

    /// Drop idle limiters whose buckets have not been used within the horizon.
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
        cx: &mut Context<'_>,
    ) -> Poll<bool> {
        let now = tokio::time::Instant::now();
        self.evict_idle(now);

        let entry = self.state.entry((peer, kind)).or_insert_with(|| LimiterState {
            limiter: reth_tokio_util::ratelimit::RateLimit::new(self.rate),
            last_used: now,
        });
        entry.last_used = now;

        match entry.limiter.poll_ready(cx) {
            Poll::Ready(()) => {
                entry.limiter.tick();
                Poll::Ready(true)
            }
            Poll::Pending => Poll::Pending,
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use futures::future::poll_fn;
    use libp2p::{PeerId, identity};
    use std::task::Poll;

    /// Convenience config for tests using default thresholds.
    fn cfg() -> ReputationConfig {
        ReputationConfig {
            greylist_threshold: DEFAULT_GREYLIST_THRESHOLD,
            ban_threshold: DEFAULT_BAN_THRESHOLD,
            halflife: Duration::from_secs(600),
        }
    }

    /// Repeated errors eventually ban a peer.
    #[test]
    fn peer_store_reaches_ban_threshold() {
        let mut store = PeerReputationStore::new(cfg());
        let peer = PeerId::random();
        for _ in 0..20 {
            let ev = store.apply(peer, PeerAction::ReqRespError);
            if ev.is_banned {
                assert!(store.is_banned(&peer));
                return;
            }
        }
        panic!("peer was not banned after repeated errors");
    }

    /// Fresh peers are not banned before any actions are applied.
    #[test]
    fn store_allows_fresh_peers() {
        let store = PeerReputationStore::new(cfg());
        let peer = identity::Keypair::generate_ed25519().public().to_peer_id();
        assert!(!store.is_banned(&peer));
    }

    /// Decay drives scores toward zero over time.
    #[test]
    fn decay_heals_greylist_over_time() {
        // Start well below greylist and ensure decay moves score toward zero.
        let score = -5.0;
        let last = Instant::now() - Duration::from_secs(600);
        let halflife = Duration::from_secs(60);
        let healed = PeerReputationStore::decayed(score, last, Instant::now(), halflife);
        assert!(healed > score, "decay should move score toward zero");
        assert!(healed > -1.0, "should clear greylist over long decay period");
    }

    /// Allows within quota then limits until bucket refills.
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

    /// Buckets are independent per peer.
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

    /// Idle limiter entries are evicted after the horizon.
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
