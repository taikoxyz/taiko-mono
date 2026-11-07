//! Checkpoint ancestry against the local chain: whenever a block carries an anchor witness, the
//! anchor's proven `lastCheckpoint` must name a block of this node's own committed chain
//! ([`rules::check_checkpoint`]). The committed parent and genesis hashes are known; any other
//! height is the EL's canonical block, whose chain `FinalizeBlock` keeps on the committed head.

use alloy_primitives::B256;

use super::{App, deadline, validate::Rejection};
use crate::{
    engine::{Engine, EngineError},
    l1::L1Source,
    rules,
    store::AppState,
    types::AnchorState,
};

impl<L: L1Source, E: Engine> App<L, E> {
    /// Checks `anchor`'s proven `lastCheckpoint` against the local chain under the committed
    /// `state` ([`rules::check_checkpoint`]). A checkpoint above the parent is refused without an
    /// EL read.
    ///
    /// ¹ An EL without a canonical block at the checkpoint height yet
    /// ([`Rejection::LocalBlockMissing`]), a retryable engine error or an elapsed deadline is a
    /// retryable dependency, never a conflict, so the verdict stays the same on every node that
    /// holds the chain; a malformed EL answer requires repair.
    pub(super) async fn check_anchor_checkpoint(
        &self,
        state: &AppState,
        anchor: &AnchorState,
    ) -> Result<(), Rejection> {
        let inbox = &anchor.inbox;
        let (height, hash) = (inbox.last_checkpoint_height, inbox.last_checkpoint_hash);
        rules::check_checkpoint_height(state.last_height, height)?;
        let local = self.local_block_hash(state, height).await?;
        Ok(rules::check_checkpoint(state.last_height, height, hash, local)?)
    }

    /// The local chain's EL block hash at committed height `number`, at most the parent's: the
    /// committed parent's and the genesis block's come from `state`, any other from the EL's
    /// canonical chain within the engine deadline.
    async fn local_block_hash(&self, state: &AppState, number: u64) -> Result<B256, Rejection> {
        if number == state.last_height {
            return Ok(state.parent.hash);
        }
        if number == state.genesis.genesis_height {
            return Ok(state.genesis.genesis_hash);
        }
        let header = deadline(
            "EL header read",
            self.opts.engine_timeout,
            self.engine.header_by_number(number),
        )
        .await?
        .ok_or(Rejection::LocalBlockMissing(number))?;
        if header.number != number {
            return Err(
                EngineError::HeaderNumberMismatch { requested: number, got: header.number }.into()
            );
        }
        Ok(header.hash_slow())
    }
}
