//! `InitChain`: authenticate deployment or recovery bootstrap against own L1 and the EL,
//! then persist the initial [`AppState`].

use crate::wire::{request, response};
use std::collections::BTreeMap;

use alloy_consensus::Header;

use super::{AbciError, App, app_hash, at_generation_origin, within};
use crate::{
    engine::Engine,
    genesis::{
        BootstrapWitness, GenesisConsensusParams, decode_bootstrap_state, genesis_time,
        verify_committee, verify_context,
    },
    l1::L1Source,
    rules::check_chain_id,
    schedule::Schedule,
    store::{AppState, STATE_SCHEMA_VERSION},
    types::{GenesisRecord, Member, ParentInfo},
    valstate::ValState,
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
    /// successful `InitChain` also counts as this process's EL reconcile (see [`App::info`]).
    /// Answers with the authenticated origin EL hash: H* or ELHash(c).
    pub(super) async fn init_chain(
        &mut self,
        req: request::InitChain,
    ) -> Result<response::InitChain, AbciError> {
        let restart = match &self.state {
            None => false,
            Some(state) if at_generation_origin(state) => true,
            Some(_) => return Err(AbciError::AlreadyInitialized),
        };
        let mut pause = super::FINALIZE_RETRY_INITIAL;
        let state = loop {
            match self.verify_genesis(&req).await {
                Ok(state) => break state,
                Err(error) if startup_input_unavailable(&error) => {
                    self.trust.await_authentication(error.to_string());
                    tracing::warn!(%error, ?pause, "initialization waits for authenticated L1/EL inputs");
                    tokio::time::sleep(pause).await;
                    pause = (pause * 2).min(super::FINALIZE_RETRY_MAX);
                }
                Err(error) => return Err(super::trust::classify_trust_error(error)),
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
        self.el_reconciled = true;
        self.trust.committed(self.state.as_ref().expect("initialized state"));

        Ok(response::InitChain {
            consensus_params: None,
            validators: vec![],
            app_hash: app_hash(origin_hash),
        })
    }

    /// Verifies an `InitChain` request and returns the state it starts.
    ///
    /// Recovery evidence dispatches to `verify_recovery_genesis`; the following checks describe
    /// unchanged generation-zero initialization.
    /// In order: decodes the `app_state` witness; requires the request's time to equal the
    /// initialization timestamp and its representable consensus parameters to be canonical;
    /// requires its L1 header to be final and
    /// canonical in the own L1 view; verifies the Inbox witness (initialized Inbox, genesis
    /// record, `genesisCutoff < L1_0`) and that the header is block `L1_0`; validates the
    /// schedule; requires the `chain_id` generation to equal the Inbox's `recoveryGeneration` and
    /// `initial_height == 1`; recomputes the `e_0` committee from its witness (proofs against
    /// `L1_0`'s state root, snapshot cutoff `genesisCutoff` as is, without the cutoff lag and
    /// grid that apply from `e_0 + 1` on) and requires its record hash to equal
    /// `genesisCommitteeRecordHash` and its members to be exactly the genesis validators; makes
    /// sure the EL serves `B*` with hash `H*` and state root `S*` (EL sync if needed).
    /// Persists the authenticated Inbox address. The state has `last = (B*,
    /// H*)`, forced inclusion cursor 0 and CometBFT's genesis validator state of `e_0` at `B*`.
    async fn verify_genesis(&self, req: &request::InitChain) -> Result<AppState, AbciError> {
        let w = match decode_bootstrap_state(&req.app_state_bytes)? {
            BootstrapWitness::Initial(w) => w,
            BootstrapWitness::Recovery(w) => return self.verify_recovery_genesis(req, &w).await,
        };
        let params = &self.params;
        let l1_header = &w.l1_header;
        let expected = genesis_time(l1_header.timestamp())?;
        if req.time != expected {
            return Err(AbciError::GenesisTimeMismatch { got: req.time, expected });
        }
        if req.consensus_params != GenesisConsensusParams::abci() {
            return Err(AbciError::GenesisConsensusParamsMismatch);
        }

        let finalized = within(
            "L1 finality check of the genesis header",
            self.opts.l1_timeout,
            self.l1().finalized_number(),
        )
        .await?;
        if finalized < l1_header.number() {
            return Err(AbciError::GenesisNotFinal {
                number: l1_header.number(),
                hash: l1_header.hash(),
            });
        }
        if within(
            "L1 canonicality check of the genesis header",
            self.opts.l1_timeout,
            self.l1().canonical_hash(l1_header.number()),
        )
        .await? !=
            l1_header.hash()
        {
            return Err(AbciError::SafetyHalt(
                "genesis header differs from own finalized L1".into(),
            ));
        }

        let context = verify_context(l1_header, &w.inbox, params)?;
        let schedule = Schedule::from_genesis(&context.genesis);
        let generation = context.anchor.inbox.recovery_generation;
        if generation != 0 {
            return Err(AbciError::StoredState(
                "unsupported recovery generation: fresh generation 0 only".into(),
            ));
        }
        check_chain_id(&req.chain_id, params, generation)?;
        let initial_height = req.initial_height.value();
        if initial_height != schedule.h0() {
            return Err(AbciError::InitialHeight { got: initial_height, expected: schedule.h0() });
        }

        let committee = verify_committee(&context, &w.committee, params)?;
        check_validators(&req.validators, &committee.members)?;
        let val_state = genesis_val_state(0, &committee.members)?;
        let parent = self.genesis_parent(&context.genesis).await?;
        Ok(AppState {
            schema_version: STATE_SCHEMA_VERSION,
            recovery: None,
            app_version: crate::app::APP_VERSION,
            chain_id: req.chain_id.clone(),
            generation,
            inbox: w.inbox.address,
            genesis: context.genesis,
            last_height: 0,
            last_comet_hash: alloy_primitives::B256::ZERO,
            parent,
            anchor: context.anchor,
            forced_cursor: 0,
            committees: BTreeMap::from([(Schedule::E0, committee)]),
            val_state,
        })
    }

    /// Independently authenticates fixed recovery evidence, historical anchor and local EL
    /// boundary. The immutable sidecar is durable before callers can publish the corresponding
    /// AppState. The generation starts from CometBFT's genesis validator state of the origin
    /// committee at the origin height.
    async fn verify_recovery_genesis(
        &self,
        req: &request::InitChain,
        w: &crate::RecoveryWitness,
    ) -> Result<AppState, AbciError> {
        use crate::recovery::verify_recovery_witness;
        let origin = verify_recovery_witness(w, &self.params)?;
        if w.finalized_header != w.recovery_header || w.finalized_inbox != w.recovery_inbox {
            return Err(crate::RecoveryError::Invalid(
                "recovery genesis must embed the canonical R observation".into(),
            )
            .into());
        }
        let expected = genesis_time(origin.l1_timestamp)?;
        if req.time != expected {
            return Err(AbciError::GenesisTimeMismatch { got: req.time, expected });
        }
        if req.consensus_params != GenesisConsensusParams::abci() {
            return Err(AbciError::GenesisConsensusParamsMismatch);
        }
        check_chain_id(&req.chain_id, &self.params, origin.generation)?;
        if req.initial_height.value() != origin.height + 1 {
            return Err(AbciError::InitialHeight {
                got: req.initial_height.value(),
                expected: origin.height + 1,
            });
        }
        check_validators(&req.validators, &origin.committee.members)?;
        let val_state = genesis_val_state(origin.height, &origin.committee.members)?;
        let mut pause = super::FINALIZE_RETRY_INITIAL;
        let bootstrap = loop {
            match self.recovery_inputs(w).await {
                Ok(bootstrap) => break bootstrap,
                Err(error) if startup_input_unavailable(&error) => {
                    // The guarded signer owns the session. A successful stock InitChain replay
                    // must not rotate it, while unavailable inputs immediately close readiness.
                    self.trust.await_authentication(error.to_string());
                    tracing::warn!(height = origin.height, %error, ?pause, "recovery initialization waits for authenticated history");
                    tokio::time::sleep(pause).await;
                    pause = (pause * 2).min(super::FINALIZE_RETRY_MAX);
                }
                Err(error) => return Err(super::trust::classify_trust_error(error)),
            }
        };
        let (_, anchor) = bootstrap.verify(&self.params)?;
        let genesis = crate::genesis::verify_deployment_context(
            &w.genesis.l1_header,
            &w.genesis.inbox,
            &self.params,
        )?
        .genesis;
        let state = AppState {
            schema_version: STATE_SCHEMA_VERSION,
            app_version: super::APP_VERSION,
            chain_id: req.chain_id.clone(),
            generation: origin.generation,
            inbox: self.params.inbox,
            genesis,
            last_height: origin.height,
            last_comet_hash: alloy_primitives::B256::ZERO,
            parent: crate::recovery::recovery_parent(w),
            anchor,
            forced_cursor: origin.forced_cursor,
            committees: BTreeMap::from([(
                origin.committee.record.target_epoch,
                origin.committee.clone(),
            )]),
            val_state,
            recovery: Some(origin),
        };
        self.store.save_recovery_bootstrap(&bootstrap)?;
        Ok(state)
    }

    /// One bounded recovery acquisition attempt; unavailable history is retried by InitChain.
    async fn recovery_inputs(
        &self,
        w: &crate::RecoveryWitness,
    ) -> Result<crate::recovery::RecoveryBootstrap, AbciError> {
        within(
            "recovery own-L1 authentication",
            self.opts.l1_timeout,
            crate::recovery::check_recovery_canonicality(self.l1(), &self.params, w),
        )
        .await?;
        let bootstrap = match self.store.load_recovery_bootstrap()? {
            Some(bootstrap) => {
                let (retained, anchor) = bootstrap.verify(&self.params)?;
                if retained != *w {
                    return Err(AbciError::SafetyHalt(
                        "recovery request differs from immutable bootstrap".into(),
                    ));
                }
                let finalized = within(
                    "recovery historical finality",
                    self.opts.l1_timeout,
                    self.l1.finalized_number(),
                )
                .await?;
                if finalized < anchor.number {
                    return Err(crate::RecoveryError::Unavailable(
                        "historical recovery anchor is not final".into(),
                    )
                    .into());
                }
                if within(
                    "recovery historical canonicality",
                    self.opts.l1_timeout,
                    self.l1.canonical_hash(anchor.number),
                )
                .await? !=
                    anchor.hash
                {
                    return Err(AbciError::SafetyHalt("historical recovery anchor changed".into()));
                }
                bootstrap
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
        Ok(bootstrap)
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

/// CometBFT's genesis validator state at the origin `height` of the validators `members`, which
/// [`check_validators`] matched against the request. CometBFT refuses a genesis set it cannot
/// build, so neither can the app.
fn genesis_val_state(height: u64, members: &[Member]) -> Result<ValState, AbciError> {
    let validators: Vec<_> = members.iter().map(|m| (m.pubkey, m.power)).collect();
    ValState::genesis(height, &validators).map_err(|error| {
        AbciError::GenesisValidatorsMismatch(format!("not a CometBFT validator set: {error}"))
    })
}

/// Only acquisition failures keep startup ABCI requests pending on the same connection.
/// Authenticated contradictions and malformed own-source replies still fail for safety.
pub(super) fn startup_input_unavailable(error: &AbciError) -> bool {
    match error {
        AbciError::Recovery(crate::RecoveryError::Unavailable(_)) |
        AbciError::Timeout { .. } |
        AbciError::ElBlockMissing(_) |
        AbciError::GenesisNotFinal { .. } |
        AbciError::ElSync(crate::elsync::ElSyncError::Timeout { .. }) => true,
        AbciError::Engine(error) => error.is_retryable(),
        AbciError::ElSync(crate::elsync::ElSyncError::Engine(error)) => error.is_retryable(),
        AbciError::L1(error) => !error.is_integrity_failure(),
        _ => false,
    }
}
