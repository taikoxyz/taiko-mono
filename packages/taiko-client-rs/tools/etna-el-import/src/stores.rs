//! Install actual authenticated headers, without fabricating a genesis-to-checkpoint prefix.

use std::{fmt::Display, fs::File, path::Path};

use alloy_consensus::Header;
use alloy_primitives::U256;
use reth_codecs::Compact;
use reth_db::mdbx::DatabaseArguments;
use reth_db_api::{
    Database,
    models::CompactU256,
    tables,
    transaction::{DbTx, DbTxMut},
};
use reth_nippy_jar::{NippyJar, NippyJarWriter};
use reth_static_file_types::{SegmentHeader, SegmentRangeInclusive, StaticFileSegment};

use crate::{ImportError, VerifiedHeaders, state::existing_directory};

/// Convert a pinned storage/codec failure into a non-publishing local import error.
fn db_error(error: impl Display) -> ImportError {
    ImportError::Database(error.to_string())
}

/// Flush both file contents and the containing directory before exposing new paths.
fn sync_files(directory: &Path) -> Result<(), ImportError> {
    for entry in std::fs::read_dir(directory)? {
        let entry = entry?;
        if !entry.file_type()?.is_file() {
            return Err(ImportError::Invalid("nonregular static-file entry"));
        }
        File::open(entry.path())?.sync_all()?;
    }
    File::open(directory)?.sync_all()?;
    Ok(())
}

/// Append exactly the compact column encoding used by the pinned stock static writer.
fn append_compact<T: Compact>(
    writer: &mut NippyJarWriter<SegmentHeader>,
    value: &T,
) -> Result<(), ImportError> {
    let mut bytes = Vec::new();
    value.to_compact(&mut bytes);
    writer.append_column(Some(Ok(bytes))).map_err(db_error)
}

/// Create one real contiguous header jar, whose first row may start after a pruned gap.
fn write_header_jar(directory: &Path, headers: &[Header]) -> Result<(), ImportError> {
    let first = headers.first().ok_or(ImportError::Invalid("empty header jar"))?;
    let last = headers.last().expect("nonempty slice checked");
    let segment = StaticFileSegment::Headers;
    let range = SegmentRangeInclusive::new(first.number, last.number);
    let path = directory.join(segment.filename(&range));
    let jar = NippyJar::new(
        segment.columns(),
        &path,
        SegmentHeader::new(range, Some(range), None, segment),
    )
    .with_lz4();
    let mut writer = NippyJarWriter::new(jar).map_err(db_error)?;
    for header in headers {
        append_compact(&mut writer, header)?;
        append_compact(&mut writer, &CompactU256::from(U256::ZERO))?;
        append_compact(&mut writer, &header.hash_slow())?;
    }
    writer.commit().map_err(db_error)?;
    Ok(())
}

/// Replace header jars and both directions of canonical lookup in unpublished offline staging.
///
/// The caller owns fresh staging and must verify actual state/code, sanitize auxiliary data,
/// run normal provider consistency/startup checks, then publish its cross-store boundary.
/// Failure leaves staging incomplete; it grants no permission to start an EL or signer.
pub fn install_headers(
    database: &Path,
    static_files: &Path,
    genesis: &Header,
    verified: &VerifiedHeaders<'_>,
) -> Result<(), ImportError> {
    existing_directory(database)?;
    existing_directory(static_files)?;
    if genesis.number != 0 || genesis.hash_slow() != verified.genesis_hash() {
        return Err(ImportError::Invalid("local original genesis header differs"));
    }
    let parent = static_files.parent().ok_or(ImportError::Invalid("missing static-file parent"))?;
    let staging = tempfile::Builder::new().prefix(".etna-headers-").tempdir_in(parent)?;
    if verified.headers()[0].number != 0 {
        write_header_jar(staging.path(), std::slice::from_ref(genesis))?;
    }
    write_header_jar(staging.path(), verified.headers())?;
    sync_files(staging.path())?;
    for entry in std::fs::read_dir(static_files)? {
        let entry = entry?;
        if entry.file_name().to_string_lossy().starts_with("static_file_headers_") {
            std::fs::remove_file(entry.path())?;
        }
    }
    for entry in std::fs::read_dir(staging.path())? {
        let entry = entry?;
        std::fs::rename(entry.path(), static_files.join(entry.file_name()))?;
    }
    sync_files(static_files)?;

    let db = reth_db::open_db(database, DatabaseArguments::default()).map_err(db_error)?;
    let tx = db.tx_mut().map_err(db_error)?;
    tx.clear::<tables::HeaderNumbers>().map_err(db_error)?;
    tx.clear::<tables::Headers>().map_err(db_error)?;
    tx.clear::<tables::CanonicalHeaders>().map_err(db_error)?;
    for header in std::iter::once(genesis).chain(verified.headers()) {
        let hash = header.hash_slow();
        tx.put::<tables::HeaderNumbers>(hash, header.number).map_err(db_error)?;
        tx.put::<tables::Headers>(header.number, header.clone()).map_err(db_error)?;
        tx.put::<tables::CanonicalHeaders>(header.number, hash).map_err(db_error)?;
    }
    tx.put::<tables::ChainState>(
        tables::ChainStateKey::LastFinalizedBlock,
        verified.finalized().number,
    )
    .map_err(db_error)?;
    tx.put::<tables::ChainState>(tables::ChainStateKey::LastSafeBlock, verified.terminal().number)
        .map_err(db_error)?;
    tx.commit().map_err(db_error)?;
    drop(db);
    sync_files(database)?;
    Ok(())
}
