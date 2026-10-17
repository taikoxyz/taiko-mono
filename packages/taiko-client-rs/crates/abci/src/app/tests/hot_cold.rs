//! Hot and cold `FinalizeBlock` agree on generated forced inclusion runs.
//!
//! A hot node finalizes a block on the verdict its `ProcessProposal` cached. A cold node (crash
//! replay, block sync) never judged the block: its `FinalizeBlock` re-validates it, confirms a
//! moved anchor in its own L1 and completes a canonical skip with its own singleton probe. The
//! property: on every decided block of a generated run, both answer the same `FinalizeBlock`
//! response, derive the same pending state before `Commit` and commit the same state, and the
//! forced inclusion cursor advances by one exactly when the block consumes an entry.
//!
//! A scenario plants one to three calldata queue entries in the own L1. Each admits a canonical
//! transaction, empty bytes or undecodable bytes, appears at one of the [`ANCHORS`] blocks and
//! comes due at one of them (or never). The run then decides one to [`MAX_BLOCKS`] blocks from
//! `H_0`. Each block inherits the parent's anchor or moves it forward, and takes an
//! honest action legal for the entry at the committed cursor: an ordinary block before the entry
//! is due (with or without its optional preimage), an inclusion at position zero (with or without
//! the preimage and later mempool transactions), a due invalid-bytes skip, or a due canonical
//! skip whose singleton probe includes nothing. A run ending on a canonical skip decides one more
//! block, at the next cursor. The cold node may also crash after `FinalizeBlock`, before
//! `Commit`, and replay the block after a restart.

use std::{fmt::Display, future::Future, time::Duration};

use alloy_consensus::{SignableTransaction, TxEip1559, TxEnvelope, TxLegacy};
use alloy_eips::eip2718::Encodable2718;
use alloy_primitives::{Address, Bytes, Signature, TxKind, U256, keccak256};
use proptest::prelude::*;
use tempfile::TempDir;

use super::{
    proposal::{bft_time, commit, finalize, finalize_req, process, process_req},
    *,
};
use crate::{
    app::validate::{self, Validated},
    envelope::{AnchorWitness, EtnaEnvelope, ExecutionBlock, ForcedWitness},
    forced::{ForcedDecision, ForcedEntry, decode_canonical},
    l1::verify_anchor_witness,
    rules,
    store::AppState,
    test_utils::{L1Call, simple_block},
};

/// The anchor blocks the own L1 finalizes after the genesis anchor `L1_0 = 64`, in order. Each
/// holds the queue entries visible there; `L1_0` holds none.
const ANCHORS: [u64; 4] = [66, 67, 68, 69];

/// The most blocks a scenario decides from `H_0`: with the block after a final canonical skip,
/// every height stays below the first switch height and within the back-pressure cap of its
/// anchor's last checkpoint.
const MAX_BLOCKS: usize = 10;

/// Generated scenarios per test run.
const CASES: u32 = 64;

/// What a queue entry admits.
#[derive(Clone, Debug)]
enum Content {
    /// A canonical signed transaction.
    Canonical {
        /// Whether it is an EIP-1559 transaction rather than a legacy one.
        eip1559: bool,
    },
    /// An actually empty admission.
    Empty,
    /// Bytes that are not exactly one canonical transaction.
    Undecodable(Vec<u8>),
}

/// A generated queue entry.
#[derive(Clone, Debug)]
struct EntrySpec {
    /// Index into [`ANCHORS`] of the first anchor block whose queue holds the entry.
    visible: usize,
    /// Index into [`ANCHORS`] of the first anchor at which the entry is due; past the end, never.
    due: usize,
    /// The admitted bytes.
    content: Content,
}

/// The generated choices of one block, which [`Run::honest_block`] maps onto an honest block.
#[derive(Clone, Debug)]
struct BlockChoice {
    /// 0 inherits the parent's anchor; `k > 0` moves it to the `k`-th anchor block after it (the
    /// last one when fewer remain).
    anchor_step: usize,
    /// Picks one of the actions legal at the committed cursor (modulo their number).
    action: usize,
    /// Whether an ordinary or including block carries the pending entry's optional preimage.
    preimage: bool,
    /// How many mempool transactions the block carries (after an included forced one).
    mempool: usize,
    /// Whether the cold node crashes after `FinalizeBlock`, before `Commit`, and replays it.
    crash: bool,
}

/// A generated run: the planted queue and the decided blocks.
#[derive(Clone, Debug)]
struct Scenario {
    /// The queue, in index order.
    entries: Vec<EntrySpec>,
    /// The blocks decided from `H_0`.
    blocks: Vec<BlockChoice>,
    /// The block decided after a run that ends on a canonical skip.
    follow_up: BlockChoice,
}

/// An honest block's treatment of the entry at the committed cursor.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
enum Action {
    /// Consumes nothing: no entry is pending, or it is neither due nor included.
    Ordinary,
    /// Includes the entry's canonical transaction at position zero.
    Include,
    /// Skips a due entry whose bytes are not one canonical transaction.
    SkipInvalid,
    /// Skips a due canonical transaction that a singleton build on the parent leaves out.
    SkipCanonical,
}

/// A planted queue entry.
#[derive(Debug)]
struct Entry {
    /// The exact admitted bytes, which the entry's hash commits to.
    bytes: Bytes,
    /// Whether the bytes are exactly one canonical transaction.
    canonical: bool,
    /// The first anchor block whose queue holds the entry.
    visible_at: u64,
    /// The submission timestamp.
    timestamp: u64,
}

/// An honest block for the next height and what it does to the queue.
struct Block {
    /// The block's height.
    height: u64,
    /// The block's BFT time, in Unix seconds.
    bft: u64,
    /// The block's anchor block number: moved, or the parent's.
    anchor: u64,
    /// The committed cursor the block is judged on.
    cursor: u64,
    /// What the block does to the entry at the cursor.
    action: Action,
    /// The forced inclusion decision the block must classify as.
    decision: ForcedDecision,
    /// The block's envelope.
    env: EtnaEnvelope,
}

/// The hot and the cold app side by side, over the same own-L1 view of the planted queue.
struct Run {
    /// The genesis both apps start from.
    fx: Fixture,
    /// The planted queue, in index order.
    entries: Vec<Entry>,
    /// The app that processes, finalizes and commits every block.
    hot: App<MockL1, MockEngine>,
    /// The app that only finalizes and commits every block.
    cold: App<MockL1, MockEngine>,
    /// The hot app's store.
    hot_dir: TempDir,
    /// The cold app's store, which a restart reopens.
    cold_dir: TempDir,
}

impl Run {
    /// Two apps initialized on the fixture genesis, each with its own store and EL, whose own L1s
    /// finalized the anchor blocks holding the queue `specs` describes.
    async fn new(specs: &[EntrySpec]) -> Self {
        let fx = Fixture::genesis(1);
        let entries = realize(&fx, specs);
        let (hot_dir, cold_dir) = (tempfile::tempdir().unwrap(), tempfile::tempdir().unwrap());
        let hot = initialized(&fx, hot_dir.path()).await;
        let cold = initialized(&fx, cold_dir.path()).await;
        plant_anchors(&fx, hot.l1(), &entries);
        plant_anchors(&fx, cold.l1(), &entries);
        Self { fx, entries, hot, cold, hot_dir, cold_dir }
    }

    /// The honest block `choice` picks for the next height: its anchor inherited or moved forward,
    /// and an action legal for the entry at the committed cursor under that anchor.
    fn honest_block(&self, choice: &BlockChoice) -> Block {
        let state = self.hot.state().expect("initialized");
        let height = state.last_height + 1;
        let ahead: Vec<u64> =
            ANCHORS.into_iter().filter(|number| *number > state.anchor.number).collect();
        let moved = choice
            .anchor_step
            .checked_sub(1)
            .and_then(|step| ahead.get(step.min(ahead.len().saturating_sub(1))).copied());
        let anchor = moved.unwrap_or(state.anchor.number);
        // `H_0` carries an anchor witness even for an inherited anchor.
        let anchor_witness = (moved.is_some() || height == state.schedule().h0())
            .then(|| self.fx.anchor_witness(self.hot.l1(), anchor));

        let cursor = state.forced_cursor;
        let pending = usize::try_from(cursor)
            .ok()
            .and_then(|index| self.entries.get(index))
            .filter(|entry| entry.visible_at <= anchor);
        let action = pending.map_or(Action::Ordinary, |entry| {
            let legal = legal_actions(entry.canonical, self.is_due(entry, anchor));
            legal[choice.action % legal.len()]
        });
        // A skip carries the entry's exact bytes; other blocks may omit them.
        let forced = pending.map(|entry| {
            let carried =
                matches!(action, Action::SkipInvalid | Action::SkipCanonical) || choice.preimage;
            let tx = if carried { entry.bytes.clone() } else { Bytes::new() };
            self.fx.forced_witness(self.hot.l1(), anchor, cursor, tx)
        });
        let mut txs: Vec<TxEnvelope> = (0..choice.mempool).map(mempool_tx).collect();
        let decision = match (action, pending) {
            (Action::Include, Some(entry)) => {
                txs.insert(0, decode_canonical(&entry.bytes).expect("a canonical entry"));
                ForcedDecision::Included(cursor)
            }
            (Action::SkipInvalid, Some(_)) => ForcedDecision::SkippedInvalid(cursor),
            (Action::SkipCanonical, Some(entry)) => {
                ForcedDecision::NeedsSkip { index: cursor, tx: entry.bytes.clone() }
            }
            _ => ForcedDecision::Ordinary,
        };
        let env = envelope(&self.hot, anchor_witness, forced, &txs);
        Block { height, bft: bft_time(&self.hot), anchor, cursor, action, decision, env }
    }

    /// Decides `block` on both apps and checks that they agree. The hot app processes, finalizes
    /// and commits it; the cold app finalizes it (and, when `crash`, replays it after a restart)
    /// and commits it.
    async fn decide(&mut self, block: &Block, crash: bool) -> Result<(), TestCaseError> {
        let (height, cursor) = (block.height, block.cursor);
        let committed = self.hot.state().expect("initialized").clone();
        prop_assert_eq!(self.cold.state(), Some(&committed), "height {}: parents", height);

        // The deterministic checks classify the block as the generator meant it.
        let verdict = validate::validate_block(
            &committed,
            &self.hot.params,
            &block.env,
            height,
            block.bft,
            super::proposal::proposer(),
        )
        .map_err(|e| fail(format!("height {height}: generated block invalid: {e}")))?;
        prop_assert_eq!(&verdict.decision, &block.decision, "height {}: decision", height);
        // A canonical skip's singleton probe: the forced transaction alone, on the committed
        // parent with the candidate's derived attributes. The EL includes nothing.
        let (probe, singleton) = match &block.decision {
            ForcedDecision::NeedsSkip { tx, .. } => {
                let tx = decode_canonical(tx).expect("a canonical skip");
                let tx_list = protocol::shasta::encode_transactions(&[tx]);
                let attrs = rules::payload_attributes(
                    &verdict.expected,
                    verdict.anchor.hash,
                    Some(tx_list),
                );
                let probe =
                    EngineCall::BuildBlock { parent: committed.parent.hash, attrs: attrs.into() };
                (vec![probe], Some(empty_singleton(&verdict)))
            }
            _ => (vec![], None),
        };

        // Hot: ProcessProposal completes the decision, executes the block and caches the verdict;
        // FinalizeBlock reuses it without probing, executing or reading L1 again.
        script(&self.hot, singleton.as_ref());
        let proposal = process_req(height, block.bft, vec![block.env.encode()]);
        let before = self.hot.engine().calls().len();
        let accepted = process(&mut self.hot, proposal.clone()).await;
        prop_assert_eq!(
            accepted,
            response::ProcessProposal::Accept,
            "height {}: halt = {:?}",
            height,
            self.hot.halt
        );
        prop_assert_eq!(probes(&self.hot, before), probe.clone(), "height {}: hot probe", height);
        let cached = self.hot.verdicts.get(&proposal.hash).cloned().expect("a cached verdict");
        let decided = finalize_req(&proposal);
        self.hot.l1().state().calls.clear();
        let before = self.hot.engine().calls().len();
        let hot_out = bounded(finalize(&mut self.hot, decided.clone()))
            .await?
            .map_err(|e| fail(format!("height {height}: hot FinalizeBlock: {e}")))?;
        prop_assert!(self.hot.decided_live, "height {}: hot reuses the verdict", height);
        let hash = block.env.block.header.hash_slow();
        let finalized = verdict.anchor.inbox.last_checkpoint_hash;
        let calls = self.hot.engine().calls();
        prop_assert_eq!(
            &calls[before..],
            &[EngineCall::Forkchoice { head: hash, safe: hash, finalized }][..],
            "height {}: hot FinalizeBlock neither probes nor executes",
            height
        );
        prop_assert!(self.hot.l1().calls().is_empty(), "height {}: hot L1 reads", height);

        // Cold: FinalizeBlock re-validates, confirms a moved anchor in the own L1 and probes a
        // canonical skip itself.
        script(&self.cold, singleton.as_ref());
        self.cold.l1().state().calls.clear();
        let before = self.cold.engine().calls().len();
        let cold_out = bounded(finalize(&mut self.cold, decided.clone()))
            .await?
            .map_err(|e| fail(format!("height {height}: cold FinalizeBlock: {e}")))?;
        prop_assert!(!self.cold.decided_live, "height {}: cold re-validates", height);
        prop_assert_eq!(probes(&self.cold, before), probe.clone(), "height {}: cold probe", height);
        self.check_cold_l1_reads(block)?;

        // Same response and successor state; the cursor moves past exactly a consumed entry.
        prop_assert_eq!(&cold_out, &hot_out, "height {}: FinalizeBlock responses", height);
        prop_assert_eq!(&self.cold.pending, &self.hot.pending, "height {}: pending", height);
        let next = self.hot.pending.clone().expect("FinalizeBlock leaves a pending state");
        let consumed = block.action != Action::Ordinary;
        prop_assert_eq!(
            next.forced_cursor,
            cursor + u64::from(consumed),
            "height {}: cursor after {:?}",
            height,
            block.action
        );
        prop_assert_eq!((next.parent.hash, next.anchor.number), (hash, block.anchor));
        prop_assert_eq!(self.hot.state(), Some(&committed), "height {}: uncommitted", height);
        prop_assert_eq!(self.cold.state(), Some(&committed), "height {}: uncommitted", height);
        let completed =
            Validated { forced: consumed.then_some(cursor), executed: true, ..verdict.clone() };
        prop_assert_eq!(cached, completed, "height {}: cached verdict", height);

        if crash {
            self.restart_cold(&committed).await?;
            script(&self.cold, singleton.as_ref());
            let replayed = bounded(finalize(&mut self.cold, decided))
                .await?
                .map_err(|e| fail(format!("height {height}: replayed FinalizeBlock: {e}")))?;
            prop_assert_eq!(&replayed, &hot_out, "height {}: replayed response", height);
            prop_assert_eq!(self.cold.pending.as_ref(), Some(&next), "height {}: replay", height);
            prop_assert_eq!(probes(&self.cold, 0), probe, "height {}: replayed probe", height);
            self.check_cold_l1_reads(block)?;
        }

        commit(&mut self.hot)
            .await
            .map_err(|e| fail(format!("height {height}: hot Commit: {e}")))?;
        commit(&mut self.cold)
            .await
            .map_err(|e| fail(format!("height {height}: cold Commit: {e}")))?;
        for (app, dir) in [(&self.hot, &self.hot_dir), (&self.cold, &self.cold_dir)] {
            prop_assert_eq!(app.state(), Some(&next), "height {}: committed state", height);
            let stored = Store::volatile(dir.path().to_path_buf()).load().map_err(fail)?;
            prop_assert_eq!(stored.as_ref(), Some(&next), "height {}: persisted", height);
            // The decided block, never a singleton probe's result, is the EL head.
            let head = app.engine().state().chain.get(&height).map(|header| header.hash_slow());
            prop_assert_eq!(head, Some(hash), "height {}: EL head", height);
        }
        Ok(())
    }

    /// Checks the cold app's own-L1 reads for its last `FinalizeBlock` of `block`: none without an
    /// anchor witness; otherwise only anchor confirmations, ending on the block's anchor.
    fn check_cold_l1_reads(&self, block: &Block) -> Result<(), TestCaseError> {
        let calls = self.cold.l1().calls();
        let confirmed =
            calls.iter().all(|c| matches!(c, L1Call::Finalized | L1Call::CanonicalHash(_))) &&
                matches!(calls.last(), Some(L1Call::CanonicalHash(n)) if *n == block.anchor);
        let expected = if block.env.anchor.is_some() { confirmed } else { calls.is_empty() };
        prop_assert!(expected, "height {}: cold own-L1 reads {:?}", block.height, calls);
        Ok(())
    }

    /// Restarts the cold node after `FinalizeBlock`, before `Commit`: its EL keeps the executed
    /// block, its store the committed parent and its own L1 the same chain. CometBFT's handshake
    /// `Info` then reconciles the EL with the parent.
    async fn restart_cold(&mut self, committed: &AppState) -> Result<(), TestCaseError> {
        let engine = self.cold.engine().reopen();
        let l1 = self.fx.l1();
        plant_anchors(&self.fx, &l1, &self.entries);
        let (params, dir) = (self.fx.params.clone(), self.cold_dir.path());
        self.cold = app_with(l1, engine, params, dir, AppOptions::default());
        prop_assert_eq!(self.cold.state(), Some(committed), "the restart loads the parent");
        info(&mut self.cold).await.map_err(|e| fail(format!("Info after a restart: {e}")))?;
        Ok(())
    }

    /// Whether `entry` is due at an anchor on the anchor block `anchor`.
    fn is_due(&self, entry: &Entry, anchor: u64) -> bool {
        Fixture::l1_timestamp(anchor) >= entry.timestamp + self.fx.genesis.forced_inclusion_delay
    }
}

/// The honest actions on a pending entry. Before it is due, a block may stay ordinary or include a
/// canonical transaction at position zero; once due, it must include or skip a canonical
/// transaction, and skip invalid bytes.
fn legal_actions(canonical: bool, due: bool) -> &'static [Action] {
    match (canonical, due) {
        (true, false) => &[Action::Ordinary, Action::Include],
        (false, false) => &[Action::Ordinary],
        (true, true) => &[Action::Include, Action::SkipCanonical],
        (false, true) => &[Action::SkipInvalid],
    }
}

/// The entries `specs` describe: each submitted one forced inclusion delay before the anchor
/// block it comes due at (past the last anchor block: never due in the run).
fn realize(fx: &Fixture, specs: &[EntrySpec]) -> Vec<Entry> {
    let never = ANCHORS[ANCHORS.len() - 1] + 1;
    (0u64..)
        .zip(specs)
        .map(|(index, spec)| {
            let (bytes, canonical) = match &spec.content {
                Content::Canonical { eip1559 } => {
                    (forced_tx(100 + index, *eip1559).encoded_2718().into(), true)
                }
                Content::Empty => (Bytes::new(), false),
                Content::Undecodable(bytes) => (Bytes::copy_from_slice(bytes), false),
            };
            assert_eq!(decode_canonical(&bytes).is_some(), canonical, "{:?}", spec.content);
            let due_at = ANCHORS.get(spec.due).copied().unwrap_or(never);
            Entry {
                bytes,
                canonical,
                visible_at: ANCHORS[spec.visible],
                timestamp: Fixture::l1_timestamp(due_at) - fx.genesis.forced_inclusion_delay,
            }
        })
        .collect()
}

/// Plants the [`ANCHORS`] blocks in `l1` and finalizes them. Each holds the last checkpoint at
/// `H_0` and the entries visible there: a queue prefix, whose length is the tail.
fn plant_anchors(fx: &Fixture, l1: &MockL1, entries: &[Entry]) {
    for number in ANCHORS {
        let mut inbox = fx.inbox_with(fx.genesis.genesis_height + 1);
        inbox.forced_inclusion_queue = (0u64..)
            .zip(entries)
            .filter(|(_, entry)| entry.visible_at <= number)
            .map(|(index, entry)| ForcedEntry {
                index,
                tx_hash: keccak256(&entry.bytes),
                timestamp: entry.timestamp,
                l1_block: entry.visible_at,
            })
            .collect();
        inbox.forced_inclusion_tail = inbox.forced_inclusion_queue.len() as u64;
        fx.advance_l1(l1, number, &inbox, &fx.registry);
    }
}

/// The envelope an honest proposer builds for the next height of `app`: anchored by `anchor` (or
/// on the committed anchor), carrying `forced`, its block exactly `txs` on the derived header, as
/// the mock EL builds an explicit transaction list.
fn envelope(
    app: &App<MockL1, MockEngine>,
    anchor: Option<AnchorWitness>,
    forced: Option<ForcedWitness>,
    txs: &[TxEnvelope],
) -> EtnaEnvelope {
    let state = app.state().expect("initialized");
    let anchor_state = match &anchor {
        Some(witness) => {
            verify_anchor_witness(witness, app.params.inbox).expect("a planted anchor verifies")
        }
        None => state.anchor.clone(),
    };
    let height = state.last_height + 1;
    let expected = validate::expected_header(
        state,
        &app.params,
        height,
        &anchor_state,
        bft_time(app),
        super::proposal::proposer(),
    )
    .expect("derivable header");
    let tx_list = protocol::shasta::encode_transactions(txs);
    let attrs = rules::payload_attributes(&expected, anchor_state.hash, Some(tx_list));
    EtnaEnvelope { block: simple_block(state.parent.hash, &attrs), anchor, committee: None, forced }
}

/// What the EL builds for the singleton probe of the canonical skip `v`: the candidate's derived
/// header without any transaction, the forced one failing on the parent.
fn empty_singleton(v: &Validated) -> ExecutionBlock {
    let tx_list = protocol::shasta::encode_transactions(&[]);
    simple_block(
        v.expected.parent_hash,
        &rules::payload_attributes(&v.expected, v.anchor.hash, Some(tx_list)),
    )
}

/// Scripts the result of a canonical skip's singleton probe, if any, on `app`'s EL.
fn script(app: &App<MockL1, MockEngine>, singleton: Option<&ExecutionBlock>) {
    if let Some(block) = singleton {
        app.engine().state().build_script.push_back(Ok(block.clone()));
    }
}

/// The singleton probes (block builds) `app`'s EL received after its first `from` calls.
fn probes(app: &App<MockL1, MockEngine>, from: usize) -> Vec<EngineCall> {
    let calls = app.engine().calls();
    calls[from..].iter().filter(|c| matches!(c, EngineCall::BuildBlock { .. })).cloned().collect()
}

/// A canonical signed transaction with `nonce`: an EIP-1559 one when `eip1559`, else a legacy one
/// (with the fixed test signature: nothing here recovers a sender).
fn forced_tx(nonce: u64, eip1559: bool) -> TxEnvelope {
    let signature = Signature::new(U256::from(1), U256::from(1), false);
    if eip1559 {
        let tx = TxEip1559 {
            chain_id: 167_001,
            nonce,
            gas_limit: 50_000,
            max_fee_per_gas: 2_000_000_000,
            max_priority_fee_per_gas: 1_000_000,
            to: TxKind::Call(Address::repeat_byte(0x22)),
            value: U256::ZERO,
            access_list: Default::default(),
            input: Bytes::from_static(&[0xfe]),
        };
        TxEnvelope::Eip1559(tx.into_signed(signature))
    } else {
        let tx = TxLegacy {
            chain_id: Some(167_001),
            nonce,
            gas_price: 1_000_000_000,
            gas_limit: 21_000,
            to: TxKind::Call(Address::repeat_byte(0x11)),
            value: U256::from(5),
            input: Bytes::new(),
        };
        TxEnvelope::Legacy(tx.into_signed(signature))
    }
}

/// The `k`-th mempool transaction of a block, distinct from every forced one.
fn mempool_tx(k: usize) -> TxEnvelope {
    let tx = TxLegacy {
        chain_id: Some(167_001),
        nonce: 200 + k as u64,
        gas_price: 1_000_000_000,
        gas_limit: 21_000,
        to: TxKind::Call(Address::repeat_byte(0x33)),
        value: U256::from(1),
        input: Bytes::new(),
    };
    TxEnvelope::Legacy(tx.into_signed(Signature::new(U256::from(1), U256::from(1), false)))
}

/// A failed case with `reason`.
fn fail(reason: impl Display) -> TestCaseError {
    TestCaseError::fail(reason.to_string())
}

/// Awaits a `FinalizeBlock`, failing the case instead of hanging if it still retries after an hour
/// (of paused time, which passes at once).
async fn bounded<T>(call: impl Future<Output = T>) -> Result<T, TestCaseError> {
    tokio::time::timeout(Duration::from_secs(3_600), call)
        .await
        .map_err(|_| fail("FinalizeBlock still retries after an hour"))
}

/// Decides `scenario` on a hot and a cold app, then checks that the final cursor counts every
/// consumed entry.
async fn run(scenario: Scenario) -> Result<(), TestCaseError> {
    let mut run = Run::new(&scenario.entries).await;
    let mut consumed = 0;
    let mut last = Action::Ordinary;
    for choice in &scenario.blocks {
        let block = run.honest_block(choice);
        run.decide(&block, choice.crash).await?;
        consumed += u64::from(block.action != Action::Ordinary);
        last = block.action;
    }
    if last == Action::SkipCanonical {
        // The block after a canonical skip, at the next cursor, is judged alike too.
        let block = run.honest_block(&scenario.follow_up);
        run.decide(&block, scenario.follow_up.crash).await?;
        consumed += u64::from(block.action != Action::Ordinary);
    }
    let state = run.hot.state().expect("initialized");
    prop_assert_eq!(state.forced_cursor, consumed, "every consumed entry advanced the cursor");
    prop_assert_eq!(run.cold.state(), Some(state));
    Ok(())
}

/// Bytes that are never exactly one canonical transaction: malformed or truncated encodings, and
/// a canonical transaction with a trailing byte.
fn undecodable() -> impl Strategy<Value = Vec<u8>> {
    prop_oneof![
        Just(vec![0xff]),
        Just(vec![0x02]),
        Just(vec![0xc0]),
        any::<bool>().prop_map(|eip1559| {
            let mut trailing = forced_tx(99, eip1559).encoded_2718();
            trailing.push(0);
            trailing
        }),
        prop::collection::vec(any::<u8>(), 0..8).prop_map(|tail| [vec![0xff], tail].concat()),
    ]
}

/// What an entry admits: mostly canonical transactions, which can be included or skipped.
fn content() -> impl Strategy<Value = Content> {
    prop_oneof![
        3 => any::<bool>().prop_map(|eip1559| Content::Canonical { eip1559 }),
        1 => Just(Content::Empty),
        1 => undecodable().prop_map(Content::Undecodable),
    ]
}

/// One to three queue entries. The anchor blocks where they appear and come due rise with the
/// queue index, as later submissions land and come due later; most appear at the first anchor
/// block and come due early.
fn entries() -> impl Strategy<Value = Vec<EntrySpec>> {
    let visible = prop_oneof![3 => Just(0usize), 3 => 1..ANCHORS.len()];
    let due = prop_oneof![3 => Just(0usize), 2 => Just(1usize), 3 => 2..=ANCHORS.len()];
    prop::collection::vec((visible, due, content()), 1..=3).prop_map(|specs| {
        let mut visible: Vec<usize> = specs.iter().map(|(visible, _, _)| *visible).collect();
        let mut due: Vec<usize> = specs.iter().map(|(_, due, _)| *due).collect();
        visible.sort_unstable();
        due.sort_unstable();
        visible
            .into_iter()
            .zip(due)
            .zip(specs)
            .map(|((visible, due), (_, _, content))| EntrySpec { visible, due, content })
            .collect()
    })
}

/// One block's choices. The anchor mostly stays, so that entries stay pending across blocks.
fn block_choice() -> impl Strategy<Value = BlockChoice> {
    let anchor_step = prop_oneof![3 => Just(0usize), 2 => Just(1usize), 1 => Just(2usize)];
    (anchor_step, 0..2usize, any::<bool>(), 0..=2usize, prop::bool::weighted(0.25)).prop_map(
        |(anchor_step, action, preimage, mempool, crash)| BlockChoice {
            anchor_step,
            action,
            preimage,
            mempool,
            crash,
        },
    )
}

/// A whole run.
fn scenario() -> impl Strategy<Value = Scenario> {
    (entries(), prop::collection::vec(block_choice(), 1..=MAX_BLOCKS), block_choice())
        .prop_map(|(entries, blocks, follow_up)| Scenario { entries, blocks, follow_up })
}

proptest! {
    #![proptest_config(ProptestConfig { cases: CASES, ..ProptestConfig::default() })]

    /// Hot and cold `FinalizeBlock` agree on every block of a generated forced inclusion run
    /// (see the module docs).
    #[test]
    fn hot_and_cold_finalize_agree_on_forced_inclusion_runs(scenario in scenario()) {
        let runtime = tokio::runtime::Builder::new_current_thread()
            .enable_all()
            .start_paused(true)
            .build()
            .expect("a current-thread runtime");
        runtime.block_on(run(scenario))?;
    }
}
