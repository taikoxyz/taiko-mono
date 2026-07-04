//! Bootnode parsing for the whitelist preconfirmation network.
//!
//! Every configured bootnode — ENR, `enode://` URL, or raw multiaddr — resolves to a
//! TCP multiaddr that the network runtime dials directly and retries alongside static
//! peers. There is no DHT discovery: the whitelist fleet is a small, known set of
//! operators, so the configured peers are the connectivity mechanism. The previous discv5
//! integration only ever dialed addresses it discovered and never advertised this node into
//! any DHT, so removing it cannot lose connectivity that direct dialing of the configured
//! peers does not already provide.

use std::net::SocketAddr;

use libp2p::Multiaddr;
use tracing::warn;

/// Resolve bootnode entries into dialable TCP multiaddrs.
///
/// Each entry is tested in order: ENR (`enr:` prefix), enode URL (`enode://` prefix),
/// or raw multiaddr. Unparsable or undialable entries are logged and skipped.
pub(crate) fn classify_bootnodes(bootnodes: Vec<String>) -> Vec<Multiaddr> {
    let mut dial_addrs = Vec::new();

    for entry in bootnodes {
        let value = entry.trim();
        if value.is_empty() {
            continue;
        }

        if value.starts_with("enr:") {
            match parse_enr_tcp_addr(value) {
                Some(addr) => dial_addrs.push(addr),
                None => {
                    warn!(bootnode = %value, "invalid ENR bootnode or no dialable TCP address")
                }
            }
            continue;
        }

        if value.starts_with("enode://") {
            match parse_enode_url(value) {
                Some(addr) => dial_addrs.push(addr),
                None => warn!(bootnode = %value, "failed to parse enode:// URL"),
            }
            continue;
        }

        match value.parse::<Multiaddr>() {
            Ok(addr) => dial_addrs.push(addr),
            Err(err) => {
                warn!(
                    bootnode = %value,
                    error = %err,
                    "invalid bootnode entry; expected ENR, enode://, or multiaddr"
                );
            }
        }
    }

    dial_addrs
}

/// Extract a dialable TCP multiaddr from an `enr:` bootnode entry.
///
/// The ENR signature scheme is Ethereum's standard v4 (secp256k1). Only the IP and TCP
/// port are used; UDP discovery fields are ignored.
fn parse_enr_tcp_addr(value: &str) -> Option<Multiaddr> {
    let enr = value.parse::<enr::Enr<enr::k256::ecdsa::SigningKey>>().ok()?;

    if let (Some(ip), Some(tcp_port)) = (enr.ip4(), enr.tcp4()) {
        return format!("/ip4/{ip}/tcp/{tcp_port}").parse().ok();
    }

    let (ip, tcp_port) = (enr.ip6()?, enr.tcp6()?);
    format!("/ip6/{ip}/tcp/{tcp_port}").parse().ok()
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

#[cfg(test)]
mod tests {
    use std::net::Ipv4Addr;

    use super::*;

    /// Build a valid `enr:` bootnode string with the given TCP socket details.
    fn sample_enr(ip: Ipv4Addr, tcp_port: Option<u16>) -> String {
        let key = enr::k256::ecdsa::SigningKey::from_slice(&[0x11u8; 32]).expect("valid key");
        let mut builder = enr::Enr::builder();
        builder.ip4(ip);
        if let Some(port) = tcp_port {
            builder.tcp4(port);
        }
        builder.build(&key).expect("valid enr").to_base64()
    }

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
    fn classify_bootnodes_resolves_all_entry_kinds_to_dial_addrs() {
        let bootnodes = vec![
            sample_enr(Ipv4Addr::new(10, 0, 0, 9), Some(9222)),
            "enode://key@10.0.0.1:30303".to_string(),
            "/ip4/1.2.3.4/tcp/9000".to_string(),
            "".to_string(),
            "garbage".to_string(),
            "enr:not-a-real-enr".to_string(),
        ];

        let dial_addrs = classify_bootnodes(bootnodes);

        assert_eq!(
            dial_addrs,
            vec![
                "/ip4/10.0.0.9/tcp/9222".parse::<Multiaddr>().expect("valid multiaddr"),
                "/ip4/10.0.0.1/tcp/30303".parse().expect("valid multiaddr"),
                "/ip4/1.2.3.4/tcp/9000".parse().expect("valid multiaddr"),
            ]
        );
    }

    #[test]
    fn classify_bootnodes_skips_enr_without_tcp_address() {
        let dial_addrs = classify_bootnodes(vec![sample_enr(Ipv4Addr::new(10, 0, 0, 9), None)]);
        assert!(dial_addrs.is_empty());
    }

    #[test]
    fn classify_bootnodes_empty() {
        assert!(classify_bootnodes(vec![]).is_empty());
    }
}
