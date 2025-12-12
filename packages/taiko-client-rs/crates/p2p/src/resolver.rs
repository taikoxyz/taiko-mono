//! Helpers for lookahead resolver integration.

use std::sync::Arc;

/// Shared handle to a lookahead resolver implementation used by the network service.
pub type LookaheadHandle = Arc<dyn preconfirmation_service::LookaheadResolver>;

/// Convenience constructor for callers that do not yet have a lookahead resolver.
pub fn no_lookahead() -> Option<LookaheadHandle> {
    None
}
