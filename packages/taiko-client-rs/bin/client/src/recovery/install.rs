//! Separately owned Comet installation; private plans and registered keys stay protected.
use super::{
    RecoveryCommandError, plan::RecoveryPlan, profile::RecoveryProfile, store::RecoveryStore,
};
use alloy_primitives::B256;
use serde::{Deserialize, Serialize};
use std::path::PathBuf;

/// Immutable runtime location and OS identity, bound by the active descriptor and private marker.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct InstalledComet {
    /// Full plan identity; short directory names never resolve a prefix collision silently.
    pub plan_id: B256,
    /// Absolute separate home under a controller-protected searchable parent.
    pub home: PathBuf,
    /// Actual Comet user, the only non-controller owner of its P2P key.
    pub uid: u32,
    /// Actual Comet primary group; no supplementary groups are granted.
    pub gid: u32,
}
/// Derive and validate the runtime binding before creating anything.
pub fn binding(
    profile: &RecoveryProfile,
    id: B256,
) -> Result<InstalledComet, RecoveryCommandError> {
    use std::os::unix::fs::MetadataExt;
    let executable = profile.signer.as_ref().map_or(&profile.comet, |s| &s.supervisor);
    let identity = |key: &str, fallback: u32| -> Result<u32, RecoveryCommandError> {
        executable
            .env
            .get(key)
            .cloned()
            .or_else(|| std::env::var(key).ok())
            .map_or(Ok(fallback), |v| {
                v.parse().map_err(|_| RecoveryCommandError::Parse("Comet OS identity"))
            })
    };
    // SAFETY: identity reads have no preconditions or side effects.
    let caller = unsafe { libc::geteuid() };
    let uid = identity("ETNA_COMET_UID", caller)?;
    let gid = identity("ETNA_COMET_GID", unsafe { libc::getegid() })?;
    if caller != 0 && (uid != caller || gid != unsafe { libc::getegid() }) {
        return Err(RecoveryCommandError::Missing("privilege for configured Comet identity"));
    }
    let parent = super::profile::canonical_path(profile.installation_parent.as_deref().unwrap_or(
        profile.comet_home.parent().ok_or(RecoveryCommandError::Parse("Comet parent"))?,
    ))?;
    let metadata = std::fs::metadata(&parent)
        .map_err(|_| RecoveryCommandError::Missing("Comet installation parent"))?;
    if !metadata.is_dir() ||
        metadata.mode() & 0o022 != 0 ||
        ![0, caller].contains(&metadata.uid()) ||
        (uid != caller && metadata.uid() == uid)
    {
        return Err(RecoveryCommandError::Missing("protected Comet installation parent"));
    }
    for ancestor in parent.ancestors() {
        let m = std::fs::metadata(ancestor)
            .map_err(|_| RecoveryCommandError::Missing("searchable Comet ancestors"))?;
        let search = if uid == 0 {
            true
        } else if m.uid() == uid {
            m.mode() & 0o100 != 0
        } else if m.gid() == gid {
            m.mode() & 0o010 != 0
        } else {
            m.mode() & 0o001 != 0
        };
        if !m.is_dir() || !search {
            return Err(RecoveryCommandError::Missing(
                "searchable installation-parent override for Comet UID",
            ));
        }
    }
    let home = parent.join(format!("etna-comet-{}", &format!("{id:x}")[..16]));
    if home.join("run/signer.sock").as_os_str().as_encoded_bytes().len() > 103 {
        return Err(RecoveryCommandError::Missing("shorter Comet installation-parent"));
    }
    Ok(InstalledComet { plan_id: id, home, uid, gid })
}

impl InstalledComet {
    /// Controller-owned adjacent marker stays outside the Comet UID's writable subtree.
    fn marker(&self) -> Result<PathBuf, RecoveryCommandError> {
        let name = self
            .home
            .file_name()
            .ok_or(RecoveryCommandError::PlanMismatch)?
            .to_str()
            .ok_or(RecoveryCommandError::PlanMismatch)?;
        Ok(self
            .home
            .parent()
            .ok_or(RecoveryCommandError::PlanMismatch)?
            .join(format!(".{name}.recovery.json")))
    }
    /// Validate full identity, refusing missing metadata rather than regenerating over a store.
    pub fn verify_marker(&self) -> Result<(), RecoveryCommandError> {
        let marker = self.marker()?;
        super::store::check_private_file(&marker)?;
        let actual: Self =
            serde_json::from_slice(&super::store::read_bounded(&marker, 1024 * 1024)?)
                .map_err(|_| RecoveryCommandError::PlanMismatch)?;
        if actual != *self {
            return Err(RecoveryCommandError::PlanMismatch)
        }
        super::store::check_private_dir(&self.home)
    }
}

/// Reserve a deterministic empty runtime home before acquiring its adjacent component lease.
pub fn reserve(installed: &InstalledComet) -> Result<(), RecoveryCommandError> {
    use super::store::{check_private_dir, private_dir, sync_dir, write_new};
    let marker = installed.marker()?;
    if std::fs::symlink_metadata(&marker).is_ok() {
        installed.verify_marker()?;
        return private_dir(&installed.home.join("data"))
    }
    if std::fs::symlink_metadata(&installed.home).is_ok() {
        check_private_dir(&installed.home)?;
        if std::fs::read_dir(&installed.home)
            .map_err(|_| RecoveryCommandError::Io("inspect fresh Comet home"))?
            .next()
            .is_some()
        {
            return Err(RecoveryCommandError::PlanMismatch)
        }
    } else {
        private_dir(&installed.home)?;
    }
    let pending = marker.with_extension("pending");
    let bytes = serde_json::to_vec(installed)
        .map_err(|_| RecoveryCommandError::Parse("Comet installation"))?;
    if std::fs::symlink_metadata(&pending).is_ok() {
        super::store::check_private_file(&pending)?;
        if super::store::read_bounded(&pending, 1024 * 1024)? != bytes {
            return Err(RecoveryCommandError::PlanMismatch)
        }
    } else {
        write_new(&pending, &bytes)?;
    }
    std::fs::rename(&pending, &marker)
        .map_err(|_| RecoveryCommandError::Io("publish installation reservation"))?;
    sync_dir(installed.home.parent().ok_or(RecoveryCommandError::PlanMismatch)?)?;
    private_dir(&installed.home.join("data"))?;
    Ok(())
}

/// Install only immutable config/genesis and private P2P bytes; never signer/HRS/WAL history.
pub fn install(
    store: &RecoveryStore,
    plan: &RecoveryPlan,
    installed: &InstalledComet,
) -> Result<(), RecoveryCommandError> {
    use super::store::{MAX_PLAN_BYTES, private_dir, read_bounded, sync_dir, write_new};
    installed.verify_marker()?;
    if installed.plan_id != plan.id() {
        return Err(RecoveryCommandError::PlanMismatch)
    }
    store.load_plan(plan.id())?;
    for name in ["config/config.toml", "config/genesis.json", "config/node_key.json"] {
        if !plan.artifacts.contains_key(&format!("comet/{name}")) {
            return Err(RecoveryCommandError::Missing(
                "immutable Comet config/genesis/P2P; prepare again",
            ))
        }
    }
    for name in ["config", "data", "run"] {
        private_dir(&installed.home.join(name))?;
    }
    for name in ["config/config.toml", "config/genesis.json", "config/node_key.json"] {
        let bytes =
            read_bounded(&store.plan_dir(plan.id()).join("comet").join(name), MAX_PLAN_BYTES)?;
        let target = installed.home.join(name);
        if std::fs::symlink_metadata(&target).is_ok() {
            if read_bounded(&target, MAX_PLAN_BYTES)? != bytes {
                return Err(RecoveryCommandError::PlanMismatch)
            }
        } else {
            let pending = target.with_extension("pending");
            if std::fs::symlink_metadata(&pending).is_ok() {
                super::store::check_private_file(&pending)?;
                std::fs::remove_file(&pending)
                    .map_err(|_| RecoveryCommandError::Io("discard incomplete immutable copy"))?;
            }
            write_new(&pending, &bytes)?;
            std::fs::rename(&pending, &target)
                .map_err(|_| RecoveryCommandError::Io("publish immutable Comet copy"))?;
        }
        std::os::unix::fs::chown(&target, Some(installed.uid), Some(installed.gid))
            .map_err(|_| RecoveryCommandError::Missing("Comet artifact ownership"))?;
        std::fs::File::open(&target)
            .and_then(|f| f.sync_all())
            .map_err(|_| RecoveryCommandError::Io("sync installed ownership"))?;
    }
    for name in ["config", "data", "run", ""] {
        let directory = installed.home.join(name);
        std::os::unix::fs::chown(&directory, Some(installed.uid), Some(installed.gid))
            .map_err(|_| RecoveryCommandError::Missing("Comet directory ownership"))?;
        sync_dir(&directory)?;
    }
    sync_dir(installed.home.parent().ok_or(RecoveryCommandError::PlanMismatch)?)
}

/// Recheck the immutable copied artifacts, full installation identity and actual owner/modes.
pub fn verify(
    store: &RecoveryStore,
    plan: &RecoveryPlan,
    installed: &InstalledComet,
) -> Result<(), RecoveryCommandError> {
    use std::os::unix::fs::MetadataExt;
    installed.verify_marker()?;
    if installed.plan_id != plan.id() {
        return Err(RecoveryCommandError::PlanMismatch)
    }
    for name in ["", "config", "data", "run"] {
        let path = installed.home.join(name);
        super::store::check_private_dir(&path)?;
        let metadata =
            std::fs::symlink_metadata(&path).map_err(|_| RecoveryCommandError::PlanMismatch)?;
        if metadata.uid() != installed.uid || metadata.gid() != installed.gid {
            return Err(RecoveryCommandError::PlanMismatch)
        }
    }
    for name in ["config/config.toml", "config/genesis.json", "config/node_key.json"] {
        let path = installed.home.join(name);
        let metadata =
            std::fs::symlink_metadata(&path).map_err(|_| RecoveryCommandError::PlanMismatch)?;
        if !metadata.is_file() ||
            metadata.uid() != installed.uid ||
            metadata.gid() != installed.gid ||
            metadata.mode() & 0o077 != 0 ||
            plan.artifacts.get(&format!("comet/{name}")) !=
                Some(&alloy_primitives::keccak256(super::store::read_bounded(
                    &path,
                    super::store::MAX_PLAN_BYTES,
                )?))
        {
            return Err(RecoveryCommandError::PlanMismatch)
        }
    }
    store.load_plan(plan.id())?;
    Ok(())
}
