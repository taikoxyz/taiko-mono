#![allow(non_snake_case)]
use super::handlers::{bond_instructed, proposed, proved};
use rindexer::event::callback_registry::EventCallbackRegistry;
use std::path::PathBuf;

pub async fn shasta_inbox_handlers(manifest_path: &PathBuf, registry: &mut EventCallbackRegistry) {
    bond_instructed::bond_instructed_handler(manifest_path, registry).await;
    proposed::proposed_handler(manifest_path, registry).await;
    proved::proved_handler(manifest_path, registry).await;
}
