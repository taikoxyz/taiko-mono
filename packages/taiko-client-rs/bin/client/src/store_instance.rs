//! A Comet home's store instance ID (RECOV-8.2-2): `data/etna-store-instance`, 32 lowercase hex
//! characters (128 random bits) and a newline, mode 0600. Every path that creates, imports,
//! restores or rebuilds the Comet stores writes a fresh one, and the validator's signer binds its
//! key to it, so a signer that signed on other stores fences its last signed height. It is never
//! copied from another home.
use std::{
    fs::{self, File, OpenOptions},
    io::{self, Read, Write},
    os::unix::fs::OpenOptionsExt,
    path::Path,
};

/// The ID file's name in the home's `data/` directory.
pub const FILE: &str = "etna-store-instance";
/// The temporary name a write uses before its rename.
pub const TEMPORARY: &str = ".etna-store-instance.tmp";

/// Whether `bytes` is exactly one ID: 32 lowercase hex characters and a newline.
pub fn valid(bytes: &[u8]) -> bool {
    bytes.len() == 33 &&
        bytes[32] == b'\n' &&
        bytes[..32].iter().all(|b| b.is_ascii_digit() || (b'a'..=b'f').contains(b))
}

/// Writes a fresh ID into `data`, replacing any earlier one atomically: an exclusive temporary
/// file, its fsync, a rename and the directory's fsync. Returns the ID.
pub fn write_fresh(data: &Path) -> io::Result<String> {
    let mut random = [0u8; 16];
    File::open("/dev/urandom")?.read_exact(&mut random)?;
    let id: String = random.iter().map(|b| format!("{b:02x}")).collect();
    let temporary = data.join(TEMPORARY);
    match fs::remove_file(&temporary) {
        Err(e) if e.kind() != io::ErrorKind::NotFound => return Err(e),
        _ => {}
    }
    let mut file = OpenOptions::new()
        .write(true)
        .create_new(true)
        .mode(0o600)
        .custom_flags(libc::O_NOFOLLOW)
        .open(&temporary)?;
    file.write_all(format!("{id}\n").as_bytes())?;
    file.sync_all()?;
    drop(file);
    fs::rename(&temporary, data.join(FILE))?;
    File::open(data)?.sync_all()?;
    Ok(id)
}

/// Keeps a valid ID already in `data` (written earlier by the same interrupted install), or
/// writes a fresh one. Any other inode or content at the path is refused.
pub fn ensure(data: &Path) -> io::Result<String> {
    let path = data.join(FILE);
    match fs::symlink_metadata(&path) {
        Err(e) if e.kind() == io::ErrorKind::NotFound => write_fresh(data),
        Err(e) => Err(e),
        Ok(metadata) if !metadata.is_file() => {
            Err(io::Error::new(io::ErrorKind::InvalidData, "store instance ID is not a file"))
        }
        Ok(_) => {
            let bytes = fs::read(&path)?;
            if !valid(&bytes) {
                return Err(io::Error::new(io::ErrorKind::InvalidData, "invalid store instance ID"));
            }
            Ok(String::from_utf8_lossy(&bytes[..32]).into_owned())
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::os::unix::fs::PermissionsExt;

    #[test]
    fn fresh_ids_are_private_valid_and_never_repeat() {
        let dir = tempfile::tempdir().unwrap();
        let first = write_fresh(dir.path()).unwrap();
        let bytes = fs::read(dir.path().join(FILE)).unwrap();
        assert!(valid(&bytes) && bytes.starts_with(first.as_bytes()));
        assert_eq!(
            fs::metadata(dir.path().join(FILE)).unwrap().permissions().mode() & 0o777,
            0o600
        );
        let second = write_fresh(dir.path()).unwrap();
        assert_ne!(first, second);
        assert!(!dir.path().join(TEMPORARY).exists());
        // ensure keeps a valid one and refuses anything else.
        assert_eq!(ensure(dir.path()).unwrap(), second);
        fs::write(dir.path().join(FILE), b"not an id\n").unwrap();
        assert!(ensure(dir.path()).is_err());
        assert_eq!(fs::read(dir.path().join(FILE)).unwrap(), b"not an id\n");
    }

    #[test]
    fn only_32_lowercase_hex_and_a_newline_is_valid() {
        assert!(valid(b"00112233445566778899aabbccddeeff\n"));
        for invalid in [
            &b"00112233445566778899AABBCCDDEEFF\n"[..],
            b"00112233445566778899aabbccddeeff",
            b"00112233445566778899aabbccddeef\n",
            b"00112233445566778899aabbccddeeff\n\n",
            b"0011223344556677889gaabbccddeeff\n",
        ] {
            assert!(!valid(invalid), "{invalid:?}");
        }
    }
}
