//! Private inherited process leases. These descriptors confer no signing authority.
//!
//! Locks are never explicitly unlocked: every inherited open-file description must close
//! before another owner can proceed. In particular, controller death is not quiescence.

use alloy_primitives::B256;
use std::{
    fs::{File, OpenOptions},
    os::{
        fd::{AsRawFd, FromRawFd, RawFd},
        unix::fs::{MetadataExt, OpenOptionsExt},
    },
    path::{Path, PathBuf},
};

/// Inherited hold-only descriptors; values contain no private paths or signing secrets.
pub const OWNER_FDS_ENV: &str = "ETNA_OWNER_FDS";
/// Scoped participant join descriptor. Stock descendants must not receive this variable.
pub const OWNER_JOIN_ENV: &str = "ETNA_OWNER_JOIN";

/// A participating writer role.
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum ComponentRole {
    /// Offline checkpoint execution store; the normal EL inherits the complete barrier.
    Execution,
    /// ABCI application writer.
    App,
    /// Validator supervisor, signer and stock Comet subtree.
    Supervisor,
    /// Full-node stock Comet process.
    Comet,
    /// Transaction journal writer.
    Lander,
}
impl ComponentRole {
    /// Stable private grant role tag shared with the Python supervisor.
    pub fn tag(self) -> &'static str {
        match self {
            Self::App => "app",
            Self::Execution => "execution",
            Self::Supervisor => "supervisor",
            Self::Comet => "comet",
            Self::Lander => "lander",
        }
    }
}
/// Canonical writer storage and its protected sibling lock.
#[derive(Clone, Debug)]
pub struct ComponentPaths {
    /// Role allowed to join this reservation.
    pub role: ComponentRole,
    /// Writer's canonical storage directory.
    pub directory: PathBuf,
}
impl ComponentPaths {
    /// Resolve existing storage, including aliases, without changing its contents.
    pub fn new(role: ComponentRole, directory: &Path) -> Result<Self, OwnershipError> {
        let directory = directory.canonicalize().map_err(|_| OwnershipError)?;
        if !directory.is_dir() {
            return Err(OwnershipError);
        }
        Ok(Self { role, directory })
    }
    /// Protected sibling location: Comet's writable home never contains this inode.
    pub fn lock_path(&self) -> Result<PathBuf, OwnershipError> {
        let parent = self.directory.parent().ok_or(OwnershipError)?;
        let name = self.directory.file_name().ok_or(OwnershipError)?;
        let mut lock = std::ffi::OsString::from(".");
        lock.push(name);
        lock.push(".etna-owner.lock");
        Ok(parent.join(lock))
    }
}
/// Busy or unverifiable ownership never permits mutation.
#[derive(Debug, thiserror::Error)]
#[error("component ownership is busy; stop the external controller or surviving children")]
pub struct OwnershipError;
/// Controller reservation retained for its lifetime and inherited by every runtime child.
pub struct ActivationLease {
    /// Private locked file; closing, never explicit unlocking, releases our reference.
    file: File,
    /// Immutable selected plan, for consumers' identity checks.
    pub plan_id: B256,
}
/// Opaque role-scoped private coordination, never signing authority.
pub struct OwnerGrant {
    /// All-reservation barrier retained even by children which only join one component.
    files: Vec<File>,
    /// The single allowed role tag.
    role: String,
    /// Index of the component descriptor within the barrier.
    join: usize,
}
/// Component reservation retained for its lifetime.
pub struct ComponentLease {
    /// Canonical reservation identity.
    pub paths: ComponentPaths,
    /// Closing this file does not unlock surviving inherited descriptions.
    file: File,
}
/// Validate a lock inode and its protected parent; never follow a final-component alias.
fn open_lock(path: &Path) -> Result<File, OwnershipError> {
    let parent = path.parent().ok_or(OwnershipError)?;
    let directory = parent.metadata().map_err(|_| OwnershipError)?;
    // A different unprivileged UID (including stock Comet) must not replace the inode.
    let uid = unsafe { libc::geteuid() };
    if !directory.is_dir() ||
        directory.mode() & 0o022 != 0 ||
        (directory.uid() != uid && directory.uid() != 0)
    {
        return Err(OwnershipError);
    }
    let file = OpenOptions::new()
        .read(true)
        .write(true)
        .create(true)
        .truncate(false)
        .mode(0o600)
        .custom_flags(libc::O_NOFOLLOW | libc::O_CLOEXEC)
        .open(path)
        .map_err(|_| OwnershipError)?;
    validate_file(&file)?;
    let named = path.symlink_metadata().map_err(|_| OwnershipError)?;
    let opened = file.metadata().map_err(|_| OwnershipError)?;
    if named.dev() != opened.dev() || named.ino() != opened.ino() {
        return Err(OwnershipError);
    }
    Ok(file)
}
/// Require a private, singly linked regular lock inode owned by this controller UID.
fn validate_file(file: &File) -> Result<(), OwnershipError> {
    let metadata = file.metadata().map_err(|_| OwnershipError)?;
    if !metadata.is_file() ||
        metadata.mode() & 0o077 != 0 ||
        metadata.nlink() != 1 ||
        metadata.uid() != unsafe { libc::geteuid() }
    {
        return Err(OwnershipError);
    }
    Ok(())
}
/// Reserve one private recovery root across all plan identities.
pub fn acquire_activation(root: &Path, plan_id: B256) -> Result<ActivationLease, OwnershipError> {
    let root = root.canonicalize().map_err(|_| OwnershipError)?;
    let file = open_lock(&root.join("activation.lock"))?;
    file.try_lock().map_err(|_| OwnershipError)?;
    Ok(ActivationLease { file, plan_id })
}
impl ComponentLease {
    /// Reserve storage, or join exactly the role and inode in an inherited grant.
    pub fn acquire(
        paths: &ComponentPaths,
        grant: Option<&OwnerGrant>,
    ) -> Result<Self, OwnershipError> {
        // Recheck at the acquisition boundary even when a caller built the public struct.
        let paths = ComponentPaths::new(paths.role, &paths.directory)?;
        let file = open_lock(&paths.lock_path()?)?;
        let file = if let Some(grant) = grant {
            let inherited = &grant.files[grant.join];
            let a = file.metadata().map_err(|_| OwnershipError)?;
            let b = inherited.metadata().map_err(|_| OwnershipError)?;
            if grant.role != paths.role.tag() || (a.dev(), a.ino()) != (b.dev(), b.ino()) {
                return Err(OwnershipError);
            }
            // A same-inode FD alone is not a grant: the independent description must be
            // blocked, while relocking the inherited description must succeed.
            if !matches!(file.try_lock(), Err(std::fs::TryLockError::WouldBlock)) {
                return Err(OwnershipError);
            }
            inherited.try_lock().map_err(|_| OwnershipError)?;
            inherited.try_clone().map_err(|_| OwnershipError)?
        } else {
            file.try_lock().map_err(|_| OwnershipError)?;
            file
        };
        Ok(Self { paths, file })
    }
    /// Create missing standalone storage privately, then retain both scoped and hold leases.
    pub fn standalone(
        role: ComponentRole,
        directory: &Path,
    ) -> Result<(Self, Option<OwnerGrant>), OwnershipError> {
        use std::os::unix::fs::DirBuilderExt;
        std::fs::DirBuilder::new()
            .recursive(true)
            .mode(0o700)
            .create(directory)
            .map_err(|_| OwnershipError)?;
        let paths = ComponentPaths::new(role, directory)?;
        let grant = OwnerGrant::from_env()?;
        let lease = Self::acquire(&paths, grant.as_ref())?;
        Ok((lease, grant))
    }
}
impl OwnerGrant {
    /// Construct a scoped child grant while duplicating every reserved description.
    pub fn for_child(
        activation: &ActivationLease,
        leases: &[ComponentLease],
        index: usize,
    ) -> Result<Self, OwnershipError> {
        let selected = leases.get(index).ok_or(OwnershipError)?;
        let mut files = vec![activation.file.try_clone().map_err(|_| OwnershipError)?];
        for lease in leases {
            files.push(lease.file.try_clone().map_err(|_| OwnershipError)?);
        }
        Ok(Self { files, role: selected.paths.role.tag().into(), join: index + 1 })
    }
    /// Import only valid private descriptors and one matching role-scoped join handle.
    pub fn from_env() -> Result<Option<Self>, OwnershipError> {
        let holds = std::env::var(OWNER_FDS_ENV);
        let join = std::env::var(OWNER_JOIN_ENV);
        if holds.is_err() && join.is_err() {
            return Ok(None);
        }
        let holds = holds.map_err(|_| OwnershipError)?;
        let join = join.map_err(|_| OwnershipError)?;
        let (role, selected) = join.split_once(':').ok_or(OwnershipError)?;
        let selected: RawFd = selected.parse().map_err(|_| OwnershipError)?;
        let mut files = Vec::new();
        let mut index = None;
        for value in holds.split(',') {
            if files.len() >= 64 {
                return Err(OwnershipError);
            }
            let fd: RawFd = value.parse().map_err(|_| OwnershipError)?;
            if fd < 3 {
                return Err(OwnershipError);
            }
            let duplicate = unsafe { libc::fcntl(fd, libc::F_DUPFD_CLOEXEC, 3) };
            if duplicate < 0 {
                return Err(OwnershipError);
            }
            // SAFETY: fcntl returned a new, owned descriptor above.
            let file = unsafe { File::from_raw_fd(duplicate) };
            validate_file(&file)?;
            if fd == selected {
                index = Some(files.len());
            }
            files.push(file);
        }
        Ok(Some(Self { files, role: role.into(), join: index.ok_or(OwnershipError)? }))
    }
    /// Descriptors to inherit in the forked child only; the parent's CLOEXEC stays set.
    pub fn descriptors(&self) -> Vec<RawFd> {
        self.files.iter().map(AsRawFd::as_raw_fd).collect()
    }
    /// Private environment values for a single participating child.
    pub fn environment(&self) -> [(&'static str, String); 2] {
        [
            (
                OWNER_FDS_ENV,
                self.descriptors().iter().map(ToString::to_string).collect::<Vec<_>>().join(","),
            ),
            (OWNER_JOIN_ENV, format!("{}:{}", self.role, self.files[self.join].as_raw_fd())),
        ]
    }
}
/// Probe an existing legacy lock without editing it. This is only a quiescence check:
/// external nonparticipating controllers must already be stopped by the operator.
/// Never retain this lock while launching the original signer/journal implementation.
pub fn check_legacy_lock(path: &Path) -> Result<(), OwnershipError> {
    match path.symlink_metadata() {
        Err(error) if error.kind() == std::io::ErrorKind::NotFound => return Ok(()),
        Err(_) => return Err(OwnershipError),
        Ok(metadata) if !metadata.is_file() => return Err(OwnershipError),
        Ok(_) => {}
    }
    let file = OpenOptions::new()
        .read(true)
        .write(true)
        .custom_flags(libc::O_NOFOLLOW | libc::O_CLOEXEC)
        .open(path)
        .map_err(|_| OwnershipError)?;
    // Existing journal locks may be 0644; their bytes and permissions stay untouched.
    let metadata = file.metadata().map_err(|_| OwnershipError)?;
    if !metadata.is_file() || metadata.nlink() != 1 || metadata.mode() & 0o022 != 0 {
        return Err(OwnershipError);
    }
    file.try_lock().map_err(|_| OwnershipError)?;
    Ok(())
}
/// Observe a legacy local control listener without unlinking its inode or adopting its owner.
/// Absence is evidence only; external controllers must already be explicitly stopped.
pub async fn check_legacy_listener(path: &Path) -> Result<(), OwnershipError> {
    use std::os::unix::fs::FileTypeExt;
    match path.symlink_metadata() {
        Err(error) if error.kind() == std::io::ErrorKind::NotFound => return Ok(()),
        Ok(metadata) if metadata.file_type().is_socket() => {}
        _ => return Err(OwnershipError),
    }
    match tokio::time::timeout(
        std::time::Duration::from_secs(1),
        tokio::net::UnixStream::connect(path),
    )
    .await
    {
        Ok(Err(error))
            if matches!(
                error.kind(),
                std::io::ErrorKind::ConnectionRefused | std::io::ErrorKind::NotFound
            ) =>
        {
            Ok(())
        }
        _ => Err(OwnershipError),
    }
}
#[cfg(test)]
mod tests {
    use super::*;
    // A concurrent fork briefly inherits every thread's CLOEXEC files until exec. Use the
    // existing isolated-test helper so immediate drop/reacquire checks observe only our holders.
    #[test]
    fn recovery_parent_and_grant_drop_leave_child_fenced() {
        if !crate::test_utils::in_own_process(
            module_path!(),
            "recovery_parent_and_grant_drop_leave_child_fenced",
        ) {
            return;
        }
        use std::os::unix::process::CommandExt;
        let root = tempfile::tempdir().unwrap();
        let directory = root.path().join("app");
        std::fs::create_dir(&directory).unwrap();
        let activation = acquire_activation(root.path(), B256::ZERO).unwrap();
        let paths = ComponentPaths::new(ComponentRole::App, &directory).unwrap();
        let leases = [ComponentLease::acquire(&paths, None).unwrap()];
        let grant = OwnerGrant::for_child(&activation, &leases, 0).unwrap();
        let descriptors = grant.descriptors();
        let mut command = std::process::Command::new("/bin/sleep");
        command.arg("10");
        unsafe {
            command.pre_exec(move || {
                for fd in &descriptors {
                    if libc::fcntl(*fd, libc::F_SETFD, 0) == -1 {
                        return Err(std::io::Error::last_os_error());
                    }
                }
                Ok(())
            });
        }
        let mut child = command.spawn().unwrap();
        drop(grant);
        drop(leases);
        drop(activation);
        let controller_busy = acquire_activation(root.path(), B256::ZERO).is_err();
        let component_busy = ComponentLease::acquire(&paths, None).is_err();
        child.kill().unwrap();
        child.wait().unwrap();
        assert!(controller_busy && component_busy, "ordinary Drop unlocked inherited descriptions");
        assert!(acquire_activation(root.path(), B256::ZERO).is_ok());
        assert!(ComponentLease::acquire(&paths, None).is_ok());
    }
    #[test]
    fn recovery_lock_alias_and_unsafe_parent_are_busy_without_touching_evidence() {
        if !crate::test_utils::in_own_process(
            module_path!(),
            "recovery_lock_alias_and_unsafe_parent_are_busy_without_touching_evidence",
        ) {
            return;
        }
        use std::os::unix::fs::PermissionsExt;
        let root = tempfile::tempdir().unwrap();
        let directory = root.path().join("app");
        std::fs::create_dir(&directory).unwrap();
        let paths = ComponentPaths::new(ComponentRole::App, &directory).unwrap();
        let evidence = root.path().join("registered-key");
        std::fs::write(&evidence, b"registered private key").unwrap();
        std::os::unix::fs::symlink(&evidence, paths.lock_path().unwrap()).unwrap();
        assert!(ComponentLease::acquire(&paths, None).is_err());
        assert_eq!(std::fs::read(&evidence).unwrap(), b"registered private key");
        std::fs::remove_file(paths.lock_path().unwrap()).unwrap();
        std::fs::set_permissions(root.path(), std::fs::Permissions::from_mode(0o777)).unwrap();
        assert!(ComponentLease::acquire(&paths, None).is_err());
        assert!(!paths.lock_path().unwrap().exists());
    }
    #[tokio::test]
    async fn recovery_legacy_listener_is_only_a_busy_observation() {
        if !crate::test_utils::in_own_process(
            module_path!(),
            "recovery_legacy_listener_is_only_a_busy_observation",
        ) {
            return;
        }
        let root = tempfile::tempdir().unwrap();
        let socket = root.path().join("control.sock");
        let listener = tokio::net::UnixListener::bind(&socket).unwrap();
        assert!(check_legacy_listener(&socket).await.is_err());
        assert!(socket.exists());
        drop(listener);
        assert!(check_legacy_listener(&socket).await.is_ok());
        assert!(socket.exists());
        let alias = root.path().join("alias.sock");
        std::os::unix::fs::symlink(&socket, &alias).unwrap();
        assert!(check_legacy_listener(&alias).await.is_err());
    }
    #[test]
    fn recovery_join_rejects_unlocked_or_foreign_description() {
        if !crate::test_utils::in_own_process(
            module_path!(),
            "recovery_join_rejects_unlocked_or_foreign_description",
        ) {
            return;
        }
        let root = tempfile::tempdir().unwrap();
        let directory = root.path().join("app");
        std::fs::create_dir(&directory).unwrap();
        let paths = ComponentPaths::new(ComponentRole::App, &directory).unwrap();
        let file = open_lock(&paths.lock_path().unwrap()).unwrap();
        let grant = OwnerGrant { files: vec![file], role: "app".into(), join: 0 };
        assert!(ComponentLease::acquire(&paths, Some(&grant)).is_err());
        let lease = ComponentLease::acquire(&paths, None).unwrap();
        assert!(ComponentLease::acquire(&paths, Some(&grant)).is_err());
        let matched = OwnerGrant {
            files: vec![lease.file.try_clone().unwrap()],
            role: "app".into(),
            join: 0,
        };
        assert!(ComponentLease::acquire(&paths, Some(&matched)).is_ok());
        let wrong_role = OwnerGrant {
            files: vec![lease.file.try_clone().unwrap()],
            role: "lander".into(),
            join: 0,
        };
        assert!(ComponentLease::acquire(&paths, Some(&wrong_role)).is_err());
    }
    #[test]
    fn recovery_legacy_journal_lock_probe_preserves_existing_bytes() {
        if !crate::test_utils::in_own_process(
            module_path!(),
            "recovery_legacy_journal_lock_probe_preserves_existing_bytes",
        ) {
            return;
        }
        use std::os::unix::fs::PermissionsExt;
        let root = tempfile::tempdir().unwrap();
        let path = root.path().join("transaction-store.lock");
        std::fs::write(&path, b"old lock evidence pid=1234").unwrap();
        std::fs::set_permissions(&path, std::fs::Permissions::from_mode(0o644)).unwrap();
        assert!(check_legacy_lock(&path).is_ok());
        let file = OpenOptions::new().read(true).write(true).open(&path).unwrap();
        file.try_lock().unwrap();
        assert!(check_legacy_lock(&path).is_err());
        assert_eq!(std::fs::read(&path).unwrap(), b"old lock evidence pid=1234");
    }
    #[test]
    fn recovery_controller_cannot_duplicate_live_owner() {
        if !crate::test_utils::in_own_process(
            module_path!(),
            "recovery_controller_cannot_duplicate_live_owner",
        ) {
            return;
        }
        let root = tempfile::tempdir().unwrap();
        let first = acquire_activation(root.path(), B256::ZERO).unwrap();
        assert!(acquire_activation(root.path(), B256::ZERO).is_err());
        drop(first);
        assert!(acquire_activation(root.path(), B256::ZERO).is_ok());
    }
    #[test]
    fn recovery_component_alias_cannot_duplicate_live_owner() {
        if !crate::test_utils::in_own_process(
            module_path!(),
            "recovery_component_alias_cannot_duplicate_live_owner",
        ) {
            return;
        }
        let root = tempfile::tempdir().unwrap();
        let dir = root.path().join("app");
        std::fs::create_dir(&dir).unwrap();
        let alias = root.path().join("alias");
        std::os::unix::fs::symlink(&dir, &alias).unwrap();
        for role in [ComponentRole::App, ComponentRole::Lander, ComponentRole::Supervisor] {
            let paths = ComponentPaths::new(role, &dir).unwrap();
            let first = ComponentLease::acquire(&paths, None).unwrap();
            let unresolved = ComponentPaths { role, directory: alias.clone() };
            assert!(ComponentLease::acquire(&unresolved, None).is_err());
            let alias = ComponentPaths::new(role, &alias).unwrap();
            assert!(ComponentLease::acquire(&alias, None).is_err());
            drop(first);
            assert!(ComponentLease::acquire(&alias, None).is_ok());
        }
    }
}
