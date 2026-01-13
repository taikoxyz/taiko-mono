use std::task::Poll;

use preconfirmation_net::{LocalValidationAdapter, P2pConfig, P2pNode};

#[tokio::test]
async fn p2p_node_run_is_continuous() {
    let mut cfg = P2pConfig::default();
    cfg.listen_addr = std::net::SocketAddr::from(([127, 0, 0, 1], 0));
    cfg.discovery_listen = std::net::SocketAddr::from(([127, 0, 0, 1], 0));
    cfg.enable_discovery = false;

    let validator = Box::new(LocalValidationAdapter::new(None));
    let (_handle, node) = P2pNode::new(cfg, validator).expect("p2p node");

    let mut run = Box::pin(node.run());
    let poll = futures::poll!(run.as_mut());
    assert!(matches!(poll, Poll::Pending));
}
