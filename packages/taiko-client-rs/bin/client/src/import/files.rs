//! Canonical, single-link inputs and private, fsynced output files.
use super::*;
use serde::de::DeserializeOwned;
use std::{
    fs::{self, File, OpenOptions},
    io::{Read, Write},
    os::unix::fs::{DirBuilderExt, MetadataExt, OpenOptionsExt},
};

/// An existing canonical path with no symlinked ancestor or lexical alias.
pub(super) fn canonical(path: &Path) -> R<()> {
    if fs::canonicalize(path).map_err(io)?.as_os_str() != path.as_os_str() {
        return Err(bad("noncanonical input path"))
    }
    Ok(())
}
/// Validate the protected parent before publishing a new sibling.
pub(super) fn parent(path: &Path) -> R<&Path> {
    let p = path.parent().ok_or_else(|| bad("absolute path required"))?;
    canonical(p)?;
    let m = p.metadata().map_err(io)?;
    if !p.is_dir() ||
        (m.mode() & 0o022 != 0) ||
        (m.uid() != unsafe { libc::geteuid() } && m.uid() != 0) ||
        p.join(path.file_name().ok_or_else(|| bad("missing target name"))?) != path
    {
        return Err(bad("unsafe publication parent"))
    }
    Ok(p)
}
/// Open an input without following aliases or special files.
pub(super) fn file(path: &Path) -> R<File> {
    canonical(path)?;
    let f = OpenOptions::new()
        .read(true)
        .custom_flags(libc::O_NOFOLLOW | libc::O_NONBLOCK)
        .open(path)
        .map_err(io)?;
    let m = f.metadata().map_err(io)?;
    if !m.is_file() || m.nlink() != 1 {
        return Err(bad("expected singly linked regular file"))
    }
    Ok(f)
}
/// Read a bounded single-link input, rejecting growth.
pub(super) fn read(path: &Path, limit: u64) -> R<Vec<u8>> {
    let mut b = Vec::new();
    file(path)?.take(limit + 1).read_to_end(&mut b).map_err(io)?;
    if b.len() as u64 > limit {
        return Err(bad("input exceeds size bound"))
    }
    Ok(b)
}
/// Strict small structured input.
pub(super) fn json<T: DeserializeOwned>(path: &Path) -> R<T> {
    serde_json::from_slice(&read(path, 16 << 20)?)
        .map_err(|_| bad("invalid JSON or unsupported schema"))
}
/// Create a fresh controller-only directory; never adopt an existing object.
pub(super) fn mkdir(p: &Path) -> R<()> {
    fs::DirBuilder::new().mode(0o700).create(p).map_err(io)
}
/// Create an exclusive private staging file.
pub(super) fn create(p: &Path) -> R<File> {
    OpenOptions::new().create_new(true).write(true).mode(0o600).open(p).map_err(io)
}
/// Make file additions/renames durable.
pub(super) fn sync(p: &Path) -> R<()> {
    File::open(p).and_then(|f| f.sync_all()).map_err(io)
}
/// Publish one immutable small file durably, including the directory entry.
pub(super) fn write(p: &Path, b: &[u8]) -> R<()> {
    let dir = p.parent().ok_or_else(|| bad("no parent"))?;
    let mut f = tempfile::NamedTempFile::new_in(dir).map_err(io)?;
    f.write_all(b).and_then(|()| f.as_file().sync_all()).map_err(io)?;
    f.persist_noclobber(p).map_err(|e| io(e.error))?;
    sync(dir)
}
/// Publish structured metadata atomically without replacing any earlier decision.
pub(super) fn put<T: serde::Serialize>(p: &Path, value: &T) -> R<()> {
    write(p, &serde_json::to_vec(value).map_err(|_| bad("metadata serialization"))?)
}
/// Keccak digest used by the native manifest and immutable stock config/genesis markers.
pub(super) fn keccak_file(path: &Path) -> R<B256> {
    let mut f = file(path)?;
    let mut buffer = vec![0; 256 << 10];
    let mut h = alloy_primitives::Keccak256::new();
    loop {
        let n = f.read(&mut buffer).map_err(io)?;
        if n == 0 {
            break
        }
        h.update(&buffer[..n])
    }
    Ok(h.finalize())
}
/// Hash every logical byte of a large immutable input with accelerated SHA-256, yielding
/// between bounded chunks so the outer cancellation path retains and then drops all leases.
/// Copy into an independent inode when requested, keeping zero-filled MDBX capacity sparse.
pub(super) async fn local_digest(source: &Path, dest: Option<&Path>) -> R<B256> {
    use std::io::{Seek, SeekFrom};
    let mut hash = ring::digest::Context::new(&ring::digest::SHA256);
    let mut f = file(source)?;
    let mut out = dest.map(create).transpose()?;
    let mut len = 0u64;
    let mut buf = vec![0; 256 << 10];
    let zeros = vec![0; buf.len()];
    let mut chunks = 0u32;
    loop {
        let n = f.read(&mut buf).map_err(io)?;
        if n == 0 {
            break
        }
        len += n as u64;
        hash.update(&buf[..n]);
        if let Some(o) = out.as_mut() {
            if buf[..n] == zeros[..n] {
                o.seek(SeekFrom::Current(n as i64)).map_err(io)?;
            } else {
                o.write_all(&buf[..n]).map_err(io)?
            }
        }
        chunks += 1;
        if chunks == 32 {
            tokio::task::yield_now().await;
            chunks = 0
        }
    }
    if let Some(o) = out {
        o.set_len(len).and_then(|()| o.sync_all()).map_err(io)?
    }
    Ok(B256::from_slice(hash.finish().as_ref()))
}
/// Return false only for actual absence, never for inaccessible or dangling aliases.
pub(super) fn exists(p: &Path) -> R<bool> {
    match fs::symlink_metadata(p) {
        Ok(_) => Ok(true),
        Err(e) if e.kind() == std::io::ErrorKind::NotFound => Ok(false),
        Err(e) => Err(io(e)),
    }
}
/// Publish a directory with atomic no-replacement semantics even under concurrent exporters.
pub(super) fn publish_dir(from: &Path, to: &Path) -> R<()> {
    use std::{ffi::CString, os::unix::ffi::OsStrExt};
    let a = CString::new(from.as_os_str().as_bytes()).map_err(|_| bad("invalid pathname"))?;
    let b = CString::new(to.as_os_str().as_bytes()).map_err(|_| bad("invalid pathname"))?;
    #[cfg(target_os = "linux")]
    let result = unsafe {
        libc::renameat2(
            libc::AT_FDCWD,
            a.as_ptr(),
            libc::AT_FDCWD,
            b.as_ptr(),
            libc::RENAME_NOREPLACE,
        )
    };
    #[cfg(target_os = "macos")]
    let result = unsafe { libc::renamex_np(a.as_ptr(), b.as_ptr(), libc::RENAME_EXCL) };
    if result != 0 {
        return Err(io(std::io::Error::last_os_error()))
    }
    Ok(())
}
/// Staging directories are private at creation regardless of the caller's umask.
pub(super) fn stage(parent: &Path, prefix: &str) -> R<tempfile::TempDir> {
    use std::os::unix::fs::PermissionsExt;
    tempfile::Builder::new()
        .prefix(prefix)
        .permissions(fs::Permissions::from_mode(0o700))
        .tempdir_in(parent)
        .map_err(io)
}

/// Plan-scoped inode identity. A copied marker never authorizes deleting the receiving tree.
fn stage_identity(dir: &Path, id: B256) -> R<Value> {
    protected_root(dir)?;
    let m = dir.symlink_metadata().map_err(io)?;
    Ok(serde_json::json!({"schema":1,"installation_id":id,"device":m.dev(),"inode":m.ino()}))
}
/// Retire only the explicitly claimed work tree. Keep its identifier *outside* the retired
/// tree through recursive deletion so a crash midway can be resumed without guessing ownership.
pub(super) fn discard(root: &Path, id: B256) -> R<()> {
    let target = root.join(".checkpoint-work");
    let retired = root.join(".retired-work");
    let intent = root.join("retiring.json");
    if !exists(&intent)? {
        if exists(&retired)? {
            return Err(bad("unclaimed retired checkpoint directory"))
        }
        if !exists(&target)? {
            return Ok(())
        }
        let identity = stage_identity(&target, id)?;
        if json::<Value>(&target.join("owner.json"))? != identity {
            return Err(bad("refusing unrelated staging directory"))
        }
        put(&intent, &identity)?;
    }
    let identity: Value = json(&intent)?;
    if identity["schema"] != 1 || identity["installation_id"] != serde_json::json!(id) {
        return Err(bad("unknown checkpoint cleanup claim"))
    }
    if exists(&target)? {
        if exists(&retired)? ||
            identity != stage_identity(&target, id)? ||
            json::<Value>(&target.join("owner.json"))? != identity
        {
            return Err(bad("refusing mismatched stage retirement"))
        }
        publish_dir(&target, &retired)?;
        sync(root)?;
    }
    if exists(&retired)? {
        if stage_identity(&retired, id)? != identity {
            return Err(bad("refusing unrelated retired directory"))
        }
        fs::remove_dir_all(&retired).map_err(io)?;
        sync(root)?;
    }
    fs::remove_file(intent).map_err(io)?;
    sync(root)
}
/// Acquire a new private work tree after disposing only this operation's earlier claimed data.
pub(super) fn restart_stage(root: &Path, id: B256) -> R<PathBuf> {
    discard(root, id)?;
    let target = root.join(".checkpoint-work");
    let pending = stage(root, ".claim-")?;
    put(&pending.path().join("owner.json"), &stage_identity(pending.path(), id)?)?;
    publish_dir(pending.path(), &target)?;
    sync(root)?;
    Ok(target)
}

/// A private operation root may additionally permit search-only access by the isolated Comet
/// UID. All metadata and every non-Comet component remain individually private.
pub(super) fn protected_root(path: &Path) -> R<()> {
    canonical(path)?;
    let m = path.symlink_metadata().map_err(io)?;
    if !m.is_dir() || m.mode() & 0o066 != 0 || m.uid() != unsafe { libc::geteuid() } {
        return Err(bad("expected protected controller root"))
    }
    Ok(())
}
/// Make an otherwise private controller parent traversable, never writable, by stock Comet.
pub(super) fn searchable(p: &Path) -> R<()> {
    use std::os::unix::fs::PermissionsExt;
    fs::set_permissions(p, fs::Permissions::from_mode(0o711)).map_err(io)?;
    sync(p)
}
/// Ensure the configured stock identity can traverse the complete publication path.
pub(super) fn comet_identity(i: &Installation, parent: &Path) -> R<Option<(u32, u32)>> {
    let (caller, group) = unsafe { (libc::geteuid(), libc::getegid()) };
    let (uid, gid) = match (i.comet_uid, i.comet_gid) {
        (None, None) => return Ok(None),
        (Some(u), Some(g)) => (u, g),
        _ => return Err(bad("configure Comet UID and GID together")),
    };
    if (uid, gid) == (caller, group) {
        return Ok(None)
    }
    if caller != 0 {
        return Err(bad("separate Comet OS identity requires controller privilege"))
    }
    for a in parent.ancestors() {
        let m = a.metadata().map_err(io)?;
        let search = if uid == 0 {
            true
        } else if uid == m.uid() {
            m.mode() & 0o100 != 0
        } else if gid == m.gid() {
            m.mode() & 0o010 != 0
        } else {
            m.mode() & 0o001 != 0
        };
        if !search {
            return Err(bad("Comet UID cannot traverse operation parent"))
        }
    }
    Ok(Some((uid, gid)))
}
/// Assign fresh unpublished stock files only. No supervisor or signer data enters this tree.
pub(super) fn assign_tree(p: &Path, uid: u32, gid: u32) -> R<()> {
    let m = fs::symlink_metadata(p).map_err(io)?;
    if m.is_dir() {
        for e in fs::read_dir(p).map_err(io)? {
            assign_tree(&e.map_err(io)?.path(), uid, gid)?
        }
    } else if !m.is_file() || m.nlink() != 1 {
        return Err(bad("aliased Comet install artifact"))
    }
    std::os::unix::fs::chown(p, Some(uid), Some(gid)).map_err(io)?;
    sync(p)
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::io::{Seek, SeekFrom};
    #[tokio::test]
    async fn sparse_mdbx_copy_preserves_logical_digest_and_owns_an_independent_inode() {
        let tmp = tempfile::tempdir().unwrap();
        let root = tmp.path().canonicalize().unwrap();
        let src = root.join("source");
        let dst = root.join("copy");
        let mut f = create(&src).unwrap();
        f.set_len(8 << 20).unwrap();
        f.seek(SeekFrom::Start(3 << 20)).unwrap();
        f.write_all(b"mutable-state-page").unwrap();
        drop(f);
        let expected = local_digest(&src, None).await.unwrap();
        assert_eq!(local_digest(&src, Some(&dst)).await.unwrap(), expected);
        assert_eq!(local_digest(&dst, None).await.unwrap(), expected);
        let a = src.metadata().unwrap();
        let b = dst.metadata().unwrap();
        assert_eq!(a.len(), b.len());
        assert_ne!(a.ino(), b.ino());
        if a.blocks() * 512 < a.len() / 2 {
            assert!(b.blocks() * 512 < b.len() / 2, "copy expanded a known-sparse dataset");
        }
        fs::write(&dst, b"installed state").unwrap();
        assert_eq!(local_digest(&src, None).await.unwrap(), expected);
    }
    #[test]
    fn interrupted_recursive_removal_cannot_erase_an_unowned_replacement() {
        let tmp = tempfile::tempdir().unwrap();
        let root = tmp.path().canonicalize().unwrap();
        let id = B256::repeat_byte(3);
        let owned = restart_stage(&root, id).unwrap();
        let retired = root.join(".retired-work");
        let identity = stage_identity(&owned, id).unwrap();
        put(&root.join("retiring.json"), &identity).unwrap();
        publish_dir(&owned, &retired).unwrap();
        fs::remove_file(retired.join("owner.json")).unwrap();
        fs::write(retired.join("remaining-db"), b"done next time").unwrap();
        assert!(restart_stage(&root, id).is_ok());
        assert!(!retired.exists());
        assert!(!root.join("retiring.json").exists());
        let old = root.join(".checkpoint-work");
        let claim = stage_identity(&old, id).unwrap();
        put(&root.join("retiring.json"), &claim).unwrap();
        fs::rename(&old, root.join("unrelated-backup")).unwrap();
        mkdir(&retired).unwrap();
        fs::write(retired.join("wal"), b"preserve").unwrap();
        assert!(discard(&root, id).is_err());
        assert_eq!(fs::read(retired.join("wal")).unwrap(), b"preserve");
    }
}
