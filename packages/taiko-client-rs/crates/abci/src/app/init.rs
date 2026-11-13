//! `InitChain`: authenticate deployment or recovery bootstrap against own L1 and the EL,
//! then persist the initial [`AppState`].

use crate::wire::{request, response};
use std::collections::BTreeMap;

use alloy_consensus::Header;

use super::{
    AbciError, App, ErrorClass, app_hash, at_generation_origin, classify, contradiction_halt,
    finalize::Backoff, within,
};
use crate::{
    engine::Engine,
    genesis::{
        BootstrapWitness, GenesisConsensusParams, GenesisExpectation, decode_bootstrap_state,
        verify_bootstrap,
    },
    l1::{L1Source, OwnFinality, own_finality},
    recovery::{RecoveryBootstrap, RecoveryWitness, VerifiedBootstrap, recovery_parent},
    rules::RuleViolation,
    store::AppState,
    types::{GenesisRecord, Member, ParentInfo},
    valstate::ValStateError,
};

impl<L: L1Source, E: Engine> App<L, E> {
    /// Handles `InitChain`: verifies the genesis and persists the initial state.
    ///
    /// CometBFT re-sends `InitChain` whenever the app reports height 0, i.e. after a restart
    /// before the first PoS block is committed. An app already holding a state answers only
    /// while that state is still at its generation origin (B* or c): the request is verified again
    /// and must yield exactly the stored state, which is then answered as before without being
    /// rewritten. Either way the origin's validator state is recorded first
    /// ([`Store::save_val_state`](crate::store::Store::save_val_state); a well-formed record of
    /// another state fails). A state past its origin, or a request yielding another state, is
    /// [`AbciError::AlreadyInitialized`]. Temporary L1/EL acquisition failures keep the same
    /// request pending; authenticated contradictions still fail for safety.
    ///
    /// See [`App::verify_genesis`] for the checks; as they make sure the EL serves `B*`, a
    /// successful `InitChain` also counts as the EL reconcile of the current set of ABCI
    /// connections (see [`App::info`]). Answers with the authenticated origin EL hash: H* or
    /// ELHash(c), the same on every re-sent `InitChain`, even when the EL already holds the
    /// generation's first block after a crash before its `Commit` (CONS-3.1-9).
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
                genesis_cutoff = state.genesis.genesis_cutoff,
                validators = req.validators.len(),
                "chain initialized"
            );
            self.state = Some(state);
            self.publish_state_metrics();
        }
        self.el_reconciled_epoch = Some(epoch);
        self.trust.committed(self.state.as_ref().expect("initialized state"));

        Ok(response::InitChain {
            consensus_params: None,
            validators: vec![],
            app_hash: app_hash(origin_hash),
        })
    }

    /// Verifies an `InitChain` request and returns the state it starts.
    ///
    /// In order: decodes the `app_state` witness; verifies it once with [`verify_bootstrap`]
    /// (generation zero: the Inbox witness at `L1_0`, the schedule and the `e_0` committee at
    /// `genesisCutoff` with its record hash; recovery: the fixed origin, R's observation and
    /// committee and the deployment context, embedding R as the finalized observation); requires
    /// the request's time, canonical consensus parameters, `chain_id`, initial height and
    /// validators to be exactly the ones that evidence determines ([`check_request`]); then
    /// acquires the inputs the evidence leaves to the own L1 and EL. At generation zero: the
    /// `L1_0` header must be final and canonical in the own L1 view, and the EL must serve `B*`
    /// with hash `H*` and state root `S*` (EL sync if needed). For a recovery, the inputs come
    /// from [`App::recovery_inputs`], retried here while unavailable. The state is
    /// [`VerifiedGenesis::origin_state`](crate::genesis::VerifiedGenesis::origin_state), as for
    /// an import at the origin: `last = (B*, H*)` with the `L1_0` anchor, or c with its
    /// historical anchor; the origin's forced inclusion cursor; and CometBFT's genesis validator
    /// state of the initial committee at the origin height. A recovery's immutable bootstrap
    /// sidecar is durable before this returns, so before the state is published.
    async fn verify_genesis(&self, req: &request::InitChain) -> Result<AppState, AbciError> {
        let witness = decode_bootstrap_state(&req.app_state_bytes)?;
        let (verified, expected) = verify_bootstrap(&witness, &self.params)?;
        check_request(req, &expected, self.params.l2_chain_id)?;
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

    /// One bounded recovery acquisition attempt; unavailable history is retried by InitChain.
    ///
    /// Reauthenticates the retained headers, the current generation and the fixed origin in
    /// the own finalized L1 view ([`check_recovery_canonicality`]); takes the historical anchor
    /// from the immutable sidecar a previous attempt stored (which must retain `w` exactly, with
    /// its anchor still final and canonical) or fetches it from the own L1
    /// ([`recovery_bootstrap`]); and requires the EL to serve c and its parent exactly as `w`
    /// authenticates them, and c's state. Returns the sidecar to store and what its verification
    /// authenticates.
    ///
    /// [`check_recovery_canonicality`]: crate::recovery::check_recovery_canonicality
    /// [`recovery_bootstrap`]: crate::recovery::recovery_bootstrap
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
                within(
                    "recovery historical anchor",
                    self.opts.l1_timeout,
                    crate::recovery::recovery_bootstrap(self.l1(), &self.params, w),
                )
                .await?
            }
        };
        let header = self.el_header(w.el_header.number).await?;
        if header != w.el_header {
            return Err(AbciError::SafetyHalt(
                "EL contradicts authenticated recovery origin".into(),
            ));
        }
        if let Some(parent) = w.parent_headers.first() &&
            self.el_header(parent.number).await? != *parent
        {
            return Err(AbciError::SafetyHalt(
                "EL contradicts authenticated recovery parent".into(),
            ));
        }
        // The first recovered block executes on c's state. An EL that pruned it after
        // `prepare`, or was replaced since, is missing data: InitChain waits with trust closed
        // instead of reporting Ready and halting on that first execution (SYNC-9-7).
        let state = self.engine.historical_state_available(w.el_header.hash_slow());
        if !within("EL recovery origin state read", self.opts.engine_timeout, state).await? {
            return Err(crate::RecoveryError::Unavailable(format!(
                "execution engine lacks the state of recovery origin {}",
                w.el_header.number
            ))
            .into());
        }
        Ok((bootstrap, history))
    }

    /// Makes sure the EL serves the genesis anchor `B*` with hash `H*` (syncing it over devp2p
    /// if needed) and summarizes it as the parent of `H_0`.
    ///
    /// An EL that rejects the genesis hash, serves another block at height 0 or returns a
    /// state root differing from the authenticated `S*` contradicts
    /// the verified genesis: [`AbciError::SafetyHalt`].
    async fn genesis_parent(&self, genesis: &GenesisRecord) -> Result<ParentInfo, AbciError> {
        let (number, hash) = (0, genesis.genesis_hash);
        self.sync_el_to("EL sync to the genesis anchor", number, hash).await?;

        let header = self.el_header(number).await?;
        let found = header.hash_slow();
        if found != hash {
            return Err(AbciError::SafetyHalt(format!(
                "execution engine serves {found} at the genesis anchor {number}, expected H* {hash}"
            )));
        }
        if header.state_root != genesis.genesis_state_root {
            return Err(AbciError::SafetyHalt(format!(
                "execution engine's genesis state root {} differs from S* {}",
                header.state_root, genesis.genesis_state_root
            )));
        }

        Ok(ParentInfo {
            number: 0,
            hash,
            timestamp: header.timestamp,
            gas_limit: header.gas_limit,
            gas_used: header.gas_used,
            base_fee: header.base_fee_per_gas.unwrap_or(0),
            difficulty: header.difficulty,
            grandparent_timestamp: 0,
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
/// determines (START-10-20/21, RECOV-8.4-7/9), in this order: the genesis time, the canonical
/// consensus parameters, the `chain_id`, the initial height and the validators.
fn check_request(
    req: &request::InitChain,
    expected: &GenesisExpectation,
    l2_chain_id: u64,
) -> Result<(), AbciError> {
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

/// Requires the genesis validators to be exactly `members`: the same native secp256k1eth keys with
/// the same powers, in any order, without duplicates.
fn check_validators(
    validators: &[crate::wire::ValidatorUpdate],
    members: &[Member],
) -> Result<(), AbciError> {
    let mismatch = AbciError::GenesisValidatorsMismatch;
    let mut genesis = BTreeMap::new();
    for v in validators {
        let pubkey = v.pub_key;
        if genesis.insert(pubkey, v.power.value()).is_some() {
            return Err(mismatch(format!("validator {pubkey} is listed twice")));
        }
    }
    for m in members {
        match genesis.remove(&m.pubkey) {
            Some(power) if power == m.power => {}
            Some(power) => {
                return Err(mismatch(format!(
                    "validator {} has power {power}, the committee gives {}",
                    m.pubkey, m.power
                )));
            }
            None => return Err(mismatch(format!("committee member {} is missing", m.pubkey))),
        }
    }
    match genesis.keys().next() {
        Some(extra) => Err(mismatch(format!("validator {extra} is not a committee member"))),
        None => Ok(()),
    }
}

/// The error of an initial committee that is not a CometBFT validator set: CometBFT refuses a
/// genesis set it cannot build, so neither can the app.
fn not_a_validator_set(error: ValStateError) -> AbciError {
    AbciError::GenesisValidatorsMismatch(format!("not a CometBFT validator set: {error}"))
}
