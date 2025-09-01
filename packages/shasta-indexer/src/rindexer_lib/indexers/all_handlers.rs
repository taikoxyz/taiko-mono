use super::indexer::shasta_inbox_proposal::shasta_inbox_proposal_handlers;
use rindexer::event::callback_registry::EventCallbackRegistry;
use std::path::PathBuf;

pub async fn register_all_handlers(manifest_path: &PathBuf) -> EventCallbackRegistry {
    let mut registry = EventCallbackRegistry::new();
    shasta_inbox_proposal_handlers(manifest_path, &mut registry).await;
    registry
}
