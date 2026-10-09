//! `Info` (spec §5.2), `Query` and `CheckTx` (spec §5.6).

use tendermint::{
    AppHash,
    abci::{Code, request, response},
    block::Height,
};

use super::{
    APP_NAME, APP_VERSION, AbciError, App, ELSYNC_POLL, app_hash, at_genesis, cometbft_height,
    within,
};
use crate::{elsync::ensure_block, engine::Engine, l1::L1Source, store::AppState};

/// Response code of a rejected `CheckTx` and of a failed `Query`.
pub const CODE_REJECTED: u32 = 1;

/// The `CheckTx` rejection log: user transactions travel over EL devp2p (D16).
pub const CHECK_TX_LOG: &str = "transactions go to the execution layer";

impl<L: L1Source, E: Engine> App<L, E> {
    /// Handles `Info`: the last committed height and its EL block hash.
    ///
    /// Reports 0 and an empty hash before `InitChain` and while the state is still at the
    /// genesis anchor `B*` (no PoS block committed): CometBFT's store is then empty, and it only
    /// accepts an app at height 0, to which it re-sends `InitChain`.
    ///
    /// With a state, the first `Info` after the process started (CometBFT's handshake) first
    /// reconciles the EL with it ([`App::reconcile_el`]), so the handshake replays on top of an
    /// EL that holds the committed head; its failure is the request's error and the next `Info`
    /// tries again. Once a reconcile (or `InitChain`) succeeded, `Info` answers from the
    /// committed state alone: CometBFT also sends `Info` for every RPC `/abci_info` call, on the
    /// same sequential worker as consensus, and an EL hiccup there must neither delay consensus
    /// nor fail the connection.
    pub(super) async fn info(&mut self, _req: request::Info) -> Result<response::Info, AbciError> {
        let (last_block_height, last_block_app_hash) = match &self.state {
            None => (Height::from(0u32), AppHash::default()),
            Some(state) => {
                if !self.el_reconciled {
                    self.reconcile_el(state).await?;
                    self.el_reconciled = true;
                }
                if at_genesis(state) {
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
    /// An EL without a block there is pointed at the head and awaited ([`ensure_block`]); an EL
    /// serving another block there, rejecting the head, or serving another block after
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
                within(
                    "EL sync to the committed head",
                    opts.elsync_timeout + opts.engine_timeout,
                    ensure_block(&self.engine, number, hash, opts.elsync_timeout, ELSYNC_POLL),
                )
                .await
            }
        }
    }

    /// Handles `Query`.
    ///
    /// Paths: `/status` answers the JSON [`Status`](super::Status); `/committee/<epoch>` answers
    /// the JSON [`CommitteeState`](crate::store::CommitteeState) of a known epoch. Anything else
    /// (an unknown path or epoch, or any query before `InitChain`) answers code
    /// [`CODE_REJECTED`] with the reason in `log`. `height` is the last committed height.
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

    /// The JSON answer to the query `path`, or the reason it has none.
    fn query_value(&self, path: &str) -> Result<Vec<u8>, String> {
        let state = self.state.as_ref().ok_or("the app is not initialized")?;
        if path == "/status" {
            let status = self.status().ok_or("the app is not initialized")?;
            return serde_json::to_vec(&status).map_err(|e| e.to_string());
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

    /// Handles `CheckTx`: rejects every transaction (the CometBFT mempool is `nop`, D16).
    pub(super) fn check_tx(&self, _req: request::CheckTx) -> response::CheckTx {
        response::CheckTx {
            code: Code::from(CODE_REJECTED),
            log: CHECK_TX_LOG.to_string(),
            ..Default::default()
        }
    }
}
