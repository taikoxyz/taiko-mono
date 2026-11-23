//! Spool original Comet frames backwards to locate the exact required window, then stream
//! them forwards. Only a constant number of complete blocks need to be resident.
use super::*;
use alloy_consensus::Header;
use alloy_primitives::{U256, hex};
use alloy_provider::Provider;
use lander::{
    checkpoint_import::{
        IMPORT_SCHEMA, ImportPackage, ImportValidator, WindowBlock, evidence_expired, header_floor,
    },
    comet::{CometSource, HttpCometSource},
};
use prost::Message;
use std::{
    io::{Seek, SeekFrom},
    os::unix::fs::PermissionsExt,
    time::Duration,
};
use tendermint_proto::v0_38::types::Commit as RawCommit;

/// The archive node's sources and the selected checkpoint of one export.
#[derive(clap::Args, Clone, Debug)]
pub struct Request {
    /// Stock read-only Comet RPC of an archive node of this generation.
    #[arg(long = "comet.http", value_parser = crate::flags::common::http_url)]
    pub comet_http: Url,
    /// Canonical EL RPC of that node; only `debug_getRawHeader` and `eth_chainId` are read.
    #[arg(long = "l2.http", value_parser = crate::flags::common::http_url)]
    pub l2_http: Url,
    /// The generation's original stock `genesis.json`.
    #[arg(long)]
    pub comet_genesis: PathBuf,
    /// The stored recovery bootstrap JSON; required for a recovery generation.
    #[arg(long)]
    pub recovery_bootstrap: Option<PathBuf>,
    /// The selected landed checkpoint height s.
    #[arg(long)]
    pub height: u64,
    /// The package directory to create; it must be absent.
    #[arg(long)]
    pub out: PathBuf,
    /// Offline stock Comet data directory containing state.db at s - 1. Required beyond the
    /// fixed origin (DATA-5.4-8).
    #[arg(long)]
    pub comet_state_dir: Option<PathBuf>,
    /// Stock Comet helper used to compare the independent state snapshot before publication.
    #[arg(long, default_value = "etna-comet-import")]
    pub comet_helper: PathBuf,
    /// The archived raw validator-state preimage after s - 1 (DATA-5.4-3), for a source app that
    /// already pruned it.
    #[arg(long)]
    pub validator_state: Option<PathBuf>,
}

/// Read the canonical execution header at a named number, never historical execution state.
async fn header(provider: &alloy_provider::RootProvider, n: u64) -> R<Header> {
    let raw: alloy_primitives::Bytes = provider
        .raw_request("debug_getRawHeader".into(), (format!("0x{n:x}"),))
        .await
        .map_err(|_| ImportError::Unavailable(format!("missing execution archive header {n}")))?;
    let h: Header =
        alloy_rlp::decode_exact(&raw).map_err(|_| bad("invalid execution header RLP"))?;
    if h.number != n || alloy_rlp::encode(&h).as_slice() != raw.as_ref() {
        return Err(bad("noncanonical archive header or wrong height"))
    }
    Ok(h)
}
/// Collect a portable package for `request.height`, authenticate it against own finalized L1
/// exactly as `import` will (DATA-5.4-2) and publish it at `request.out` by one rename. It holds
/// neither EL state nor validator secrets. An interrupted export leaves only a private
/// `.<out>.export-*` directory beside `out`, which may be deleted.
pub async fn run(own: &Own, request: &Request) -> R<Value> {
    let (out, height, archived) =
        (&request.out, request.height, request.validator_state.as_deref());
    let name = out.file_name().ok_or_else(|| bad("--out must name a directory"))?;
    let parent = match out.parent() {
        Some(p) if !p.as_os_str().is_empty() => p,
        _ => Path::new("."),
    };
    if exists(out)? {
        return Err(bad("export destination must be absent"));
    }
    let (params, l1) = own.connect().await?;
    if crate::commands::rpc_chain_id(&request.l2_http, "l2.http")
        .await
        .map_err(|_| unavailable("archive EL chain ID"))? !=
        U256::from(params.l2_chain_id)
    {
        return Err(bad("archive EL chain ID mismatch"));
    }
    let el = rpc::client::connect_http_with_limits(
        request.l2_http.clone(),
        Duration::from_secs(30),
        8 << 20,
    );
    let comet = HttpCometSource::new(request.comet_http.clone(), Duration::from_secs(30), 64 << 20)
        .map_err(bad)?;
    let genesis: abci::GenesisDoc =
        serde_json::from_slice(&read(&request.comet_genesis, 16 << 20)?)
            .map_err(|_| bad("invalid --comet-genesis"))?;
    let fixed = lander::checkpoint_import::select_export(&genesis, height, &params, &l1).await?;
    let origin = fixed.origin_height();
    let stock = if height > origin {
        Some(request.comet_state_dir.as_deref().ok_or_else(|| {
            unavailable("--comet-state-dir must supply an exact stock state snapshot at s - 1")
        })?)
    } else {
        None
    };
    let stage = tempfile::Builder::new()
        .prefix(&format!(".{}.export-", name.to_string_lossy()))
        .permissions(fs::Permissions::from_mode(0o700))
        .tempdir_in(parent)
        .map_err(io)?;
    let mut spool = tempfile::tempfile_in(stage.path()).map_err(io)?;
    let mut offsets = Vec::new();
    let mut boundary = None;
    let mut w = height;
    let mut terminal_header = None;
    if height > origin {
        // The window reaches the latest block at or below s carrying an anchor witness and every
        // height still within an evidence age limit at s.
        let mut seen_anchor = false;
        let mut terminal_time = None;
        let mut cached = None;
        loop {
            if w == origin {
                break
            }
            if seen_anchor && height - w > abci::genesis::EVIDENCE_MAX_AGE_NUM_BLOCKS {
                let h = comet.archive_header(w).await.map_err(source)?;
                if evidence_expired(height, terminal_time.expect("read terminal first"), w, h.time)
                {
                    boundary = Some(h);
                    break
                }
            }
            let block = comet.block(w).await.map_err(source)?;
            if w == height {
                terminal_header = Some(block.block.header.clone());
            }
            terminal_time.get_or_insert(block.block.header.time);
            let env = abci::EtnaEnvelope::decode(
                block.block.data.first().ok_or_else(|| bad("missing envelope"))?,
            )
            .map_err(bad)?;
            seen_anchor |= env.anchor.is_some();
            let hash = block.block.header.validators_hash;
            if cached.as_ref().is_none_or(|(h, _)| *h != hash) {
                let validators = comet.archive_validators(w).await.map_err(source)?;
                cached = Some((
                    hash,
                    validators
                        .into_iter()
                        .map(|(key, power)| ImportValidator { key, power })
                        .collect::<Vec<_>>(),
                ));
            }
            let frame = WindowBlock {
                block: block.raw_block,
                commit: RawCommit::from(block.commit).encode_to_vec().into(),
                validators: cached.as_ref().unwrap().1.clone(),
            };
            let off = spool.stream_position().map_err(io)?;
            serde_json::to_writer(&mut spool, &frame).map_err(|_| bad("spool frame"))?;
            spool.write_all(b"\n").map_err(io)?;
            let end = spool.stream_position().map_err(io)?;
            if end > 1 << 40 {
                return Err(bad("archive exceeds capacity"))
            }
            offsets.push((off, end - off));
            w -= 1;
        }
    }
    let mut frames = create(&stage.path().join("blocks.jsonl"))?;
    for (offset, len) in offsets.into_iter().rev() {
        tokio::task::yield_now().await;
        spool.seek(SeekFrom::Start(offset)).map_err(io)?;
        if std::io::copy(&mut (&mut spool).take(len), &mut frames).map_err(io)? != len {
            return Err(bad("short spool frame"))
        }
    }
    drop(spool);
    frames.sync_all().map_err(io)?;
    let mut prefix = Vec::new();
    let start = w.min(header_floor(origin, height, params.unsettled_limit));
    for n in start..=w {
        prefix.push(header(&el, n).await?)
    }

    let preimage = preimage(&comet, height, origin, archived).await?;
    let recovery_bootstrap = match &request.recovery_bootstrap {
        Some(p) => Some(
            serde_json::from_slice(&read(p, 16 << 20)?)
                .map_err(|_| bad("invalid --recovery-bootstrap"))?,
        ),
        None => None,
    };
    let meta = ImportPackage {
        schema: IMPORT_SCHEMA,
        genesis,
        checkpoint_height: height,
        origin_header: None,
        recovery_bootstrap,
        boundary_header: boundary,
        validator_state: preimage.into(),
        execution_headers: prefix,
    };
    let mut package = create(&stage.path().join("package.json"))?;
    let bytes = serde_json::to_vec(&meta).map_err(|e| bad(format!("package metadata: {e}")))?;
    package.write_all(&bytes).and_then(|()| package.sync_all()).map_err(io)?;
    // The same authentication `import` runs, before anything is published.
    let verified = package::verify(stage.path(), &params, &l1, None).await?;
    if let Some(stock) = stock {
        let terminal =
            terminal_header.as_ref().ok_or_else(|| unavailable("missing terminal block"))?;
        if terminal.hash().as_bytes() != verified.landing().comet_hash.as_slice() {
            return Err(bad("stock comparison header differs from the authenticated landing"));
        }
        verify_stock(request, stock, stage.path(), &meta, terminal).await?;
    }
    let generation = verified.state().generation;
    sync(stage.path())?;
    let staged = stage.keep();
    if let Err(e) = fs::rename(&staged, out) {
        let _ = fs::remove_dir_all(&staged);
        return Err(io(e));
    }
    sync(parent)?;
    Ok(json!({"phase":"exported","height":height,"generation":generation}))
}
/// Compare against the independent node's committed stock state before publishing (DATA-5.4-8).
async fn verify_stock(
    request: &Request,
    stock: &Path,
    stage: &Path,
    meta: &ImportPackage,
    terminal: &tendermint::block::Header,
) -> R<()> {
    let path = stage.join("validator-state.bin");
    write_new(&path, &meta.validator_state)?;
    let predecessor =
        terminal.last_block_id.map_or_else(String::new, |b| hex::encode(b.hash.as_bytes()));
    let mut command = tokio::process::Command::new(&request.comet_helper);
    let status = command
        .kill_on_drop(true)
        .arg("verify-export")
        .arg("--comet-state-dir")
        .arg(stock)
        .arg("--validator-state")
        .arg(&path)
        .arg("--chain-id")
        .arg(&meta.genesis.chain_id)
        .arg("--initial-height")
        .arg(&meta.genesis.initial_height)
        .arg("--height")
        .arg((request.height - 1).to_string())
        .arg("--block-hash")
        .arg(predecessor)
        .arg("--app-hash")
        .arg(hex::encode(terminal.app_hash.as_bytes()))
        .status()
        .await
        .map_err(|error| unavailable(format!("cannot run stock Comet verifier: {error}")))?;
    if status.code() == Some(2) {
        tracing::error!(height = request.height - 1, "validator state differs from stock CometBFT");
        return Err(ImportError::Safety("validator state differs from stock CometBFT".into()));
    }
    if !status.success() {
        return Err(unavailable(format!("cannot verify stock Comet state ({status})")));
    }
    fs::remove_file(path).map_err(io)
}

/// The package's validator-state preimage for a checkpoint at `height`: the state after
/// `height - 1` (DATA-5.4-3, DATA-5.4-8), from `archived` or else the source app's
/// `/val_state/<height - 1>` query, which serves any retained height. The fixed origin takes
/// none (DATA-5.4-1). It stays unauthenticated until `package::verify` checks it against
/// header(s)'s app_hash.
async fn preimage(
    comet: &impl CometSource,
    height: u64,
    origin: u64,
    archived: Option<&Path>,
) -> R<Vec<u8>> {
    if height == origin {
        if archived.is_some() {
            return Err(bad("fixed genesis takes no validator-state preimage"))
        }
        return Ok(Vec::new());
    }
    match archived {
        Some(p) => read(p, 16 << 20),
        None => comet.val_state(height - 1).await.map_err(source),
    }
}

/// Untrusted history has no authority to promote defects to a durable safety latch.
fn source(e: lander::LanderError) -> ImportError {
    match e {
        lander::LanderError::Unavailable(_) | lander::LanderError::Temporary(_) => {
            ImportError::Unavailable(format!("archive: {e}"))
        }
        other => bad(format!("invalid archive response: {other}")),
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::sync::Mutex;

    /// An archive app that answers `/val_state/<h>` for any `h` and records each request.
    #[derive(Default)]
    struct Archive(Mutex<Vec<u64>>);

    #[async_trait::async_trait]
    impl CometSource for Archive {
        async fn status(&self) -> lander::Result<lander::comet::CometStatus> {
            unreachable!("the preimage read needs no status")
        }
        async fn block(&self, _: u64) -> lander::Result<lander::CertifiedBlock> {
            unreachable!("the preimage read needs no block")
        }
        async fn val_state(&self, height: u64) -> lander::Result<Vec<u8>> {
            self.0.lock().unwrap().push(height);
            Ok(height.to_be_bytes().to_vec())
        }
        async fn archive_validators(
            &self,
            _: u64,
        ) -> lander::Result<Vec<(abci::key::ConsensusKey, u64)>> {
            unreachable!("the preimage read needs no validator set")
        }
    }

    /// DATA-5.4-3/8: the package for s carries the state after s - 1, at any s, including one
    /// that is not a multiple of 6.
    #[tokio::test]
    async fn export_reads_s_minus_1_at_non_multiple_of_6() {
        let archive = Archive::default();
        assert_eq!(preimage(&archive, 7, 0, None).await.unwrap(), 6u64.to_be_bytes());
        assert_eq!(*archive.0.lock().unwrap(), [6]);
        // The fixed origin takes no preimage and reads none.
        assert!(preimage(&archive, 0, 0, None).await.unwrap().is_empty());
        assert_eq!(*archive.0.lock().unwrap(), [6]);
        // An archived preimage replaces the query.
        let dir = tempfile::tempdir().unwrap();
        let path = dir.path().join("validator-state.bin");
        std::fs::write(&path, b"after 6").unwrap();
        assert_eq!(preimage(&archive, 7, 0, Some(&path)).await.unwrap(), b"after 6");
        assert_eq!(*archive.0.lock().unwrap(), [6]);
    }
}
