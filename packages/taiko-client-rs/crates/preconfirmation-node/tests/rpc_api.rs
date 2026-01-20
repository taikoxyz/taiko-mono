//! Test to verify the RPC API trait and implementation are available.

/// Verifies that the RPC API trait is generated and the implementation exists.
#[test]
fn rpc_api_trait_is_generated() {
    fn assert_trait<T: preconfirmation_node::rpc::PreconfRpcApiServer>() {}
    assert_trait::<preconfirmation_node::rpc::PreconfRpcApiImpl>();
}
