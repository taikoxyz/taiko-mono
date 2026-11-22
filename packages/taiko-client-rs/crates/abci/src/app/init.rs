//! `InitChain`: authenticate deployment or recovery bootstrap against own L1 and the EL,
//! then persist the initial [`AppState`].

use crate::wire::{request, response};

use alloy_consensus::Header;

use super::{
    AbciError, App, ErrorClass, app_hash, at_generation_origin, classify, contradiction_halt,
    finalize::Backoff, within,
};
use crate::{
    ChainParams,
    engine::Engine,
    fallback::FallbackKeys,
    genesis::{
        BootstrapWitness, GenesisConsensusParams, GenesisError, GenesisExpectation,
        decode_bootstrap_state, named_fallback_keys, verify_bootstrap,
    },
    key::ConsensusKey,
    l1::{L1Source, OwnFinality, ReadBounded, own_finality},
    recovery::{RecoveryBootstrap, RecoveryWitness, VerifiedBootstrap, recovery_parent},
    rules::RuleViolation,
    store::AppState,
    types::{GenesisRecord, ParentInfo},
};

impl<L: L1Source, E: Engine> App<L, E> {
    /// Handles `InitChain`: verifies the genesis and persists the initial state.
    ///
    /// CometBFT re-sends `InitChain` whenever the app reports height 0, i.e. after a restart
    /// before the first PoS block is committed. An app already holding a state answers only
    /// while that state is still at its generation origin (the Etna start S or c): the request is
    /// verified again and must yield exactly the stored state, which is then answered as before
    /// without being rewritten. Either way the origin's validator state is recorded first
    /// ([`Store::save_val_state`](crate::store::Store::save_val_state); a well-formed record of
    /// another state fails). A state past its origin, or a request yielding another state, is
    /// [`AbciError::AlreadyInitialized`]. Temporary L1/EL acquisition failures keep the same
    /// request pending; authenticated contradictions still fail for safety.
    ///
    /// See [`App::verify_genesis`] for the checks; as they make sure the EL serves the origin
    /// block (the Etna start block or c), a successful `InitChain` also counts as the EL reconcile
    /// of the current set of ABCI connections (see [`App::info`]). Answers with appHash(o)
    /// (CONS-3.1-8, ENC-A-29b.e) of the authenticated origin EL hash, the start hash or
    /// ELHash(c), and the generation's genesis validator state at o: the same on every re-sent
    /// `InitChain`, even when the EL already holds the generation's first block after a crash
    /// before its `Commit` (CONS-3.1-9).
    pub(super) async fn init_chain(
        &mut self,
        req: request::InitChain,
    ) -> Result<response::InitChain, AbciError> {
        let restart = match &self.state {
            None => false,
            Some(state) if at_generation_origin(state) => true,
            Some(_) => return Err(AbciError::AlreadyInitialized),
        };
        let epoch = self.connections.current();
        let origin = req.initial_height.value().saturating_sub(1);
        let mut backoff = Backoff::startup("InitChain", origin);
        let state = loop {
            match self.verify_genesis(&req).await {
                Ok(state) => break state,
                Err(error) => {
                    self.await_startup_input(&mut backoff, "genesis verification", error).await?
                }
            }
        };
        let origin_hash = state.parent.hash;
        let answer = app_hash(&state);
        if restart && self.state.as_ref() != Some(&state) {
            return Err(AbciError::AlreadyInitialized);
        }
        // The origin's genesis validator state, recorded before the state and again (unchanged,
        // or where a store imported at the origin lacks it) on a re-sent InitChain: the exact
        // state later records are recomputed from (SYNC-9-5c).
        self.store.save_val_state(&state.val_state)?;
        if restart {
            tracing::info!(chain_id = %state.chain_id, "InitChain re-sent at genesis; re-verified");
        } else {
            self.store.save(&state)?;
            tracing::info!(
                chain_id = %state.chain_id,
                genesis_height = state.genesis.genesis_height,
                origin_hash = %origin_hash,
                l1_0 = state.genesis.l1_0,
                validators = req.validators.len(),
                "chain initialized"
            );
            self.state = Some(state);
            self.publish_state_metrics();
        }
        self.el_reconciled_epoch = Some(epoch);
        self.trust.committed(self.state.as_ref().expect("initialized state"));

        Ok(response::InitChain { consensus_params: None, validators: vec![], app_hash: answer })
    }

    /// Verifies an `InitChain` request and returns the state it starts.
    ///
    /// In order: decodes the `app_state` witness; takes the fallback key list the request's
    /// validators name ([`named_fallback_keys`]) and verifies the evidence once with it
    /// ([`verify_bootstrap`]: generation zero's Inbox witness at `L1_0`, whose origin record's
    /// fourth word must be the list's hash; or a recovery's fixed origin, R's observation and the
    /// deployment context, embedding R as the finalized observation, whose origin record must
    /// hold the list's hash); requires the request's time, canonical consensus parameters,
    /// `chain_id`, initial height and validators, each key of the origin list exactly once at
    /// power 1, to be exactly the ones that evidence determines ([`check_request`]); then acquires
    /// the inputs the evidence leaves to the own L1 and EL. At generation zero: the `L1_0` header
    /// must be final and canonical in the own L1 view, and the EL must serve the Etna start block
    /// with the start hash and the start state root (EL sync if needed). For a recovery, the
    /// inputs come from [`App::recovery_inputs`], retried here while unavailable, and include the
    /// origin fallback key list obtained from the own L1, which the request's validators must
    /// name exactly ([`check_fallback_validators`]). The state is
    /// [`VerifiedGenesis::origin_state`](crate::genesis::VerifiedGenesis::origin_state), as for
    /// an import at the origin: `last = (S, start hash)` with the `L1_0` anchor, or c with its
    /// historical anchor; the origin's forced inclusion cursor; CometBFT's genesis validator
    /// state of the origin keys at the origin height; and the origin key list. A recovery's
    /// immutable bootstrap sidecar is durable before this returns, so before the state is
    /// published.
    async fn verify_genesis(&self, req: &request::InitChain) -> Result<AppState, AbciError> {
        let witness = decode_bootstrap_state(&req.app_state_bytes)?;
        let keys =
            named_fallback_keys(req.validators.iter().map(|v| v.pub_key)).ok_or_else(|| {
                AbciError::GenesisValidatorsMismatch(
                    "the validators are not a fallback key list: none, more than 128, or a key \
                 listed twice"
                        .into(),
                )
            })?;
        let (verified, expected) =
            verify_bootstrap(&witness, &self.params, keys).map_err(|error| match error {
                GenesisError::FallbackKeysMismatch { got, expected } => {
                    AbciError::GenesisValidatorsMismatch(format!(
                        "the validators' fallback key list {got} is not the origin record's \
                         {expected}"
                    ))
                }
                error => error.into(),
            })?;
        check_request(req, &expected, &self.params)?;
        let chain_id = req.chain_id.clone();
        let BootstrapWitness::Recovery(w) = &witness else {
            for header in &verified.l1_headers {
                let (number, hash) = (header.number(), header.hash());
                match within(
                    "L1 finality check of the genesis header",
                    self.opts.l1_timeout,
                    own_finality(self.l1(), number, hash),
                )
                .await?
                {
                    OwnFinality::Canonical => {}
                    OwnFinality::NotFinal { .. } => {
                        return Err(AbciError::GenesisNotFinal { number, hash });
                    }
                    OwnFinality::OffChain { .. } => {
                        return Err(AbciError::SafetyHalt(
                            "genesis header differs from own finalized L1".into(),
                        ));
                    }
                }
            }
            let parent = self.genesis_parent(&verified.genesis).await?;
            return verified
                .origin_state(chain_id, parent, verified.anchor.clone())
                .map_err(not_a_validator_set);
        };
        let mut backoff = Backoff::startup("recovery InitChain", verified.origin_height());
        let (bootstrap, history) = loop {
            match self.recovery_inputs(w).await {
                Ok(inputs) => break inputs,
                // The guarded signer owns the session. A successful stock InitChain replay must
                // not rotate it, while unavailable inputs immediately close readiness.
                Err(error) => {
                    self.await_startup_input(&mut backoff, "recovery history acquisition", error)
                        .await?
                }
            }
        };
        check_fallback_validators(&req.validators, &history.fallback_keys)?;
        let state = verified
            .origin_state(chain_id, recovery_parent(w), history.anchor)
            .map_err(not_a_validator_set)?;
        self.store.save_recovery_bootstrap(&bootstrap)?;
        Ok(state)
    }

    /// Handles `error` of one startup acquisition (`InitChain`) or EL reconciliation (the first
    /// `Info`) attempt by its [`classify`] class (SYNC-9-7): missing data closes readiness with
    /// the error as the reason and waits out `backoff` before the caller retries the same
    /// request; a contradiction is a safety halt ([`contradiction_halt`]); any other error fails
    /// the request as it is.
    pub(super) async fn await_startup_input(
        &self,
        backoff: &mut Backoff,
        method: &'static str,
        error: AbciError,
    ) -> Result<(), AbciError> {
        match classify(&error) {
            ErrorClass::MissingData => {
                let reason = error.to_string();
                self.trust.await_authentication(reason.clone());
                backoff.wait(method, &reason).await;
                Ok(())
            }
            ErrorClass::Contradiction => Err(contradiction_halt(error)),
            ErrorClass::Other => Err(error),
        }
    }

    /// One recovery acquisition attempt, every L1 step bounded; unavailable history is retried
    /// by InitChain.
    ///
    /// Reauthenticates the retained headers, the current generation and the fixed origin in
    /// the own finalized L1 view ([`check_recovery_canonicality`]); takes the historical anchor
    /// and the origin fallback key list from the immutable sidecar a previous attempt stored
    /// (which must retain `w` exactly, with its anchor still final and canonical, and the list
    /// whose hash the origin record holds) or fetches both from the own L1: the anchor
    /// ([`historical_anchor`]) within one deadline, the list ([`origin_fallback_keys`]) with a
    /// deadline on each of its reads, as its log scan can take many; then points the EL at c's
    /// authenticated hash ([`App::sync_el_to`]) and requires it to serve c and its parent
    /// exactly as `w` authenticates them, and c's state. Returns the sidecar to store and what
    /// its verification authenticates.
    ///
    /// [`check_recovery_canonicality`]: crate::recovery::check_recovery_canonicality
    /// [`historical_anchor`]: crate::recovery::historical_anchor
    /// [`origin_fallback_keys`]: crate::recovery::origin_fallback_keys
    async fn recovery_inputs(
        &self,
        w: &RecoveryWitness,
    ) -> Result<(RecoveryBootstrap, VerifiedBootstrap), AbciError> {
        within(
            "recovery own-L1 authentication",
            self.opts.l1_timeout,
            crate::recovery::check_recovery_canonicality(self.l1(), &self.params, w),
        )
        .await?;
        let (bootstrap, history) = match self.store.load_recovery_bootstrap()? {
            Some(bootstrap) => {
                let history = bootstrap.verify(&self.params)?;
                if history.witness != *w {
                    return Err(AbciError::SafetyHalt(
                        "recovery request differs from immutable bootstrap".into(),
                    ));
                }
                let anchor = &history.anchor;
                match within(
                    "recovery historical finality",
                    self.opts.l1_timeout,
                    own_finality(self.l1(), anchor.number, anchor.hash),
                )
                .await?
                {
                    OwnFinality::Canonical => {}
                    OwnFinality::NotFinal { .. } => {
                        return Err(crate::RecoveryError::Unavailable(
                            "historical recovery anchor is not final".into(),
                        )
                        .into());
                    }
                    OwnFinality::OffChain { .. } => {
                        return Err(AbciError::SafetyHalt(
                            "historical recovery anchor changed".into(),
                        ));
                    }
                }
                (bootstrap, history)
            }
            None => {
                let anchor = within(
                    "recovery historical anchor",
                    self.opts.l1_timeout,
                    crate::recovery::historical_anchor(self.l1(), &self.params, w),
                )
                .await?;
                // A list stored long before R may come only from many log queries: each L1 read
                // has its own deadline and the acquisition none, so a deep scan completes. A
                // read that times out or fails is missing data, retried by InitChain.
                let l1 = ReadBounded { l1: self.l1.clone(), limit: self.opts.l1_timeout };
                let keys = crate::recovery::origin_fallback_keys(&l1, &self.params, w).await?;
                crate::recovery::bootstrap_from(&self.params, w, anchor, keys)?
            }
        };
        // An EL holding another block at c, or none, takes the settled block there in place of
        // its own (RECOV-8.1-7): point it at c's authenticated hash, as at the Etna start. Until
        // it serves that block and its authenticated parent, c is missing data (SYNC-9-7). An EL
        // that rejects that hash, or accepts it and keeps serving another block, contradicts it.
        let (number, hash) = (w.el_header.number, w.el_header.hash_slow());
        self.sync_el_to("EL sync to the recovery origin", number, hash).await?;
        if let Some(parent) = w.parent_headers.first() &&
            self.el_header(parent.number).await? != *parent
        {
            return Err(crate::RecoveryError::Unavailable(format!(
                "execution engine does not serve the authenticated parent of recovery origin \
                 {number}"
            ))
            .into());
        }
        // The first recovered block executes on c's state. An EL that pruned it after
        // `prepare`, or was replaced since, is missing data: InitChain waits with trust closed
        // instead of reporting Ready and halting on that first execution (SYNC-9-7).
        let state = self.engine.historical_state_available(hash);
        if !within("EL recovery origin state read", self.opts.engine_timeout, state).await? {
            return Err(crate::RecoveryError::Unavailable(format!(
                "execution engine lacks the state of recovery origin {number}"
            ))
            .into());
        }
        Ok((bootstrap, history))
    }

    /// Makes sure the EL serves the Etna start block with the start hash (syncing it over devp2p
    /// if needed) and summarizes it as the parent of `H_0`.
    ///
    /// An EL that rejects the start hash, serves another block at the start height or returns a
    /// state root differing from the authenticated start state root contradicts
    /// the verified genesis: [`AbciError::SafetyHalt`].
    async fn genesis_parent(&self, genesis: &GenesisRecord) -> Result<ParentInfo, AbciError> {
        let (number, hash) = (genesis.genesis_height, genesis.genesis_hash);
        self.sync_el_to("EL sync to the Etna start block", number, hash).await?;

        let header = self.el_header(number).await?;
        let found = header.hash_slow();
        if found != hash {
            return Err(AbciError::SafetyHalt(format!(
                "execution engine serves {found} at the Etna start {number}, expected hash {hash}"
            )));
        }
        if header.state_root != genesis.genesis_state_root {
            return Err(AbciError::SafetyHalt(format!(
                "execution engine's Etna start state root {} differs from the authenticated start state root {}",
                header.state_root, genesis.genesis_state_root
            )));
        }

        self.check_switch_header(genesis, &header)?;
        let grandparent_timestamp = if let Some(parent_number) = number.checked_sub(1) {
            let parent = self.el_header(parent_number).await?;
            if parent.hash_slow() != header.parent_hash || parent.timestamp >= header.timestamp {
                return Err(AbciError::SafetyHalt(
                    "Etna start has inconsistent own-EL parent".into(),
                ));
            }
            parent.timestamp
        } else {
            0
        };
        Ok(ParentInfo {
            number,
            hash,
            timestamp: header.timestamp,
            gas_limit: header.gas_limit,
            gas_used: header.gas_used,
            base_fee: header.base_fee_per_gas.unwrap_or(0),
            difficulty: header.difficulty,
            grandparent_timestamp,
        })
    }

    /// The EL's canonical header at `number`; a missing block is [`AbciError::ElBlockMissing`].
    async fn el_header(&self, number: u64) -> Result<Header, AbciError> {
        within("EL header read", self.opts.engine_timeout, self.engine.header_by_number(number))
            .await?
            .ok_or(AbciError::ElBlockMissing(number))
    }
}

/// Requires the request's representable fields to be exactly the ones its bootstrap evidence
/// and origin fallback key list determine, in this order: the genesis time, the canonical
/// consensus parameters, the `chain_id`, the initial height and the validators, the list's keys
/// each at power 1 ([`check_validators`]).
fn check_request(
    req: &request::InitChain,
    expected: &GenesisExpectation,
    params: &ChainParams,
) -> Result<(), AbciError> {
    let l2_chain_id = params.l2_chain_id;
    if req.time != expected.genesis_time {
        return Err(AbciError::GenesisTimeMismatch {
            got: req.time,
            expected: expected.genesis_time,
        });
    }
    if req.consensus_params != GenesisConsensusParams::abci() {
        return Err(AbciError::GenesisConsensusParamsMismatch);
    }
    if req.chain_id != expected.chain_id {
        return Err(
            RuleViolation::InvalidChainId { chain_id: req.chain_id.clone(), l2_chain_id }.into()
        );
    }
    let initial_height = req.initial_height.value();
    if initial_height != expected.initial_height {
        return Err(AbciError::InitialHeight {
            got: initial_height,
            expected: expected.initial_height,
        });
    }
    check_validators(&req.validators, &expected.validators)
}

/// Requires the genesis validators to be exactly `expected`: the same native secp256k1eth keys
/// with the same powers, in any order, without duplicates.
fn check_validators(
    validators: &[crate::wire::ValidatorUpdate],
    expected: &[(ConsensusKey, u64)],
) -> Result<(), AbciError> {
    let mismatch = AbciError::GenesisValidatorsMismatch;
    let mut genesis = std::collections::BTreeMap::new();
    for v in validators {
        let pubkey = v.pub_key;
        if genesis.insert(pubkey, v.power.value()).is_some() {
            return Err(mismatch(format!("validator {pubkey} is listed twice")));
        }
    }
    for (key, expected) in expected {
        match genesis.remove(key) {
            Some(power) if power == *expected => {}
            Some(power) => {
                return Err(mismatch(format!(
                    "validator {key} has power {power}, the origin fallback key list gives \
                     {expected}"
                )));
            }
            None => return Err(mismatch(format!("origin fallback key {key} is missing"))),
        }
    }
    match genesis.keys().next() {
        Some(extra) => {
            Err(mismatch(format!("validator {extra} is not in the origin fallback key list")))
        }
        None => Ok(()),
    }
}

/// Requires a recovery generation's genesis validators to be exactly the fallback key list
/// `keys` whose hash its origin record holds: every validator at voting power 1, no key listed
/// twice, and their keys, in ascending order, the list's keys.
pub(crate) fn check_fallback_validators(
    validators: &[crate::wire::ValidatorUpdate],
    keys: &FallbackKeys,
) -> Result<(), AbciError> {
    let mismatch = AbciError::GenesisValidatorsMismatch;
    let mut listed = Vec::with_capacity(validators.len());
    for v in validators {
        if v.power.value() != 1 {
            return Err(mismatch(format!(
                "validator {} has power {}, a fallback key has power 1",
                v.pub_key,
                v.power.value()
            )));
        }
        listed.push(v.pub_key);
    }
    listed.sort();
    if let Some(pair) = listed.windows(2).find(|pair| pair[0] == pair[1]) {
        return Err(mismatch(format!("validator {} is listed twice", pair[0])));
    }
    if let Some(missing) = keys.keys().iter().find(|key| listed.binary_search(key).is_err()) {
        return Err(mismatch(format!(
            "fallback key {missing} of the origin list {} is missing",
            keys.hash()
        )));
    }
    if let Some(extra) = listed.iter().find(|key| keys.keys().binary_search(key).is_err()) {
        return Err(mismatch(format!(
            "validator {extra} is not in the origin fallback key list {}",
            keys.hash()
        )));
    }
    Ok(())
}

/// The error of an initial set that is not a CometBFT validator set: CometBFT refuses a genesis
/// set it cannot build, so neither can the app. Any other error keeps its own class.
fn not_a_validator_set(error: GenesisError) -> AbciError {
    match error {
        GenesisError::ValidatorSet(error) => {
            AbciError::GenesisValidatorsMismatch(format!("not a CometBFT validator set: {error}"))
        }
        other => other.into(),
    }
}
