//! Bounded private storage and atomic durable publication of immutable recovery bundles.
use super::{
    RecoveryCommandError,
    plan::{RecoveryPlan, valid_artifact},
    profile::RecoveryProfile,
    status::RecoveryJournal,
};
use alloy_primitives::{B256, keccak256};
use std::{
    collections::BTreeMap,
    fs::{File, OpenOptions},
    io::{Read, Write},
    path::{Path, PathBuf},
};

/// Maximum accepted serialized plan/artifact size in bytes.
pub const MAX_PLAN_BYTES: u64 = 16 * 1024 * 1024;

/// Opens a regular file without following its final symlink, using private modes on creation.
fn open_file(path: &Path, create_new: bool) -> Result<File, RecoveryCommandError> {
    let mut options = OpenOptions::new();
    options.read(true);
    if create_new {
        options.write(true).create_new(true);
    }
    #[cfg(unix)]
    {
        use std::os::unix::fs::OpenOptionsExt;
        options.mode(0o600).custom_flags(libc::O_NOFOLLOW | libc::O_NONBLOCK);
    }
    let file = options.open(path).map_err(|_| RecoveryCommandError::Io("open regular file"))?;
    if !file.metadata().map_err(|_| RecoveryCommandError::Io("file metadata"))?.is_file() {
        return Err(RecoveryCommandError::Parse("file type"));
    }
    Ok(file)
}
/// Reads a regular input with an allocation bound and detects concurrent size changes.
pub fn read_bounded(path: &Path, limit: u64) -> Result<Vec<u8>, RecoveryCommandError> {
    let file = open_file(path, false)?;
    let size = file.metadata().map_err(|_| RecoveryCommandError::Io("file metadata"))?.len();
    if size > limit {
        return Err(RecoveryCommandError::Parse("file size"));
    }
    let mut bytes = Vec::new();
    file.take(limit + 1).read_to_end(&mut bytes).map_err(|_| RecoveryCommandError::Io("read"))?;
    if bytes.len() as u64 != size || bytes.len() as u64 > limit {
        return Err(RecoveryCommandError::Parse("file size"));
    }
    Ok(bytes)
}
/// Creates a private directory or refuses nonprivate/aliased existing directories.
fn private_dir(path: &Path) -> Result<(), RecoveryCommandError> {
    if !path.exists() {
        let mut builder = std::fs::DirBuilder::new();
        #[cfg(unix)]
        {
            use std::os::unix::fs::DirBuilderExt;
            builder.mode(0o700);
        }
        builder.create(path).map_err(|_| RecoveryCommandError::Io("create private directory"))?;
    }
    check_private_dir(path)
}
/// Rejects directory aliases and public permissions without creating or changing anything.
fn check_private_dir(path: &Path) -> Result<(), RecoveryCommandError> {
    let metadata = std::fs::symlink_metadata(path)
        .map_err(|_| RecoveryCommandError::Io("directory metadata"))?;
    if !metadata.is_dir() {
        return Err(RecoveryCommandError::Parse("private directory"));
    }
    #[cfg(unix)]
    {
        use std::os::unix::fs::PermissionsExt;
        if metadata.permissions().mode() & 0o077 != 0 {
            return Err(RecoveryCommandError::Parse("private directory permissions"));
        }
    }
    Ok(())
}
/// Makes directory entries durable before publication or after atomic replacement.
fn sync_dir(path: &Path) -> Result<(), RecoveryCommandError> {
    File::open(path)
        .and_then(|f| f.sync_all())
        .map_err(|_| RecoveryCommandError::Io("sync directory"))
}
/// Writes a newly created private file and durably flushes its complete contents.
fn write_new(path: &Path, bytes: &[u8]) -> Result<(), RecoveryCommandError> {
    if bytes.len() as u64 > MAX_PLAN_BYTES {
        return Err(RecoveryCommandError::Parse("file size"));
    }
    let mut file = open_file(path, true)?;
    file.write_all(bytes)
        .and_then(|()| file.sync_all())
        .map_err(|_| RecoveryCommandError::Io("write and sync"))
}

/// Root-scoped immutable plan storage; live-service ownership is separate from publication.
pub struct RecoveryStore {
    /// Private root containing plans and journals.
    root: PathBuf,
}
impl RecoveryStore {
    /// Selects a root without creating it, keeping status filesystem read-only.
    pub fn new(root: &Path) -> Self {
        Self { root: root.to_path_buf() }
    }
    /// Short collision-checked namespace; every read checks the complete 256-bit plan ID.
    /// A prefix collision fails closed and never overwrites or chooses another namespace.
    pub fn plan_dir(&self, id: B256) -> PathBuf {
        self.root.join("plans").join(&format!("{id:x}")[..16])
    }
    /// Loads and revalidates bounded plan, profile commitment and every staged artifact.
    pub fn load_plan(&self, id: B256) -> Result<RecoveryPlan, RecoveryCommandError> {
        let dir = self.plan_dir(id);
        check_private_dir(&self.root)?;
        check_private_dir(&self.root.join("plans"))?;
        for name in ["", "app", "comet", "comet/config", "comet/data", "comet/run"] {
            check_private_dir(&dir.join(name))?;
        }
        check_private_file(&dir.join("profile.json"))?;
        let plan: RecoveryPlan =
            serde_json::from_slice(&read_bounded(&dir.join("plan.json"), MAX_PLAN_BYTES)?)
                .map_err(|_| RecoveryCommandError::Parse("plan"))?;
        if plan.id() != id {
            return Err(RecoveryCommandError::PlanMismatch);
        }
        plan.validate()?;
        let profile: RecoveryProfile =
            serde_json::from_slice(&read_bounded(&dir.join("profile.json"), 1024 * 1024)?)
                .map_err(|_| RecoveryCommandError::Parse("stored profile"))?;
        profile.validate()?;
        if profile.digest() != plan.profile_digest {
            return Err(RecoveryCommandError::PlanMismatch);
        }
        for (name, hash) in &plan.artifacts {
            if keccak256(read_bounded(&dir.join(name), MAX_PLAN_BYTES)?) != *hash {
                return Err(RecoveryCommandError::PlanMismatch);
            }
        }
        if plan.artifacts.contains_key("comet/config/node_key.json") {
            check_private_file(&dir.join("comet/config/node_key.json"))?;
            super::prepare::validate_node_key(&read_bounded(
                &dir.join("comet/config/node_key.json"),
                16 * 1024,
            )?)?;
        }
        validate_chain_artifact(&plan, &read_bounded(&dir.join("app-chain.toml"), 1024 * 1024)?)?;
        Ok(plan)
    }
    /// Loads the private profile only after validating the complete immutable bundle.
    pub fn load_profile(&self, id: B256) -> Result<RecoveryProfile, RecoveryCommandError> {
        self.load_plan(id)?;
        serde_json::from_slice(&read_bounded(&self.plan_dir(id).join("profile.json"), 1024 * 1024)?)
            .map_err(|_| RecoveryCommandError::Parse("stored profile"))
    }
    /// Fsyncs an exclusively staged bundle before atomic publication; identical retries verify
    /// existing bytes. The method never copies old app state, Comet WAL, keys or signer HRS.
    pub fn publish_plan(
        &self,
        plan: &RecoveryPlan,
        profile: &RecoveryProfile,
        artifacts: &BTreeMap<String, Vec<u8>>,
    ) -> Result<(), RecoveryCommandError> {
        plan.validate()?;
        profile.validate()?;
        profile.validate_root(&self.root)?;
        let profile_bytes =
            serde_json::to_vec(profile).map_err(|_| RecoveryCommandError::Parse("profile"))?;
        if profile_bytes.len() > 1024 * 1024 {
            return Err(RecoveryCommandError::Parse("profile size"));
        }
        let hashes: BTreeMap<_, _> =
            artifacts.iter().map(|(n, b)| (n.clone(), keccak256(b))).collect();
        if hashes != plan.artifacts ||
            profile.digest() != plan.profile_digest ||
            artifacts.keys().any(|n| !valid_artifact(n))
        {
            return Err(RecoveryCommandError::PlanMismatch);
        }
        validate_chain_artifact(
            plan,
            artifacts.get("app-chain.toml").ok_or(RecoveryCommandError::PlanMismatch)?,
        )?;
        if let Some(bytes) = artifacts.get("comet/config/node_key.json") {
            super::prepare::validate_node_key(bytes)?;
        }
        private_dir(&self.root)?;
        private_dir(&self.root.join("plans"))?;
        let id = plan.id();
        let target = self.plan_dir(id);
        if target.exists() {
            return self.load_plan(id).map(|_| ());
        }
        let stage = self.root.join("plans").join(format!(".stage-{}", &format!("{id:x}")[..16]));
        if stage.exists() {
            return Err(RecoveryCommandError::Busy);
        }
        let mut builder = std::fs::DirBuilder::new();
        #[cfg(unix)]
        {
            use std::os::unix::fs::DirBuilderExt;
            builder.mode(0o700);
        }
        builder.create(&stage).map_err(|error| {
            if error.kind() == std::io::ErrorKind::AlreadyExists {
                RecoveryCommandError::Busy
            } else {
                RecoveryCommandError::Io("create exclusive staging")
            }
        })?;
        let result = (|| {
            for name in ["app", "comet", "comet/config", "comet/data", "comet/run"] {
                private_dir(&stage.join(name))?;
            }
            for (name, bytes) in artifacts {
                write_new(&stage.join(name), bytes)?;
            }
            write_new(&stage.join("profile.json"), &profile_bytes)?;
            write_new(
                &stage.join("plan.json"),
                &serde_json::to_vec(plan).map_err(|_| RecoveryCommandError::Parse("plan"))?,
            )?;
            for name in ["comet/config", "comet/data", "comet/run", "comet", "app", ""] {
                sync_dir(&stage.join(name))?;
            }
            // The exclusive prefix staging directory serializes all writers of this target.
            if target.exists() {
                return Err(RecoveryCommandError::PlanMismatch);
            }
            std::fs::rename(&stage, &target)
                .map_err(|_| RecoveryCommandError::Io("publish plan"))?;
            sync_dir(&self.root.join("plans"))?;
            sync_dir(&self.root)?;
            if let Some(parent) = self.root.parent() {
                sync_dir(parent)?;
            }
            Ok(())
        })();
        if result.is_err() {
            let _ = std::fs::remove_dir_all(&stage);
        }
        result
    }
    /// Reads a bounded schema/identity-checked journal, absent before activation.
    pub fn load_journal(&self, id: B256) -> Result<Option<RecoveryJournal>, RecoveryCommandError> {
        let path = self.plan_dir(id).join("journal.json");
        if !path.exists() {
            return Ok(None);
        }
        let journal: RecoveryJournal = serde_json::from_slice(&read_bounded(&path, 1024 * 1024)?)
            .map_err(|_| RecoveryCommandError::Parse("journal"))?;
        if journal.schema != 1 || journal.plan_id != id {
            return Err(RecoveryCommandError::PlanMismatch);
        }
        Ok(Some(journal))
    }
    /// Serializes journal writes with an exclusive file lock and fsyncs atomic replacements.
    /// A journal remains an observation; callers must own and recheck live services separately.
    pub fn save_journal(&self, journal: &RecoveryJournal) -> Result<(), RecoveryCommandError> {
        self.load_plan(journal.plan_id)?;
        if journal.schema != 1 {
            return Err(RecoveryCommandError::Parse("journal schema"));
        }
        let dir = self.plan_dir(journal.plan_id);
        let lock_path = dir.join("journal.lock");
        let lock = match open_file(&lock_path, true) {
            Ok(file) => file,
            Err(_) => open_file(&lock_path, false)?,
        };
        lock.try_lock().map_err(|_| RecoveryCommandError::Busy)?;
        let temporary = dir.join("journal.pending");
        if temporary.exists() {
            std::fs::remove_file(&temporary)
                .map_err(|_| RecoveryCommandError::Io("remove interrupted journal"))?;
        }
        write_new(
            &temporary,
            &serde_json::to_vec(journal).map_err(|_| RecoveryCommandError::Parse("journal"))?,
        )?;
        std::fs::rename(temporary, dir.join("journal.json"))
            .map_err(|_| RecoveryCommandError::Io("publish journal"))?;
        sync_dir(&dir)
    }
}

/// Ensures credential-bearing profiles are regular private files, never public or symlinked.
pub fn check_private_file(path: &Path) -> Result<(), RecoveryCommandError> {
    let metadata = std::fs::symlink_metadata(path)
        .map_err(|_| RecoveryCommandError::Io("private profile metadata"))?;
    if !metadata.is_file() {
        return Err(RecoveryCommandError::Parse("private profile file"));
    }
    #[cfg(unix)]
    {
        use std::os::unix::fs::PermissionsExt;
        if metadata.permissions().mode() & 0o077 != 0 {
            return Err(RecoveryCommandError::Parse(
                "private profile permissions (require mode 0600)",
            ));
        }
    }
    Ok(())
}

/// Opens the staged chain configuration through the existing consensus parser and compares every
/// field, preventing a correctly hashed but unrelated config from becoming an installable bundle.
fn validate_chain_artifact(plan: &RecoveryPlan, bytes: &[u8]) -> Result<(), RecoveryCommandError> {
    if bytes.len() > 1024 * 1024 {
        return Err(RecoveryCommandError::Parse("ChainParams size"));
    }
    let text = std::str::from_utf8(bytes).map_err(|_| RecoveryCommandError::PlanMismatch)?;
    let params = abci::ChainParams::builtin(plan.deployment.l2_chain_id)
        .and_then(|p| p.with_overrides(text))
        .map_err(|_| RecoveryCommandError::PlanMismatch)?;
    if params != plan.deployment.params()? {
        return Err(RecoveryCommandError::PlanMismatch);
    }
    Ok(())
}
