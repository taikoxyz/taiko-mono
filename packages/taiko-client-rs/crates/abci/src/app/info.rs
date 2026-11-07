//! `Info`, `Query` and `CheckTx`.

use tendermint::{
    AppHash,
    abci::{Code, request, response},
    block::Height,
};

use super::{
    APP_NAME, APP_VERSION, AbciError, App, app_hash, at_generation_origin, cometbft_height, within,
};
use crate::{GRID_INTERVAL, engine::Engine, l1::L1Source, store::AppState, valstate::ValState};

/// Response code of a rejected `CheckTx` and of a failed `Query`.
pub const CODE_REJECTED: u32 = 1;

/// The `CheckTx` rejection log: user transactions travel over EL devp2p, never through
/// CometBFT (its mempool is `nop`).
pub const CHECK_TX_LOG: &str = "transactions go to the execution layer";

impl<L: L1Source, E: Engine> App<L, E> {
    /// Handles `Info`: the last committed height and its EL block hash.
    ///
    /// Reports 0 and an empty hash before `InitChain` and while the state is still at the
    /// generation origin B* or c (no new-generation block committed): CometBFT's store is empty and
    /// only accepts an app at height 0, to which it re-sends `InitChain`.
    ///
    /// With a state, the first `Info` after the process started (CometBFT's handshake) first
    /// reconciles the EL with it ([`App::reconcile_el`]), so the handshake replays on top of an
    /// EL that holds the committed head; temporary failures leave the same request pending
    /// until reconciliation succeeds. Once a reconcile (or `InitChain`) succeeded, `Info` answers
    /// from the committed state alone: CometBFT also sends `Info` for every RPC `/abci_info`
    /// call, on the same sequential worker as consensus, and an EL hiccup there must neither
    /// delay consensus nor fail the connection.
    ///
    /// Independent Comet restarts rearm the private signer session. Its bounded background
    /// trust check rechecks the durable EL head and checkpoint ancestry; ordinary Info calls
    /// retain this fast once-per-process reconciliation behavior and never wait for a future
    /// checkpoint height. Missing ancestry keeps signing closed while replay can continue.
    pub(super) async fn info(&mut self, _req: request::Info) -> Result<response::Info, AbciError> {
        let (last_block_height, last_block_app_hash) = match &self.state {
            None => (Height::from(0u32), AppHash::default()),
            Some(state) => {
                if !self.el_reconciled {
                    let mut pause = super::FINALIZE_RETRY_INITIAL;
                    loop {
                        match self.reconcile_el(state).await {
                            Ok(()) => break,
                            Err(error) if super::init::startup_input_unavailable(&error) => {
                                self.trust.await_authentication(error.to_string());
                                tracing::warn!(%error, ?pause, "startup reconciliation waits for the execution engine");
                                tokio::time::sleep(pause).await;
                                pause = (pause * 2).min(super::FINALIZE_RETRY_MAX);
                            }
                            Err(error) => return Err(super::trust::classify_trust_error(error)),
                        }
                    }
                    self.el_reconciled = true;
                }
                if at_generation_origin(state) {
                    (Height::from(0u32), AppHash::default())
                } else {
                    (cometbft_height(state.last_height), app_hash(state.parent.hash))
                }
            }
        };
        Ok(response::Info {
            data: APP_NAME.to_string(),
            version: env!("CARGO_PKG_VERSION").to_string(),
            app_version: APP_VERSION,
            last_block_height,
            last_block_app_hash,
        })
    }

    /// Makes sure the EL serves the committed head `state.parent` at `state.last_height`.
    ///
    /// An EL without a block there is pointed at the head and awaited ([`App::sync_el_to`]); an
    /// EL serving another block there, rejecting the head, or serving another block after
    /// accepting it contradicts the committed chain: [`AbciError::SafetyHalt`]. An EL ahead of
    /// the state is fine: CometBFT replays the missing heights and `FinalizeBlock` re-executes
    /// them idempotently.
    async fn reconcile_el(&self, state: &AppState) -> Result<(), AbciError> {
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
                tracing::info!(number, %hash, "execution engine lacks the committed head; syncing");
                self.sync_el_to("EL sync to the committed head", number, hash).await
            }
        }
    }

    /// Handles `Query`.
    ///
    /// Paths: `/status` answers the JSON [`Status`](super::Status); `/committee/<epoch>` answers
    /// the JSON [`CommitteeState`](crate::store::CommitteeState) of a known epoch;
    /// `/val_state/<height>`, with a canonical decimal height, answers the raw validator-state
    /// preimage of [`App::val_state_preimage`]. Anything else (an unknown path, epoch or height,
    /// or any query before `InitChain`) answers code [`CODE_REJECTED`] with the reason in `log`.
    /// `height` is the last committed height. Callers authenticate the answers themselves.
    pub(super) fn query(&self, req: request::Query) -> response::Query {
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
        let state = self.state.as_ref().ok_or("the app is not initialized")?;
        if path == "/status" {
            let status = self.status().ok_or("the app is not initialized")?;
            return serde_json::to_vec(&status).map_err(|e| e.to_string());
        }
        if let Some(height) = path.strip_prefix("/val_state/") {
            let parsed = height.parse::<u64>().ok().filter(|h| h.to_string() == height);
            let height = parsed.ok_or_else(|| format!("invalid height {height:?}"))?;
            return self.val_state_preimage(height);
        }
        let Some(epoch) = path.strip_prefix("/committee/") else {
            return Err(format!("unknown query path {path:?}"));
        };
        let epoch: u64 = epoch.parse().map_err(|_| format!("invalid epoch {epoch:?}"))?;
        let committee = state
            .committees
            .get(&epoch)
            .ok_or_else(|| format!("no committee known for epoch {epoch}"))?;
        serde_json::to_vec(committee).map_err(|e| e.to_string())
    }

    /// The validator-state preimage ([`ValState::encode`]) after the committed grid `height`: the
    /// head state's when `height` is the last committed height, else its durable sidecar.
    ///
    /// Only grid heights (multiples of [`GRID_INTERVAL`]) within the retained range
    /// `[comet_history_floor, last_height]` answer; any other height, a state not yet
    /// initialized, and a sidecar that is missing, unreadable or not framed as a preimage of that
    /// very height ([`ValState::framed_height`]) are errors naming the cause. The sidecar's
    /// entries are not decoded again on this serial worker: the app wrote them, and every reader
    /// authenticates the hash. A failing sidecar at a retained height other than the generation
    /// origin (which no Commit writes) means lost durable state and is logged as a warning.
    pub fn val_state_preimage(&self, height: u64) -> Result<Vec<u8>, String> {
        let state = self.state.as_ref().ok_or("the app is not initialized")?;
        if !height.is_multiple_of(GRID_INTERVAL) {
            return Err(format!(
                "height {height} is not a grid height (a multiple of {GRID_INTERVAL})"
            ));
        }
        let (floor, last) = (state.comet_history_floor(), state.last_height);
        if !(floor..=last).contains(&height) {
            return Err(format!(
                "the validator state at height {height} is not retained (retained: {floor}..={last})"
            ));
        }
        if height == last {
            return Ok(state.val_state.encode());
        }
        let sidecar = self
            .store
            .load_val_state(height)
            .map_err(|e| format!("cannot read the validator state at height {height}: {e}"))
            .and_then(|loaded| {
                let preimage = loaded.ok_or_else(|| {
                    format!("the validator-state sidecar of retained height {height} is missing")
                })?;
                match ValState::framed_height(&preimage) {
                    Ok(framed) if framed == height => Ok(preimage),
                    Ok(framed) => Err(format!(
                        "the validator-state sidecar of height {height} holds height {framed}"
                    )),
                    Err(e) => Err(format!(
                        "the validator-state sidecar of height {height} is corrupt: {e}"
                    )),
                }
            });
        if let Err(reason) = &sidecar &&
            height != state.origin_height()
        {
            tracing::warn!(
                height,
                %reason,
                "lost durable validator state: checkpoint trust and landings at this height wait \
                 until the sidecar is restored"
            );
        }
        sidecar
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
