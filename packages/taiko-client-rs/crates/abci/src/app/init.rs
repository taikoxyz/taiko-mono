//! `InitChain`: verify the genesis witness against the node's own L1 and the EL,
//! then persist the initial [`AppState`].

use std::collections::BTreeMap;

use alloy_consensus::Header;
use alloy_primitives::B256;
use tendermint::{
    abci::{request, response},
    validator,
};

use super::{AbciError, App, app_hash, at_genesis, within};
use crate::{
    engine::Engine,
    genesis::{
        GenesisConsensusParams, decode_app_state, genesis_time, verify_committee, verify_context,
    },
    l1::{L1Source, is_final_canonical},
    rules::generation_from_chain_id,
    schedule::Schedule,
    store::AppState,
    types::{GenesisRecord, Member, ParentInfo},
};

impl<L: L1Source, E: Engine> App<L, E> {
    /// Handles `InitChain`: verifies the genesis and persists the initial state.
    ///
    /// CometBFT re-sends `InitChain` whenever the app reports height 0, i.e. after a restart
    /// before the first PoS block is committed. An app already holding a state answers only
    /// while that state is still at the genesis anchor `B*`: the request is verified again and
    /// must yield exactly the stored state, which is then answered as before without being
    /// rewritten. A state past `B*`, or a request yielding another state, is
    /// [`AbciError::AlreadyInitialized`]; a verification failure is reported as such.
    ///
    /// See [`App::verify_genesis`] for the checks; as they make sure the EL serves `B*`, a
    /// successful `InitChain` also counts as this process's EL reconcile (see [`App::info`]).
    /// Answers the requested validators with `app_hash = H*`.
    pub(super) async fn init_chain(
        &mut self,
        req: request::InitChain,
    ) -> Result<response::InitChain, AbciError> {
        let restart = match &self.state {
            None => false,
            Some(state) if at_genesis(state) => true,
            Some(_) => return Err(AbciError::AlreadyInitialized),
        };
        let state = self.verify_genesis(&req).await?;
        let genesis_hash = state.genesis.genesis_hash;
        if restart {
            if self.state.as_ref() != Some(&state) {
                return Err(AbciError::AlreadyInitialized);
            }
            tracing::info!(chain_id = %state.chain_id, "InitChain re-sent at genesis; re-verified");
        } else {
            self.store.save(&state)?;
            tracing::info!(
                chain_id = %state.chain_id,
                genesis_height = state.genesis.genesis_height,
                genesis_hash = %genesis_hash,
                l1_0 = state.genesis.l1_0,
                genesis_cutoff = state.genesis.genesis_cutoff,
                validators = req.validators.len(),
                "chain initialized"
            );
            self.state = Some(state);
            self.publish_state_metrics();
        }
        self.el_reconciled = true;

        Ok(response::InitChain {
            consensus_params: None,
            validators: req.validators,
            app_hash: app_hash(genesis_hash),
        })
    }

    /// Verifies an `InitChain` request and returns the state it starts.
    ///
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
    /// H*)` and forced inclusion cursor 0.
    async fn verify_genesis(&self, req: &request::InitChain) -> Result<AppState, AbciError> {
        let w = decode_app_state(&req.app_state_bytes)?;
        let params = &self.params;
        let l1_header = &w.l1_header;
        let expected = genesis_time(l1_header.timestamp())?;
        if req.time != expected {
            return Err(AbciError::GenesisTimeMismatch { got: req.time, expected });
        }
        if req.consensus_params != GenesisConsensusParams::abci() {
            return Err(AbciError::GenesisConsensusParamsMismatch);
        }

        let is_final = within(
            "L1 finality check of the genesis header",
            self.opts.l1_timeout,
            is_final_canonical(self.l1(), l1_header, params.l1_finality_extra_depth),
        )
        .await?;
        if !is_final {
            return Err(AbciError::GenesisNotFinal {
                number: l1_header.number(),
                hash: l1_header.hash(),
            });
        }

        let context = verify_context(l1_header, &w.inbox, params)?;
        let schedule = Schedule::from_genesis(&context.genesis);
        let generation = generation_from_chain_id(&req.chain_id, params.l2_chain_id)?;
        if generation != context.anchor.inbox.recovery_generation {
            return Err(AbciError::GenerationMismatch {
                chain_id: generation,
                inbox: context.anchor.inbox.recovery_generation,
            });
        }
        let initial_height = req.initial_height.value();
        if initial_height != schedule.h0() {
            return Err(AbciError::InitialHeight { got: initial_height, expected: schedule.h0() });
        }

        let committee = verify_committee(&context, &w.committee, params)?;
        check_validators(&req.validators, &committee.members)?;
        let parent = self.genesis_parent(&context.genesis).await?;
        Ok(AppState {
            app_version: crate::app::APP_VERSION,
            chain_id: req.chain_id.clone(),
            generation,
            inbox: w.inbox.address,
            genesis: context.genesis,
            last_height: 0,
            parent,
            anchor: context.anchor,
            forced_cursor: 0,
            committees: BTreeMap::from([(Schedule::E0, committee)]),
        })
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

/// Requires the genesis validators to be exactly `members`: the same Ed25519 keys with the same
/// powers, in any order, without duplicates.
fn check_validators(validators: &[validator::Update], members: &[Member]) -> Result<(), AbciError> {
    let mismatch = AbciError::GenesisValidatorsMismatch;
    let mut genesis = BTreeMap::new();
    for v in validators {
        let key = v
            .pub_key
            .ed25519()
            .ok_or_else(|| mismatch(format!("validator key {:?} is not Ed25519", v.pub_key)))?;
        let pubkey = B256::try_from(key.as_bytes())
            .map_err(|_| mismatch("Ed25519 key is not 32 bytes".to_string()))?;
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
