//! Read-only authentication and immutable bundle preparation, without live-service mutation.
use super::{
    RecoveryCommandError,
    plan::{Deployment, Prerequisite, RecoveryPlan},
    profile::{NodeRole, RecoveryProfile, canonical_path},
    store::{RecoveryStore, read_bounded},
};
use abci::{
    ChainParams, Engine, L1Source,
    recovery::{
        authenticate_recovery, build_recovery_genesis, check_recovery_canonicality,
        verify_recovery_witness,
    },
};
use alloy_primitives::keccak256;
use std::{collections::BTreeMap, path::Path, time::Duration};

/// Overall acquisition deadline, independent of individual provider transport deadlines.
const PREPARE_DEADLINE: Duration = Duration::from_secs(120);
/// Preliminary EL read deadline; this is not a stateful build probe.
const READ_DEADLINE: Duration = Duration::from_secs(10);

/// Loads bounded ChainParams input and binds the full explicit profile deployment identity.
pub fn profile_params(profile: &RecoveryProfile) -> Result<ChainParams, RecoveryCommandError> {
    let bytes = read_bounded(&profile.chain_config, 1024 * 1024)
        .map_err(|_| RecoveryCommandError::Missing("ChainParams file"))?;
    let text =
        std::str::from_utf8(&bytes).map_err(|_| RecoveryCommandError::Parse("ChainParams"))?;
    let table: toml::Table =
        toml::from_str(text).map_err(|_| RecoveryCommandError::Parse("ChainParams"))?;
    let mut params = ChainParams::builtin(profile.l2_chain_id)
        .and_then(|p| p.with_overrides(text))
        .map_err(|_| RecoveryCommandError::ConfigMismatch)?;
    if table.contains_key("l1_chain_id") && params.l1_chain_id != profile.l1_chain_id {
        return Err(RecoveryCommandError::ConfigMismatch);
    }
    params.l1_chain_id = profile.l1_chain_id;
    params.validate().map_err(|_| RecoveryCommandError::ConfigMismatch)?;
    Ok(params)
}

/// Authenticates an exact generation and stages immutable files only; never starts children,
/// changes forkchoice, builds payloads, or touches original signer/Comet/app state.
pub async fn prepare<L: L1Source + ?Sized, E: Engine + ?Sized>(
    profile: &RecoveryProfile,
    generation: u64,
    root: &Path,
    l1: &L,
    engine: &E,
) -> Result<RecoveryPlan, RecoveryCommandError> {
    profile.validate()?;
    profile.validate_root(root)?;
    if generation == 0 || generation >= 1 << 48 {
        return Err(RecoveryCommandError::Parse("nonzero uint48 generation"));
    }
    let params = profile_params(profile)?;
    let (witness, genesis) = tokio::time::timeout(PREPARE_DEADLINE, async {
        let witness = authenticate_recovery(l1, engine, &params, generation).await?;
        let genesis = build_recovery_genesis(l1, engine, &params, generation).await?;
        Ok::<_, abci::recovery::RecoveryError>((witness, genesis))
    })
    .await
    .map_err(|_| RecoveryCommandError::Runtime("recovery authentication deadline"))??;
    let origin = verify_recovery_witness(&witness, &params)?;
    let mut prerequisites = vec![Prerequisite::ActivationBuildProbe];
    if profile.lander.is_some() {
        prerequisites.push(Prerequisite::LanderReconciliation);
    }
    match tokio::time::timeout(READ_DEADLINE, engine.historical_state_available(origin.el_hash))
        .await
    {
        Ok(Ok(true)) => {}
        Ok(Err(error)) if error.is_integrity_failure() => return Err(RecoveryCommandError::Invalid),
        _ => prerequisites.push(Prerequisite::HistoricalState),
    }
    match tokio::time::timeout(READ_DEADLINE, engine.finalized_header()).await {
        Ok(Ok(Some(_))) => {}
        Ok(Err(error)) if error.is_integrity_failure() => return Err(RecoveryCommandError::Invalid),
        _ => prerequisites.push(Prerequisite::FinalizedHeader),
    }
    let genesis = genesis.to_json_pretty().into_bytes();
    let deployment = Deployment::from(&params);
    let mut artifacts: BTreeMap<String, Vec<u8>> = BTreeMap::from([
        ("comet/config/genesis.json".into(), genesis.clone()),
        (
            "app-chain.toml".into(),
            toml::to_string(&deployment)
                .map_err(|_| RecoveryCommandError::Parse("ChainParams serialization"))?
                .into_bytes(),
        ),
    ]);
    match comet_template(profile) {
        Ok(config) => {
            artifacts.insert("comet/config/config.toml".into(), config);
        }
        Err(_) => prerequisites.push(Prerequisite::CometTemplate),
    }
    match node_key(profile) {
        Ok(key) => {
            artifacts.insert("comet/config/node_key.json".into(), key);
        }
        Err(_) => prerequisites.push(Prerequisite::CometNodeKey),
    }
    // Namespace length is fixed, so prerequisite calculation does not depend on the final ID.
    let canonical_root = canonical_path(root)?;
    let sample = RecoveryStore::new(&canonical_root).plan_dir(alloy_primitives::B256::ZERO);
    if ["app/checkpoint-trust.sock", "comet/run/signer.sock"]
        .iter()
        .any(|name| sample.join(name).as_os_str().as_encoded_bytes().len() > 103)
    {
        prerequisites.push(Prerequisite::RuntimeSocketPath);
    }
    let plan = RecoveryPlan {
        schema: 1,
        profile_digest: profile.digest(),
        deployment,
        witness: alloy_rlp::encode(&witness).into(),
        origin,
        genesis: genesis.into(),
        artifacts: artifacts.iter().map(|(n, b)| (n.clone(), keccak256(b))).collect(),
        prerequisites,
        client_version: env!("CARGO_PKG_VERSION").into(),
    };
    plan.validate()?;
    // Recheck after preliminary reads/template staging and immediately before publication.
    tokio::time::timeout(PREPARE_DEADLINE, check_recovery_canonicality(l1, &params, &witness))
        .await
        .map_err(|_| RecoveryCommandError::Runtime("final recovery recheck deadline"))??;
    RecoveryStore::new(root).publish_plan(&plan, profile, &artifacts)?;
    Ok(plan)
}

/// Produces fresh stock Comet configuration from a public template, never copying runtime data.
/// Missing/ambiguous tables, external signer role mismatches and arbitrary database/WAL paths
/// become an explicit prerequisite; only controller-managed relative storage survives.
fn comet_template(profile: &RecoveryProfile) -> Result<Vec<u8>, RecoveryCommandError> {
    let bytes = read_bounded(&profile.comet_home.join("config/config.toml"), 1024 * 1024)?;
    normalized_comet_config(
        parse_comet_template(&bytes)?,
        profile.role == NodeRole::Validator,
        Some(&profile.peers),
    )
}

/// Accept a TOML spelling only when Rust and pinned stock Viper see the same keys. TOML
/// already expands ordinary dotted syntax to nested tables. Literal dotted keys and
/// mixed-case aliases would survive a normal round trip yet shadow normalized settings.
pub(crate) fn parse_comet_template(bytes: &[u8]) -> Result<toml::Table, RecoveryCommandError> {
    let value: toml::Value = toml::from_str(
        std::str::from_utf8(bytes).map_err(|_| RecoveryCommandError::Parse("Comet template"))?,
    )
    .map_err(|_| RecoveryCommandError::Parse("Comet template"))?;
    if !canonical_comet_keys(&value) {
        return Err(RecoveryCommandError::Parse("ambiguous Comet configuration key"))
    }
    match value {
        toml::Value::Table(table) => Ok(table),
        _ => Err(RecoveryCommandError::Parse("Comet template")),
    }
}

/// Stock's own keys use lowercase ASCII, digits, hyphens and underscores. Check nested
/// inline tables and arrays of tables as well as ordinary sections.
fn canonical_comet_keys(value: &toml::Value) -> bool {
    match value {
        toml::Value::Table(table) => table.iter().all(|(key, v)| {
            !key.is_empty() &&
                key.bytes().all(|b| {
                    b.is_ascii_lowercase() || b.is_ascii_digit() || matches!(b, b'_' | b'-')
                }) &&
                canonical_comet_keys(v)
        }),
        toml::Value::Array(values) => values.iter().all(canonical_comet_keys),
        _ => true,
    }
}

/// Normalize all stock path-bearing fields to the new home, and preserve only explicit
/// peer settings. Never copy storage, registered key material or a signer state file.
pub(crate) fn normalized_comet_config(
    mut table: toml::Table,
    validator: bool,
    peers: Option<&[String]>,
) -> Result<Vec<u8>, RecoveryCommandError> {
    if table.get("proxy_app").and_then(toml::Value::as_str).is_none() {
        return Err(RecoveryCommandError::Missing("Comet template proxy_app"));
    }
    // Stock v0.40 path-bearing fields are intentionally handled exhaustively. A custom home,
    // Unix ABCI/RPC endpoint, state import or TLS key layout needs explicit operator repair.
    if table.contains_key("home") ||
        !table["proxy_app"].as_str().is_some_and(|s| s.starts_with("tcp://"))
    {
        return Err(RecoveryCommandError::Missing("supported Comet template layout"));
    }
    for section in ["rpc", "p2p", "mempool", "consensus", "statesync"] {
        if let Some(value) = table.get_mut(section) {
            let fields = value
                .as_table_mut()
                .ok_or(RecoveryCommandError::Parse("Comet template section"))?;
            if fields.contains_key("home") ||
                ["laddr", "grpc_laddr"].iter().any(|name| {
                    fields.get(*name).is_some_and(|v| {
                        v.as_str().is_none_or(|listeners| {
                            listeners.split(',').any(|address| {
                                address.trim().split_once("://").is_some_and(|(protocol, _)| {
                                    matches!(protocol, "unix" | "unixpacket")
                                })
                            })
                        })
                    })
                })
            {
                return Err(RecoveryCommandError::Missing("supported Comet template layout"));
            }
            if section == "rpc" &&
                ["tls_cert_file", "tls_key_file"]
                    .iter()
                    .any(|name| fields.get(*name).is_some_and(|v| v.as_str() != Some("")))
            {
                return Err(RecoveryCommandError::Missing("fresh Comet TLS configuration"));
            }
            if section == "mempool" {
                fields.insert("wal_dir".into(), toml::Value::String("data/mempool.wal".into()));
            }
            if section == "statesync" {
                if fields.get("enable").is_some_and(|v| v.as_bool() != Some(false)) {
                    return Err(RecoveryCommandError::Missing("state-sync disabled Comet template"));
                }
                fields.insert("temp_dir".into(), toml::Value::String(String::new()));
            }
        }
    }
    let signer = table
        .get("priv_validator_laddr")
        .map(|v| v.as_str().ok_or(RecoveryCommandError::Parse("Comet signer address")))
        .transpose()?
        .unwrap_or("");
    if validator == signer.is_empty() {
        return Err(RecoveryCommandError::Missing("role-compatible Comet signer template"));
    }
    for (name, value) in [
        ("genesis_file", "config/genesis.json"),
        ("db_dir", "data"),
        ("node_key_file", "config/node_key.json"),
        ("priv_validator_key_file", "config/priv_validator_key.json"),
        ("priv_validator_state_file", "data/priv_validator_state.json"),
    ] {
        table.insert(name.into(), toml::Value::String(value.into()));
    }
    if validator {
        // Stock initializes a disposable local FilePV before replacing it with the mandatory
        // external signer. These fresh relative paths never contain the registered identity.
        table.insert(
            "priv_validator_laddr".into(),
            toml::Value::String("unix://run/signer.sock".into()),
        );
    }
    let p2p = table
        .get_mut("p2p")
        .and_then(toml::Value::as_table_mut)
        .ok_or(RecoveryCommandError::Missing("Comet p2p template"))?;
    p2p.insert("addr_book_file".into(), toml::Value::String("config/addrbook.json".into()));
    if let Some(peers) = peers {
        p2p.insert("persistent_peers".into(), toml::Value::String(peers.join(",")));
    }
    if let Some(consensus) = table.get_mut("consensus") {
        let consensus = consensus
            .as_table_mut()
            .ok_or(RecoveryCommandError::Parse("Comet consensus template"))?;
        consensus.insert("wal_file".into(), toml::Value::String("data/cs.wal/wal".into()));
    }
    toml::to_string(&table)
        .map(String::into_bytes)
        .map_err(|_| RecoveryCommandError::Parse("Comet template serialization"))
}

/// Stock transport-key envelope, deliberately excluding registered FilePV metadata.
#[derive(serde::Deserialize)]
#[serde(deny_unknown_fields)]
struct TransportKey {
    /// Stock-compatible key decoder validates the Ed25519 seed/public-key pair.
    priv_key: tendermint::private_key::PrivateKey,
}

/// Validates stock Ed25519 P2P key bytes using the pinned Tendermint decoder, without signing.
/// Registered FilePV structures and other algorithms are never staged as transport identities.
pub fn validate_node_key(bytes: &[u8]) -> Result<(), RecoveryCommandError> {
    if bytes.len() > 16 * 1024 {
        return Err(RecoveryCommandError::Parse("Comet node key size"));
    }
    let shape: serde_json::Value =
        serde_json::from_slice(bytes).map_err(|_| RecoveryCommandError::Parse("Comet node key"))?;
    if shape.get("priv_key").and_then(serde_json::Value::as_object).is_none_or(|fields| {
        fields.len() != 2 || !fields.contains_key("type") || !fields.contains_key("value")
    }) {
        return Err(RecoveryCommandError::Parse("Comet node key"));
    }
    let key: TransportKey =
        serde_json::from_slice(bytes).map_err(|_| RecoveryCommandError::Parse("Comet node key"))?;
    if !matches!(key.priv_key, tendermint::private_key::PrivateKey::Ed25519(_)) {
        return Err(RecoveryCommandError::Parse("Comet node key algorithm"));
    }
    Ok(())
}

/// Preserves the explicitly configured original P2P identity in the private immutable bundle.
/// A nondefault node-key layout requires operator normalization, rather than guessing a key.
fn node_key(profile: &RecoveryProfile) -> Result<Vec<u8>, RecoveryCommandError> {
    let config = read_bounded(&profile.comet_home.join("config/config.toml"), 1024 * 1024)?;
    let config: toml::Table = toml::from_str(
        std::str::from_utf8(&config).map_err(|_| RecoveryCommandError::Parse("Comet template"))?,
    )
    .map_err(|_| RecoveryCommandError::Parse("Comet template"))?;
    if config.get("node_key_file").is_some_and(|v| v.as_str() != Some("config/node_key.json")) {
        return Err(RecoveryCommandError::Missing("stock P2P node key layout"));
    }
    let path = profile.comet_home.join("config/node_key.json");
    super::store::check_private_file(&path)?;
    let bytes = read_bounded(&path, 16 * 1024)?;
    validate_node_key(&bytes)?;
    Ok(bytes)
}

#[cfg(test)]
mod effective_config_tests {
    use super::*;
    #[test]
    fn viper_aliases_cannot_shadow_canonical_paths_or_consensus_settings() {
        for extra in [
            "DB_BACKEND='memdb'",
            "DB_DIR='foreign'",
            "'statesync.enable'=true",
            "'consensus.wal_file'='foreign/wal'",
            "'consensus.timeout_propose'='-1s'",
            "[CONSENSUS]\nTIMEOUT_PROPOSE='-1s'",
            "[[test]]\n'foo.bar'=true",
            "statesync.enable='true'",
            "rpc.tls_key_file=1",
        ] {
            let input = format!("proxy_app='tcp://127.0.0.1:26658'\n{extra}\n[p2p]\npex=false");
            assert!(
                parse_comet_template(input.as_bytes())
                    .and_then(|t| normalized_comet_config(t, false, None))
                    .is_err(),
                "accepted {extra}"
            );
        }
        let ordinary=b"proxy_app='tcp://127.0.0.1:26658'\ndb_backend='goleveldb'\nconsensus.timeout_propose='3s'\n[mempool]\nkeep-invalid-txs-in-cache=false\n[p2p]\npex=false";
        assert!(
            parse_comet_template(ordinary)
                .and_then(|t| normalized_comet_config(t, false, None))
                .is_ok()
        );
    }
}
