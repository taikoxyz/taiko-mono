//! Keep MDBX reader locks and long-running scans local to the offline import.

use std::{
    fs::{File, OpenOptions},
    io::{Read, Seek, SeekFrom, Write},
    os::{
        fd::AsRawFd,
        unix::fs::{OpenOptionsExt, PermissionsExt},
    },
    path::Path,
};

use reth_db::{
    DatabaseEnv,
    mdbx::{DatabaseArguments, RO, tx::Tx},
};
use reth_db_api::{Database, transaction::DbTx};

use crate::ImportError;

/// Grow only owned import/scratch datasets in 64 MiB steps. The normal 8 TiB maximum and
/// durable transaction mode still apply. The bound runtime uses the same growth step.
pub(crate) fn write_arguments() -> DatabaseArguments {
    DatabaseArguments::default().with_growth_step(Some(64 * 1024 * 1024))
}

/// An offline full scan has exclusive ownership of the candidate and no interactive deadline.
pub(crate) fn scan(db: &DatabaseEnv) -> Result<Tx<RO>, ImportError> {
    let mut tx = db.tx().map_err(|err| ImportError::Database(err.to_string()))?;
    tx.disable_long_read_transaction_safety();
    Ok(tx)
}

/// Find a physical data or hole boundary, allowing a portable sparse fallback on other filesystems.
fn extent(file: &File, start: u64, kind: libc::c_int) -> std::io::Result<Option<u64>> {
    let offset = i64::try_from(start).map_err(std::io::Error::other)?;
    // SAFETY: the open descriptor is live, and lseek does not retain or dereference pointers.
    let result = unsafe { libc::lseek(file.as_raw_fd(), offset, kind) };
    if result >= 0 {
        return Ok(Some(result as u64));
    }
    let err = std::io::Error::last_os_error();
    if err.raw_os_error() == Some(libc::ENXIO) { Ok(None) } else { Err(err) }
}

/// Copy one file to a fresh owned inode, preserving logical size without allocating holes.
pub(crate) fn sparse_copy(input: &Path, output: &Path) -> Result<(), ImportError> {
    let mut src = File::open(input)?;
    let mut dst = OpenOptions::new().write(true).create_new(true).mode(0o600).open(output)?;
    let size = src.metadata()?.len();
    let mut at = 0;
    let mut buf = vec![0u8; 1024 * 1024];
    let mut extents = true;
    while at < size {
        let mut end = size;
        if extents {
            match extent(&src, at, libc::SEEK_DATA).and_then(|data| {
                data.map(|pos| Ok((pos, extent(&src, pos, libc::SEEK_HOLE)?.unwrap_or(size))))
                    .transpose()
            }) {
                Ok(Some((data, hole))) if data >= at && data < hole && hole <= size => {
                    at = data;
                    end = hole;
                }
                Ok(None) => break,
                Ok(Some(_)) => return Err(ImportError::Invalid("inconsistent source extents")),
                Err(err)
                    if [Some(libc::EINVAL), Some(libc::ENOTSUP), Some(libc::EOPNOTSUPP)]
                        .contains(&err.raw_os_error()) =>
                {
                    extents = false
                }
                Err(err) => return Err(err.into()),
            }
        }
        src.seek(SeekFrom::Start(at))?;
        while at < end {
            let n = (end - at).min(buf.len() as u64) as usize;
            src.read_exact(&mut buf[..n])?;
            if !buf[..n].iter().all(|&byte| byte == 0) {
                dst.seek(SeekFrom::Start(at))?;
                dst.write_all(&buf[..n])?;
            }
            at += n as u64;
        }
    }
    if src.metadata()?.len() != size {
        return Err(ImportError::Invalid("source changed during offline copy"));
    }
    dst.set_len(size)?;
    Ok(())
}

/// Use mode 0700 even with a permissive caller umask or a shared system temporary directory.
pub(crate) fn private_temp(prefix: &str, parent: &Path) -> Result<tempfile::TempDir, ImportError> {
    Ok(tempfile::Builder::new()
        .prefix(prefix)
        .permissions(std::fs::Permissions::from_mode(0o700))
        .tempdir_in(parent)?)
}
