//! A package directory: `package.json`, `execution_headers.jsonl`, one EL header per line, and
//! `blocks.jsonl`, one native window frame per line.
use super::*;
use alloy_consensus::Header;
use lander::checkpoint_import::{ImportPackage, WindowBlock, authenticate_import};
use serde::de::DeserializeOwned;
use std::io::{BufRead, BufReader, BufWriter};

/// Hex-encoded original native block/commit plus the bounded complete validator set.
const FRAME_LIMIT: u64 = 50 << 20;
/// The stock dir's window file, one [`WindowBlock`] per line from w + 1 to s.
const BLOCKS: &str = "blocks.jsonl";
/// The package's ascending linked EL headers through w ([`ImportPackage::execution_headers`]),
/// one per line, outside `package.json`.
const HEADERS: &str = "execution_headers.jsonl";
/// One header line's capacity; a canonical header's JSON line is under 2 KiB.
const HEADER_LIMIT: u64 = 16 << 10;
/// The most headers a package carries: U's largest value, 262,144, plus the inherited
/// checkpoint just below the range.
const MAX_HEADERS: u64 = abci::config::MAX_UNSETTLED_LIMIT + 1;

/// Open the package file `path`.
fn open(path: &Path) -> R<BufReader<File>> {
    File::open(path)
        .map(BufReader::new)
        .map_err(|e| unavailable(format!("package {}: {:?}", path.display(), e.kind())))
}

/// Decode JSON Lines from `reader` one bounded line at a time; fail on a partial or overlong
/// line. `what` names one line in diagnostics.
fn lines<T: DeserializeOwned>(
    mut reader: impl BufRead,
    limit: u64,
    what: &'static str,
) -> impl Iterator<Item = R<T>> {
    let mut done = false;
    std::iter::from_fn(move || {
        if done {
            return None;
        }
        let mut bytes = Vec::new();
        match (&mut reader).take(limit + 1).read_until(b'\n', &mut bytes) {
            Ok(0) => {
                done = true;
                None
            }
            Ok(n) if n as u64 <= limit && bytes.last() == Some(&b'\n') => {
                Some(serde_json::from_slice(&bytes).map_err(|_| bad(format!("invalid {what}"))))
            }
            Ok(_) => {
                done = true;
                Some(Err(bad(format!("overlong or incomplete {what}"))))
            }
            Err(e) => {
                done = true;
                Some(Err(io(e)))
            }
        }
    })
}

/// Decode one bounded JSON frame at a time; fail on partial or overlong frames.
pub(super) fn frames(dir: &Path) -> R<impl Iterator<Item = R<WindowBlock>>> {
    Ok(lines(open(&dir.join(BLOCKS))?, FRAME_LIMIT, "consensus frame"))
}

/// Read the package's EL headers one bounded line at a time, never the whole file; a header
/// beyond [`MAX_HEADERS`] is refused. The lander authenticates them.
fn headers(reader: impl BufRead) -> R<Vec<Header>> {
    let mut headers = Vec::new();
    for header in lines(reader, HEADER_LIMIT, "execution header") {
        if headers.len() as u64 == MAX_HEADERS {
            return Err(bad(format!("package holds more than {MAX_HEADERS} execution headers")));
        }
        headers.push(header?);
    }
    Ok(headers)
}

/// Durably write `headers` as the package's `execution_headers.jsonl` in `dir`.
pub(super) fn write_headers(dir: &Path, headers: &[Header]) -> R<()> {
    let mut out = BufWriter::new(create(&dir.join(HEADERS))?);
    write_lines(&mut out, headers)?;
    out.into_inner().map_err(|e| io(e.into_error()))?.sync_all().map_err(io)
}

/// Authenticate the package in `dir` against own finalized L1, reading each file once.
///
/// With `stock`, every frame the verifier consumes is also written to `stock/blocks.jsonl`, one
/// line each, serialized from the same in-memory frame the verifier receives. On success the
/// verifier has checked every frame it consumed and refused any trailing one, so that file holds
/// exactly the authenticated window: the stock helper installs no byte that was not verified, and
/// nothing is read from the package directory again.
pub(super) async fn verify<L: abci::L1Source + ?Sized>(
    dir: &Path,
    params: &abci::ChainParams,
    l1: &L,
    stock: Option<&Path>,
) -> R<VerifiedImport> {
    let mut meta: ImportPackage =
        serde_json::from_slice(&read(&dir.join("package.json"), 256 << 20)?)
            .map_err(|_| bad("invalid package metadata"))?;
    meta.execution_headers = headers(open(&dir.join(HEADERS))?)?;
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
/// original genesis and the validator state DATA-5.4-3 derives for s, both from the verified
/// checkpoint. Go installs that state's s + 1 and s + 2 sets.
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

    /// `count` copies of `line`, produced on demand rather than held.
    struct Repeated {
        line: Vec<u8>,
        at: usize,
        left: usize,
    }

    impl Read for Repeated {
        fn read(&mut self, out: &mut [u8]) -> std::io::Result<usize> {
            if self.at == self.line.len() {
                if self.left == 0 {
                    return Ok(0);
                }
                (self.at, self.left) = (0, self.left - 1);
            }
            let n = out.len().min(self.line.len() - self.at);
            out[..n].copy_from_slice(&self.line[self.at..self.at + n]);
            self.at += n;
            Ok(n)
        }
    }

    /// A chain header with every optional field present.
    fn header(number: u64) -> Header {
        Header {
            number,
            base_fee_per_gas: Some(10_000_000),
            extra_data: vec![0x5a; 13].into(),
            withdrawals_root: Some(B256::repeat_byte(1)),
            blob_gas_used: Some(0),
            excess_blob_gas: Some(0),
            parent_beacon_block_root: Some(B256::repeat_byte(2)),
            requests_hash: Some(B256::repeat_byte(3)),
            ..Default::default()
        }
    }

    #[test]
    fn package_headers_stream_one_per_line_and_read_back() {
        let dir = tempfile::tempdir().unwrap();
        let written = (5..9).map(header).collect::<Vec<_>>();
        write_headers(dir.path(), &written).unwrap();
        let bytes = fs::read(dir.path().join(HEADERS)).unwrap();
        assert_eq!(bytes.iter().filter(|b| **b == b'\n').count(), written.len());
        assert!(bytes.split(|b| *b == b'\n').all(|line| line.len() < 2048));
        assert_eq!(headers(open(&dir.path().join(HEADERS)).unwrap()).unwrap(), written);
        assert!(headers(&bytes[..bytes.len() - 1]).is_err(), "a partial last line is refused");
        let long = format!("{}\n", " ".repeat(HEADER_LIMIT as usize));
        assert!(headers(long.as_bytes()).is_err(), "an overlong line is refused");
        assert!(matches!(open(&dir.path().join("absent.jsonl")), Err(ImportError::Unavailable(_))));
    }

    /// A full range of headers, U + 1 at U's largest value, exceeds the 256 MiB of
    /// `package.json`; the package streams it, and one header more is refused.
    #[test]
    fn package_header_262146_is_refused() {
        assert_eq!(MAX_HEADERS, 262_145);
        let mut line = serde_json::to_vec(&header(7)).unwrap();
        line.push(b'\n');
        let reader =
            |count| BufReader::new(Repeated { at: line.len(), left: count, line: line.clone() });
        assert!(line.len() as u64 * MAX_HEADERS > 256 << 20);
        assert_eq!(headers(reader(262_145)).unwrap().len(), 262_145);
        let result = headers(reader(262_146));
        assert!(
            matches!(&result, Err(ImportError::Candidate(m)) if m.contains("262145")),
            "{result:?}"
        );
    }
}
