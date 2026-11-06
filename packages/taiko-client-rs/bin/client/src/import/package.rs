//! A strictly framed directory package. Both verifiers consume the same immutable frames.
use super::*;
use lander::checkpoint_import::{ImportPackage, VerifiedImport, WindowBlock, authenticate_import};
use std::{
    fs,
    io::{BufRead, BufReader, BufWriter, Read, Write},
};

/// Hex-encoded original native block/commit plus the bounded complete validator set.
const FRAME_LIMIT: u64 = 50 << 20;
/// Explicit local package bound; exceeding it never truncates the required suffix.
const SOURCE_LIMIT: u64 = 1 << 40;
/// Verify no private signing files, unknown entries or aliases enter a package.
pub(super) async fn identity(dir: &Path) -> R<[B256; 2]> {
    files::canonical(dir)?;
    let mut names = fs::read_dir(dir)
        .map_err(io)?
        .map(|i| i.map(|f| f.file_name()))
        .collect::<Result<Vec<_>, _>>()
        .map_err(io)?;
    names.sort();
    if names != ["blocks.jsonl", "package.json"] {
        return Err(bad("unexpected package files"))
    }
    let path = dir.join("blocks.jsonl");
    if files::file(&path)?.metadata().map_err(io)?.len() > SOURCE_LIMIT {
        return Err(bad("package exceeds capacity"))
    }
    if files::file(&dir.join("package.json"))?.metadata().map_err(io)?.len() > 256 << 20 {
        return Err(bad("metadata exceeds capacity"))
    }
    Ok([
        files::local_digest(&dir.join("package.json"), None).await?,
        files::local_digest(&path, None).await?,
    ])
}
/// Decode one bounded JSON frame at a time; fail on partial/trailing frames.
pub(super) fn frames(dir: &Path) -> R<impl Iterator<Item = R<WindowBlock>>> {
    let mut reader = BufReader::new(files::file(&dir.join("blocks.jsonl"))?);
    let mut done = false;
    Ok(std::iter::from_fn(move || {
        if done {
            return None
        }
        let mut bytes = Vec::new();
        let result = (&mut reader).take(FRAME_LIMIT + 1).read_until(b'\n', &mut bytes);
        match result {
            Ok(0) => {
                done = true;
                None
            }
            Ok(n) if n as u64 <= FRAME_LIMIT && bytes.last() == Some(&b'\n') => {
                Some(serde_json::from_slice(&bytes).map_err(|_| bad("invalid consensus frame")))
            }
            Ok(_) => {
                done = true;
                Some(Err(bad("overlong or incomplete consensus frame")))
            }
            Err(e) => {
                done = true;
                Some(Err(io(e)))
            }
        }
    }))
}
/// Reopen all consensus material and authenticate it against this own-finalized L1 observation.
pub(super) async fn verify(
    dir: &Path,
    params: &abci::ChainParams,
    l1: &abci::RpcL1Source,
) -> R<VerifiedImport> {
    let meta: ImportPackage =
        serde_json::from_slice(&files::read(&dir.join("package.json"), 256 << 20)?)
            .map_err(|_| bad("invalid package metadata"))?;
    authenticate_import(&meta, frames(dir)?, params, l1).await
}
/// Build stock input from the exact Rust frames without loading the block array or trusting a
/// second source.
pub(super) async fn stock(dir: &Path, path: &Path, v: &VerifiedImport) -> R<B256> {
    // All authenticated GenesisDoc strings are canonical ASCII and all other strings are hex.
    // The struct order below matches the stock helper's json.Marshal(Package) exactly.
    let file = files::create(path)?;
    let mut out = BufWriter::new(StockWriter { file, hash: alloy_primitives::Keccak256::new() });
    out.write_all(br#"{"schema":1,"genesis":"#).map_err(io)?;
    serde_json::to_writer(&mut out, v.genesis()).map_err(|_| bad("stock genesis framing"))?;
    out.write_all(br#","blocks":["#).map_err(io)?;
    for (i, frame) in frames(dir)?.enumerate() {
        tokio::task::yield_now().await;
        if i > 0 {
            out.write_all(b",").map_err(io)?
        }
        serde_json::to_writer(&mut out, &frame?).map_err(|_| bad("stock block framing"))?;
    }
    out.write_all(br#"],"validator_state":"#).map_err(io)?;
    serde_json::to_writer(&mut out, &alloy_primitives::Bytes::from(v.state().val_state.encode()))
        .map_err(|_| bad("stock preimage framing"))?;
    out.write_all(b"}")
        .and_then(|()| out.flush())
        .and_then(|()| out.get_ref().file.sync_all())
        .map_err(io)?;
    Ok(out.into_inner().map_err(|e| io(e.into_error()))?.hash.finalize())
}

/// Hash exactly the bytes durably supplied to the native verifier.
struct StockWriter {
    /// New independent package file.
    file: std::fs::File,
    /// Go-compatible digest consumed by the structured receipt.
    hash: alloy_primitives::Keccak256,
}
impl Write for StockWriter {
    /// Hash only bytes the underlying writer actually consumed.
    fn write(&mut self, b: &[u8]) -> std::io::Result<usize> {
        let n = self.file.write(b)?;
        self.hash.update(&b[..n]);
        Ok(n)
    }
    /// Forward flush to the real file before publication.
    fn flush(&mut self) -> std::io::Result<()> {
        self.file.flush()
    }
}
