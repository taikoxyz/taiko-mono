use libp2p::{
    gossipsub::{self, IdentTopic},
    identify, ping, request_response as rr,
    swarm::derive_prelude::*,
};
use libp2p_allow_block_list::{Behaviour as BlockListBehaviour, BlockedPeers};
use libp2p_connection_limits::{Behaviour as ConnectionLimitsBehaviour, ConnectionLimits};

/// Combined libp2p behaviour: ping, identify, gossipsub, request-response, and gating behaviours.
#[derive(NetworkBehaviour)]
pub struct NetBehaviour {
    pub ping: ping::Behaviour,
    pub identify: identify::Behaviour,
    pub gossipsub: gossipsub::Behaviour,
    pub commitments_rr: rr::Behaviour<crate::codec::CommitmentsCodec>,
    pub raw_txlists_rr: rr::Behaviour<crate::codec::RawTxListCodec>,
    pub head_rr: rr::Behaviour<crate::codec::HeadCodec>,
    pub block_list: BlockListBehaviour<BlockedPeers>,
    pub conn_limits: ConnectionLimitsBehaviour,
}

impl NetBehaviour {
    pub fn new(
        local_public_key: libp2p::identity::PublicKey,
        topics: (IdentTopic, IdentTopic),
        protocols: crate::codec::Protocols,
    ) -> Self {
        let ping = ping::Behaviour::default();
        let identify = identify::Behaviour::new(identify::Config::new(
            "preconf-p2p/0.1".into(),
            local_public_key,
        ));

        let gs_config = kona_gossip::default_config_builder()
            .validation_mode(gossipsub::ValidationMode::Permissive)
            .build()
            .expect("gossipsub config");
        let mut gossipsub =
            gossipsub::Behaviour::new(gossipsub::MessageAuthenticity::Anonymous, gs_config)
                .expect("gossipsub behaviour");
        gossipsub.subscribe(&topics.0).expect("subscribe commitments");
        gossipsub.subscribe(&topics.1).expect("subscribe raw txlists");

        use kona_peers::PeerScoreLevel;
        let topic_hashes = vec![topics.0.hash().clone(), topics.1.hash().clone()];
        if let Some(params) = PeerScoreLevel::Light.to_params(topic_hashes, true, 2) {
            let thresholds = PeerScoreLevel::thresholds();
            let _ = gossipsub.with_peer_score(params, thresholds);
        }

        let commitments_rr = rr::Behaviour::with_codec(
            crate::codec::CommitmentsCodec::default(),
            std::iter::once((protocols.commitments.clone(), rr::ProtocolSupport::Full)),
            rr::Config::default(),
        );
        let raw_txlists_rr = rr::Behaviour::with_codec(
            crate::codec::RawTxListCodec::default(),
            std::iter::once((protocols.raw_txlists.clone(), rr::ProtocolSupport::Full)),
            rr::Config::default(),
        );

        let head_rr = rr::Behaviour::with_codec(
            crate::codec::HeadCodec::default(),
            std::iter::once((protocols.head.clone(), rr::ProtocolSupport::Full)),
            rr::Config::default(),
        );

        let block_list = BlockListBehaviour::<BlockedPeers>::default();
        let conn_limits = ConnectionLimitsBehaviour::new(ConnectionLimits::default());

        Self {
            ping,
            identify,
            gossipsub,
            commitments_rr,
            raw_txlists_rr,
            head_rr,
            block_list,
            conn_limits,
        }
    }
}
