//! Bootnode parsing and discv5 peer discovery for the whitelist preconfirmation network.
//!
//! Every dialable configured bootnode — ENR, `enode://` URL, or raw multiaddr — resolves
//! to a TCP multiaddr that the network runtime dials directly and retries alongside static
//! peers. ENR and enode entries carry a node identity, so their dial addresses pin the
//! derived libp2p peer id: dials verify the remote identity and the runtime protects the
//! configured identity before its first connection. ENR and enode entries also seed a
//! [`kona_disc`] discv5 service, even when their
//! TCP port is zero and therefore unsuitable for direct dialing. The discovery service
//! mirrors the Go client's op-node discovery: the local node advertises a signed ENR
//! (IP, TCP, UDP, and the `"opstack"` chain-id entry) and randomly walks the DHT for
//! peers carrying a matching chain-id entry. Discovered peers are converted into
//! peer-id-pinned TCP multiaddrs and fed to the runtime's peer manager, which dials
//! them while the connection count is below the low-tide target.

use std::net::SocketAddr;

use discv5::enr::k256;
use kona_disc::{Discv5Driver, Discv5Handler, LocalNode};
use kona_peers::{BootNode, BootNodes, NodeRecord, enr_to_multiaddr, local_id_to_p2p_id};
use libp2p::{Multiaddr, PeerId, identity, multiaddr::Protocol};
use tokio::sync::mpsc;
use tracing::warn;

use crate::error::{Result, WhitelistPreconfirmationDriverError};

/// Resolve bootnode entries into dialable TCP multiaddrs.
///
/// Each entry is tested in order: ENR (`enr:` prefix), enode URL (`enode://` prefix),
/// or raw multiaddr. Unparsable or undialable entries are logged and skipped.
pub(crate) fn classify_bootnodes(bootnodes: &[String]) -> Vec<Multiaddr> {
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
                None => warn!(
                    bootnode = %value,
                    "invalid enode:// URL, pubkey, or no dialable nonzero TCP address"
                ),
            }
            continue;
        }

        match value.parse::<Multiaddr>() {
            Ok(addr) if has_nonzero_tcp_port(&addr) => dial_addrs.push(addr),
            Ok(_) => warn!(bootnode = %value, "bootnode has no dialable nonzero TCP port"),
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

/// Report whether a multiaddr contains a nonzero TCP port suitable for direct dialing.
fn has_nonzero_tcp_port(addr: &Multiaddr) -> bool {
    addr.iter().any(|protocol| matches!(protocol, Protocol::Tcp(port) if port != 0))
}

/// Parse bootnode entries into discv5 bootstrap nodes.
///
/// ENR entries become signed records; enode URLs become unsigned contacts whose real ENR
/// is requested from their UDP endpoint (`?discport=` respected) during bootstrap. Raw
/// multiaddr entries carry no discovery key material and are skipped. Unparsable entries
/// are logged and skipped, mirroring [`classify_bootnodes`].
pub(crate) fn parse_discovery_bootnodes(bootnodes: &[String]) -> BootNodes {
    let mut nodes = Vec::new();

    for entry in bootnodes {
        let value = entry.trim();
        if value.is_empty() {
            continue;
        }

        if value.starts_with("enr:") {
            match value.parse::<discv5::Enr>() {
                Ok(enr) => nodes.push(BootNode::from(enr)),
                Err(err) => {
                    warn!(bootnode = %value, error = %err, "failed to parse ENR discovery bootnode");
                }
            }
            continue;
        }

        if value.starts_with("enode://") {
            let record = match value.parse::<NodeRecord>() {
                Ok(record) => record,
                Err(err) => {
                    warn!(bootnode = %value, error = %err, "failed to parse enode:// discovery bootnode");
                    continue;
                }
            };
            match BootNode::from_unsigned(record) {
                Ok(node) => nodes.push(node),
                Err(err) => {
                    warn!(bootnode = %value, error = %err, "failed to convert enode:// bootnode for discovery");
                }
            }
        }
    }

    BootNodes(nodes)
}

/// Spawn the kona discv5 discovery service.
///
/// The local ENR is signed with `local_key` (which must be secp256k1 so the discovery
/// identity matches the libp2p peer id Go peers derive when dialing), advertises
/// `advertise` as its IP and TCP port plus the discv5 listen port as UDP, and carries
/// the `"opstack"` entry for `chain_id` so Go and Rust fleets discover each other.
/// ENR auto-updates from peer votes are disabled: the advertised address is static, and
/// NAT-voted addresses (e.g. a cloud egress IP) would not be dialable.
///
/// Returns the driver handle (which must be kept alive for the lifetime of the service)
/// and the stream of chain-validated discovered ENRs.
pub(crate) fn spawn_discovery(
    local_key: &identity::Keypair,
    chain_id: u64,
    listen: SocketAddr,
    advertise: SocketAddr,
    bootnodes: BootNodes,
) -> Result<(Discv5Handler, mpsc::Receiver<discv5::Enr>)> {
    let signing_key = discovery_signing_key(local_key)?;
    let local_node = LocalNode::new(signing_key, advertise.ip(), advertise.port(), listen.port());

    let listen_config = match listen {
        SocketAddr::V4(addr) => discv5::ListenConfig::Ipv4 { ip: *addr.ip(), port: addr.port() },
        SocketAddr::V6(addr) => discv5::ListenConfig::Ipv6 { ip: *addr.ip(), port: addr.port() },
    };
    let mut config_builder = discv5::ConfigBuilder::new(listen_config);
    // The advertised address is static: reject ENR updates from peer address votes and
    // skip NAT probing, matching op-node's SetStaticIP behaviour.
    config_builder.disable_enr_update();
    config_builder.auto_nat_listen_duration(None);

    let driver = Discv5Driver::builder(local_node, chain_id, config_builder.build())
        .with_bootnodes(bootnodes)
        .build()
        .map_err(|err| {
            WhitelistPreconfirmationDriverError::p2p(format!(
                "failed to build discv5 discovery service: {err}"
            ))
        })?;

    Ok(driver.start())
}

/// Derive the discv5 ENR signing key from the libp2p identity keypair.
///
/// Discovery requires a secp256k1 identity: Go peers derive the libp2p peer id from the
/// ENR's public key when dialing, so the two must be the same key.
fn discovery_signing_key(local_key: &identity::Keypair) -> Result<k256::ecdsa::SigningKey> {
    let secret = local_key
        .clone()
        .try_into_secp256k1()
        .map_err(|err| {
            WhitelistPreconfirmationDriverError::p2p(format!(
                "discovery requires a secp256k1 P2P identity: {err}"
            ))
        })?
        .secret()
        .to_bytes();

    k256::ecdsa::SigningKey::from_slice(&secret).map_err(|err| {
        WhitelistPreconfirmationDriverError::p2p(format!(
            "failed to convert P2P identity into discovery signing key: {err}"
        ))
    })
}

/// Convert a discovered ENR into a peer-id-pinned dialable TCP multiaddr.
///
/// Returns `None` for the local node itself and for ENRs without a nonzero dialable TCP
/// socket or secp256k1 key.
pub(crate) fn discovered_candidate(enr: &discv5::Enr, local_peer_id: &PeerId) -> Option<Multiaddr> {
    let addr = enr_dialable_multiaddr(enr)?;
    let peer_id = addr.iter().find_map(|protocol| match protocol {
        Protocol::P2p(peer_id) => Some(peer_id),
        _ => None,
    })?;

    (&peer_id != local_peer_id).then_some(addr)
}

/// Convert an ENR into an identity-pinned multiaddr using its first nonzero TCP socket.
///
/// [`enr_to_multiaddr`] selects the IPv4 socket even when its TCP port is zero, which
/// would discard a dialable IPv6 endpoint on dual-stack records; fall back to a nonzero
/// IPv6 socket in that case, keeping the peer id pinned by the record's key.
fn enr_dialable_multiaddr(enr: &discv5::Enr) -> Option<Multiaddr> {
    let pinned = enr_to_multiaddr(enr)?;
    if has_nonzero_tcp_port(&pinned) {
        return Some(pinned);
    }

    let peer_id = pinned.iter().find_map(|protocol| match protocol {
        Protocol::P2p(peer_id) => Some(peer_id),
        _ => None,
    })?;
    let socket = enr.tcp6_socket().filter(|socket| socket.port() != 0)?;

    let mut addr = Multiaddr::from(*socket.ip());
    addr.push(Protocol::Tcp(socket.port()));
    addr.push(Protocol::P2p(peer_id));
    Some(addr)
}

/// Extract a dialable, identity-pinned TCP multiaddr from an `enr:` bootnode entry.
///
/// Delegates to [`enr_dialable_multiaddr`], which appends the libp2p peer id derived
/// from the record's secp256k1 key so dials verify the remote identity. Records without
/// a nonzero TCP port or secp256k1 key are rejected.
fn parse_enr_tcp_addr(value: &str) -> Option<Multiaddr> {
    let enr = value.parse::<discv5::Enr>().ok()?;
    enr_dialable_multiaddr(&enr)
}

/// Parse an `enode://` URL into an identity-pinned multiaddr for direct dialing.
///
/// Accepts `enode://<hex-pubkey>@<ip>:<tcp-port>[?discport=<udp>]` and returns
/// `/ip4/{ip}/tcp/{port}/p2p/{peer_id}` (or `/ip6/…`), deriving the libp2p peer id from
/// the enode pubkey so dials verify the remote identity and the runtime can protect it
/// before its first connection. URLs with an invalid pubkey or zero TCP port are
/// rejected.
pub(crate) fn parse_enode_url(url: &str) -> Option<Multiaddr> {
    let record = url.parse::<NodeRecord>().ok()?;
    if record.tcp_port == 0 {
        return None;
    }
    let peer_id = local_id_to_p2p_id(record.id).ok()?;

    let mut addr = Multiaddr::from(record.address);
    addr.push(Protocol::Tcp(record.tcp_port));
    addr.push(Protocol::P2p(peer_id));
    Some(addr)
}

#[cfg(test)]
mod tests {
    use std::net::{Ipv4Addr, Ipv6Addr};

    use super::*;

    /// A stable secp256k1 test secret for deterministic identities.
    const TEST_SECRET: [u8; 32] = [0x11u8; 32];

    /// Build a valid `enr:` bootnode string with the given TCP socket details.
    fn sample_enr(ip: Ipv4Addr, tcp_port: Option<u16>) -> String {
        let key = enr::k256::ecdsa::SigningKey::from_slice(&TEST_SECRET).expect("valid key");
        let mut builder = enr::Enr::builder();
        builder.ip4(ip);
        if let Some(port) = tcp_port {
            builder.tcp4(port);
        }
        builder.build(&key).expect("valid enr").to_base64()
    }

    /// The libp2p keypair matching [`TEST_SECRET`].
    fn sample_libp2p_keypair() -> identity::Keypair {
        let secret = identity::secp256k1::SecretKey::try_from_bytes(TEST_SECRET.to_vec())
            .expect("valid secp256k1 secret");
        identity::Keypair::from(identity::secp256k1::Keypair::from(secret))
    }

    /// The uncompressed secp256k1 pubkey hex (no `04` prefix) for [`TEST_SECRET`].
    fn sample_pubkey_hex() -> String {
        let secp_key =
            sample_libp2p_keypair().try_into_secp256k1().expect("secp256k1 test keypair");
        alloy_primitives::hex::encode(&secp_key.public().to_bytes_uncompressed()[1..])
    }

    #[test]
    fn parse_enode_url_pins_peer_id_from_pubkey() {
        let url = format!("enode://{}@10.0.1.5:30303?discport=30304", sample_pubkey_hex());
        let addr = parse_enode_url(&url).expect("should parse valid enode URL");
        assert_eq!(
            addr.to_string(),
            format!(
                "/ip4/10.0.1.5/tcp/30303/p2p/{}",
                sample_libp2p_keypair().public().to_peer_id()
            )
        );
    }

    #[test]
    fn parse_enode_url_valid_ipv4_no_query() {
        let url = format!("enode://{}@192.168.1.1:30303", sample_pubkey_hex());
        let addr = parse_enode_url(&url).expect("should parse enode URL without query");
        assert!(addr.to_string().starts_with("/ip4/192.168.1.1/tcp/30303/p2p/"));
    }

    #[test]
    fn parse_enode_url_rejects_invalid_pubkey() {
        assert_eq!(
            parse_enode_url(
                "enode://a3f84d16471e6d8a0dc1e2d62f7a9c5b3e4f5678901234567890abcdef123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef01234567@10.0.1.5:30303"
            ),
            None,
            "a pubkey that is not a curve point must not become a dial target"
        );
    }

    #[test]
    fn classify_bootnodes_resolves_all_entry_kinds_to_pinned_dial_addrs() {
        let sample_peer = sample_libp2p_keypair().public().to_peer_id();
        let bootnodes = vec![
            sample_enr(Ipv4Addr::new(10, 0, 0, 9), Some(9222)),
            format!("enode://{}@10.0.0.1:30303", sample_pubkey_hex()),
            "enode://key@10.0.0.1:30303".to_string(),
            "/ip4/1.2.3.4/tcp/9000".to_string(),
            "".to_string(),
            "garbage".to_string(),
            "enr:not-a-real-enr".to_string(),
        ];

        let dial_addrs = classify_bootnodes(&bootnodes);

        assert_eq!(
            dial_addrs,
            vec![
                format!("/ip4/10.0.0.9/tcp/9222/p2p/{sample_peer}")
                    .parse::<Multiaddr>()
                    .expect("valid multiaddr"),
                format!("/ip4/10.0.0.1/tcp/30303/p2p/{sample_peer}")
                    .parse()
                    .expect("valid multiaddr"),
                "/ip4/1.2.3.4/tcp/9000".parse().expect("valid multiaddr"),
            ],
            "ENR/enode entries pin identities; the bogus-pubkey enode is dropped"
        );
    }

    #[test]
    fn classify_bootnodes_skips_enr_without_tcp_address() {
        let dial_addrs = classify_bootnodes(&[sample_enr(Ipv4Addr::new(10, 0, 0, 9), None)]);
        assert!(dial_addrs.is_empty());
    }

    #[test]
    fn classify_bootnodes_skips_enr_with_zero_tcp_port() {
        let dial_addrs = classify_bootnodes(&[sample_enr(Ipv4Addr::new(10, 0, 0, 9), Some(0))]);
        assert!(dial_addrs.is_empty());
    }

    #[test]
    fn classify_bootnodes_skips_raw_multiaddr_with_zero_tcp_port() {
        let dial_addrs = classify_bootnodes(&["/ip4/10.0.0.9/tcp/0".to_string()]);
        assert!(dial_addrs.is_empty());
    }

    #[test]
    fn tcp_zero_enode_is_retained_only_for_discovery() {
        let enode = format!("enode://{}@10.0.1.5:0?discport=30304", sample_pubkey_hex());

        assert!(
            classify_bootnodes(std::slice::from_ref(&enode)).is_empty(),
            "TCP/0 must not become a direct dial target"
        );

        let nodes = parse_discovery_bootnodes(&[enode]);
        let [BootNode::Enode(addr)] = nodes.0.as_slice() else {
            panic!("TCP/0 enode must remain a discovery bootnode");
        };
        let addr = addr.to_string();
        assert!(addr.contains("/udp/30304/"), "discport must survive: {addr}");
        assert!(addr.contains("/tcp/0/"), "original TCP port must survive discovery: {addr}");
    }

    #[test]
    fn classify_bootnodes_empty() {
        assert!(classify_bootnodes(&[]).is_empty());
    }

    #[test]
    fn parse_discovery_bootnodes_keeps_enr_and_enode_entries() {
        // The enode pubkey must be a real curve point for the libp2p peer-id conversion.
        let enode = format!("enode://{}@10.0.1.5:4001?discport=30304", sample_pubkey_hex());
        let bootnodes = vec![
            sample_enr(Ipv4Addr::new(10, 0, 0, 9), Some(9222)),
            enode,
            "/ip4/1.2.3.4/tcp/9000".to_string(),
            "garbage".to_string(),
            "".to_string(),
        ];

        let nodes = parse_discovery_bootnodes(&bootnodes);

        assert_eq!(nodes.0.len(), 2, "one ENR and one enode entry should survive");
        assert!(matches!(nodes.0[0], BootNode::Enr(_)));
        let BootNode::Enode(ref addr) = nodes.0[1] else {
            panic!("expected unsigned enode bootnode");
        };
        let addr = addr.to_string();
        assert!(addr.contains("/ip4/10.0.1.5/"), "unexpected address: {addr}");
        assert!(addr.contains("/udp/30304/"), "discport must map to the UDP port: {addr}");
        assert!(addr.contains("/tcp/4001/"), "URL port must map to the TCP port: {addr}");
        let expected_peer = sample_libp2p_keypair().public().to_peer_id();
        assert!(
            addr.ends_with(&expected_peer.to_string()),
            "peer id must derive from the enode pubkey: {addr}"
        );
    }

    #[test]
    fn discovery_signing_key_requires_secp256k1_identity() {
        let err = discovery_signing_key(&identity::Keypair::generate_ed25519())
            .expect_err("ed25519 identities cannot sign ENRs");
        assert!(
            matches!(err, WhitelistPreconfirmationDriverError::P2p(message) if message.contains("secp256k1"))
        );

        let key = discovery_signing_key(&sample_libp2p_keypair()).expect("secp256k1 converts");
        assert_eq!(key.to_bytes().as_slice(), TEST_SECRET.as_slice());
    }

    #[test]
    fn discovered_candidate_pins_peer_id_and_skips_self() {
        let enr = sample_enr(Ipv4Addr::new(10, 0, 0, 9), Some(4001))
            .parse::<discv5::Enr>()
            .expect("valid enr");
        let local = sample_libp2p_keypair().public().to_peer_id();

        assert_eq!(
            discovered_candidate(&enr, &local),
            None,
            "an ENR signed with the local key is the local node"
        );

        let other = identity::Keypair::generate_secp256k1().public().to_peer_id();
        let addr = discovered_candidate(&enr, &other).expect("foreign peers are dialable");
        let addr = addr.to_string();
        assert!(addr.starts_with("/ip4/10.0.0.9/tcp/4001/p2p/"), "unexpected address: {addr}");
        assert!(addr.ends_with(&local.to_string()), "peer id must derive from the ENR key");
    }

    #[test]
    fn discovered_candidate_requires_tcp_socket() {
        let enr =
            sample_enr(Ipv4Addr::new(10, 0, 0, 9), None).parse::<discv5::Enr>().expect("valid enr");
        let other = identity::Keypair::generate_secp256k1().public().to_peer_id();

        assert_eq!(discovered_candidate(&enr, &other), None);
    }

    #[test]
    fn discovered_candidate_rejects_zero_tcp_port() {
        let enr = sample_enr(Ipv4Addr::new(10, 0, 0, 9), Some(0))
            .parse::<discv5::Enr>()
            .expect("valid enr");
        let other = identity::Keypair::generate_secp256k1().public().to_peer_id();

        assert_eq!(discovered_candidate(&enr, &other), None, "tcp/0 records are undialable");
    }

    #[test]
    fn enr_with_zero_ipv4_tcp_falls_back_to_ipv6_socket() {
        let key = enr::k256::ecdsa::SigningKey::from_slice(&TEST_SECRET).expect("valid key");
        let enr_str = enr::Enr::builder()
            .ip4(Ipv4Addr::new(10, 0, 0, 9))
            .tcp4(0)
            .ip6(Ipv6Addr::LOCALHOST)
            .tcp6(9222)
            .build(&key)
            .expect("valid enr")
            .to_base64();
        let expected =
            format!("/ip6/::1/tcp/9222/p2p/{}", sample_libp2p_keypair().public().to_peer_id());

        let dial_addrs = classify_bootnodes(std::slice::from_ref(&enr_str));
        assert_eq!(
            dial_addrs.iter().map(ToString::to_string).collect::<Vec<_>>(),
            vec![expected.clone()],
            "dual-stack records with tcp4/0 must fall back to the IPv6 socket"
        );

        let enr = enr_str.parse::<discv5::Enr>().expect("valid enr");
        let other = identity::Keypair::generate_secp256k1().public().to_peer_id();
        assert_eq!(
            discovered_candidate(&enr, &other).map(|addr| addr.to_string()),
            Some(expected),
            "discovered candidates must use the nonzero IPv6 socket"
        );
    }

    /// Full startup smoke test: the service binds a loopback UDP socket and publishes a
    /// local ENR carrying the advertised endpoint and the chain-id entry Go peers
    /// filter on.
    #[tokio::test]
    async fn spawn_discovery_publishes_chain_tagged_local_enr() {
        let key = sample_libp2p_keypair();
        let reserved = std::net::UdpSocket::bind("127.0.0.1:0").expect("reserve loopback port");
        let listen = reserved.local_addr().expect("reserved socket has a local address");
        assert_ne!(listen.port(), 0, "smoke test must configure an explicit UDP port");
        drop(reserved);
        let advertise: SocketAddr = "127.0.0.1:4001".parse().expect("valid socket");
        let chain_id = 167_012u64;

        let (handler, _enr_rx) =
            spawn_discovery(&key, chain_id, listen, advertise, BootNodes(Vec::new()))
                .expect("discovery should start on loopback");

        let enr = tokio::time::timeout(std::time::Duration::from_secs(10), handler.local_enr())
            .await
            .expect("local ENR request should not time out")
            .expect("discovery driver should answer");

        assert!(
            kona_peers::EnrValidation::validate(&enr, chain_id).is_valid(),
            "local ENR must carry the matching chain-id entry"
        );
        assert_eq!(enr.ip4(), Some(Ipv4Addr::new(127, 0, 0, 1)));
        assert_eq!(enr.tcp4(), Some(4001));
        assert_eq!(enr.udp4(), Some(listen.port()));
        assert_eq!(
            discovered_candidate(
                &enr,
                &identity::Keypair::generate_secp256k1().public().to_peer_id()
            )
            .map(|addr| addr.to_string()),
            Some(format!("/ip4/127.0.0.1/tcp/4001/p2p/{}", key.public().to_peer_id())),
            "the advertised ENR must convert into a dialable peer-id-pinned multiaddr"
        );
    }
}
