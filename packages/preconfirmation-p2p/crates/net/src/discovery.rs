//! Discovery adapter backed by `reth-discv5`.
//!
//! This module provides the interface for peer discovery using Discv5,
//! leveraging `reth-discv5` for its implementation. It defines the
//! configuration for discovery, the events it can emit, and a function
//! to spawn the discovery service.

use std::{net::SocketAddr, time::Instant};

use crate::config::DiscoveryPreset;
use discv5::ListenConfig;
use libp2p::{Multiaddr, PeerId};
use metrics::{counter, histogram};
use rand::RngCore;
use tokio::{sync::mpsc, task::JoinHandle};

/// Configuration for discovery.
///
/// Mirrors common discv5 knobs but keeps defaults simple.
#[derive(Debug, Clone)]
pub struct DiscoveryConfig {
    /// UDP listen socket for discv5. This is the address Discv5 will bind to.
    pub listen: SocketAddr,
    /// Bootnodes encoded as ENR (Ethereum Node Record) strings. These are initial
    /// nodes used to bootstrap the discovery process.
    pub bootnodes: Vec<String>,
    /// Optional UDP port to advertise in the ENR. If `None`, the listen port will be used.
    pub enr_udp_port: Option<u16>,
    /// Optional TCP port to advertise in the ENR. If `None`, the listen port will be used.
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
///
/// These events inform the network service about significant occurrences
/// during the peer discovery process.
#[derive(Debug, Clone)]
pub enum DiscoveryEvent {
    /// A new peer has been discovered.
    PeerDiscovered(PeerId),
    /// An error occurred while trying to connect to or parse a bootnode.
    BootnodeFailed(String),
    /// A multiaddress for a discovered peer has been found.
    MultiaddrFound(Multiaddr),
}

/// Lightweight handle for a discovery instance.
///
/// This struct acts as a placeholder or a simplified interface for the discovery
/// mechanism. In this specific implementation, it's primarily for compatibility
/// with previous designs.
pub struct Discovery;

impl Discovery {
    /// Constructs a discovery scaffold.
    ///
    /// For compatibility only; the actual discovery logic is handled by `spawn_discovery`.
    ///
    /// # Arguments
    ///
    /// * `_config` - The `DiscoveryConfig` (currently unused in this simplified handle).
    ///
    /// # Returns
    ///
    /// A new `Discovery` instance.
    pub fn new(_config: DiscoveryConfig) -> Self {
        Self
    }

    /// Polls for the next discovery event.
    ///
    /// This method is part of a polling interface, but with the current async task model,
    /// events are typically received via a channel, making this method effectively
    /// unused and always returning `None`.
    ///
    /// # Returns
    ///
    /// Always returns `None` in the current implementation.
    pub fn poll(&mut self) -> Option<DiscoveryEvent> {
        None
    }
}

/// Spawns a Discv5 instance in the background and forwards discovered multiaddrs via a channel.
///
/// This function starts the Discv5 service, which actively searches for other peers
/// and reports their multiaddrs through the returned channel. This is conditionally
/// compiled based on the `reth-discovery` feature.
///
/// # Arguments
///
/// * `config` - The `DiscoveryConfig` specifying how Discv5 should be set up.
///
/// # Returns
///
/// A `Result` containing:
/// - `mpsc::Receiver<DiscoveryEvent>`: A channel receiver for `DiscoveryEvent`s.
/// - `JoinHandle<()>`: A handle to the spawned Discv5 background task.
///
/// Returns an `anyhow::Error` if the `reth-discovery` feature is not enabled
/// or if Discv5 fails to start.
pub fn spawn_discovery(
    config: DiscoveryConfig,
    preset: DiscoveryPreset,
) -> anyhow::Result<(mpsc::Receiver<DiscoveryEvent>, JoinHandle<()>)> {
    #[cfg(feature = "reth-discovery")]
    {
        // Keep the async side-effect hidden behind a small, testable surface.
        spawn_reth_discv5(config, preset)
    }
    #[cfg(not(feature = "reth-discovery"))]
    {
        anyhow::bail!("discovery feature disabled (enable `reth-discovery` feature)")
    }
}

#[cfg(feature = "reth-discovery")]
/// Spawns a `reth-discv5` instance.
///
/// This internal function handles the actual setup and execution of the `reth-discv5`
/// discovery service. It generates a random secp256k1 key for the discovery identity,
/// configures the Discv5 listener, adds bootnodes, and then starts the Discv5 process.
/// Discovered peers' multiaddrs are sent through the provided `mpsc::Sender`.
///
/// # Arguments
///
/// * `config` - The `DiscoveryConfig` containing settings for the Discv5 instance.
///
/// # Returns
///
/// A `Result` containing:
/// - `mpsc::Receiver<DiscoveryEvent>`: A channel receiver for `DiscoveryEvent`s.
/// - `JoinHandle<()>`: A handle to the spawned Discv5 background task.
///
/// Returns an `anyhow::Error` if key generation fails, Discv5 fails to start,
/// or an initial `DiscoveryEvent` cannot be sent.
fn spawn_reth_discv5(
    config: DiscoveryConfig,
    preset: DiscoveryPreset,
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

        let cfg_builder = apply_preset(cfg_builder, preset);
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
        let loop_start = Instant::now();
        while let Some(event) = updates.recv().await {
            let elapsed = loop_start.elapsed().as_secs_f64();
            match disc.on_discv5_update(event) {
                Some(peer) => {
                    let addr = peer.node_record.address;
                    let tcp = peer.node_record.tcp_port;
                    let maybe_multi = match addr {
                        std::net::IpAddr::V4(ip4) => format!("/ip4/{}/tcp/{}", ip4, tcp),
                        std::net::IpAddr::V6(ip6) => format!("/ip6/{}/tcp/{}", ip6, tcp),
                    }
                    .parse()
                    .ok();

                    if let Some(multi) = maybe_multi {
                        counter!("p2p_discovery_event", "kind" => "lookup_success").increment(1);
                        histogram!("p2p_discovery_lookup_latency_seconds", "outcome" => "success")
                            .record(elapsed);
                        let _ = tx.send(DiscoveryEvent::MultiaddrFound(multi)).await;
                    }
                }
                None => {
                    counter!("p2p_discovery_event", "kind" => "lookup_failure").increment(1);
                    histogram!("p2p_discovery_lookup_latency_seconds", "outcome" => "error")
                        .record(elapsed);
                }
            }
        }
    });

    Ok((rx, handle))
}

#[cfg(feature = "reth-discovery")]
fn apply_preset(
    builder: reth_discv5::ConfigBuilder,
    preset: DiscoveryPreset,
) -> reth_discv5::ConfigBuilder {
    let (lookup_interval, bootstrap_interval, bootstrap_count) = match preset {
        DiscoveryPreset::Dev => (60, 10, 50),
        DiscoveryPreset::Test => (30, 5, 100),
        DiscoveryPreset::Prod => (20, 5, 200),
    };

    builder
        .lookup_interval(lookup_interval)
        .bootstrap_lookup_interval(bootstrap_interval)
        .bootstrap_lookup_countdown(bootstrap_count)
}
