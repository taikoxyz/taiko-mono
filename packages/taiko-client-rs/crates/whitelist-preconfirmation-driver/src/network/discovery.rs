//! Peer discovery using discv5 and bootnode parsing.
//!
//! Replaces the external `preconfirmation-net` crate's `spawn_discovery` with
//! a direct discv5 integration that parses ENR boot entries, runs periodic
//! `find_node` queries, and feeds discovered TCP multiaddrs back through a
//! channel for the network event loop to dial.

use std::net::SocketAddr;

use libp2p::Multiaddr;
use tokio::sync::mpsc;
use tracing::{debug, info, warn};

use crate::error::{Result, WhitelistPreconfirmationDriverError};

/// Parsed bootnode configuration split into direct dial multiaddrs and ENR discovery peers.
#[derive(Debug, Default, PartialEq, Eq)]
pub(crate) struct ClassifiedBootnodes {
    /// Parsed multiaddrs to dial directly.
    pub(crate) dial_addrs: Vec<Multiaddr>,
    /// ENR entries to feed into discovery.
    pub(crate) discovery_enrs: Vec<String>,
}

/// Classify bootnodes into direct-dial multiaddrs and discovery ENRs.
///
/// Each entry is tested in order: ENR (`enr:` prefix), enode URL (`enode://`
/// prefix), or raw multiaddr. Unrecognised entries are logged and skipped.
pub(crate) fn classify_bootnodes(bootnodes: Vec<String>) -> ClassifiedBootnodes {
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

/// Parse an `enode://` URL into a multiaddr for direct dialing.
///
/// Accepts `enode://<hex-pubkey>@<ip>:<tcp-port>[?discport=<udp>]` and returns
/// `/ip4/{ip}/tcp/{port}` (or `/ip6/…`). The pubkey and optional discport query
/// are intentionally ignored — we only need the TCP dial address.
pub(crate) fn parse_enode_url(url: &str) -> Option<Multiaddr> {
    let rest = url.strip_prefix("enode://")?;
    let (_, host_part) = rest.split_once('@')?;
    let host_port = host_part.split('?').next()?;
    let sock: SocketAddr = host_port.parse().ok()?;
    let scheme = if sock.ip().is_ipv4() { "ip4" } else { "ip6" };
    format!("/{scheme}/{}/tcp/{}", sock.ip(), sock.port()).parse().ok()
}

/// Initialize optional discovery receiver based on config and available ENR bootnodes.
///
/// Returns a receiver that yields discovered peer multiaddrs, or `None` if
/// discovery is disabled or no ENR bootnodes are available.
pub(crate) async fn init_discovery(
    enable_discovery: bool,
    discovery_listen: SocketAddr,
    discovery_enrs: Vec<String>,
) -> Option<mpsc::Receiver<Multiaddr>> {
    match (enable_discovery, discovery_enrs.is_empty()) {
        (true, false) => spawn_discv5(discovery_listen, discovery_enrs)
            .await
            .map_err(|err| {
                warn!(error = %err, "failed to start whitelist preconfirmation discovery");
            })
            .ok(),
        (true, true) => {
            info!("discovery enabled but no ENR bootnodes provided; skipping discv5 bootstrap");
            None
        }
        (false, false) => {
            warn!(count = discovery_enrs.len(), "discovery is disabled; skipping ENR bootnodes");
            None
        }
        (false, true) => None,
    }
}

/// Receive one discovery event, if discovery is enabled.
pub(crate) async fn recv_discovered_multiaddr(
    discovery_rx: &mut Option<mpsc::Receiver<Multiaddr>>,
) -> Option<Multiaddr> {
    discovery_rx.as_mut()?.recv().await
}

/// Spawn a discv5 instance and return a receiver of discovered TCP multiaddrs.
///
/// The startup path parses the provided ENR strings, adds them as boot nodes,
/// and starts the discv5 service before returning so initialization errors are
/// surfaced to the caller instead of being logged only inside the detached
/// discovery task. Once startup succeeds, the spawned task periodically runs
/// `find_node` queries with random target IDs and forwards any discovered ENR
/// that advertises a TCP port through the channel.
async fn spawn_discv5(
    listen_addr: SocketAddr,
    enr_strings: Vec<String>,
) -> Result<mpsc::Receiver<Multiaddr>> {
    let mut boot_enrs = Vec::new();
    for s in &enr_strings {
        match s.parse::<discv5::Enr>() {
            Ok(enr) => boot_enrs.push(enr),
            Err(err) => warn!(enr = %s, error = %err, "failed to parse ENR bootnode"),
        }
    }

    let (tx, rx) = mpsc::channel(256);

    let discv5_config = discv5::ConfigBuilder::new(discv5::ListenConfig::from(listen_addr)).build();

    let key = discv5::enr::CombinedKey::generate_secp256k1();
    let local_enr = discv5::enr::Enr::builder()
        .build(&key)
        .map_err(WhitelistPreconfirmationDriverError::p2p)?;
    let mut discv5 =
        discv5::Discv5::new(local_enr, key, discv5_config)
            .map_err(WhitelistPreconfirmationDriverError::p2p)?;

    for enr in &boot_enrs {
        if let Err(err) = discv5.add_enr(enr.clone()) {
            warn!(error = %err, "failed to add ENR to discv5 table");
        }
    }

    discv5.start().await.map_err(WhitelistPreconfirmationDriverError::p2p)?;

    tokio::spawn(async move {
        debug!("discv5 discovery started on {}", listen_addr);

        loop {
            match discv5.find_node(discv5::enr::NodeId::random()).await {
                Ok(found) => {
                    for enr in found {
                        if let Some(addr) = enr_to_multiaddr(&enr) &&
                            tx.send(addr).await.is_err()
                        {
                            debug!("discovery receiver dropped; stopping");
                            return;
                        }
                    }
                }
                Err(err) => {
                    debug!(error = %err, "discv5 find_node failed");
                }
            }
            tokio::time::sleep(std::time::Duration::from_secs(30)).await;
        }
    });

    Ok(rx)
}

/// Extract a TCP multiaddr from a discv5 ENR if it has dialable IPv4 or IPv6 TCP info.
fn enr_to_multiaddr(enr: &discv5::Enr) -> Option<Multiaddr> {
    if let (Some(ip), Some(tcp_port)) = (enr.ip4(), enr.tcp4()) {
        return format!("/ip4/{ip}/tcp/{tcp_port}").parse().ok();
    }

    let (ip, tcp_port) = (enr.ip6()?, enr.tcp6()?);
    format!("/ip6/{ip}/tcp/{tcp_port}").parse().ok()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parse_enode_url_valid_ipv4() {
        let url = "enode://a3f84d16471e6d8a0dc1e2d62f7a9c5b3e4f5678901234567890abcdef123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef01234567@10.0.1.5:30303?discport=30304";
        let addr = parse_enode_url(url).expect("should parse valid enode URL");
        assert_eq!(addr.to_string(), "/ip4/10.0.1.5/tcp/30303");
    }

    #[test]
    fn parse_enode_url_valid_ipv4_no_query() {
        let url = "enode://abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890@192.168.1.1:30303";
        let addr = parse_enode_url(url).expect("should parse enode URL without query");
        assert_eq!(addr.to_string(), "/ip4/192.168.1.1/tcp/30303");
    }

    #[test]
    fn classify_bootnodes_mixed() {
        let bootnodes = vec![
            "enr:abc123".to_string(),
            "enode://key@10.0.0.1:30303".to_string(),
            "/ip4/1.2.3.4/tcp/9000".to_string(),
            "".to_string(),
            "garbage".to_string(),
        ];

        let classified = classify_bootnodes(bootnodes);
        assert_eq!(classified.discovery_enrs.len(), 1);
        assert_eq!(classified.dial_addrs.len(), 2);
    }

    #[test]
    fn classify_bootnodes_empty() {
        let classified = classify_bootnodes(vec![]);
        assert!(classified.dial_addrs.is_empty());
        assert!(classified.discovery_enrs.is_empty());
    }
}
