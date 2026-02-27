//! Bootnode parsing and peer dialing helpers.

use std::collections::HashSet;

use libp2p::{Multiaddr, Swarm};
use tokio::sync::mpsc;
use tracing::{debug, warn};

use super::types::Behaviour;
use crate::metrics::WhitelistPreconfirmationDriverMetrics;

#[derive(Debug, Default, PartialEq, Eq)]
/// Parsed bootnode configuration split into direct dial multiaddrs and ENR discovery peers.
pub(super) struct ClassifiedBootnodes {
    /// Parsed multiaddrs to dial directly.
    pub(super) dial_addrs: Vec<Multiaddr>,
    /// ENR entries to feed into discovery.
    pub(super) discovery_enrs: Vec<String>,
}

/// Parse an `enode://` URL into a multiaddr for direct dialing.
///
/// Accepts `enode://<hex-pubkey>@<ip>:<tcp-port>[?discport=<udp>]` and returns
/// `/ip4/{ip}/tcp/{port}` (or `/ip6/…`). The pubkey and optional discport query
/// are intentionally ignored — we only need the TCP dial address.
pub(super) fn parse_enode_url(url: &str) -> Option<Multiaddr> {
    let rest = url.strip_prefix("enode://")?;
    let (_, host_part) = rest.split_once('@')?;
    let host_port = host_part.split('?').next()?;
    let sock: std::net::SocketAddr = host_port.parse().ok()?;
    let scheme = if sock.ip().is_ipv4() { "ip4" } else { "ip6" };
    format!("/{scheme}/{}/tcp/{}", sock.ip(), sock.port()).parse().ok()
}

/// Classify bootnodes into direct-dial multiaddrs and discovery ENRs.
pub(super) fn classify_bootnodes(bootnodes: Vec<String>) -> ClassifiedBootnodes {
    let mut classified = ClassifiedBootnodes::default();

    for entry in bootnodes {
        let value = entry.trim();
        if value.is_empty() {
            continue;
        }

        if value.starts_with("enr:") {
            classified.discovery_enrs.push(value.to_string());
            continue;
        }

        if value.starts_with("enode://") {
            match parse_enode_url(value) {
                Some(addr) => classified.dial_addrs.push(addr),
                None => warn!(bootnode = %value, "failed to parse enode:// URL"),
            }
            continue;
        }

        match value.parse::<Multiaddr>() {
            Ok(addr) => classified.dial_addrs.push(addr),
            Err(err) => {
                warn!(
                    bootnode = %value,
                    error = %err,
                    "invalid bootnode entry; expected ENR, enode://, or multiaddr"
                );
            }
        }
    }

    classified
}

/// Dial a peer address once.
pub(super) fn dial_once(
    swarm: &mut Swarm<Behaviour>,
    dialed_addrs: &mut HashSet<Multiaddr>,
    addr: Multiaddr,
    source: &str,
) {
    if !dialed_addrs.insert(addr.clone()) {
        debug!(%addr, source, "already dialed address; skipping");
        return;
    }

    metrics::counter!(
        WhitelistPreconfirmationDriverMetrics::NETWORK_DIAL_ATTEMPTS_TOTAL,
        "source" => source.to_string(),
    )
    .increment(1);

    if let Err(err) = swarm.dial(addr.clone()) {
        metrics::counter!(
            WhitelistPreconfirmationDriverMetrics::NETWORK_DIAL_FAILURES_TOTAL,
            "source" => source.to_string(),
        )
        .increment(1);
        warn!(%addr, source, error = %err, "failed to dial address");
    }
}

/// Receive one discovery event, if discovery is enabled.
pub(super) async fn recv_discovered_multiaddr(
    discovery_rx: &mut Option<mpsc::Receiver<Multiaddr>>,
) -> Option<Multiaddr> {
    discovery_rx.as_mut()?.recv().await
}
