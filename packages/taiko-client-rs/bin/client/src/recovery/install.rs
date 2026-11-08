//! Fresh stores for a prepared generation: a new Comet home holding only its config, the
//! original P2P key and the plan's genesis, and a new empty app directory. Install never reads,
//! copies or creates a registered key, HRS or signing authority (RECOV-8.2-1..3).
use super::{
    RecoveryCommandError,
    plan::{RecoveryPlan, parent, read_bounded, sync_dir, write_new},
};
use std::{
    os::unix::fs::{DirBuilderExt, PermissionsExt},
    path::{Path, PathBuf},
};

/// Longest Unix socket path, without the terminating NUL, that fits macOS `sun_path` (Linux
/// allows 107). The supervisor's script uses the same bound.
const MAX_UNIX_SOCKET_PATH: usize = 103;
/// The longest name the supervisor gives a per-start signer socket in `<home>/run`.
const SIGNER_SOCKET_SAMPLE: &str = "run/signer-0000000000000000.sock";
/// The app's private trust socket in its data directory.
const TRUST_SOCKET: &str = "checkpoint-trust.sock";
/// Comet's subdirectories; `run/` holds the supervisor's signer sockets.
const HOME_DIRS: [&str; 3] = ["config", "data", "run"];

/// Writes `home` and `app_dir` for `plan`, or completes an interrupted install of the same
/// inputs; a repeated install changes nothing.
///
/// In order: validate the plan; render `comet_config` with the shared template helper and
/// check `node_key` is a stock Ed25519 transport key, never a registered FilePV or secp256k1
/// key (RECOV-8.2-2); refuse socket paths beyond the Unix limit; refuse an app directory that
/// is not absent or empty, since an earlier generation's latches and records must never count
/// for the new one (RECOV-8-14/16, SYNC-9-5c), and a home holding anything but the exact files
/// this install writes; create `home/{config,data,run}` and `app_dir` with mode 0700; write
/// config.toml, node_key.json and, last, genesis.json with mode 0600, each through a temporary
/// file, fsync and rename. genesis.json is the completion marker. Nothing is chowned: packaged
/// deployments chown the home to the Comet UID afterwards.
pub fn install(
    plan: &RecoveryPlan,
    comet_config: &Path,
    node_key: &Path,
    home: &Path,
    app_dir: &Path,
) -> Result<(), RecoveryCommandError> {
    plan.validate()?;
    let template = parse_comet_template(
        &read_bounded(comet_config, 1024 * 1024)
            .map_err(|_| RecoveryCommandError::Missing("readable Comet config template"))?,
    )?;
    let validator = validator_template(&template)?;
    let config = normalized_comet_config(template)?;
    let key = read_bounded(node_key, 16 * 1024)
        .map_err(|_| RecoveryCommandError::Missing("readable Comet node key"))?;
    validate_node_key(&key)?;
    check_socket_paths(home, app_dir, validator)?;
    check_fresh_app(app_dir)?;
    // genesis.json stays last: its presence means the whole install is durable.
    let files =
        [("config.toml", config), ("node_key.json", key), ("genesis.json", plan.genesis.to_vec())];
    check_fresh_home(home, &files)?;

    private_dir(home)?;
    for name in HOME_DIRS {
        private_dir(&home.join(name))?;
    }
    private_dir(app_dir)?;
    let config_dir = home.join("config");
    let (marker, contents) = files.split_last().expect("three files");
    for (name, bytes) in contents {
        publish(&config_dir, name, bytes)?;
    }
    for dir in HOME_DIRS.iter().map(|name| home.join(name)).chain([home.to_path_buf()]) {
        sync_dir(&dir)?;
    }
    sync_dir(parent(home))?;
    sync_dir(app_dir)?;
    sync_dir(parent(app_dir))?;
    publish(&config_dir, marker.0, &marker.1)?;
    sync_dir(&config_dir)
}

/// `path` with its existing parent resolved, as the supervisor and the app resolve theirs.
fn resolved(path: &Path) -> Result<PathBuf, RecoveryCommandError> {
    let name = path.file_name().ok_or(RecoveryCommandError::Parse("store directory path"))?;
    Ok(parent(path)
        .canonicalize()
        .map_err(|_| RecoveryCommandError::Missing("existing parent of each new store"))?
        .join(name))
}

/// Refuses a home or app directory whose sockets could not be bound: the app's trust socket
/// always, the supervisor's per-start signer socket for a validator.
fn check_socket_paths(
    home: &Path,
    app_dir: &Path,
    validator: bool,
) -> Result<(), RecoveryCommandError> {
    let fits = |path: PathBuf| path.as_os_str().len() <= MAX_UNIX_SOCKET_PATH;
    if !fits(resolved(app_dir)?.join(TRUST_SOCKET)) {
        return Err(RecoveryCommandError::Missing("shorter app directory path for its Unix socket"));
    }
    if validator && !fits(resolved(home)?.join(SIGNER_SOCKET_SAMPLE)) {
        return Err(RecoveryCommandError::Missing("shorter Comet home path for the signer socket"));
    }
    Ok(())
}

/// The names of a directory's entries.
fn entries(dir: &Path) -> Result<Vec<String>, RecoveryCommandError> {
    std::fs::read_dir(dir)
        .map_err(|_| RecoveryCommandError::Io("read directory"))?
        .map(|entry| {
            entry
                .map_err(|_| RecoveryCommandError::Io("read directory"))
                .map(|e| e.file_name().to_string_lossy().into_owned())
        })
        .collect()
}

/// Whether `path` is absent (false) or a real directory (true); anything else is refused.
fn existing_dir(path: &Path, refusal: &'static str) -> Result<bool, RecoveryCommandError> {
    match std::fs::symlink_metadata(path) {
        Err(error) if error.kind() == std::io::ErrorKind::NotFound => Ok(false),
        Err(_) => Err(RecoveryCommandError::Io("directory metadata")),
        Ok(metadata) if metadata.is_dir() => Ok(true),
        Ok(_) => Err(RecoveryCommandError::Missing(refusal)),
    }
}

/// The new generation's app directory must be absent or empty.
fn check_fresh_app(app_dir: &Path) -> Result<(), RecoveryCommandError> {
    const FRESH: &str = "fresh empty app directory";
    if existing_dir(app_dir, FRESH)? && !entries(app_dir)?.is_empty() {
        return Err(RecoveryCommandError::Missing(FRESH));
    }
    Ok(())
}

/// The home may only hold what an earlier run of this same install wrote: empty `data/` and
/// `run/`, and in `config/` byte-identical final files or this install's temporary files.
fn check_fresh_home(home: &Path, files: &[(&str, Vec<u8>)]) -> Result<(), RecoveryCommandError> {
    const FRESH: &str = "fresh Comet home";
    if !existing_dir(home, FRESH)? {
        return Ok(());
    }
    for name in entries(home)? {
        if !HOME_DIRS.contains(&name.as_str()) || !existing_dir(&home.join(&name), FRESH)? {
            return Err(RecoveryCommandError::Missing(FRESH));
        }
        if name != "config" && !entries(&home.join(&name))?.is_empty() {
            return Err(RecoveryCommandError::Missing(FRESH));
        }
    }
    let config = home.join("config");
    if !existing_dir(&config, FRESH)? {
        return Ok(());
    }
    for name in entries(&config)? {
        if let Some((_, bytes)) = files.iter().find(|(file, _)| *file == name) {
            if read_bounded(&config.join(&name), bytes.len() as u64 + 1)
                .map_err(|_| RecoveryCommandError::PlanMismatch)? !=
                *bytes
            {
                return Err(RecoveryCommandError::PlanMismatch);
            }
        } else if !files.iter().any(|(file, _)| name == temporary(file)) {
            return Err(RecoveryCommandError::Missing(FRESH));
        }
    }
    Ok(())
}

/// Creates a private directory, or makes an existing real one private.
fn private_dir(path: &Path) -> Result<(), RecoveryCommandError> {
    if existing_dir(path, "real directory")? {
        std::fs::set_permissions(path, std::fs::Permissions::from_mode(0o700))
            .map_err(|_| RecoveryCommandError::Io("make directory private"))
    } else {
        std::fs::DirBuilder::new()
            .mode(0o700)
            .create(path)
            .map_err(|_| RecoveryCommandError::Io("create private directory"))
    }
}

/// This install's temporary name for `name`.
fn temporary(name: &str) -> String {
    format!(".{name}.tmp")
}

/// Writes `dir/name` through a fresh temporary file, unless an identical file is already there
/// (checked by [`check_fresh_home`]). A leftover temporary file is this install's own.
fn publish(dir: &Path, name: &str, bytes: &[u8]) -> Result<(), RecoveryCommandError> {
    let target = dir.join(name);
    if std::fs::symlink_metadata(&target).is_ok() {
        return Ok(());
    }
    let pending = dir.join(temporary(name));
    if std::fs::symlink_metadata(&pending).is_ok() {
        std::fs::remove_file(&pending)
            .map_err(|_| RecoveryCommandError::Io("discard an interrupted write"))?;
    }
    write_new(&pending, bytes)?;
    std::fs::rename(&pending, &target).map_err(|_| RecoveryCommandError::Io("publish file"))
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

/// Whether the template configures an external signer (a validator); a full node has none.
fn validator_template(table: &toml::Table) -> Result<bool, RecoveryCommandError> {
    Ok(!table
        .get("priv_validator_laddr")
        .map(|v| v.as_str().ok_or(RecoveryCommandError::Parse("Comet signer address")))
        .transpose()?
        .unwrap_or("")
        .is_empty())
}

/// Normalize all stock path-bearing fields to the new home, keeping the template's own
/// listeners and peers. Never copy storage, registered key material or a signer state file.
///
/// Refuses what a fresh relative home cannot honour: no TCP `proxy_app`, a custom `home`, a
/// Unix RPC/gRPC/P2P listener, custom RPC TLS files, active state sync, or no `[p2p]` table.
/// A validator template (a non-empty `priv_validator_laddr`) gets the Unix placeholder
/// `unix://run/signer.sock`: it only selects the Unix transport, and the supervisor gives each
/// start its own socket in `run/`. Stock Comet then creates a disposable local FilePV in the
/// fresh relative paths, which never holds the registered identity.
pub(crate) fn normalized_comet_config(
    mut table: toml::Table,
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
    let validator = validator_template(&table)?;
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
/// A registered FilePV structure or another algorithm is never a transport identity
/// (RECOV-8.2-2: no copy of the registered key may sign outside its signer state).
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
                parse_comet_template(input.as_bytes()).and_then(normalized_comet_config).is_err(),
                "accepted {extra}"
            );
        }
        let ordinary=b"proxy_app='tcp://127.0.0.1:26658'\ndb_backend='goleveldb'\nconsensus.timeout_propose='3s'\n[mempool]\nkeep-invalid-txs-in-cache=false\n[p2p]\npex=false";
        assert!(parse_comet_template(ordinary).and_then(normalized_comet_config).is_ok());
    }
}
