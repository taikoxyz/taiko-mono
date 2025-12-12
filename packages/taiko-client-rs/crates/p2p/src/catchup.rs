//! Catch-up state machine for preconfirmation head sync.
//!
//! This module currently exposes a pure, event-driven state machine that tracks
//! discovery of a remote head and the pagination cursors needed to backfill
//! commitments before entering live mode. Networking is intentionally abstracted
//! away; callers consume the emitted `CatchupAction`s to drive req/resp
//! exchanges.

use std::{
    collections::VecDeque,
    time::{Duration, Instant},
};

use libp2p::PeerId;
use preconfirmation_types::Bytes32;

use crate::{
    metrics::set_head_sync,
    types::{HeadSyncStatus, PreconfHead, SdkEvent, Uint256},
};

/// Actions the pure state machine asks its caller to perform.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum CatchupAction {
    /// Request the remote head from any available peer.
    RequestHead,
    /// Request a page of commitments starting at `from_height`.
    RequestCommitments {
        /// First block number to request (inclusive).
        from_height: Uint256,
        /// Maximum number of commitments to fetch in this page.
        max: u32,
    },
    /// Request a raw tx list associated with a commitment.
    RequestRawTxList {
        /// Peer to ask for the tx list.
        peer: Option<PeerId>,
        /// Hash-derived cursor for the tx list.
        raw_tx_list_hash: [u8; 32],
    },
    /// Emit a status update to downstream consumers.
    EmitStatus(HeadSyncStatus),
    /// Cancel any outstanding work or timers.
    CancelInflight,
}

/// Events that can drive the catch-up state machine.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum CatchupEvent {
    /// Begin a new catch-up cycle from the provided local head.
    Start,
    /// Abort the current catch-up attempt and return to idle.
    Cancel,
    /// A peer reported its head via req/resp.
    HeadObserved(PreconfHead),
    /// A commitments page was received; `last_block` is the highest block in the page.
    CommitmentsPage {
        /// Highest block number present in the page.
        last_block: Uint256,
        /// Raw tx list hashes referenced by the commitments in the page.
        tx_hashes: Vec<Bytes32>,
    },
    /// A raw tx list response matching a previously requested hash was received.
    RawTxListReceived {
        /// Hash of the raw tx list that has been fetched.
        raw_tx_list_hash: [u8; 32],
    },
    /// Local processing advanced the head height.
    LocalAdvanced(Uint256),
    /// Periodic tick for time-based transitions (unused for now).
    Tick,
}

/// Internal phases for the catch-up state machine.
#[derive(Debug, Clone, PartialEq, Eq)]
enum Phase {
    Idle { local: Uint256 },
    Discovering { local: Uint256 },
    Syncing { local: Uint256, remote: Uint256, next: Uint256 },
    Live { head: Uint256 },
}

/// Pure catch-up state machine tracking local and remote heads.
#[derive(Debug, Clone)]
pub struct Catchup {
    /// Current phase of the catch-up state machine.
    phase: Phase,
    /// Page size used when requesting commitment ranges.
    page_size: u32,
    /// Minimum backoff delay between retries when awaiting req/resp replies.
    backoff_min: Duration,
    /// Maximum backoff delay between retries.
    backoff_max: Duration,
    /// Maximum retries before declaring a stall and canceling in-flight work.
    retry_budget: u32,
    /// Timestamp of the last outbound request the state machine issued (head/commitments).
    last_request_at: Option<Instant>,
    /// Number of consecutive retries performed in the current phase.
    retries: u32,
    /// Current backoff window for head/commitments.
    current_backoff: Duration,
    /// Pending raw txlist hashes to request.
    pending_raw: VecDeque<[u8; 32]>,
    /// Currently in-flight raw txlist hash if any.
    inflight_raw: Option<[u8; 32]>,
    /// Timestamp of last raw txlist request.
    raw_last_request_at: Option<Instant>,
    /// Consecutive retries for the current raw txlist.
    raw_retries: u32,
    /// Current backoff for raw txlist.
    raw_backoff: Duration,
    /// PRNG state used to add jitter to backoff windows.
    rng_state: u64,
}

impl Catchup {
    /// Create a new catch-up controller seeded with the current local head.
    pub fn new(local_head: Uint256) -> Self {
        Self {
            phase: Phase::Idle { local: local_head },
            page_size: 64,
            backoff_min: Duration::from_secs(2),
            backoff_max: Duration::from_secs(30),
            retry_budget: 5,
            last_request_at: None,
            retries: 0,
            current_backoff: Duration::from_secs(2),
            pending_raw: VecDeque::new(),
            inflight_raw: None,
            raw_last_request_at: None,
            raw_retries: 0,
            raw_backoff: Duration::from_secs(2),
            rng_state: 0xdead_beef,
        }
    }

    /// Override the page size used for commitments pagination.
    pub fn set_page_size(&mut self, page_size: u32) {
        self.page_size = page_size;
    }

    /// Configure backoff parameters for retries.
    pub fn configure_backoff(&mut self, min: Duration, max: Duration, retries: u32) {
        self.backoff_min = min;
        self.backoff_max = max;
        self.retry_budget = retries;
        self.current_backoff = min;
        self.raw_backoff = min;
    }

    /// Start head discovery; callers should execute returned actions.
    pub fn start(&mut self) -> Vec<CatchupAction> {
        self.step(CatchupEvent::Start, Instant::now())
    }

    /// Cancel in-flight synchronization and return to idle.
    pub fn cancel(&mut self) -> Vec<CatchupAction> {
        self.step(CatchupEvent::Cancel, Instant::now())
    }

    /// Process an inbound head response and surface an SDK event.
    pub fn on_head_response(&mut self, head: PreconfHead) -> SdkEvent {
        let mut actions = self.step(CatchupEvent::HeadObserved(head), Instant::now());
        // Best-effort: surface the latest status; if none was emitted, fall back to current.
        let status = actions
            .iter()
            .rev()
            .find_map(|a| match a {
                CatchupAction::EmitStatus(status) => Some(status.clone()),
                _ => None,
            })
            .unwrap_or_else(|| self.status());
        // Ignore other actions for now; integration layer will drive them later.
        actions.clear();
        SdkEvent::HeadSync(status)
    }

    /// Update local head height and return any resulting actions.
    pub fn update_local_head(&mut self, head: Uint256) -> Vec<CatchupAction> {
        self.step(CatchupEvent::LocalAdvanced(head), Instant::now())
    }

    /// Expose the current status derived from internal phase.
    pub fn status(&self) -> HeadSyncStatus {
        match &self.phase {
            Phase::Idle { .. } => HeadSyncStatus::Idle,
            Phase::Discovering { local } => {
                HeadSyncStatus::Syncing { local: local.clone(), remote: local.clone() }
            }
            Phase::Syncing { local, remote, .. } => {
                HeadSyncStatus::Syncing { local: local.clone(), remote: remote.clone() }
            }
            Phase::Live { head } => HeadSyncStatus::Live { head: head.clone() },
        }
    }

    /// Core state transition function. Pure aside from metric updates.
    pub fn step(&mut self, event: CatchupEvent, _now: Instant) -> Vec<CatchupAction> {
        match event {
            CatchupEvent::Start => match self.phase.clone() {
                Phase::Idle { local } | Phase::Live { head: local } => {
                    self.phase = Phase::Discovering { local: local.clone() };
                    set_head_sync(u256_to_u64(&local), u256_to_u64(&local));
                    self.last_request_at = Some(_now);
                    self.retries = 0;
                    self.current_backoff = self.backoff_min;
                    self.raw_backoff = self.backoff_min;
                    self.raw_retries = 0;
                    self.raw_last_request_at = None;
                    self.inflight_raw = None;
                    self.pending_raw.clear();
                    vec![CatchupAction::EmitStatus(self.status()), CatchupAction::RequestHead]
                }
                _ => vec![],
            },
            CatchupEvent::Cancel => match self.phase.clone() {
                Phase::Idle { .. } => vec![],
                Phase::Discovering { local } |
                Phase::Syncing { local, .. } |
                Phase::Live { head: local } => {
                    self.phase = Phase::Idle { local: local.clone() };
                    set_head_sync(u256_to_u64(&local), u256_to_u64(&local));
                    self.pending_raw.clear();
                    self.inflight_raw = None;
                    self.raw_last_request_at = None;
                    vec![
                        CatchupAction::CancelInflight,
                        CatchupAction::EmitStatus(HeadSyncStatus::Idle),
                    ]
                }
            },
            CatchupEvent::HeadObserved(head) => {
                let remote = head.block_number;
                match self.phase.clone() {
                    Phase::Idle { local } | Phase::Discovering { local } => {
                        if remote <= local {
                            self.phase = Phase::Live { head: local.clone() };
                            set_head_sync(u256_to_u64(&local), u256_to_u64(&local));
                            vec![CatchupAction::EmitStatus(HeadSyncStatus::Live { head: local })]
                        } else {
                            self.phase = Phase::Syncing {
                                local: local.clone(),
                                remote: remote.clone(),
                                next: local.clone(),
                            };
                            set_head_sync(u256_to_u64(&local), u256_to_u64(&remote));
                            self.last_request_at = Some(_now);
                            self.retries = 0;
                            self.current_backoff = self.backoff_min;
                            vec![
                                CatchupAction::EmitStatus(self.status()),
                                CatchupAction::RequestCommitments {
                                    from_height: local,
                                    max: self.page_size,
                                },
                            ]
                        }
                    }
                    Phase::Syncing { local, remote: current_remote, .. } => {
                        if remote > current_remote {
                            self.phase = Phase::Syncing {
                                local: local.clone(),
                                remote: remote.clone(),
                                next: local.clone(),
                            };
                            set_head_sync(u256_to_u64(&local), u256_to_u64(&remote));
                            self.last_request_at = Some(_now);
                            self.retries = 0;
                            self.current_backoff = self.backoff_min;
                            vec![CatchupAction::EmitStatus(self.status())]
                        } else {
                            vec![]
                        }
                    }
                    Phase::Live { .. } => vec![],
                }
            }
            CatchupEvent::LocalAdvanced(new_local) => match self.phase.clone() {
                Phase::Syncing { remote, .. } if new_local >= remote => {
                    self.phase = Phase::Live { head: new_local.clone() };
                    set_head_sync(u256_to_u64(&new_local), u256_to_u64(&new_local));
                    vec![CatchupAction::EmitStatus(HeadSyncStatus::Live { head: new_local })]
                }
                Phase::Syncing { remote, .. } => {
                    self.phase = Phase::Syncing {
                        local: new_local.clone(),
                        remote: remote.clone(),
                        next: new_local.clone(),
                    };
                    set_head_sync(u256_to_u64(&new_local), u256_to_u64(&remote));
                    vec![CatchupAction::EmitStatus(self.status())]
                }
                Phase::Discovering { .. } | Phase::Idle { .. } | Phase::Live { .. } => vec![],
            },
            CatchupEvent::CommitmentsPage { last_block, tx_hashes } => match self.phase.clone() {
                Phase::Syncing { remote, .. } => {
                    let mut actions = self.enqueue_raw_requests(tx_hashes);

                    if last_block >= remote {
                        self.phase = Phase::Live { head: last_block.clone() };
                        set_head_sync(u256_to_u64(&last_block), u256_to_u64(&last_block));
                        actions.push(CatchupAction::EmitStatus(HeadSyncStatus::Live {
                            head: last_block,
                        }));
                        actions
                    } else {
                        self.phase = Phase::Syncing {
                            local: last_block.clone(),
                            remote: remote.clone(),
                            next: last_block.clone(),
                        };
                        set_head_sync(u256_to_u64(&last_block), u256_to_u64(&remote));
                        self.last_request_at = Some(_now);
                        self.retries = 0;
                        self.current_backoff = self.backoff_min;
                        actions.push(CatchupAction::EmitStatus(self.status()));
                        actions.push(CatchupAction::RequestCommitments {
                            from_height: last_block,
                            max: self.page_size,
                        });
                        actions
                    }
                }
                _ => vec![],
            },
            CatchupEvent::RawTxListReceived { raw_tx_list_hash } => {
                if self.inflight_raw == Some(raw_tx_list_hash) {
                    self.inflight_raw = None;
                    self.raw_last_request_at = None;
                    self.raw_retries = 0;
                    self.raw_backoff = self.backoff_min;
                    self.next_raw_request()
                } else {
                    vec![]
                }
            }
            CatchupEvent::Tick => self.handle_tick(_now),
        }
    }

    /// Process a periodic tick and emit retries or cancellations if stalled.
    fn handle_tick(&mut self, now: Instant) -> Vec<CatchupAction> {
        match self.phase.clone() {
            Phase::Discovering { .. } => self.maybe_retry_head(now),
            Phase::Syncing { local, .. } => {
                let mut actions = self.maybe_retry_commitments(now, local);
                actions.extend(self.maybe_retry_raw(now));
                actions
            }
            _ => vec![],
        }
    }

    /// Retry head discovery if enough time has elapsed, emitting cancel when retries are exhausted.
    fn maybe_retry_head(&mut self, now: Instant) -> Vec<CatchupAction> {
        if self.should_retry(now) {
            if self.retries + 1 >= self.retry_budget {
                self.last_request_at = None;
                self.retries = 0;
                self.current_backoff = self.backoff_min;
                return vec![
                    CatchupAction::CancelInflight,
                    CatchupAction::EmitStatus(HeadSyncStatus::Idle),
                ];
            }
            self.retries += 1;
            self.last_request_at = Some(now);
            self.bump_backoff();
            return vec![CatchupAction::RequestHead];
        }
        vec![]
    }

    /// Retry commitments pagination if stalled, otherwise emit a cancel to reset state.
    fn maybe_retry_commitments(
        &mut self,
        now: Instant,
        from_height: Uint256,
    ) -> Vec<CatchupAction> {
        if self.should_retry(now) {
            if self.retries + 1 >= self.retry_budget {
                self.last_request_at = None;
                self.retries = 0;
                self.current_backoff = self.backoff_min;
                return vec![
                    CatchupAction::CancelInflight,
                    CatchupAction::EmitStatus(self.status()),
                ];
            }
            self.retries += 1;
            self.last_request_at = Some(now);
            self.bump_backoff();
            return vec![CatchupAction::RequestCommitments { from_height, max: self.page_size }];
        }
        vec![]
    }

    /// Determine whether the retry/backoff window has elapsed since the last request.
    fn should_retry(&mut self, now: Instant) -> bool {
        self.last_request_at
            .map(|t| now.duration_since(t) >= self.jittered(self.current_backoff))
            .unwrap_or(false)
    }

    /// Issue the next raw txlist request if none in flight.
    fn next_raw_request(&mut self) -> Vec<CatchupAction> {
        if self.inflight_raw.is_none() {
            if let Some(next) = self.pending_raw.pop_front() {
                self.inflight_raw = Some(next);
                self.raw_last_request_at = Some(Instant::now());
                self.raw_retries = 0;
                self.raw_backoff = self.backoff_min;
                return vec![CatchupAction::RequestRawTxList { peer: None, raw_tx_list_hash: next }];
            }
        }
        Vec::new()
    }

    /// Queue raw txlist hashes and request the first if idle.
    fn enqueue_raw_requests(&mut self, hashes: Vec<Bytes32>) -> Vec<CatchupAction> {
        for hash in hashes {
            self.pending_raw.push_back(bytes32_to_arr(&hash));
        }
        self.next_raw_request()
    }

    /// Retry or advance raw txlist fetching based on backoff.
    fn maybe_retry_raw(&mut self, now: Instant) -> Vec<CatchupAction> {
        if let Some(inflight) = self.inflight_raw {
            let ready = self
                .raw_last_request_at
                .map(|t| now.duration_since(t) >= self.jittered(self.raw_backoff))
                .unwrap_or(false);
            if ready {
                if self.raw_retries + 1 >= self.retry_budget {
                    // give up on this hash and move on
                    self.inflight_raw = None;
                    self.raw_last_request_at = None;
                    self.raw_retries = 0;
                    self.raw_backoff = self.backoff_min;
                    return self.next_raw_request();
                }
                self.raw_retries += 1;
                self.raw_last_request_at = Some(now);
                self.bump_raw_backoff();
                return vec![CatchupAction::RequestRawTxList {
                    peer: None,
                    raw_tx_list_hash: inflight,
                }];
            }
        }
        Vec::new()
    }

    /// Increase backoff for head/commitments.
    fn bump_backoff(&mut self) {
        let doubled = self.current_backoff.saturating_mul(2);
        self.current_backoff = std::cmp::min(doubled, self.backoff_max);
    }

    /// Increase backoff for raw txlist retries.
    fn bump_raw_backoff(&mut self) {
        let doubled = self.raw_backoff.saturating_mul(2);
        self.raw_backoff = std::cmp::min(doubled, self.backoff_max);
    }

    /// Add a small jitter to a base duration using an LCG.
    fn jittered(&mut self, base: Duration) -> Duration {
        let base_ms = base.as_millis() as u64;
        self.rng_state = self.rng_state.wrapping_mul(6364136223846793005).wrapping_add(1);
        let jitter_ms = if base_ms == 0 { 0 } else { (self.rng_state >> 16) % (base_ms / 2 + 1) };
        base + Duration::from_millis(jitter_ms)
    }
}

/// Convert an SSZ 256-bit unsigned integer into `u64`, saturating on overflow.
fn u256_to_u64(value: &Uint256) -> u64 {
    let bytes = value.to_bytes_le();
    let mut buf = [0u8; 8];
    let len = bytes.len().min(8);
    buf[..len].copy_from_slice(&bytes[..len]);
    let truncated = u64::from_le_bytes(buf);
    if bytes.iter().skip(8).any(|&b| b != 0) { u64::MAX } else { truncated }
}

/// Convert an SSZ Bytes32 into a fixed 32-byte array.
fn bytes32_to_arr(bytes: &Bytes32) -> [u8; 32] {
    let mut out = [0u8; 32];
    out.copy_from_slice(bytes.as_ref());
    out
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::types::PreconfHead;

    /// Build a Uint256 from a u64 for test readability.
    fn u256(n: u64) -> Uint256 {
        Uint256::from(n)
    }

    #[test]
    /// Start should request head and emit a syncing status.
    fn start_requests_head_and_emits_status() {
        let mut catchup = Catchup::new(u256(5));
        let actions = catchup.start();

        assert!(actions.iter().any(|a| matches!(a, CatchupAction::RequestHead)));
        assert!(actions.iter().any(|a| matches!(a, CatchupAction::EmitStatus(HeadSyncStatus::Syncing { local, remote }) if *local == u256(5) && *remote == u256(5))));
        assert!(
            matches!(catchup.status(), HeadSyncStatus::Syncing { local, remote } if local == u256(5) && remote == u256(5))
        );
    }

    #[test]
    /// Remote head ahead moves state to syncing and requests commitments.
    fn head_response_ahead_moves_to_syncing() {
        let mut catchup = Catchup::new(u256(1));
        catchup.start();
        let head = PreconfHead { block_number: u256(10), submission_window_end: u256(0) };
        let actions = catchup.step(CatchupEvent::HeadObserved(head), Instant::now());

        assert!(
            matches!(catchup.status(), HeadSyncStatus::Syncing { local, remote } if local == u256(1) && remote == u256(10))
        );
        assert!(actions.iter().any(|a| matches!(a, CatchupAction::RequestCommitments { from_height, max } if *from_height == u256(1) && *max == 64)));
    }

    #[test]
    /// Remote head behind keeps us live at local head.
    fn head_response_at_or_below_local_enters_live() {
        let mut catchup = Catchup::new(u256(7));
        catchup.start();
        let head = PreconfHead { block_number: u256(6), submission_window_end: u256(0) };
        let actions = catchup.step(CatchupEvent::HeadObserved(head), Instant::now());

        assert!(matches!(catchup.status(), HeadSyncStatus::Live { head } if head == u256(7)));
        assert!(actions.iter().any(|a| matches!(a, CatchupAction::EmitStatus(HeadSyncStatus::Live { head }) if *head == u256(7))));
    }

    #[test]
    /// Cancel returns to idle and emits idle status.
    fn cancel_returns_to_idle() {
        let mut catchup = Catchup::new(u256(3));
        catchup.start();
        let actions = catchup.cancel();

        assert!(matches!(catchup.status(), HeadSyncStatus::Idle));
        assert!(
            actions.iter().any(|a| matches!(a, CatchupAction::EmitStatus(HeadSyncStatus::Idle)))
        );
    }

    #[test]
    /// Commitments page advances local height and requests next page.
    fn commitments_page_advances_and_requests_next() {
        let mut catchup = Catchup::new(u256(1));
        catchup.start();
        // simulate head discovered at 10
        catchup.step(
            CatchupEvent::HeadObserved(PreconfHead {
                block_number: u256(10),
                submission_window_end: u256(0),
            }),
            Instant::now(),
        );

        let actions = catchup.step(
            CatchupEvent::CommitmentsPage {
                last_block: u256(5),
                tx_hashes: vec![Bytes32::default()],
            },
            Instant::now(),
        );

        assert!(
            matches!(catchup.status(), HeadSyncStatus::Syncing { local, remote } if local == u256(5) && remote == u256(10))
        );
        assert!(actions.iter().any(|a| matches!(a, CatchupAction::RequestCommitments { from_height, max } if *from_height == u256(5) && *max == 64)));
    }

    #[test]
    /// When commitments reach remote head, transition to live.
    fn commitments_page_reaching_remote_enters_live() {
        let mut catchup = Catchup::new(u256(2));
        catchup.start();
        catchup.step(
            CatchupEvent::HeadObserved(PreconfHead {
                block_number: u256(5),
                submission_window_end: u256(0),
            }),
            Instant::now(),
        );

        let actions = catchup.step(
            CatchupEvent::CommitmentsPage { last_block: u256(5), tx_hashes: vec![] },
            Instant::now(),
        );

        assert!(matches!(catchup.status(), HeadSyncStatus::Live { head } if head == u256(5)));
        assert!(actions.iter().any(|a| matches!(a, CatchupAction::EmitStatus(HeadSyncStatus::Live { head }) if *head == u256(5))));
    }

    #[test]
    /// Commitments page triggers raw txlist fetches for referenced hashes.
    fn commitments_page_emits_txlist_requests() {
        let mut catchup = Catchup::new(u256(0));
        catchup.start();
        catchup.step(
            CatchupEvent::HeadObserved(PreconfHead {
                block_number: u256(2),
                submission_window_end: u256(0),
            }),
            Instant::now(),
        );

        let hash = Bytes32::try_from(vec![1u8; 32]).unwrap();
        let actions = catchup.step(
            CatchupEvent::CommitmentsPage { last_block: u256(1), tx_hashes: vec![hash] },
            Instant::now(),
        );

        assert!(actions.iter().any(|a| matches!(a, CatchupAction::RequestRawTxList { raw_tx_list_hash, .. } if *raw_tx_list_hash == [1u8;32])));
    }

    #[test]
    /// Tick retries head discovery after backoff interval.
    fn tick_retries_head_request() {
        let mut catchup = Catchup::new(u256(0));
        let now = Instant::now();
        catchup.step(CatchupEvent::Start, now);

        let actions = catchup.step(CatchupEvent::Tick, now + Duration::from_secs(6));
        assert!(actions.iter().any(|a| matches!(a, CatchupAction::RequestHead)));
    }

    #[test]
    /// Tick retries commitments a few times then cancels when exhausted.
    fn tick_retries_commitments_then_cancels() {
        let mut catchup = Catchup::new(u256(1));
        let now = Instant::now();
        catchup.step(CatchupEvent::Start, now);
        catchup.step(
            CatchupEvent::HeadObserved(PreconfHead {
                block_number: u256(5),
                submission_window_end: u256(0),
            }),
            now,
        );

        // Force near-exhausted retries and stale timer to trigger cancel on next tick.
        catchup.retries = catchup.retry_budget.saturating_sub(1);
        catchup.last_request_at = Some(now - Duration::from_secs(100));

        let actions = catchup.step(CatchupEvent::Tick, now + Duration::from_secs(101));
        assert!(actions.iter().any(|a| matches!(a, CatchupAction::CancelInflight)));
    }

    #[test]
    /// Raw txlist hashes are queued and requested sequentially.
    fn raw_txlists_are_queued() {
        let mut catchup = Catchup::new(u256(0));
        let now = Instant::now();
        catchup.step(CatchupEvent::Start, now);
        catchup.step(
            CatchupEvent::HeadObserved(PreconfHead {
                block_number: u256(3),
                submission_window_end: u256(0),
            }),
            now,
        );

        let hashes = vec![
            Bytes32::try_from(vec![1u8; 32]).unwrap(),
            Bytes32::try_from(vec![2u8; 32]).unwrap(),
        ];
        let actions = catchup
            .step(CatchupEvent::CommitmentsPage { last_block: u256(1), tx_hashes: hashes }, now);

        // Only one raw request should be issued at a time.
        assert_eq!(
            actions.iter().filter(|a| matches!(a, CatchupAction::RequestRawTxList { .. })).count(),
            1
        );

        // After receiving first, next should be requested.
        let next_actions =
            catchup.step(CatchupEvent::RawTxListReceived { raw_tx_list_hash: [1u8; 32] }, now);
        assert!(next_actions.iter().any(|a| matches!(a, CatchupAction::RequestRawTxList { raw_tx_list_hash, .. } if *raw_tx_list_hash == [2u8;32])));
    }

    #[test]
    /// Raw txlist retries backoff and eventually advances past failures.
    fn raw_txlist_retries_then_moves_on() {
        let mut catchup = Catchup::new(u256(0));
        catchup.configure_backoff(Duration::from_millis(1), Duration::from_millis(2), 2);
        let now = Instant::now();
        catchup.step(CatchupEvent::Start, now);
        catchup.step(
            CatchupEvent::HeadObserved(PreconfHead {
                block_number: u256(2),
                submission_window_end: u256(0),
            }),
            now,
        );
        let hash = Bytes32::try_from(vec![9u8; 32]).unwrap();
        let _ = catchup.step(
            CatchupEvent::CommitmentsPage { last_block: u256(1), tx_hashes: vec![hash] },
            now,
        );

        let mut retries = 0;
        for i in 0..5 {
            let actions =
                catchup.step(CatchupEvent::Tick, now + Duration::from_millis(5 * (i + 1)));
            if actions.iter().any(|a| matches!(a, CatchupAction::RequestRawTxList { .. })) {
                retries += 1;
            }
        }

        assert!(retries >= 1);
        assert!(catchup.inflight_raw.is_none() || catchup.pending_raw.is_empty());
    }
}
