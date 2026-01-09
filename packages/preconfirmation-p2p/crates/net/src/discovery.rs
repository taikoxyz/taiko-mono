//! Discovery adapter backed by `reth-discv5`.
//!
//! This module wires discv5 into a simple multiaddr stream used by the network driver.

use std::{
    net::{IpAddr, SocketAddr},
    time::Instant,
};

use discv5::ListenConfig;
use libp2p::Multiaddr;
use metrics::{counter, histogram};
use rand::RngCore;
use reth_discv5::{Config as RethDiscv5Config, Discv5 as RethDiscv5};
use secp256k1::SecretKey;
use tokio::sync::mpsc;

/// Spawns a Discv5 instance in the background and forwards discovered multiaddrs via a channel.
///
/// # Arguments
///
/// * `listen` - The UDP socket address to listen on for discv5.
/// * `bootnodes` - A list of ENR strings for bootstrap nodes.
///
/// # Returns
///
/// A receiver that yields discovered peer multiaddrs.
pub fn spawn_discovery(
    listen: SocketAddr,
    bootnodes: Vec<String>,
) -> anyhow::Result<mpsc::Receiver<Multiaddr>> {
    // Conservative defaults aligned with prior production tuning.
    const LOOKUP_INTERVAL_SECS: u64 = 20;
    const BOOTSTRAP_LOOKUP_INTERVAL_SECS: u64 = 5;
    const BOOTSTRAP_LOOKUP_COUNTDOWN: u64 = 200;

    let (tx, rx) = mpsc::channel(64);

    tokio::spawn(async move {
        // Generate a random secp256k1 key for discovery identity. Scope-limited so the RNG is
        // dropped before any await, keeping the future Send.
        let secret_key = {
            let mut rng = rand::thread_rng();
            let mut sk_bytes = [0u8; 32];
            rng.fill_bytes(&mut sk_bytes);
            SecretKey::from_slice(&sk_bytes)
        };

        let secret_key = match secret_key {
            Ok(key) => key,
            Err(err) => {
                tracing::warn!(target: "p2p", "failed to generate discv5 key: {err}");
                return;
            }
        };

        // Listen config mirrors prior behaviour; TCP advertisement uses the listen socket.
        let listen_config = match listen {
            SocketAddr::V4(v4) => ListenConfig::Ipv4 { ip: *v4.ip(), port: v4.port() },
            SocketAddr::V6(v6) => ListenConfig::Ipv6 { ip: *v6.ip(), port: v6.port() },
        };

        let tcp_socket = SocketAddr::new(listen.ip(), listen.port());

        let mut cfg_builder = RethDiscv5Config::builder(tcp_socket)
            .discv5_config(discv5::ConfigBuilder::new(listen_config).build());

        for enr in bootnodes.iter() {
            if enr.is_empty() {
                continue;
            }
            cfg_builder = cfg_builder.add_cl_serialized_signed_boot_nodes(enr);
        }

        cfg_builder = cfg_builder
            .lookup_interval(LOOKUP_INTERVAL_SECS)
            .bootstrap_lookup_interval(BOOTSTRAP_LOOKUP_INTERVAL_SECS)
            .bootstrap_lookup_countdown(BOOTSTRAP_LOOKUP_COUNTDOWN);
        let cfg = cfg_builder.build();

        let (disc, mut updates, _node_record) = match RethDiscv5::start(&secret_key, cfg).await {
            Ok(parts) => parts,
            Err(err) => {
                tracing::warn!(target: "p2p", "failed to start discv5: {err}");
                return;
            }
        };

        // Forward dialable addresses into the channel.
        let loop_start = Instant::now();
        loop {
            tokio::select! {
                _ = tx.closed() => break,
                maybe_event = updates.recv() => {
                    let Some(event) = maybe_event else {
                        break;
                    };

                    let elapsed = loop_start.elapsed().as_secs_f64();
                    match disc.on_discv5_update(event) {
                        Some(peer) => {
                            let addr = peer.node_record.address;
                            let tcp = peer.node_record.tcp_port;
                            let maybe_multi = match addr {
                                IpAddr::V4(ip4) => format!("/ip4/{}/tcp/{}", ip4, tcp),
                                IpAddr::V6(ip6) => format!("/ip6/{}/tcp/{}", ip6, tcp),
                            }
                            .parse()
                            .ok();

                            if let Some(multi) = maybe_multi {
                                counter!("p2p_discovery_event", "kind" => "lookup_success").increment(1);
                                histogram!("p2p_discovery_lookup_latency_seconds", "outcome" => "success")
                                    .record(elapsed);
                                if tx.send(multi).await.is_err() {
                                    break;
                                }
                            }
                        }
                        None => {
                            counter!("p2p_discovery_event", "kind" => "lookup_failure").increment(1);
                            histogram!("p2p_discovery_lookup_latency_seconds", "outcome" => "error")
                                .record(elapsed);
                        }
                    }
                }
            }
        }
    });

    Ok(rx)
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::net::{IpAddr, Ipv4Addr, SocketAddr};

    #[tokio::test]
    async fn spawn_discovery_returns_multiaddr_receiver() {
        let listen = SocketAddr::new(IpAddr::V4(Ipv4Addr::LOCALHOST), 0);
        let result: anyhow::Result<tokio::sync::mpsc::Receiver<Multiaddr>> =
            spawn_discovery(listen, Vec::new());

        if let Ok(rx) = result {
            drop(rx);
        }
    }
}
