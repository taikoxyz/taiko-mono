//! Private schema-one deployment profile; never rendered in public reports.

use super::RecoveryCommandError;
use alloy_primitives::{B256, keccak256};
use serde::{Deserialize, Serialize};
use std::{
    collections::BTreeMap,
    path::{Path, PathBuf},
};

/// Whether the recovered node has a registered validator key.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "kebab-case")]
pub enum NodeRole {
    /// A registered validator using the external guarded signer and supervisor.
    Validator,
    /// A non-signing consensus full node, with no registered signer configuration.
    FullNode,
}

/// Executable prefix passed directly to Command, without shell interpretation.
#[derive(Clone, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Executable {
    /// Absolute executable path supplied explicitly by the operator.
    pub program: PathBuf,
    /// Ordered private argument prefix; controller-owned flags are appended later.
    pub argv: Vec<String>,
    /// Explicit private environment values, never printed or inherited into a public plan.
    #[serde(default)]
    pub env: BTreeMap<String, String>,
}

/// Original permanent validator bindings, outside every disposable app/Comet tree.
#[derive(Clone, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct SignerProfile {
    /// Existing registered FilePV key; never copied into staging.
    pub key: PathBuf,
    /// Original generation-zero FilePV HRS path; never reset or migrated.
    pub state: PathBuf,
    /// Private authority directory retained across generations.
    pub authority: PathBuf,
    /// Guarded signer executable prefix.
    pub executable: Executable,
    /// Explicit packaged supervisor executable prefix.
    pub supervisor: Executable,
}

/// Optional independently owned transaction sender configuration.
#[derive(Clone, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct LanderProfile {
    /// Original account journal directory, reused without rewriting signed bytes.
    pub data_dir: PathBuf,
    /// Explicit lander command prefix and private environment.
    pub executable: Executable,
}

/// Version-one private operator input, including endpoints and original component paths.
#[derive(Clone, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct RecoveryProfile {
    /// Supported private input schema; exactly one.
    pub schema: u32,
    /// Node's consensus role.
    pub role: NodeRole,
    /// Explicit full-width deployment L1 identifier.
    pub l1_chain_id: alloy_primitives::U256,
    /// Deployment L2 identifier selecting built-in parameters.
    pub l2_chain_id: u64,
    /// Explicit ChainParams TOML override file.
    pub chain_config: PathBuf,
    /// Own L1 endpoint, potentially containing credentials.
    pub l1_http: String,
    /// Public EL endpoint, potentially containing credentials.
    pub l2_http: String,
    /// Private authenticated EL endpoint.
    pub l2_auth: String,
    /// Private JWT file path; its contents never enter the plan.
    pub jwt_secret: PathBuf,
    /// Original app data directory to preserve.
    pub app_data_dir: PathBuf,
    /// Original Comet home; config/config.toml is the read-only template.
    pub comet_home: PathBuf,
    /// App executable prefix.
    pub app: Executable,
    /// Stock Comet executable prefix.
    pub comet: Executable,
    /// Explicit persistent peer list for the fresh Comet configuration.
    pub peers: Vec<String>,
    /// Validator-only original private signer bindings.
    pub signer: Option<SignerProfile>,
    /// Optional independent lander preserving its original journal.
    pub lander: Option<LanderProfile>,
    /// Optional protected, searchable parent for the separately owned Comet installation.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub installation_parent: Option<PathBuf>,
    /// Pinned stock-library read-only Comet inspector executable, required for activation.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub inspector: Option<Executable>,
}

impl RecoveryProfile {
    /// Reads bounded private TOML and checks schema, role and path separation.
    pub fn load(path: &Path) -> Result<Self, RecoveryCommandError> {
        super::store::check_private_file(path)?;
        let bytes = super::store::read_bounded(path, 1024 * 1024)?;
        let profile: Self = toml::from_str(
            std::str::from_utf8(&bytes).map_err(|_| RecoveryCommandError::Parse("profile"))?,
        )
        .map_err(|_| RecoveryCommandError::Parse("profile"))?;
        profile.validate()?;
        Ok(profile)
    }

    /// Validates role combinations, explicit endpoints and disjoint persistent stores.
    pub fn validate(&self) -> Result<(), RecoveryCommandError> {
        if self.schema != 1 || (self.role == NodeRole::Validator) != self.signer.is_some() {
            return Err(RecoveryCommandError::Parse("profile schema or role"));
        }
        for endpoint in [&self.l1_http, &self.l2_http, &self.l2_auth] {
            let url =
                url::Url::parse(endpoint).map_err(|_| RecoveryCommandError::Parse("endpoint"))?;
            if !matches!(url.scheme(), "http" | "https") || url.host_str().is_none() {
                return Err(RecoveryCommandError::Parse("endpoint"));
            }
        }
        if !self.l2_auth.starts_with("http://") {
            return Err(RecoveryCommandError::Parse("authenticated endpoint"));
        }
        let mut stores =
            vec![canonical_path(&self.app_data_dir)?, canonical_path(&self.comet_home)?];
        if let Some(lander) = &self.lander {
            stores.push(canonical_path(&lander.data_dir)?);
        }
        for (i, path) in stores.iter().enumerate() {
            if stores.iter().skip(i + 1).any(|other| overlaps(path, other)) {
                return Err(RecoveryCommandError::Parse("overlapping component stores"));
            }
        }
        for path in [&self.chain_config, &self.jwt_secret] {
            canonical_path(path)?;
        }
        let mut executables = vec![&self.app, &self.comet];
        if let Some(signer) = &self.signer {
            let key = canonical_path(&signer.key)?;
            let state = canonical_path(&signer.state)?;
            let authority = canonical_path(&signer.authority)?;
            if key == state ||
                key == authority ||
                state == authority ||
                [&key, &state, &authority]
                    .iter()
                    .any(|path| stores.iter().any(|store| overlaps(path, store)))
            {
                return Err(RecoveryCommandError::Parse("overlapping signer storage"));
            }
            executables.extend([&signer.executable, &signer.supervisor]);
        }
        if let Some(lander) = &self.lander {
            executables.push(&lander.executable);
        }
        if let Some(inspector) = &self.inspector {
            executables.push(inspector);
        }
        if let Some(parent) = &self.installation_parent {
            canonical_path(parent)?;
        }
        for executable in executables {
            if !executable.program.is_absolute() ||
                executable.argv.iter().any(|arg| arg.contains('\0')) ||
                executable
                    .env
                    .iter()
                    .any(|(k, v)| k.is_empty() || k.contains(['=', '\0']) || v.contains('\0'))
            {
                return Err(RecoveryCommandError::Parse("executable"));
            }
        }
        Ok(())
    }

    /// Checks the new root against every original store and private input before any write.
    pub fn validate_root(&self, root: &Path) -> Result<(), RecoveryCommandError> {
        let root = canonical_path(root)?;
        let mut paths =
            vec![&self.app_data_dir, &self.comet_home, &self.chain_config, &self.jwt_secret];
        if let Some(signer) = &self.signer {
            paths.extend([&signer.key, &signer.state, &signer.authority]);
        }
        if let Some(lander) = &self.lander {
            paths.push(&lander.data_dir);
        }
        for path in paths {
            if overlaps(&root, &canonical_path(path)?) {
                return Err(RecoveryCommandError::Parse("recovery root overlaps original storage"));
            }
        }
        Ok(())
    }

    /// Canonical private-profile commitment; only this digest enters the public plan.
    pub fn digest(&self) -> B256 {
        keccak256(serde_json::to_vec(self).expect("fixed profile serialization"))
    }
}

/// Resolves existing ancestors and symlink aliases without requiring a future path to exist.
/// Dot/parent components are rejected so path ownership cannot acquire alternate spellings.
pub fn canonical_path(path: &Path) -> Result<PathBuf, RecoveryCommandError> {
    if !path.is_absolute() ||
        path.components()
            .any(|c| matches!(c, std::path::Component::ParentDir | std::path::Component::CurDir))
    {
        return Err(RecoveryCommandError::Parse("absolute component path"));
    }
    if std::fs::symlink_metadata(path).is_ok() {
        return path.canonicalize().map_err(|_| RecoveryCommandError::Io("resolve path"));
    }
    let parent = path.parent().ok_or(RecoveryCommandError::Parse("component path"))?;
    let name = path.file_name().ok_or(RecoveryCommandError::Parse("component path"))?;
    Ok(canonical_path(parent)?.join(name))
}
/// Whether either path contains the other; callers first resolve aliases with canonical_path.
pub fn overlaps(a: &Path, b: &Path) -> bool {
    a.starts_with(b) || b.starts_with(a)
}
