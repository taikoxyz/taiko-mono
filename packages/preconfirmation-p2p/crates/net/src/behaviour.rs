//! libp2p behaviour bundle combining ping, identify, gossipsub, req/resp, and gating for
//! preconfirmation networking.

use anyhow::Result;
use libp2p::{
    gossipsub::{self, IdentTopic},
    identify, ping, request_response as rr,
    swarm::derive_prelude::*,
};
use libp2p_allow_block_list::{Behaviour as BlockListBehaviour, BlockedPeers};
use libp2p_connection_limits::{Behaviour as ConnectionLimitsBehaviour, ConnectionLimits};
use preconfirmation_types::MAX_GOSSIP_SIZE_BYTES;
use std::{collections::HashMap, iter, time::Duration};

/// Combined libp2p behaviour: ping, identify, gossipsub, request-response, and gating behaviours.
///
/// This struct bundles multiple libp2p functionalities into a single network behaviour,
/// allowing them to be managed by a single `Swarm` instance.
#[derive(NetworkBehaviour)]
pub struct NetBehaviour {
    /// The `Ping` protocol, used to measure latency and keep connections alive.
    pub ping: ping::Behaviour,
    /// The `Identify` protocol, used to exchange peer information.
    pub identify: identify::Behaviour,
    /// The `Gossipsub` protocol, used for publish-subscribe messaging.
    pub gossipsub: gossipsub::Behaviour,
    /// Request-response protocol for preconfirmation commitments.
    pub commitments_rr: rr::Behaviour<crate::codec::CommitmentsCodec>,
    /// Request-response protocol for raw transaction lists.
    pub raw_txlists_rr: rr::Behaviour<crate::codec::RawTxListCodec>,
    /// Request-response protocol for preconfirmation head.
    pub head_rr: rr::Behaviour<crate::codec::HeadCodec>,
    /// Behaviour for blocking and allowing peers based on various criteria.
    pub block_list: BlockListBehaviour<BlockedPeers>,
    /// Behaviour for enforcing connection limits.
    pub conn_limits: ConnectionLimitsBehaviour,
}

impl NetBehaviour {
    /// Creates a new `NetBehaviour` instance with the given configuration.
    ///
    /// # Arguments
    ///
    /// * `keypair` - The identity keypair of the local peer (used for identify + signed gossip).
    /// * `topics` - A tuple containing the `IdentTopic` for commitments and raw transaction lists,
    ///   used to subscribe to gossipsub topics.
    /// * `protocols` - The `Protocols` configuration, defining the request-response protocol IDs.
    ///
    /// # Returns
    ///
    /// A new `NetBehaviour` instance.
    pub fn new(
        keypair: libp2p::identity::Keypair,
        topics: (IdentTopic, IdentTopic),
        protocols: crate::codec::Protocols,
        cfg: &crate::config::NetworkConfig,
    ) -> Result<Self> {
        let local_public_key = keypair.public();
        let ping = ping::Behaviour::default();
        let identify = identify::Behaviour::new(identify::Config::new(
            "preconf-p2p/0.1".into(),
            local_public_key,
        ));

        let gs_config = kona_gossip::default_config_builder()
            // Align max frame size with preconfirmation_types::MAX_GOSSIP_SIZE_BYTES (spec cap).
            .max_transmit_size(MAX_GOSSIP_SIZE_BYTES)
            .heartbeat_interval(cfg.gossipsub_heartbeat)
            // Hold messages until application validation completes to avoid propagating invalid
            // gossip.
            .validation_mode(gossipsub::ValidationMode::Strict)
            .build()
            .map_err(|e| anyhow::anyhow!("gossipsub config: {e}"))?;
        let mut gossipsub =
            gossipsub::Behaviour::new(gossipsub::MessageAuthenticity::Signed(keypair), gs_config)
                .map_err(|e| anyhow::anyhow!("gossipsub behaviour: {e}"))?;
        gossipsub
            .subscribe(&topics.0)
            .map_err(|e| anyhow::anyhow!("subscribe commitments: {e}"))?;
        gossipsub
            .subscribe(&topics.1)
            .map_err(|e| anyhow::anyhow!("subscribe raw txlists: {e}"))?;

        // Spec §7.1 scoring: enable gossipsub v1.1 scoring with app feedback-like weights.
        use libp2p::gossipsub::{PeerScoreParams, PeerScoreThresholds, TopicScoreParams};
        let thresholds = PeerScoreThresholds {
            gossip_threshold: -1.0,
            publish_threshold: -2.0,
            graylist_threshold: -5.0,
            accept_px_threshold: 0.0,
            opportunistic_graft_threshold: 0.5,
        };

        // Build per-topic params aligned with the spec defaults.
        let mut topic_params = HashMap::new();
        for topic in [&topics.0, &topics.1] {
            let p = TopicScoreParams {
                invalid_message_deliveries_weight: 2.0,
                invalid_message_deliveries_decay: 0.99,
                first_message_deliveries_weight: 0.5,
                first_message_deliveries_decay: 0.999,
                time_in_mesh_weight: 0.0,
                time_in_mesh_quantum: Duration::from_secs(1),
                time_in_mesh_cap: 3600.0,
                ..Default::default()
            };
            topic_params.insert(topic.hash().clone(), p);
        }

        let params = PeerScoreParams {
            topics: topic_params,
            app_specific_weight: 1.0,
            decay_interval: Duration::from_secs(10),
            decay_to_zero: 0.1,
            retain_score: Duration::from_secs(3600),
            ..Default::default()
        };

        let _ = gossipsub.with_peer_score(params, thresholds);

        let reqresp_cfg = rr::Config::default()
            .with_request_timeout(cfg.request_timeout)
            .with_max_concurrent_streams(cfg.max_reqresp_concurrent_streams);

        let commitments_rr = rr::Behaviour::with_codec(
            crate::codec::CommitmentsCodec::default(),
            iter::once((protocols.commitments.clone(), rr::ProtocolSupport::Full)),
            reqresp_cfg.clone(),
        );
        let raw_txlists_rr = rr::Behaviour::with_codec(
            crate::codec::RawTxListCodec::default(),
            iter::once((protocols.raw_txlists.clone(), rr::ProtocolSupport::Full)),
            reqresp_cfg.clone(),
        );

        let head_rr = rr::Behaviour::with_codec(
            crate::codec::HeadCodec::default(),
            iter::once((protocols.head.clone(), rr::ProtocolSupport::Full)),
            reqresp_cfg,
        );

        let limits = ConnectionLimits::default()
            .with_max_pending_incoming(cfg.max_pending_incoming)
            .with_max_pending_outgoing(cfg.max_pending_outgoing)
            .with_max_established_incoming(cfg.max_established_incoming)
            .with_max_established_outgoing(cfg.max_established_outgoing)
            .with_max_established(cfg.max_established_total)
            .with_max_established_per_peer(cfg.max_established_per_peer);

        let block_list = BlockListBehaviour::<BlockedPeers>::default();
        let conn_limits = ConnectionLimitsBehaviour::new(limits);

        Ok(Self {
            ping,
            identify,
            gossipsub,
            commitments_rr,
            raw_txlists_rr,
            head_rr,
            block_list,
            conn_limits,
        })
    }
}
