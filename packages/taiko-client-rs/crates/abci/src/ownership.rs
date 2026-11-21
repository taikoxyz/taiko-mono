//! Private single-owner leases on writer storage. A lease confers no signing authority.
//!
//! A lock is never explicitly unlocked: it is held until its open-file description closes, so a
//! second writer for the same storage is refused until the first one has exited.

use std::{
    fs::{File, OpenOptions},
    os::unix::fs::{MetadataExt, OpenOptionsExt},
    path::{Path, PathBuf},
};

/// A writer that owns a storage directory.
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum ComponentRole {
    /// ABCI application writer.
    App,
    /// Transaction journal writer.
    Lander,
}
/// Canonical writer storage and its protected sibling lock.
#[derive(Clone, Debug)]
pub struct ComponentPaths {
    /// The writer that owns this storage.
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
#[error("component ownership is busy; stop the other owner of this storage")]
pub struct OwnershipError;
/// Component reservation retained for its lifetime.
pub struct ComponentLease {
    /// Canonical reservation identity.
    pub paths: ComponentPaths,
    /// The locked file, never read: dropping it releases the reservation.
    _file: File,
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
/// Require a private, singly linked regular lock inode owned by this process's UID.
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
impl ComponentLease {
    /// Reserve `paths` exclusively; another live owner of the same storage makes this fail.
    pub fn acquire(paths: &ComponentPaths) -> Result<Self, OwnershipError> {
        // Recheck at the acquisition boundary even when a caller built the public struct.
        let paths = ComponentPaths::new(paths.role, &paths.directory)?;
        let file = open_lock(&paths.lock_path()?)?;
        file.try_lock().map_err(|_| OwnershipError)?;
        Ok(Self { paths, _file: file })
    }
    /// Create missing storage privately (0700), then reserve it.
    pub fn standalone(role: ComponentRole, directory: &Path) -> Result<Self, OwnershipError> {
        use std::os::unix::fs::DirBuilderExt;
        std::fs::DirBuilder::new()
            .recursive(true)
            .mode(0o700)
            .create(directory)
            .map_err(|_| OwnershipError)?;
        Self::acquire(&ComponentPaths::new(role, directory)?)
    }
}
#[cfg(test)]
mod tests {
    use super::*;
    // A concurrent fork briefly inherits every thread's CLOEXEC files until exec. Use the
    // existing isolated-test helper so immediate drop/reacquire checks observe only our holders.
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
        assert!(ComponentLease::acquire(&paths).is_err());
        assert_eq!(std::fs::read(&evidence).unwrap(), b"registered private key");
        std::fs::remove_file(paths.lock_path().unwrap()).unwrap();
        std::fs::set_permissions(root.path(), std::fs::Permissions::from_mode(0o777)).unwrap();
        assert!(ComponentLease::acquire(&paths).is_err());
        assert!(!paths.lock_path().unwrap().exists());
    }
    #[test]
    fn recovery_standalone_lease_cannot_duplicate_live_owner() {
        if !crate::test_utils::in_own_process(
            module_path!(),
            "recovery_standalone_lease_cannot_duplicate_live_owner",
        ) {
            return;
        }
        use std::os::unix::fs::PermissionsExt;
        let root = tempfile::tempdir().unwrap();
        let directory = root.path().join("missing/app");
        let first = ComponentLease::standalone(ComponentRole::App, &directory).unwrap();
        let mode = std::fs::metadata(&directory).unwrap().permissions().mode();
        assert_eq!(mode & 0o777, 0o700);
        assert!(ComponentLease::standalone(ComponentRole::App, &directory).is_err());
        drop(first);
        assert!(ComponentLease::standalone(ComponentRole::App, &directory).is_ok());
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
        for role in [ComponentRole::App, ComponentRole::Lander] {
            let paths = ComponentPaths::new(role, &dir).unwrap();
            let first = ComponentLease::acquire(&paths).unwrap();
            let unresolved = ComponentPaths { role, directory: alias.clone() };
            assert!(ComponentLease::acquire(&unresolved).is_err());
            let alias = ComponentPaths::new(role, &alias).unwrap();
            assert!(ComponentLease::acquire(&alias).is_err());
            drop(first);
            assert!(ComponentLease::acquire(&alias).is_ok());
        }
    }
}
