//! Spool original Comet frames backwards to locate the exact required window, then stream
//! them forwards. Only a constant number of complete blocks need to be resident.
use super::*;
use alloy_consensus::Header;
use alloy_provider::Provider;
use lander::{
    checkpoint_import::{ImportPackage, WindowBlock, evidence_expired, header_floor},
    comet::{CometSource, HttpCometSource},
};
use prost::Message;
use std::{
    io::{Read, Seek, SeekFrom, Write},
    time::Duration,
};
use tendermint_proto::v0_38::types::Commit as RawCommit;

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
/// Collect and verify a portable package. It contains neither EL state nor validator secrets.
pub async fn run(profile: &Path, height: u64, out: &Path, archived: Option<&Path>) -> R<Value> {
    let (p, profile_hash) = Profile::load(profile)?;
    let archive = p.archive.as_ref().ok_or_else(|| bad("archive profile absent"))?;
    let parent = files::parent(out)?;
    if files::exists(out)? {
        return Err(bad("export destination must be absent"))
    }
    let latch_path = parent
        .join(format!(".{}.checkpoint-halted.json", out.file_name().unwrap().to_string_lossy()));
    if files::exists(&latch_path)? {
        return Err(files::json(&latch_path)?)
    }
    let (params, l1) = p.own().await?;
    if crate::commands::rpc_chain_id(&archive.l2_http, "l2.http")
        .await
        .map_err(|_| ImportError::Unavailable("archive EL chain ID".into()))? !=
        U256::from(p.l2_chain_id)
    {
        return Err(bad("archive EL chain ID mismatch"))
    }
    let el = rpc::client::connect_http_with_limits(
        archive.l2_http.clone(),
        Duration::from_secs(30),
        8 << 20,
    );
    let comet = HttpCometSource::new(archive.comet_http.clone(), Duration::from_secs(30), 64 << 20)
        .map_err(bad)?;
    let genesis: abci::GenesisDoc = files::json(&archive.comet_genesis)?;
    let fixed = export_result(
        &latch_path,
        lander::checkpoint_import::select_export(&genesis, height, &params, &l1).await,
    )?;
    let origin = fixed.recovery.as_ref().map_or(0, |r| r.height);
    let schedule = abci::Schedule::from_genesis(&fixed.genesis);
    if height < origin ||
        height > abci::schedule::UINT48_MAX ||
        !height.is_multiple_of(abci::GRID_INTERVAL)
    {
        return Err(bad("invalid checkpoint selection"))
    }
    let id = keccak256(serde_json::to_vec(&(out, profile_hash, height, archived)).map_err(bad)?);
    let export_root =
        parent.join(format!(".{}.etna-export", out.file_name().unwrap().to_string_lossy()));
    if !files::exists(&export_root)? {
        let fresh = files::stage(parent, ".export-claim-")?;
        files::put(&fresh.path().join("export.json"), &id)?;
        files::publish_dir(fresh.path(), &export_root)?;
        files::sync(parent)?;
    }
    files::protected_root(&export_root)?;
    if files::json::<B256>(&export_root.join("export.json"))? != id {
        return Err(bad("unrelated archived export operation"))
    }
    let lease = acquire_activation(&export_root, id).map_err(bad)?;
    let work = files::restart_stage(&export_root, id)?;
    let stage = work.join("package");
    files::mkdir(&stage)?;
    let mut spool = tempfile::tempfile_in(&stage).map_err(io)?;
    let mut offsets = Vec::new();
    let mut boundary = None;
    let mut w = height;
    if height > origin {
        let mut min_required = height;
        for next in [height + 1, height + 2] {
            let epoch = schedule
                .active_committee_epoch(next, origin)
                .ok_or_else(|| bad("invalid committee schedule"))?;
            if epoch != origin / schedule.epoch_len {
                let switch = schedule
                    .checked_h_first(epoch)
                    .and_then(|h| h.checked_sub(2))
                    .ok_or_else(|| bad("invalid switch height"))?;
                min_required = min_required.min(switch);
                if let Some(d) = schedule.derivation_parent_height(epoch).filter(|d| *d > origin) {
                    min_required = min_required.min(d)
                }
            }
        }
        let mut seen_anchor = false;
        let mut terminal_time = None;
        let mut cached = None;
        loop {
            if w == origin {
                break
            }
            if seen_anchor && w < min_required && height - w > 100_000 {
                let h = comet.archive_header(w).await.map_err(source)?;
                if evidence_expired(height, terminal_time.expect("read terminal first"), w, h.time)
                {
                    boundary = Some(h);
                    break
                }
            }
            let block = comet.block(w).await.map_err(source)?;
            terminal_time.get_or_insert(block.block.header.time);
            let env = abci::EtnaEnvelope::decode(
                block.block.data.first().ok_or_else(|| bad("missing envelope"))?,
            )
            .map_err(bad)?;
            seen_anchor |= env.anchor.is_some();
            let hash = block.block.header.validators_hash;
            if cached.as_ref().is_none_or(|(h, _)| *h != hash) {
                cached =
                    Some((hash, comet.archive_validators(w, params.n_max).await.map_err(source)?));
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
    let mut frames = files::create(&stage.join("blocks.jsonl"))?;
    for (offset, len) in offsets.into_iter().rev() {
        tokio::task::yield_now().await;
        spool.seek(SeekFrom::Start(offset)).map_err(io)?;
        if std::io::copy(&mut (&mut spool).take(len), &mut frames).map_err(io)? != len {
            return Err(bad("short spool frame"))
        }
    }
    frames.sync_all().map_err(io)?;
    let mut prefix = Vec::new();
    let start = w.min(header_floor(origin, height, params.unsettled_limit));
    for n in start..=w {
        prefix.push(header(&el, n).await?)
    }
    let origin_header = if let Some(h) = prefix.iter().find(|h| h.number == origin) {
        h.clone()
    } else {
        header(&el, origin).await?
    };
    let preimage = if height == origin {
        if archived.is_some() {
            return Err(bad("fixed genesis has no landed preimage"))
        }
        Vec::new()
    } else if let Some(p) = archived {
        files::read(p, 16 << 20)?
    } else {
        comet.val_state(height).await.map_err(source)?
    };
    let meta = ImportPackage {
        schema: 1,
        genesis,
        checkpoint_height: height,
        origin_header,
        recovery_bootstrap: archive
            .recovery_bootstrap
            .as_ref()
            .map(|p| files::json(p))
            .transpose()?,
        boundary_header: boundary,
        validator_state: preimage.into(),
        execution_headers: prefix,
    };
    files::put(&stage.join("package.json"), &meta)?;
    let verified = export_result(&latch_path, package::verify(&stage, &params, &l1).await)?;
    let generation = verified.state().generation;
    // Nonterminal successor LastCommit bytes are checked independently by the stock reader.
    if verified.first_height().is_some() {
        let work = work.join("go");
        files::mkdir(&work)?;
        let stock = work.join("stock.json");
        let hash = package::stock(&stage, &stock, &verified).await?;
        let child = helpers::Holds::acquire(&lease, &work, vec![])?;
        match helpers::comet(&archive.comet_helper, &stock, hash, None, &verified, &child).await {
            Err(e @ ImportError::Safety(_)) => {
                files::put(&latch_path, &e)?;
                return Err(e)
            }
            other => {
                other?;
            }
        }
        // Drop the full duplicate before publishing. Even a crash immediately after
        // rename can now leave only small control files beside the visible package.
        std::fs::remove_file(stock).map_err(io)?;
        files::sync(&work)?;
    }
    files::sync(&stage)?;
    files::publish_dir(&stage, out)?;
    files::sync(parent)?;
    files::discard(&export_root, id)?;
    Ok(json!({"phase":"exported","height":height,"generation":generation,"live_trust":false}))
}
/// Persist only authenticated exporter contradictions alongside its intended output.
fn export_result<T>(path: &Path, result: R<T>) -> R<T> {
    if let Err(e @ ImportError::Safety(_)) = &result {
        files::put(path, e)?
    }
    result
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
