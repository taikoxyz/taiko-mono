use bindings::codec_optimized::{
    ICheckpointStore::Checkpoint,
    IInbox::{CoreState, Proposal, TransitionRecord},
};

/// Data bundle expected by the proposer when preparing the next Shasta inbox proposal.
#[derive(Clone)]
pub struct ShastaProposeInput {
    /// Latest `CoreState` of the Shasta inbox contract.
    pub core_state: CoreState,
    /// The last on-chain proposal. And another on-chain proposal that occupying the ring-buffer
    /// slot of the next proposal to be proposed, if any.
    pub proposals: Vec<Proposal>,
    /// Transitions that are ready to be finalized.
    pub transition_records: Vec<TransitionRecord>,
    /// Checkpoint after all provided transitions have been finalized.
    pub checkpoint: Checkpoint,
}

pub trait ShastaProposeInputReader {
    /// Assemble the input for proposing a Shasta inbox proposal.
    fn read_shasta_propose_input(&self) -> Option<ShastaProposeInput>;
}
