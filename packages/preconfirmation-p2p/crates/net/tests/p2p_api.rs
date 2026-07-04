use preconfirmation_net::{P2pConfig, P2pHandle, P2pNode, ValidationAdapter};

#[allow(dead_code)]
fn assert_events(handle: &mut P2pHandle) {
    let _ = handle.events();
}

#[test]
fn p2p_api_compiles() {
    let _cfg = P2pConfig::default();
    let _ctor: fn(P2pConfig, Box<dyn ValidationAdapter>) -> anyhow::Result<(P2pHandle, P2pNode)> =
        P2pNode::new;
}
