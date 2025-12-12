use std::sync::Arc;

pub type LookaheadHandle = Arc<dyn preconfirmation_service::LookaheadResolver>;

/// Convenience constructor for callers that do not yet have a lookahead resolver.
pub fn no_lookahead() -> Option<LookaheadHandle> {
    None
}

