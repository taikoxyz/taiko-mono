//! A package directory: `package.json` and `blocks.jsonl`, one native window frame per line.
use super::*;
use lander::checkpoint_import::{ImportPackage, WindowBlock, authenticate_import};
use std::io::{BufRead, BufReader, BufWriter};

/// Hex-encoded original native block/commit plus the bounded complete validator set.
const FRAME_LIMIT: u64 = 50 << 20;
/// The stock dir's window file, one [`WindowBlock`] per line from w + 1 to s.
const BLOCKS: &str = "blocks.jsonl";

/// Decode one bounded JSON frame at a time; fail on partial or overlong frames.
pub(super) fn frames(dir: &Path) -> R<impl Iterator<Item = R<WindowBlock>>> {
    let path = dir.join(BLOCKS);
    let file = File::open(&path)
        .map_err(|e| unavailable(format!("package {}: {:?}", path.display(), e.kind())))?;
    let mut reader = BufReader::new(file);
    let mut done = false;
    Ok(std::iter::from_fn(move || {
        if done {
            return None;
        }
        let mut bytes = Vec::new();
        match (&mut reader).take(FRAME_LIMIT + 1).read_until(b'\n', &mut bytes) {
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

/// Authenticate the package in `dir` against own finalized L1, reading each file once.
///
/// With `stock`, every frame the verifier consumes is also written to `stock/blocks.jsonl`, one
/// line each, serialized from the same in-memory frame the verifier receives. On success the
/// verifier has checked every frame it consumed and refused any trailing one, so that file holds
/// exactly the authenticated window: the stock helper installs no byte that was not verified, and
/// nothing is read from the package directory again.
pub(super) async fn verify(
    dir: &Path,
    params: &abci::ChainParams,
    l1: &abci::RpcL1Source,
    stock: Option<&Path>,
) -> R<VerifiedImport> {
    let meta: ImportPackage = serde_json::from_slice(&read(&dir.join("package.json"), 256 << 20)?)
        .map_err(|_| bad("invalid package metadata"))?;
    let frames = frames(dir)?;
    let Some(stock) = stock else {
        return authenticate_import(&meta, frames, params, l1).await;
    };
    let mut copy = BufWriter::new(create(&stock.join(BLOCKS))?);
    let tee = frames.map(|frame| -> R<WindowBlock> {
        let frame = frame?;
        serde_json::to_writer(&mut copy, &frame)
            .map_err(|e| unavailable(format!("stock window copy: {e}")))?;
        copy.write_all(b"\n").map_err(io)?;
        Ok(frame)
    });
    let verified = authenticate_import(&meta, tee, params, l1).await?;
    copy.into_inner().map_err(|e| io(e.into_error()))?;
    Ok(verified)
}

/// Complete the stock dir beside the authenticated `blocks.jsonl` that [`verify`] wrote: the
/// original genesis and the validator-state preimage at s, both from the verified checkpoint.
pub(super) fn write_stock_dir(stock: &Path, v: &VerifiedImport) -> R<()> {
    write_new(&stock.join("genesis.json"), &serde_json::to_vec(v.genesis()).map_err(bad)?)?;
    write_new(&stock.join("validator-state.bin"), &v.state().val_state.encode())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn frames_refuse_a_short_last_frame() {
        let dir = tempfile::tempdir().unwrap();
        fs::write(dir.path().join(BLOCKS), b"{}").unwrap();
        assert!(frames(dir.path()).unwrap().next().unwrap().is_err());
    }
}
