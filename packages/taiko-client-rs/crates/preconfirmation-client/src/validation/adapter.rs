//! Builders for the P2P validation adapter.

use std::sync::Arc;

use preconfirmation_net::{
    LocalValidationAdapter, LookaheadResolver, LookaheadValidationAdapter, ValidationAdapter,
};
use preconfirmation_types::Bytes20;

/// Build a network validation adapter from the optional lookahead resolver.
pub fn build_network_validator(
    expected_slasher: Option<Bytes20>,
    resolver: Option<Arc<dyn LookaheadResolver>>,
) -> Box<dyn ValidationAdapter> {
    // Choose the base validator based on lookahead availability.
    let adapter: Box<dyn ValidationAdapter> = match resolver {
        Some(resolver) => {
            // Use the lookahead validator when available.
            Box::new(LookaheadValidationAdapter::new(expected_slasher, resolver))
        }
        None => {
            // Use the local validator when no lookahead resolver is configured.
            Box::new(LocalValidationAdapter::new(expected_slasher))
        }
    };
    adapter
}
