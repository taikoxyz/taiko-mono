//! Discovery adapter backed by `reth-discv5` so we reuse upstream maintenance instead of
//! hand-rolling discv5 wiring. Public surface stays identical to the prior scaffold.

use std::net::SocketAddr;

use discv5::ListenConfig;
use libp2p::{Multiaddr, PeerId};
use rand::RngCore;
use tokio::{sync::mpsc, task::JoinHandle};

/// Configuration for discovery; mirrors common discv5 knobs but keeps defaults simple.
#[derive(Debug, Clone)]
pub struct DiscoveryConfig {
    /// UDP listen socket for discv5.
    pub listen: SocketAddr,
    /// Bootnodes encoded as ENR strings.
    pub bootnodes: Vec<String>, // ENR strings
    /// Optional UDP port to advertise in ENR.
    pub enr_udp_port: Option<u16>,
    /// Optional TCP port to advertise in ENR.
    pub enr_tcp_port: Option<u16>,
}

impl Default for DiscoveryConfig {
    fn default() -> Self {
        Self {
            listen: SocketAddr::from(([0, 0, 0, 0], 0)),
            bootnodes: Vec::new(),
            enr_udp_port: None,
            enr_tcp_port: None,
        }
    }
}

/// Events emitted by the discovery layer.
#[derive(Debug, Clone)]
pub enum DiscoveryEvent {
    PeerDiscovered(PeerId),
    BootnodeFailed(String),
    MultiaddrFound(Multiaddr),
}

/// Lightweight handle for a discovery instance.
pub struct Discovery;

impl Discovery {
    /// Construct a discovery scaffold. For compatibility only.
    pub fn new(_config: DiscoveryConfig) -> Self {
        Self
    }

    /// Poll for the next discovery event (unused with the async task model).
    pub fn poll(&mut self) -> Option<DiscoveryEvent> {
        None
    }
}

/// Spawn a discv5 instance in the background and forward discovered multiaddrs via channel.
pub fn spawn_discovery(
    config: DiscoveryConfig,
) -> anyhow::Result<(mpsc::Receiver<DiscoveryEvent>, JoinHandle<()>)> {
    #[cfg(feature = "reth-discovery")]
    {
        spawn_reth_discv5(config)
    }
    #[cfg(not(feature = "reth-discovery"))]
    {
        anyhow::bail!("discovery feature disabled (enable `reth-discovery` feature)")
    }
}

#[cfg(feature = "reth-discovery")]
fn spawn_reth_discv5(
    config: DiscoveryConfig,
) -> anyhow::Result<(mpsc::Receiver<DiscoveryEvent>, JoinHandle<()>)> {
    use reth_discv5::{Config as RethDiscv5Config, Discv5 as RethDiscv5};
    use secp256k1::SecretKey;

    let (tx, rx) = mpsc::channel(64);

    let handle = tokio::spawn(async move {
        // Generate a random secp256k1 key for discovery identity. Scope-limited so the RNG is
        // dropped before any await, keeping the future Send.
        let secret_key = {
            let mut rng = rand::thread_rng();
            let mut sk_bytes = [0u8; 32];
            rng.fill_bytes(&mut sk_bytes);
            SecretKey::from_slice(&sk_bytes)
                .map_err(|err| format!("failed to generate discv5 key: {err}"))
        };

        let secret_key = match secret_key {
            Ok(key) => key,
            Err(msg) => {
                let _ = tx.send(DiscoveryEvent::BootnodeFailed(msg)).await;
                return;
            }
        };

        // Listen config mirrors prior behaviour; TCP advertisement can be overridden.
        let listen_config = match config.listen {
            SocketAddr::V4(v4) => ListenConfig::Ipv4 { ip: *v4.ip(), port: v4.port() },
            SocketAddr::V6(v6) => ListenConfig::Ipv6 { ip: *v6.ip(), port: v6.port() },
        };

        let tcp_socket = SocketAddr::new(
            config.listen.ip(),
            config.enr_tcp_port.unwrap_or(config.listen.port()),
        );

        let mut cfg_builder = RethDiscv5Config::builder(tcp_socket)
            .discv5_config(discv5::ConfigBuilder::new(listen_config).build());

        for enr in config.bootnodes.iter() {
            if enr.is_empty() {
                continue;
            }
            cfg_builder = cfg_builder.add_cl_serialized_signed_boot_nodes(enr);
        }

        let cfg = cfg_builder.build();

        let (disc, mut updates, _node_record) = match RethDiscv5::start(&secret_key, cfg).await {
            Ok(parts) => parts,
            Err(err) => {
                let _ = tx
                    .send(DiscoveryEvent::BootnodeFailed(format!("failed to start discv5: {err}")))
                    .await;
                return;
            }
        };

        // Forward dialable addresses into the channel.
        while let Some(event) = updates.recv().await {
            if let Some(peer) = disc.on_discv5_update(event) {
                let addr = peer.node_record.address;
                let tcp = peer.node_record.tcp_port;
                let maybe_multi = match addr {
                    std::net::IpAddr::V4(ip4) => format!("/ip4/{}/tcp/{}", ip4, tcp),
                    std::net::IpAddr::V6(ip6) => format!("/ip6/{}/tcp/{}", ip6, tcp),
                }
                .parse()
                .ok();

                if let Some(multi) = maybe_multi {
                    let _ = tx.send(DiscoveryEvent::MultiaddrFound(multi)).await;
                }
            }
        }
    });

    Ok((rx, handle))
}
