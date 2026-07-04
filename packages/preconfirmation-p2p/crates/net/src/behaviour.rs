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
        let (score_params, score_thresholds) = peer_score_settings(&topics);
        gossipsub
            .with_peer_score(score_params, score_thresholds)
            .map_err(|e| anyhow::anyhow!("gossipsub peer score: {e}"))?;

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

/// Builds the gossipsub v1.1 peer-score parameters and thresholds for the
/// preconfirmation topics per spec §7.1.
///
/// The spec's `invalidMessageDeliveriesWeight: 2.0` is a penalty magnitude: gossipsub
/// requires penalty weights to be negative and rejects the whole parameter set otherwise,
/// so it is applied as `-2.0`. Mesh-delivery penalties (P3/P3b) are not part of the spec
/// profile and are explicitly disabled; their libp2p defaults would penalize peers on
/// quiet topics. The IP-colocation, behaviour, and slow-peer penalties are disabled for
/// the same reason: their libp2p defaults would graylist healthy peers in small or
/// co-hosted deployments (e.g. several sidecars behind one NAT), and per ARCHITECTURE.md
/// colocation/abuse protection relies on connection limits and request rate limiting.
fn peer_score_settings(
    topics: &(IdentTopic, IdentTopic),
) -> (gossipsub::PeerScoreParams, gossipsub::PeerScoreThresholds) {
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
            topic_weight: 1.0,
            invalid_message_deliveries_weight: -2.0,
            invalid_message_deliveries_decay: 0.99,
            first_message_deliveries_weight: 0.5,
            first_message_deliveries_decay: 0.999,
            first_message_deliveries_cap: 20.0,
            time_in_mesh_weight: 0.0,
            time_in_mesh_quantum: Duration::from_secs(1),
            time_in_mesh_cap: 3600.0,
            mesh_message_deliveries_weight: 0.0,
            mesh_failure_penalty_weight: 0.0,
            ..Default::default()
        };
        topic_params.insert(topic.hash().clone(), p);
    }

    let params = PeerScoreParams {
        topics: topic_params,
        app_specific_weight: 1.0,
        // Non-spec penalty components: disable explicitly instead of inheriting the
        // libp2p defaults (-5.0 / -10.0 / -0.2), which would penalize healthy peers.
        ip_colocation_factor_weight: 0.0,
        behaviour_penalty_weight: 0.0,
        slow_peer_weight: 0.0,
        decay_interval: Duration::from_secs(10),
        decay_to_zero: 0.1,
        retain_score: Duration::from_secs(3600),
        ..Default::default()
    };

    (params, thresholds)
}

#[cfg(test)]
mod tests {
    use super::*;
    use libp2p::gossipsub::{PeerScoreParams, PeerScoreThresholds};

    /// Builds the inputs needed to construct a `NetBehaviour` in tests.
    fn behaviour_inputs() -> (
        libp2p::identity::Keypair,
        (IdentTopic, IdentTopic),
        crate::codec::Protocols,
        crate::config::NetworkConfig,
    ) {
        let chain_id = 167_000;
        (
            libp2p::identity::Keypair::generate_ed25519(),
            (
                IdentTopic::new(preconfirmation_types::topic_preconfirmation_commitments(chain_id)),
                IdentTopic::new(preconfirmation_types::topic_raw_txlists(chain_id)),
            ),
            crate::codec::Protocols {
                commitments: preconfirmation_types::protocol_get_commitments_by_number(chain_id),
                raw_txlists: preconfirmation_types::protocol_get_raw_txlist(chain_id),
                head: preconfirmation_types::protocol_get_head(chain_id),
            },
            crate::config::NetworkConfig::default(),
        )
    }

    #[test]
    fn peer_score_settings_satisfy_gossipsub_validation() {
        let (_, topics, _, _) = behaviour_inputs();
        let (params, thresholds) = peer_score_settings(&topics);
        params.validate().expect("peer score params must pass gossipsub validation");
        thresholds.validate().expect("peer score thresholds must pass gossipsub validation");
    }

    #[test]
    fn peer_score_settings_disable_non_spec_penalties() {
        let (_, topics, _, _) = behaviour_inputs();
        let (params, _) = peer_score_settings(&topics);
        // Not part of the spec §7.1 profile; must not be inherited from libp2p defaults.
        assert_eq!(params.ip_colocation_factor_weight, 0.0);
        assert_eq!(params.behaviour_penalty_weight, 0.0);
        assert_eq!(params.slow_peer_weight, 0.0);
        for topic_params in params.topics.values() {
            assert_eq!(topic_params.mesh_message_deliveries_weight, 0.0);
            assert_eq!(topic_params.mesh_failure_penalty_weight, 0.0);
        }
    }

    #[test]
    fn new_activates_gossipsub_peer_scoring() {
        let (keypair, topics, protocols, cfg) = behaviour_inputs();
        let mut behaviour = NetBehaviour::new(keypair, topics, protocols, &cfg).expect("behaviour");
        // Scoring must already be active, so a second activation attempt is rejected.
        let second = behaviour
            .gossipsub
            .with_peer_score(PeerScoreParams::default(), PeerScoreThresholds::default());
        assert!(second.is_err(), "peer scoring was not activated during construction");
    }
}
