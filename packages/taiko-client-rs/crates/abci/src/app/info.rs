//! `Info`, `Query` and `CheckTx`.

use tendermint::{
    AppHash,
    abci::{Code, request, response},
    block::Height,
};

use super::{
    APP_NAME, APP_VERSION, AbciError, App, ErrorClass, app_hash, at_generation_origin, classify,
    cometbft_height, execution_recovery::SuffixRestore, within,
};
use crate::{
    engine::Engine,
    l1::L1Source,
    store::{AppState, ExecutionFloor, Record},
};

/// Response code of a rejected `CheckTx` and of a failed `Query`.
pub const CODE_REJECTED: u32 = 1;

/// The `CheckTx` rejection log: user transactions travel over EL devp2p, never through
/// CometBFT (its mempool is `nop`).
pub const CHECK_TX_LOG: &str = "transactions go to the execution layer";

impl<L: L1Source, E: Engine> App<L, E> {
    /// Handles `Info`: the last committed height and its `app_hash`, appHash of its EL block hash
    /// and the validator state after it (CONS-3.1-8).
    ///
    /// Reports 0 and an empty hash before `InitChain` and while the state is still at the
    /// generation origin, the Etna start S or c (no new-generation block committed): CometBFT's
    /// store is empty and only accepts an app at height 0, to which it re-sends `InitChain`.
    ///
    /// The boundary this reports is established before the server opens its ABCI socket
    /// ([`App::align_startup`]), independently of `Info` and every later CometBFT callback, so
    /// the handshake of a CometBFT started with the app never sees a misaligned app (CONS-3.1-9).
    /// The check here is a defense for each later set of ABCI connections: the first `Info` on a
    /// new set (the handshake of a CometBFT restarted under this running app) reconciles the EL
    /// again ([`App::reconcile_el_once`]) from the app's own retained inputs, never from
    /// CometBFT, so `Info` never reports a height the EL does not hold; temporary failures leave
    /// the same request pending until reconciliation succeeds. The server bumps
    /// [`App::connections`] for every connection it accepts. Within one connection set, once a
    /// reconcile (or `InitChain`) succeeded, `Info` answers from the committed state alone:
    /// CometBFT also sends `Info` for every RPC `/abci_info` call, over its existing connection
    /// and on the same sequential worker as consensus, and an EL hiccup there must neither delay
    /// consensus nor fail the connection.
    ///
    /// Independent Comet restarts also rearm the private signer session. Its bounded background
    /// trust check rechecks the durable EL head and checkpoint ancestry; `Info` never waits for
    /// a future checkpoint height. Missing ancestry keeps signing closed while replay can
    /// continue.
    pub(super) async fn info(&mut self, _req: request::Info) -> Result<response::Info, AbciError> {
        let handshake = !self.el_reconciled();
        self.reconcile_el_once("startup Info").await?;
        if handshake && let Some(state) = &self.state {
            // CometBFT compares this with the stored and replayed headers' AppHash; on a
            // mismatch it stops, and the operator compares these values (SYNC-9-5c).
            let report = super::AppHashReport::of(state);
            tracing::info!(%report, "handshake Info answers the committed app hash");
        }
        let (last_block_height, last_block_app_hash) = match &self.state {
            Some(state) if !at_generation_origin(state) => {
                (cometbft_height(state.last_height), app_hash(state))
            }
            _ => (Height::from(0u32), AppHash::default()),
        };
        Ok(response::Info {
            data: APP_NAME.to_string(),
            version: env!("CARGO_PKG_VERSION").to_string(),
            app_version: APP_VERSION,
            last_block_height,
            last_block_app_hash,
        })
    }

    /// Establishes the committed boundary before the server accepts any ABCI connection, so that
    /// stock CometBFT's handshake, which starts with `Info`, only meets an app whose EL serves
    /// its committed head (CONS-3.1-9). Runs the reconciliation the handshake `Info` also runs,
    /// with signing closed (the trust session stays closed until the worker starts): from the
    /// last state the EL holds, the missing committed blocks are re-executed from the app's
    /// retained execution bodies and the EL's canonical hash at the committed head is compared
    /// with the app's. Missing material is reported, as the trust reason and in the log, with
    /// the height that lacks it, and retried here, outside any handshake; a contradiction is a
    /// safety halt, recorded as fatal evidence like a request's, which stops startup for
    /// investigation. A no-op before `InitChain` (whose own verification makes the EL serve the
    /// origin block).
    pub async fn align_startup(&mut self) -> Result<(), AbciError> {
        let result = self.reconcile_el_once("startup alignment").await;
        match &result {
            Ok(()) => {
                if let Some(state) = &self.state {
                    tracing::info!(
                        height = state.last_height,
                        el_hash = %state.parent.hash,
                        "the EL serves the committed boundary; opening the ABCI socket"
                    );
                }
            }
            Err(error) => {
                self.record_fatal_failure(error);
            }
        }
        result
    }

    /// Reconciles the EL with the committed state ([`App::reconcile_el`]) once per set of ABCI
    /// connections: a no-op without a state or once a reconcile (or `InitChain`) succeeded since
    /// the server accepted its latest connection ([`App::el_reconciled`]). Each failed attempt is
    /// handled by its class ([`App::await_startup_input`], SYNC-9-7): missing data keeps trust
    /// closed and retries (the same request, or the startup alignment) after a [`Backoff`] pause
    /// labelled `what`, a contradiction halts, any other error fails the request.
    ///
    /// Success records the connection count read before the reconcile started, so a connection
    /// accepted meanwhile makes the next `Info` reconcile again.
    ///
    /// [`Backoff`]: super::finalize::Backoff
    pub(super) async fn reconcile_el_once(&mut self, what: &'static str) -> Result<(), AbciError> {
        let Some(state) = &self.state else { return Ok(()) };
        if self.el_reconciled() {
            return Ok(());
        }
        let epoch = self.connections.current();
        let mut backoff = super::finalize::Backoff::startup(what, state.last_height);
        while let Err(error) = self.reconcile_el(state).await {
            self.await_startup_input(&mut backoff, "EL reconciliation", error).await?;
        }
        self.el_reconciled_epoch = Some(epoch);
        Ok(())
    }

    /// Makes sure the EL serves the execution floor of an imported store with its state
    /// ([`App::check_execution_floor`]), then the committed head `state.parent` at
    /// `state.last_height`.
    ///
    /// An EL without a block at the head first gets the committed blocks it lacks re-executed
    /// from the app's retained execution bodies ([`App::restore_committed_execution`]). When a
    /// body, or the EL's state at the origin or import floor below them, is unavailable, the
    /// height lacking it is reported (log and trust reason) and the EL is pointed at the head and
    /// awaited ([`App::sync_el_to`]), so that it can acquire the blocks from its peers; if it
    /// does not, the error is [`AbciError::ExecutionInputMissing`] naming that height. An EL
    /// serving another block there, rejecting the head, or serving another block after accepting
    /// it contradicts the committed chain: [`AbciError::SafetyHalt`]. An EL ahead of the state is
    /// fine: CometBFT replays the missing heights and `FinalizeBlock` re-executes them
    /// idempotently.
    async fn reconcile_el(&self, state: &AppState) -> Result<(), AbciError> {
        if let Some(floor) = state.execution_floor {
            self.check_execution_floor(floor).await?;
        }
        let (number, hash) = (state.last_height, state.parent.hash);
        let opts = self.opts;
        match within("EL header read", opts.engine_timeout, self.engine.header_by_number(number))
            .await?
        {
            Some(header) if header.hash_slow() == hash => Ok(()),
            Some(header) => Err(AbciError::SafetyHalt(format!(
                "execution engine serves {} at committed height {number}, the app state has {hash}",
                header.hash_slow()
            ))),
            None => {
                tracing::info!(
                    number,
                    %hash,
                    "execution engine lacks the committed head; re-executing the retained committed \
                     blocks"
                );
                let (missing, detail) = match self.restore_committed_execution(state).await? {
                    SuffixRestore::Restored => {
                        return self.sync_el_to("EL sync to the committed head", number, hash).await
                    }
                    SuffixRestore::Missing(missing) => {
                        (missing, "waiting for the EL to acquire it")
                    }
                    SuffixRestore::Syncing(missing) => (missing, "the EL is syncing below it"),
                };
                let pending = AbciError::ExecutionInputMissing {
                    head: number,
                    missing,
                    detail: detail.into(),
                };
                tracing::warn!(number, missing, %hash, "{pending}");
                self.trust.await_authentication(pending.to_string());
                self.sync_el_to("EL sync to the committed head", number, hash).await.map_err(
                    |error| match classify(&error) {
                        ErrorClass::MissingData => AbciError::ExecutionInputMissing {
                            head: number,
                            missing,
                            detail: error.to_string(),
                        },
                        _ => error,
                    },
                )
            }
        }
    }

    /// Makes sure the own EL serves the import's execution floor, the block the import landed
    /// (DATA-5.4-4), and still holds its state (DATA-5.4-6). An EL serving another block there
    /// contradicts the authenticated import: [`AbciError::SafetyHalt`]. An EL without the block
    /// or its state is missing data, [`AbciError::ElBlockMissing`], which the startup
    /// reconciliation retries with trust closed (SYNC-9-7). Engine errors and deadlines are
    /// classified as for the head.
    async fn check_execution_floor(&self, floor: ExecutionFloor) -> Result<(), AbciError> {
        let ExecutionFloor { number, hash } = floor;
        let timeout = self.opts.engine_timeout;
        match within("EL execution floor read", timeout, self.engine.header_by_number(number))
            .await?
        {
            Some(header) if header.hash_slow() == hash => {}
            Some(header) => {
                return Err(AbciError::SafetyHalt(format!(
                    "execution engine serves {} at execution floor {number}, the landed import \
                     has {hash}",
                    header.hash_slow()
                )));
            }
            None => return Err(AbciError::ElBlockMissing(number)),
        }
        let state = self.engine.historical_state_available(hash);
        if within("EL execution floor state read", timeout, state).await? {
            Ok(())
        } else {
            Err(AbciError::ElBlockMissing(number))
        }
    }

    /// Handles `Query`.
    ///
    /// Paths: `/trust` answers the JSON trust snapshot; `/status` answers the JSON
    /// [`Status`](super::Status); `/signers` answers the JSON [`Signers`](crate::store::Signers)
    /// of the committed state, where the sets that sign the next two heights come from;
    /// `/val_state/<height>`, with a canonical decimal height, answers the raw validator-state
    /// preimage of [`App::val_state_preimage`]. Anything else (an unknown path or height, or any
    /// query but `/trust` before `InitChain`) answers code [`CODE_REJECTED`] with the reason in
    /// `log`.
    /// `height` is the last committed height. Callers authenticate the answers themselves.
    pub(super) fn query(&self, req: crate::wire::request::Query) -> response::Query {
        let height =
            self.state.as_ref().map_or(Height::from(0u32), |s| cometbft_height(s.last_height));
        match self.query_value(&req.path) {
            Ok(value) => response::Query { value: value.into(), height, ..Default::default() },
            Err(log) => response::Query {
                code: Code::from(CODE_REJECTED),
                log,
                height,
                ..Default::default()
            },
        }
    }

    /// The answer to the query `path`, or the reason it has none.
    fn query_value(&self, path: &str) -> Result<Vec<u8>, String> {
        if path == "/trust" {
            return serde_json::to_vec(&self.trust.snapshot()).map_err(|e| e.to_string());
        }
        let Some(state) = &self.state else {
            return Err("the app is not initialized".into());
        };
        if path == "/status" {
            let status = self.status().ok_or("the app is not initialized")?;
            return serde_json::to_vec(&status).map_err(|e| e.to_string());
        }
        if path == "/signers" {
            return serde_json::to_vec(&state.signers).map_err(|e| e.to_string());
        }
        let Some(height) = path.strip_prefix("/val_state/") else {
            return Err(format!("unknown query path {path:?}"));
        };
        let parsed = height.parse::<u64>().ok().filter(|h| h.to_string() == height);
        let height = parsed.ok_or_else(|| format!("invalid height {height:?}"))?;
        self.val_state_preimage(height)
    }

    /// The validator-state preimage
    /// ([`ValState::encode`](crate::valstate::ValState::encode)) after the committed `height`: the
    /// head state's when `height` is the last committed height, else the state the store
    /// recomputes from its newest snapshot at or below `height` and the update records since
    /// ([`Store::load_val_state`](crate::store::Store::load_val_state)). Stock CometBFT's stored
    /// validator-set lookup is never a source.
    ///
    /// Every height in the retained range answers: from s − 1, where s is the committed
    /// anchor's checkpoint ([`AppState::comet_history_floor`]), but never below the generation
    /// origin, through `last_height`. s − 1's is the preimage an import package at s carries
    /// (5.4). Any other height and a state not yet initialized are errors naming the cause. A
    /// state the store cannot recompute (no snapshot, or a missing or corrupt record on the way)
    /// or cannot read is missing data, which keeps the node retrying: an error naming the cause,
    /// logged as a warning.
    pub fn val_state_preimage(&self, height: u64) -> Result<Vec<u8>, String> {
        let state = self.state.as_ref().ok_or("the app is not initialized")?;
        let floor = state.comet_history_floor().saturating_sub(1).max(state.origin_height());
        let last = state.last_height;
        if !(floor..=last).contains(&height) {
            return Err(format!(
                "the validator state at height {height} is not retained (retained: {floor}..={last})"
            ));
        }
        if height == last {
            return Ok(state.val_state.encode());
        }
        let reason = match self.store.load_val_state(height) {
            Ok(Record::Valid(recomputed)) => return Ok(recomputed.encode()),
            Ok(Record::Missing) => format!("no validator-state snapshot at or below {height}"),
            Ok(Record::Corrupt(reason)) => reason,
            Err(error) => format!("cannot read the validator records: {error}"),
        };
        tracing::warn!(
            height,
            %reason,
            "validator state at {height} is missing data; recomputing needs a snapshot at or \
             below it and the update records since"
        );
        Err(format!("the validator state at height {height} cannot be recomputed: {reason}"))
    }

    /// Handles `CheckTx`: rejects every transaction (the CometBFT mempool is `nop`; user
    /// transactions travel over EL devp2p).
    pub(super) fn check_tx(&self, _req: request::CheckTx) -> response::CheckTx {
        response::CheckTx {
            code: Code::from(CODE_REJECTED),
            log: CHECK_TX_LOG.to_string(),
            ..Default::default()
        }
    }
}
