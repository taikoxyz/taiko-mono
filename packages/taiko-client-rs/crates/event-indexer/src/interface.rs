use bindings::codec_optimized::{
    ICheckpointStore::Checkpoint,
    IInbox::{CoreState, Proposal, TransitionRecord},
};

#[derive(Clone)]
pub struct ShastaProposeInput {
    pub core_state: CoreState,
    pub proposals: Vec<Proposal>,
    pub transition_records: Vec<TransitionRecord>,
    pub checkpoint: Checkpoint,
}

pub trait ShastaProposeInputReader {
    fn read_shasta_propose_input(&self) -> Option<ShastaProposeInput>;
}
