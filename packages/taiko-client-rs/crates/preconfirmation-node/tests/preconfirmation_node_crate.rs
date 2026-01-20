//! Test to verify the crate has been renamed to preconfirmation-node.

/// Verifies that the preconfirmation-node crate is available and exports the expected types.
#[test]
fn preconfirmation_node_crate_is_available() {
    // Just verify the type exists and is accessible.
    let _ = std::mem::size_of::<preconfirmation_node::PreconfirmationClientConfig>();
}
