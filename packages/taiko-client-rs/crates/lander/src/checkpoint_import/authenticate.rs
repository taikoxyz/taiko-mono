//! Own-finalized-L1 admission and single-pass native-window reconstruction.

use super::*;
use crate::{
    committee::Validators,
    native::{Commit, RawBlock},
    types::CertifiedBlock,
    validate,
};
use abci::{
    AnchorState, AnchorWitness, Member,
    l1::{
        OwnFinality,
        layout::{inbox, word_u48},
        mpt::verify_account_witness,
        own_finality, verify_anchor_witness,
    },
    rules,
};
use prost::Message;
use tendermint_proto::v0_38::types::Commit as RawCommit;

/// Authenticate the exporter's fixed origin and selected landing before it makes any
/// archival consensus requests. The returned public genesis facts select a bounded scan;
/// full window verification and a fresh own observation are still required before export.
pub async fn select_export<L: L1Source + ?Sized>(
    genesis: &GenesisDoc,
    height: u64,
    params: &ChainParams,
    l1: &L,
) -> Result<abci::genesis::VerifiedGenesis, ImportError> {
    params.validate().map_err(candidate)?;
    let fixed = abci::genesis::verify_original_genesis(genesis, params).map_err(candidate)?;
    for header in &fixed.l1_headers {
        canonical(l1, header).await?;
    }
    let origin = fixed.origin_height();
    if height < origin ||
        height > abci::schedule::UINT48_MAX ||
        !height.is_multiple_of(abci::GRID_INTERVAL)
    {
        return Err(candidate("invalid export checkpoint selection"))
    }
    // verify_original_genesis validated the versioned recovery frame and complete original
    // genesis. authenticate_snapshot requires its inner, untagged canonical witness RLP.
    let recovery = fixed.recovery.as_ref().map(|_| genesis.app_state.witness.slice(1..));
    own_landing(l1, params, height, &fixed, recovery).await?;
    Ok(fixed)
}

/// Authenticate the original genesis, current own-finalized generation and retained landing,
/// then consume exactly one ascending native block window. Missing frames remain unavailable;
/// no execution engine, prefix source, or successor block is needed or accepted. The future
/// yields once per frame, even for cache hits; dropping it discards partial reconstruction.
/// A synchronous iterator read or native check already in progress is not preempted.
///
/// This is the only window authentication (DATA-5.4-2): the stock installer checks nothing again,
/// so callers must hand it exactly the frames consumed here, and its report must match
/// `first_height`, `landing` and `block_id`. This result never permits signing: admission must
/// reacquire the latest own-L1 target.
pub async fn authenticate_import<L, I>(
    package: &ImportPackage,
    blocks: I,
    params: &ChainParams,
    own_l1: &L,
) -> Result<VerifiedImport, ImportError>
where
    L: L1Source + ?Sized,
    I: Iterator<Item = Result<WindowBlock, ImportError>>,
{
    params.validate().map_err(candidate)?;
    if package.schema != 1 {
        return Err(candidate("unsupported import schema"));
    }
    let fixed =
        abci::genesis::verify_original_genesis(&package.genesis, params).map_err(candidate)?;
    for header in &fixed.l1_headers {
        canonical(own_l1, header).await?;
    }
    let (origin, origin_hash) = (fixed.origin_height(), fixed.origin_hash());
    if package.origin_header.number != origin ||
        package.origin_header.hash_slow() != origin_hash ||
        (origin == 0 && package.origin_header.state_root != fixed.genesis.genesis_state_root)
    {
        return Err(candidate("fixed origin execution header mismatch"));
    }
    let (recovery_witness, origin_anchor, origin_parent) =
        match (&fixed.recovery, &package.recovery_bootstrap) {
            (None, None) => (None, fixed.anchor.clone(), parent_info(&package.origin_header, 0)?),
            (Some(_), Some(bootstrap)) => {
                let abci::recovery::VerifiedBootstrap { witness, anchor, .. } =
                    bootstrap.verify(params).map_err(candidate)?;
                // The projected origin does not commit R's parent hash. Bind the full duplicate
                // witness to the already authenticated genesis before checking own-node integrity.
                if abci::genesis::AppStateJson::from(&witness) != package.genesis.app_state ||
                    witness.el_header != package.origin_header
                {
                    return Err(candidate(
                        "bootstrap witness differs from authenticated fixed recovery",
                    ));
                }
                abci::recovery::check_recovery_canonicality(own_l1, params, &witness)
                    .await
                    .map_err(|e| match e {
                        abci::recovery::RecoveryError::Unavailable(_) => unavailable(e),
                        abci::recovery::RecoveryError::Superseded { .. } => candidate(e),
                        _ => safety(e),
                    })?;
                match own_finality(own_l1, anchor.number, anchor.hash).await.map_err(own_error)? {
                    OwnFinality::Canonical => {}
                    OwnFinality::NotFinal { .. } => {
                        return Err(unavailable(
                            "recovery historical anchor is not final in own L1",
                        ));
                    }
                    OwnFinality::OffChain { .. } => {
                        return Err(candidate("recovery historical anchor is off own L1"));
                    }
                }
                let parent = abci::recovery::recovery_parent(&witness);
                (Some(alloy_rlp::encode(&witness).into()), anchor, parent)
            }
            _ => return Err(candidate("recovery bootstrap presence differs from original genesis")),
        };
    let landing =
        own_landing(own_l1, params, package.checkpoint_height, &fixed, recovery_witness).await?;
    // The origin state InitChain persists for the same genesis (DATA-5.4-1, RECOV-8.4-7).
    let mut state = fixed
        .origin_state(package.genesis.chain_id.clone(), origin_parent, origin_anchor)
        .map_err(candidate)?;
    // Source errors have no authority to assert a protocol contradiction; only checks against
    // own-finalized L1 and data authenticated by it can produce a terminal Safety classification.
    let mut blocks = blocks
        .map(|frame| {
            frame.map_err(|error| match error {
                ImportError::Safety(detail) => {
                    candidate(format!("unauthenticated block reader: {detail}"))
                }
                other => other,
            })
        })
        .peekable();
    if landing.height == origin {
        if landing.el_hash != origin_hash || landing.forced_cursor != state.forced_cursor {
            return Err(safety("selected origin landing contradicts fixed genesis"));
        }
        if let Some(frame) = blocks.next() {
            frame?;
            return Err(candidate("origin import cannot contain consensus frames"));
        }
        if package.boundary_header.is_some() || !package.validator_state.is_empty() {
            return Err(candidate("origin import must use fixed-genesis initialization"));
        }
        let headers = execution_prefix(package, origin, origin, params)?;
        return Ok(VerifiedImport {
            state,
            genesis: package.genesis.clone(),
            landing,
            block_id: None,
            first_height: None,
            execution_headers: headers,
            recovery_bootstrap: package.recovery_bootstrap.clone(),
        });
    }
    let val_state =
        authenticate_preimage(&package.validator_state, landing.val_state_hash, landing.height)?;
    let schedule = Schedule::from_genesis(&fixed.genesis);
    let future = future_epochs(&schedule, origin, landing.height)?;
    let mut expected_committees = BTreeMap::new();
    if future.contains(&fixed.committee.record.target_epoch) {
        expected_committees.insert(fixed.committee.record.target_epoch, fixed.committee.clone());
    }
    let first = blocks
        .peek()
        .ok_or_else(|| unavailable("missing consensus window"))?
        .as_ref()
        .map_err(Clone::clone)?;
    let first_height = check_header_projection(&first.block, &landing, &val_state)?;
    let w = first_height
        .checked_sub(1)
        .filter(|w| *w >= origin && *w < landing.height)
        .ok_or_else(|| candidate("window starts outside current generation"))?;
    let mut headers = execution_prefix(package, w, landing.height, params)?;
    let mut parent =
        headers.last().cloned().ok_or_else(|| unavailable("missing execution boundary"))?;
    let keep_from = header_floor(origin, landing.height, params.unsettled_limit);
    let mut retained = headers.drain(..).filter(|h| h.number >= keep_from).collect::<Vec<_>>();
    let mut previous: Option<PreviousHeight> = None;
    let mut heights = Vec::new();
    let mut latest_anchor_height = None;
    let mut latest_anchor = None;
    let mut anchor_cache = BTreeMap::new();
    let mut terminal = None;
    let fixed_params_hash = abci::genesis::GenesisConsensusParams::etna_hash();
    let mut rejected = None;
    for frame in blocks.by_ref() {
        // Cached local frames and already-ready L1 futures need not yield themselves. Give the
        // one-shot controller's cancellation/signal branch a turn between bounded native frames.
        tokio::task::yield_now().await;
        let frame = frame?;
        check_header_projection(&frame.block, &landing, &val_state)?;
        if frame.commit.len() > 2_000_000 || frame.validators.len() > params.n_max {
            return Err(candidate("native frame exceeds consensus resource bounds"));
        }
        let (pair, same_commit) = decode_frame(&frame, previous.as_ref().map(|p| &p.commit))?;
        let h = parent.number.checked_add(1).ok_or_else(|| candidate("height overflow"))?;
        if h > landing.height {
            return Err(candidate("successor block supplied beyond selected checkpoint"));
        }
        if pair.block.header.height.value() != h {
            return Err(candidate("requested block height mismatch"));
        }
        // The hash chain authenticates these header fields. Check them before the commit, whose
        // own APP_VERSION and chain id checks would call a landed header a bad certificate.
        if let Some(fault) =
            fixed_header_fault(&pair.block.header, &package.genesis.chain_id, fixed_params_hash)
        {
            rejected = Some((h, pair.block.header.hash(), fault));
            break;
        }
        // Check the publisher-supplied commits, sets and links before any block rule: the rules
        // below then read only content that the native hash chain can authenticate.
        let committee = historical_set(&frame.validators)?;
        validate::verify_native_commit(
            &pair.commit,
            &pair.block.header,
            &committee,
            &package.genesis.chain_id,
        )
        .map_err(candidate)?;
        if let Some(prior) = &previous {
            if pair.block.header.last_block_id != Some(prior.id) {
                return Err(candidate("discontinuous native height/hash chain"));
            }
            let last = pair
                .block
                .last_commit
                .as_ref()
                .ok_or_else(|| candidate("missing successor LastCommit"))?;
            validate::verify_native_commit(
                last,
                &prior.header,
                &prior.validators,
                &package.genesis.chain_id,
            )
            .map_err(candidate)?;
            if !same_commit {
                return Err(candidate("nonterminal own commit differs from successor LastCommit"));
            }
        } else {
            verify_boundary(package.boundary_header.as_ref(), &pair, w, origin)?;
            // Only w + 1's AppHash authenticates the publisher's EL header at w.
            if pair.block.header.app_hash.as_bytes() != parent.hash_slow().as_slice() {
                return Err(candidate("execution prefix does not link to the first window block"));
            }
        }
        let content = async {
            let env = if previous.is_none() && w == origin {
                validate::verify_structure_at_origin(&pair, None, h, parent.hash_slow(), origin)
            } else {
                validate::verify_body_at_origin(&pair, h, parent.hash_slow(), origin)
            }
            .map_err(body_fault)?;
            if let Some(prior) = &previous &&
                (pair.block.header.validators_hash != prior.header.next_validators_hash ||
                    pair.block.header.time <= prior.header.time)
            {
                return Err(ContentFault::Rule("discontinuous native validator/time chain".into()));
            }
            let anchor_number = check_anchor_selection(&env, &parent, &state)?;
            let anchor =
                envelope_anchor(&env, anchor_number, own_l1, params, &mut anchor_cache).await?;
            check_metadata(
                &env,
                MetadataContext {
                    parent: &parent,
                    anchor: &anchor,
                    previous_anchor: latest_anchor.as_ref(),
                    state: &state,
                    params,
                    bft_time: pair.block.header.time,
                },
            )?;
            let mut derived = None;
            if let Some(epoch) = schedule.switch_target(h) &&
                future.contains(&epoch)
            {
                let witness = env
                    .committee
                    .as_ref()
                    .ok_or_else(|| unavailable("required switch witness absent"))?;
                let snapshot_number = if parent.number <= origin {
                    state.anchor_floor()
                } else {
                    rules::decode_extra_data(&parent.extra_data)
                        .map_err(candidate)?
                        .2
                        .max(state.anchor_floor())
                };
                if anchor.number < snapshot_number {
                    return Err(ContentFault::Rule(
                        "switch proof root predates derivation snapshot".into(),
                    ));
                }
                let (record, members) = abci::committee::verify_committee_witness_at_cutoff(
                    anchor.state_root,
                    snapshot_number,
                    params,
                    witness,
                    epoch,
                )
                .map_err(candidate)?;
                derived = Some((epoch, CommitteeState { record, members }));
            }
            Ok((env, anchor, derived))
        }
        .await;
        let (env, anchor, derived) = match content {
            Ok(content) => content,
            Err(ContentFault::Now(error)) => return Err(error),
            Err(fault) => {
                rejected = Some((h, pair.block.header.hash(), fault));
                break;
            }
        };
        if env.anchor.is_some() {
            latest_anchor_height = Some(h);
        }
        if let Some((epoch, committee)) = derived {
            expected_committees.insert(epoch, committee);
        }
        heights.push((h, pair.block.header.time));
        if h >= keep_from {
            retained.push(env.block.header.clone());
        }
        if h == landing.height {
            state.parent = parent_info(&env.block.header, parent.timestamp)?;
            terminal = Some(pair.commit.block_id);
        }
        parent = env.block.header;
        latest_anchor = Some(anchor);
        if h == landing.height {
            break;
        }
        previous = Some(PreviousHeight {
            header: pair.block.header,
            id: pair.commit.block_id,
            validators: committee,
            commit: frame.commit,
        });
    }
    if let Some((height, hash, fault)) = rejected {
        return Err(confirm_landed(fault, height, hash, &mut blocks, &landing, &val_state).await);
    }
    let block_id =
        terminal.ok_or_else(|| unavailable("window ended before selected checkpoint"))?;
    let latest_anchor_height =
        latest_anchor_height.ok_or_else(|| unavailable("window omits latest anchor witness"))?;
    for (epoch, set) in future.iter().zip([&val_state.current, &val_state.next]) {
        let derived = expected_committees
            .get(epoch)
            .ok_or_else(|| unavailable(format!("missing derived future committee {epoch}")))?;
        if !same_powers(set, derived) {
            return Err(safety(
                "landed validator-state keys/powers contradict independently derived committee",
            ));
        }
    }
    super::window::verify_complete_window(
        w,
        &heights,
        package.boundary_header.as_ref(),
        super::window::WindowContext {
            origin,
            terminal: landing.height,
            schedule: &schedule,
            future: &future,
            latest_anchor: latest_anchor_height,
        },
    )?;
    state.last_height = landing.height;
    state.last_comet_hash = landing.comet_hash;
    state.forced_cursor = landing.forced_cursor;
    state.val_state = val_state;
    state.committees = expected_committees;
    state.anchor = latest_anchor.expect("terminal block has anchor");
    // The installed EL block at s that startup checks the own EL still serves with its state
    // (DATA-5.4-4, DATA-5.4-6). An origin import keeps none: InitChain starts that store.
    state.execution_floor =
        Some(abci::ExecutionFloor { number: landing.height, hash: state.parent.hash });
    if state.forced_cursor < state.anchor.inbox.forced_inclusion_head ||
        state.forced_cursor > state.anchor.inbox.forced_inclusion_tail
    {
        return Err(safety("landed FI cursor contradicts inherited authenticated queue bounds"));
    }
    // `retained` already starts at the header floor, which back-pressure keeps at or below q.
    if !retained.iter().any(|h| {
        h.number == state.anchor.inbox.last_checkpoint_height &&
            h.hash_slow() == state.anchor.inbox.last_checkpoint_hash
    }) {
        // Every input here is authenticated: the hash-linked EL ancestry and the own-L1 anchor.
        return Err(safety("inherited anchor checkpoint contradicts authenticated EL ancestry"));
    }
    // Complete the authenticated comparisons before polling the publisher for trailing data.
    if let Some(trailing) = blocks.next() {
        trailing?;
        return Err(candidate("successor block supplied beyond selected checkpoint"));
    }
    Ok(VerifiedImport {
        state,
        genesis: package.genesis.clone(),
        landing,
        block_id: Some(block_id),
        first_height: Some(first_height),
        execution_headers: retained,
        recovery_bootstrap: package.recovery_bootstrap.clone(),
    })
}

/// Read the selected landing under the own-finalized state root that authenticates the latest
/// one, never a publisher root.
async fn own_landing<L: L1Source + ?Sized>(
    l1: &L,
    params: &ChainParams,
    selected: u64,
    fixed: &abci::genesis::VerifiedGenesis,
    recovery_witness: Option<Bytes>,
) -> Result<Landing, ImportError> {
    let finalized = l1.finalized_number().await.map_err(own_error)?;
    let header = abci::l1::source::header_at(l1, finalized).await.map_err(own_error)?;
    own_canonical(l1, &header).await?;
    let slots = crate::l1::snapshot_slots();
    let proof = l1.account_witness(params.inbox, &slots, finalized).await.map_err(own_error)?;
    if proof.address != params.inbox {
        return Err(safety("own L1 snapshot proof names wrong contract"));
    }
    let storage = verify_account_witness(header.state_root(), &proof, &slots).map_err(safety)?;
    let height = word_u48(
        storage.get(inbox::slot(inbox::LAST_CHECKPOINT_HEIGHT)).expect("verified slot"),
        0,
    );
    let proof = l1
        .account_witness(params.inbox, &crate::l1::snapshot_landing_slots(height), finalized)
        .await
        .map_err(own_error)?;
    let mut snapshot = crate::l1::decode_snapshot(
        header.clone(),
        proof,
        params.l1_chain_id,
        params.l2_chain_id,
        params,
    )
    .map_err(safety)?;
    if snapshot.generation != fixed.recovery.as_ref().map_or(0, |r| r.generation) ||
        snapshot.genesis != fixed.genesis
    {
        return Err(candidate("original genesis is not the current finalized generation"));
    }
    snapshot.recovery = fixed.recovery.clone();
    snapshot.recovery_witness = recovery_witness;
    crate::l1::authenticate_snapshot(&snapshot, params).map_err(safety)?;
    let landing = read_landing(l1, params.inbox, &header, selected).await?;
    let origin = fixed.origin_height();
    validate_selected_landing(&landing, snapshot.generation, origin, snapshot.checkpoint_height)?;
    if selected > origin && selected < snapshot.checkpoint_height {
        verify_settled_suffix(l1, &snapshot, &landing, origin).await?;
    }
    own_canonical(l1, &header).await?;
    Ok(landing)
}

/// Authenticate all four words of an individual landing against the same pinned finalized root.
async fn read_landing<L: L1Source + ?Sized>(
    l1: &L,
    inbox_address: alloy_primitives::Address,
    header: &abci::RawL1Header,
    selected: u64,
) -> Result<Landing, ImportError> {
    let slots = inbox::landing_slots(selected);
    let proof =
        l1.account_witness(inbox_address, &slots, header.number()).await.map_err(own_error)?;
    if proof.address != inbox_address {
        return Err(safety("own L1 selected landing proof names wrong contract"));
    }
    let storage = verify_account_witness(header.state_root(), &proof, &slots).map_err(safety)?;
    let packed = storage.get(slots[0]).expect("verified slot");
    if packed >> 144 != U256::ZERO {
        return Err(safety("retained landing sets reserved bits"));
    }
    let landing = Landing {
        height: selected,
        parent_height: word_u48(packed, 0),
        generation: word_u48(packed, 48),
        forced_cursor: word_u48(packed, 96),
        el_hash: storage.get(slots[1]).expect("verified slot").into(),
        comet_hash: storage.get(slots[2]).expect("verified slot").into(),
        val_state_hash: storage.get(slots[3]).expect("verified slot").into(),
    };
    Ok(landing)
}

/// Same-generation verifier rollback increments recoveryNonce but can strand old slot-285 leaves.
/// Walk only the settled L1 suffix from the authenticated current frontier to the chosen height.
/// Never fetch a consensus block, an L1 landing preceding s, or any record at a different root.
async fn verify_settled_suffix<L: L1Source + ?Sized>(
    l1: &L,
    snapshot: &crate::LandingSnapshot,
    selected: &Landing,
    origin: u64,
) -> Result<(), ImportError> {
    let slot = inbox::landing_slots(snapshot.checkpoint_height)[0];
    let packed = snapshot
        .inbox_witness
        .storage
        .iter()
        .find(|p| p.slot == slot)
        .expect("authenticated latest landing")
        .value;
    let mut child = snapshot.checkpoint_height;
    let mut parent = word_u48(packed, 0);
    loop {
        if parent >= child || parent < origin || !parent.is_multiple_of(abci::GRID_INTERVAL) {
            return Err(safety("own finalized landing has an invalid parent-height link"));
        }
        match parent.cmp(&selected.height) {
            std::cmp::Ordering::Equal => return Ok(()),
            std::cmp::Ordering::Less => {
                return Err(candidate("checkpoint is not on the selected settled history"))
            }
            std::cmp::Ordering::Greater => {}
        }
        tokio::task::yield_now().await;
        let record = read_landing(l1, snapshot.inbox, &snapshot.l1_header, parent).await?;
        validate_selected_landing(&record, snapshot.generation, origin, snapshot.checkpoint_height)
            .map_err(|_| {
                safety(
                    "own finalized landing chain points to a missing or inconsistent predecessor",
                )
            })?;
        child = parent;
        parent = record.parent_height;
    }
}

/// Publisher header canonicality is checked against own finalized L1 before using its root.
async fn canonical<L: L1Source + ?Sized>(
    l1: &L,
    header: &abci::RawL1Header,
) -> Result<(), ImportError> {
    match own_finality(l1, header.number(), header.hash()).await.map_err(own_error)? {
        OwnFinality::Canonical => Ok(()),
        OwnFinality::NotFinal { .. } => Err(unavailable("required L1 header is not finalized")),
        OwnFinality::OffChain { .. } => Err(candidate("publisher L1 header is not canonical")),
    }
}

/// Decode canonical original protobuf without normalizing away evidence or native key bytes.
fn decode_frame(
    frame: &WindowBlock,
    preceding_commit: Option<&Bytes>,
) -> Result<(CertifiedBlock, bool), ImportError> {
    let raw = RawBlock::decode(frame.block.as_ref()).map_err(candidate)?;
    let commit = RawCommit::decode(frame.commit.as_ref()).map_err(candidate)?;
    if raw.encode_to_vec() != frame.block || commit.encode_to_vec() != frame.commit {
        return Err(candidate("noncanonical native protobuf"));
    }
    let same_commit = preceding_commit.is_none_or(|previous| {
        raw.last_commit
            .as_ref()
            .is_some_and(|last| last.encode_to_vec().as_slice() == previous.as_ref())
    });
    let pair = CertifiedBlock::from_raw(raw, Commit::try_from(commit).map_err(candidate)?)
        .map_err(candidate)?;
    Ok((pair, same_commit))
}

/// Minimal retained predecessor for authenticating the successor's actual embedded certificate.
struct PreviousHeight {
    /// Signed native header at the preceding retained height.
    header: tendermint::block::Header,
    /// Exact hash/part-set commitment calculated from original block bytes.
    id: tendermint::block::Id,
    /// Keys and powers that verified the preceding height's own certificate.
    validators: Validators,
    /// Original canonical protobuf; stock C:h must reproduce these exact bytes.
    commit: Bytes,
}

/// Historical sets are authenticated by the native header, not a claimed committee record.
fn historical_set(entries: &[ImportValidator]) -> Result<Validators, ImportError> {
    let mut addresses = std::collections::BTreeSet::new();
    let mut total = 0u64;
    if entries.is_empty() {
        return Err(candidate("empty native validator set"));
    }
    for entry in entries {
        if entry.power == 0 || !addresses.insert(entry.key.address()) {
            return Err(candidate("invalid or duplicate historical validator"));
        }
        total = total
            .checked_add(entry.power)
            .filter(|p| *p <= abci::committee::MAX_TOTAL_POWER)
            .ok_or_else(|| candidate("historical voting power exceeds stock bound"))?;
    }
    Validators::from_members(
        &entries
            .iter()
            .map(|v| Member { pubkey: v.key, eff_stake: U256::ZERO, power: v.power })
            .collect::<Vec<_>>(),
    )
    .map_err(candidate)
}

/// Header-only framing never requires w's block, certificate, evidence or validator set.
fn verify_boundary(
    boundary: Option<&tendermint::block::Header>,
    first: &CertifiedBlock,
    w: u64,
    origin: u64,
) -> Result<(), ImportError> {
    match (boundary, w == origin) {
        (None, true) => Ok(()),
        (Some(header), false)
            if header.height.value() == w &&
                header.chain_id == first.block.header.chain_id &&
                first.block.header.last_block_id.is_some_and(|id| id.hash == header.hash()) &&
                header.time < first.block.header.time =>
        {
            Ok(())
        }
        (None, false) => Err(unavailable("missing authenticated predecessor header at w")),
        _ => Err(candidate("invalid or unexpected predecessor header")),
    }
}

/// Signing epochs at s+1 and s+2, retaining duplicates for direct preimage-set comparison.
fn future_epochs(schedule: &Schedule, origin: u64, height: u64) -> Result<[u64; 2], ImportError> {
    let get = |delta| {
        height
            .checked_add(delta)
            .and_then(|h| schedule.active_committee_epoch(h, origin))
            .ok_or_else(|| candidate("future committee height overflow"))
    };
    Ok([get(1)?, get(2)?])
}

/// Authenticate the exact ascending EL prefix, terminating at w and linked later by w+1.
fn execution_prefix(
    package: &ImportPackage,
    w: u64,
    height: u64,
    params: &ChainParams,
) -> Result<Vec<Header>, ImportError> {
    let origin = package.origin_header.number;
    let first = header_floor(origin, height, params.unsettled_limit).min(w);
    let mut headers = package.execution_headers.clone();
    if headers.is_empty() && first == origin && w == origin {
        headers.push(package.origin_header.clone());
    }
    if headers.len() as u64 != w - first + 1 ||
        headers.first().is_none_or(|h| h.number != first) ||
        headers.last().is_none_or(|h| h.number != w)
    {
        return Err(unavailable(format!("required execution prefix {first}..={w}")));
    }
    for header in &headers {
        crate::history::check_header_capacity(header).map_err(candidate)?;
    }
    for pair in headers.windows(2) {
        if pair[1].number != pair[0].number + 1 || pair[1].parent_hash != pair[0].hash_slow() {
            return Err(candidate("discontinuous execution prefix"));
        }
    }
    if let Some(header) = headers.iter().find(|h| h.number == origin) &&
        *header != package.origin_header
    {
        return Err(candidate("execution prefix contradicts fixed origin"));
    }
    Ok(headers)
}

/// Check a publisher's anchor choice against origin/parent context before it can select an L1
/// account lookup. Shapes requiring a carried witness never fall back to an own-node proof.
fn check_anchor_selection(
    env: &abci::EtnaEnvelope,
    parent: &Header,
    state: &AppState,
) -> Result<u64, ImportError> {
    // Only extraData's generation and anchor fields are deployment core (START-10.1-2a); the
    // fee-sharing byte is ruleset 0's and is checked after the ruleset refusal.
    let (_, generation, number) =
        rules::decode_extra_data(&env.block.header.extra_data).map_err(candidate)?;
    if generation != state.generation {
        return Err(candidate("execution generation differs from the current generation"));
    }
    let parent_number = if parent.number == state.origin_height() {
        state.anchor.number
    } else {
        rules::decode_extra_data(&parent.extra_data).map_err(candidate)?.2
    };
    let first = parent.number == state.origin_height();
    if env.anchor.is_some() != (first || number != parent_number) {
        return Err(candidate("anchor witness presence violates inheritance rules"));
    }
    rules::check_anchor_progress(parent_number, number, state.anchor_floor()).map_err(candidate)?;
    if env.anchor.as_ref().is_some_and(|w| w.l1_header.number() != number) {
        return Err(candidate("anchor witness and EL extraData differ"));
    }
    Ok(number)
}

/// Recover an inherited anchor from own L1 when its witness precedes the evidence suffix.
async fn envelope_anchor<L: L1Source + ?Sized>(
    env: &abci::EtnaEnvelope,
    number: u64,
    l1: &L,
    params: &ChainParams,
    cache: &mut BTreeMap<u64, AnchorState>,
) -> Result<AnchorState, ImportError> {
    if let Some(witness) = &env.anchor {
        canonical(l1, &witness.l1_header).await?;
        let anchor = verify_anchor_witness(witness, params.inbox).map_err(candidate)?;
        if anchor.number != number {
            return Err(candidate("anchor witness and EL extraData differ"));
        }
        cache.insert(number, anchor.clone());
        return Ok(anchor);
    }
    if let Some(anchor) = cache.get(&number) {
        return Ok(anchor.clone());
    }
    let l1_header = abci::l1::source::header_at(l1, number).await.map_err(own_error)?;
    own_canonical(l1, &l1_header).await?;
    let inbox = l1
        .account_witness(params.inbox, &inbox::anchor_slots(), number)
        .await
        .map_err(own_error)?;
    let anchor =
        verify_anchor_witness(&AnchorWitness { l1_header, inbox }, params.inbox).map_err(safety)?;
    cache.insert(number, anchor.clone());
    Ok(anchor)
}

/// Non-execution checks used to reconstruct inherited generation, rules, anchor and parent data.
struct MetadataContext<'a> {
    /// Hash-linked preceding execution header.
    parent: &'a Header,
    /// Own-L1 authenticated anchor selected by this block.
    anchor: &'a AnchorState,
    /// Prior retained block's inherited anchor, when available.
    previous_anchor: Option<&'a AnchorState>,
    /// Immutable deployment and generation facts; no pre-s execution state is consumed.
    state: &'a AppState,
    /// Authenticated chain rules including the U ancestry fence.
    params: &'a ChainParams,
    /// Canonical native consensus time, preserving nanoseconds until flooring by the EL rule.
    bft_time: tendermint::Time,
}

/// Check timestamp, fixed rules and inherited metadata without executing transactions or FI.
fn check_metadata(
    env: &abci::EtnaEnvelope,
    context: MetadataContext<'_>,
) -> Result<(), ContentFault> {
    let MetadataContext { parent, anchor, previous_anchor, state, params, bft_time } = context;
    let height = env.block.header.number;
    let bft_secs = u64::try_from(bft_time.unix_timestamp()).map_err(candidate)?;
    if env.block.header.timestamp !=
        rules::block_timestamp(parent.timestamp, bft_secs, anchor.timestamp)
    {
        return Err(candidate(
            "execution timestamp differs from authenticated consensus/anchor rule",
        )
        .into());
    }
    let number = anchor.number;
    if anchor.inbox.recovery_generation != state.generation ||
        env.block.header.parent_beacon_block_root != Some(anchor.state_root)
    {
        return Err(candidate("execution generation/anchor fields mismatch").into());
    }
    if previous_anchor.is_some_and(|a| a.number == number && a != anchor) {
        return Err(candidate("same inherited anchor has inconsistent facts").into());
    }
    rules::check_checkpoint_height(parent.number, anchor.inbox.last_checkpoint_height)
        .map_err(candidate)?;
    rules::check_back_pressure(height, anchor.inbox.last_checkpoint_height, params.unsettled_cap())
        .map_err(candidate)?;
    rules::check_rules_schedule(
        anchor.inbox.rules_schedule,
        &parent_info(parent, 0)?,
        env.block.header.timestamp,
        state.genesis.genesis_height,
    )
    .map_err(|e| match e {
        // As in FinalizeBlock, a ruleset this software lacks needs an upgrade, not a new source.
        rules::RuleViolation::UnsupportedRuleset { .. } => ContentFault::Unsupported(e.to_string()),
        _ => ContentFault::Rule(e.to_string()),
    })?;
    // The checks above are deployment core (START-10.1-2a). The fixed EL header fields and the
    // fee-sharing byte (CONS-3.2-5) are ruleset 0's and a later ruleset may change them, so
    // check them after its refusal, as the live path's expected-header check does.
    rules::check_fixed_fields(&env.block.header).map_err(candidate)?;
    if env.block.header.extra_data.first() != Some(&rules::BASEFEE_SHARING_PCTG) {
        return Err(candidate("execution base-fee sharing differs from ruleset 0").into());
    }
    rules::check_anchor_freshness(
        env.block.header.timestamp,
        anchor.timestamp,
        state.genesis.max_anchor_age,
    )
    .map_err(candidate)?;
    if state.schedule().switch_target(height).is_some() != env.committee.is_some() {
        return Err(candidate("committee witness presence violates switch schedule").into());
    }
    abci::app::check_execution_size(&env.block).map_err(candidate)?;
    Ok(())
}

/// Native keys/powers commitment of one landed full set.
fn set_hash(set: &abci::valstate::ValSet) -> Result<B256, ImportError> {
    abci::wire::validators_hash(
        &set.entries
            .iter()
            .map(|e| Member { pubkey: e.key, power: e.power as u64, eff_stake: U256::ZERO })
            .collect::<Vec<_>>(),
    )
    .map_err(safety)
}

/// Compare independent committees ignoring priority, which only the landed preimage authenticates.
fn same_powers(set: &abci::valstate::ValSet, committee: &CommitteeState) -> bool {
    set.entries.iter().map(|e| (e.key, e.power as u64)).collect::<BTreeMap<_, _>>() ==
        committee.members.iter().map(|m| (m.pubkey, m.power)).collect::<BTreeMap<_, _>>()
}

/// Contradictory replies obtained from the own source are safety failures, unlike a peer fork.
async fn own_canonical<L: L1Source + ?Sized>(
    l1: &L,
    header: &abci::RawL1Header,
) -> Result<(), ImportError> {
    match own_finality(l1, header.number(), header.hash()).await.map_err(own_error)? {
        OwnFinality::Canonical => Ok(()),
        OwnFinality::NotFinal { .. } => Err(unavailable("own L1 finalized observation receded")),
        OwnFinality::OffChain { .. } => {
            Err(safety("own L1 finalized header contradicts its canonical hash"))
        }
    }
}

/// Why window content was refused. Before the native hash chain links the block to s, a
/// publisher could have forged it, so a rule failure is classified only by [`confirm_landed`].
#[derive(Debug)]
enum ContentFault {
    /// A source, own-L1 or byte-authentication result that does not wait for the chain.
    Now(ImportError),
    /// The content breaks a fixed rule: a contradiction if landed, else a bad candidate.
    Rule(String),
    /// The content selects a ruleset this software lacks: the node must upgrade if landed.
    Unsupported(String),
}

/// Native header fields fixed for the whole generation (CONS-3.1-9, START-10-21): block protocol
/// 11, `APP_VERSION`, the chain id and the fixed consensus params. No ruleset changes them
/// (START-10.1-3d), so a landed header that breaks one is a contradiction.
fn fixed_header_fault(
    header: &tendermint::block::Header,
    chain_id: &str,
    params_hash: B256,
) -> Option<ContentFault> {
    (header.version.block != 11 ||
        header.version.app != abci::app::APP_VERSION ||
        header.chain_id.as_str() != chain_id ||
        header.consensus_hash.as_bytes() != params_hash.as_slice())
    .then(|| {
        ContentFault::Rule(
            "native block has different protocol, app version, chain id or consensus parameters"
                .into(),
        )
    })
}

/// Content checks report rule failures as candidate errors; those wait for the chain.
impl From<ImportError> for ContentFault {
    fn from(error: ImportError) -> Self {
        match error {
            ImportError::Candidate(detail) => Self::Rule(detail),
            other => Self::Now(other),
        }
    }
}

/// Split shared block validation into byte commitments, which only a bad publisher can fail,
/// and rules over the content those commitments authenticate.
fn body_fault(error: validate::ValidationError) -> ContentFault {
    match error {
        validate::ValidationError::Commitment(
            "genesis last commit" |
            "parent execution app hash" |
            "missing or conflicting previous block/commit",
        ) |
        validate::ValidationError::Etna(_) => ContentFault::Rule(error.to_string()),
        _ => ContentFault::Now(candidate(error)),
    }
}

/// Classify content refused at `height` by reading the remaining native headers. The content
/// is authenticated only if every later header links back to it and the header at s matches
/// the finalized landing; a broken link means the publisher forged it.
async fn confirm_landed(
    fault: ContentFault,
    mut height: u64,
    mut hash: tendermint::Hash,
    blocks: &mut impl Iterator<Item = Result<WindowBlock, ImportError>>,
    landing: &Landing,
    val_state: &ValState,
) -> ImportError {
    while height < landing.height {
        tokio::task::yield_now().await;
        let header = match blocks.next() {
            None => return unavailable("window ended before selected checkpoint"),
            Some(Err(error)) => return error,
            Some(Ok(frame)) => {
                if let Err(error) = check_header_projection(&frame.block, landing, val_state) {
                    return error;
                }
                match native_header(&frame.block) {
                    Ok(header) => header,
                    Err(error) => return error,
                }
            }
        };
        if header.height.value() != height + 1 ||
            header.last_block_id.map(|id| id.hash) != Some(hash)
        {
            return candidate("refused window block is not on the landed chain");
        }
        height += 1;
        hash = header.hash();
    }
    if hash.as_bytes() != landing.comet_hash.as_slice() {
        return candidate("refused window block is not on the landed chain");
    }
    match fault {
        ContentFault::Now(error) => error,
        ContentFault::Rule(detail) => safety(format!("landed window block breaks rules: {detail}")),
        ContentFault::Unsupported(detail) => unavailable(detail),
    }
}

/// Decode only the native header of an original block.
fn native_header(block: &Bytes) -> Result<tendermint::block::Header, ImportError> {
    HeaderProjection::decode(block.as_ref())
        .map_err(candidate)?
        .header
        .ok_or_else(|| candidate("missing native header"))?
        .try_into()
        .map_err(candidate)
}

/// Read the bounded header projection before ancillary certificate/validator decoding. Stock
/// evidence and embedded certificates are checked separately by ordinary native verification.
#[derive(prost::Message)]
struct HeaderProjection {
    /// Original native header whose canonical hash is authenticated by the finalized landing.
    #[prost(message, optional, tag = "1")]
    header: Option<tendermint_proto::v0_38::types::Header>,
}

/// Separate projection so nonterminal header inspection never copies transaction payloads.
#[derive(prost::Message)]
struct DataProjection {
    /// The original transaction array, including the exact envelope bytes.
    #[prost(message, optional, tag = "2")]
    data: Option<tendermint_proto::v0_38::types::Data>,
}

/// Compare terminal facts as soon as the bounded original block can authenticate them, before
/// decoding an unrelated item commit, applying an ancillary set-size limit or reading ahead.
fn check_header_projection(
    block: &Bytes,
    landing: &Landing,
    val_state: &ValState,
) -> Result<u64, ImportError> {
    if block.len() > 22_020_096 {
        return Err(candidate("native block exceeds consensus byte bound"));
    }
    let raw = HeaderProjection::decode(block.as_ref())
        .map_err(candidate)?
        .header
        .ok_or_else(|| candidate("missing native header"))?;
    let height = u64::try_from(raw.height).map_err(candidate)?;
    if height != landing.height {
        return Ok(height);
    }
    let header: tendermint::block::Header = raw.try_into().map_err(candidate)?;
    if B256::from_slice(header.hash().as_bytes()) != landing.comet_hash {
        return Err(candidate("terminal Comet hash differs from finalized landing"));
    }
    if header.next_validators_hash.as_bytes() != set_hash(&val_state.current)?.as_slice() {
        return Err(safety("landed future validators contradict terminal next_validators_hash"));
    }
    let txs = DataProjection::decode(block.as_ref())
        .map_err(candidate)?
        .data
        .ok_or_else(|| candidate("missing terminal original data"))?
        .txs;
    if header.data_hash != Some(validate::data_hash(&txs)) {
        return Err(candidate("terminal DataHash does not authenticate envelope"));
    }
    let transactions = txs.into_iter().map(Bytes::from).collect::<Vec<_>>();
    // The landing's Comet hash and DataHash fix these bytes, so no publisher can repair them.
    let envelope = abci::single_envelope(&transactions)
        .map_err(|e| safety(format!("authenticated terminal envelope is malformed: {e}")))?;
    if envelope.block.header.hash_slow() != landing.el_hash {
        return Err(safety("authenticated terminal envelope execution hash contradicts landing"));
    }
    Ok(height)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::test_utils::consensus_mpt::Fixture;

    #[test]
    fn boundary_header_is_bound_without_reading_its_block_commit_or_set() {
        let fx = Fixture::new(6, 6);
        let first = &fx.blocks[&2];
        let mut boundary = fx.blocks[&1].block.header.clone();
        verify_boundary(Some(&boundary), first, 1, 0).unwrap();
        assert!(matches!(verify_boundary(None, first, 1, 0), Err(ImportError::Unavailable(_))));
        boundary.time = tendermint::Time::from_unix_timestamp(1, 0).unwrap();
        assert!(matches!(
            verify_boundary(Some(&boundary), first, 1, 0),
            Err(ImportError::Candidate(_))
        ));
        assert!(verify_boundary(Some(&fx.blocks[&1].block.header), &fx.blocks[&1], 0, 0).is_err());
    }

    #[test]
    fn rules_boundary_is_selected_from_inherited_anchor_and_block_time() {
        let fx = Fixture::new(6, 6);
        let mut env = abci::EtnaEnvelope::decode(&fx.blocks[&6].block.data[0]).unwrap();
        let mut anchor = fx.anchors[&6].clone();
        let state = AppState {
            schema_version: abci::store::STATE_SCHEMA_VERSION,
            app_version: 1,
            chain_id: fx.blocks[&6].block.header.chain_id.to_string(),
            generation: 0,
            recovery: None,
            inbox: fx.params.inbox,
            genesis: fx.snapshot.genesis.clone(),
            last_height: 5,
            last_comet_hash: B256::ZERO,
            parent: parent_info(&fx.headers[&5], fx.headers[&4].timestamp).unwrap(),
            anchor: fx.anchors[&5].clone(),
            forced_cursor: 0,
            committees: BTreeMap::new(),
            val_state: fx.val_states[&5].clone(),
            execution_floor: None,
        };
        let check = |env: &abci::EtnaEnvelope, anchor: &AnchorState| {
            check_metadata(
                env,
                MetadataContext {
                    parent: &fx.headers[&5],
                    anchor,
                    previous_anchor: None,
                    state: &state,
                    params: &fx.params,
                    bft_time: fx.blocks[&6].block.header.time,
                },
            )
        };
        anchor.inbox.rules_schedule =
            (U256::from(1) << 48) | (U256::from(env.block.header.timestamp + 1) << 96);
        check(&env, &anchor).unwrap();
        let unsupported = (U256::from(1) << 48) | (U256::from(env.block.header.timestamp) << 96);
        anchor.inbox.rules_schedule = unsupported;
        assert!(
            matches!(check(&env, &anchor), Err(ContentFault::Unsupported(ref message)) if message.contains("ruleset"))
        );
        // A later ruleset may allow a nonzero nonce: refuse the ruleset before ruleset 0's
        // fixed fields, or a landed block under it would safety-halt this node for good.
        env.block.header.nonce = alloy_primitives::B64::from(1u64);
        assert!(
            matches!(check(&env, &anchor), Err(ContentFault::Unsupported(ref message)) if message.contains("ruleset"))
        );
        anchor.inbox.rules_schedule = U256::ZERO;
        assert!(
            matches!(check(&env, &anchor), Err(ContentFault::Rule(ref message)) if message.contains("nonce"))
        );
        // Likewise extraData's fee-sharing byte: anchor selection reads only the deployment-core
        // generation and anchor fields, and ruleset 0's 100 is checked after the refusal.
        env.block.header.nonce = alloy_primitives::B64::ZERO;
        let mut extra = env.block.header.extra_data.to_vec();
        extra[0] = 50;
        env.block.header.extra_data = extra.into();
        assert_eq!(
            check_anchor_selection(&env, &fx.headers[&5], &state).unwrap(),
            fx.anchors[&6].number
        );
        anchor.inbox.rules_schedule = unsupported;
        assert!(
            matches!(check(&env, &anchor), Err(ContentFault::Unsupported(ref message)) if message.contains("ruleset"))
        );
        anchor.inbox.rules_schedule = U256::ZERO;
        assert!(
            matches!(check(&env, &anchor), Err(ContentFault::Rule(ref message)) if message.contains("sharing"))
        );
    }

    #[test]
    fn fixed_consensus_hash_matches_stock_v040_oracle() {
        // go run of stock ConsensusParams.Hash with Etna max_bytes=22020096/max_gas=-1.
        assert_eq!(
            abci::genesis::GenesisConsensusParams::etna_hash(),
            alloy_primitives::b256!(
                "048091bc7ddc283f77bfbf91d73c44da58c3df8a9cbc867405d8b7f3daada22f"
            )
        );
    }
}
