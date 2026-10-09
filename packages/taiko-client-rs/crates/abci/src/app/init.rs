//! `InitChain` (spec §5.1): verify the genesis witness against the node's own L1 and the EL,
//! then persist the initial [`AppState`].

use std::collections::BTreeMap;

use alloy_consensus::Header;
use alloy_primitives::B256;
use tendermint::{
    abci::{request, response},
    validator,
};

use super::{AbciError, App, ELSYNC_POLL, app_hash, at_genesis, within};
use crate::{
    committee::{record_hash, verify_committee_witness},
    elsync::ensure_block,
    engine::Engine,
    genesis::decode_app_state,
    l1::{L1Source, is_final_canonical, verify_genesis_inbox},
    rules::generation_from_chain_id,
    schedule::Schedule,
    store::{AppState, CommitteeState},
    types::{ActivationRecord, AnchorState, Member, ParentInfo},
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
    /// See [`App::verify_genesis`] for the checks. Answers the requested validators with
    /// `app_hash = H*`.
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
        let genesis_hash = state.activation.genesis_hash;
        if restart {
            if self.state.as_ref() != Some(&state) {
                return Err(AbciError::AlreadyInitialized);
            }
            tracing::info!(chain_id = %state.chain_id, "InitChain re-sent at genesis; re-verified");
        } else {
            self.store.save(&state)?;
            tracing::info!(
                chain_id = %state.chain_id,
                genesis_height = state.activation.genesis_height,
                genesis_hash = %genesis_hash,
                l1_0 = state.activation.l1_0,
                validators = req.validators.len(),
                "chain initialized"
            );
            self.state = Some(state);
        }

        Ok(response::InitChain {
            consensus_params: None,
            validators: req.validators,
            app_hash: app_hash(genesis_hash),
        })
    }

    /// Verifies an `InitChain` request and returns the state it starts.
    ///
    /// In order: decodes the `app_state` witness; requires its L1 header to be final and
    /// canonical in the own L1 view; verifies the Inbox witness (activated Inbox, activation
    /// record) and that the header is block `L1_0`; validates the schedule; requires the
    /// `chain_id` generation to equal the Inbox's `recoveryGeneration` and
    /// `initial_height == B* + 1`; recomputes the `e_0` committee from its witness (cutoff from
    /// `L1_0`) and requires its record hash to equal `committee[e_0]` and its members to be
    /// exactly the genesis validators; makes sure the EL serves `B*` with hash `H*` (EL sync if
    /// needed). The state has `last = (B*, H*)`.
    async fn verify_genesis(&self, req: &request::InitChain) -> Result<AppState, AbciError> {
        let w = decode_app_state(&req.app_state_bytes)?;
        let params = &self.params;
        let l1_header = &w.l1_header;

        let is_final = within(
            "L1 finality check of the genesis header",
            self.opts.l1_timeout,
            is_final_canonical(&self.l1, l1_header, params.l1_finality_extra_depth),
        )
        .await?;
        if !is_final {
            return Err(AbciError::GenesisNotFinal {
                number: l1_header.number,
                hash: l1_header.hash_slow(),
            });
        }

        let (activation, inbox_facts, committee_e0) =
            verify_genesis_inbox(l1_header.state_root, &w.inbox, params.inbox)?;
        if l1_header.number != activation.l1_0 {
            return Err(AbciError::GenesisL1Mismatch {
                header: l1_header.number,
                l1_0: activation.l1_0,
            });
        }

        let schedule = Schedule::from_activation(&activation);
        schedule.validate(params.unsettled_cap())?;

        let generation = generation_from_chain_id(&req.chain_id, params.l2_chain_id)?;
        if generation != inbox_facts.recovery_generation {
            return Err(AbciError::GenerationMismatch {
                chain_id: generation,
                inbox: inbox_facts.recovery_generation,
            });
        }
        let initial_height = req.initial_height.value();
        if initial_height != schedule.h0() {
            return Err(AbciError::InitialHeight { got: initial_height, expected: schedule.h0() });
        }

        let (record, members) = verify_committee_witness(
            l1_header.state_root,
            params,
            &w.committee,
            activation.l1_0,
            Schedule::E0,
        )?;
        let derived = record_hash(params.l2_chain_id, &record);
        if derived != committee_e0 {
            return Err(AbciError::CommitteeRecordMismatch { derived, recorded: committee_e0 });
        }
        check_validators(&req.validators, &members)?;

        let parent = self.genesis_parent(&activation).await?;
        Ok(AppState {
            chain_id: req.chain_id.clone(),
            generation,
            activation: activation.clone(),
            schedule,
            last_height: activation.genesis_height,
            parent,
            anchor: AnchorState {
                number: activation.l1_0,
                hash: l1_header.hash_slow(),
                state_root: l1_header.state_root,
                timestamp: l1_header.timestamp,
                inbox: inbox_facts,
            },
            committees: BTreeMap::from([(Schedule::E0, CommitteeState { record, members })]),
        })
    }

    /// Makes sure the EL serves the genesis anchor `B*` with hash `H*` (syncing it over devp2p
    /// if needed) and summarizes it as the parent of `H_0`.
    ///
    /// An EL that rejects `H*`, serves another block at `B*`, or whose block at `B* − 1` is not
    /// `B*`'s parent contradicts the verified genesis: [`AbciError::SafetyHalt`].
    async fn genesis_parent(&self, activation: &ActivationRecord) -> Result<ParentInfo, AbciError> {
        let (number, hash) = (activation.genesis_height, activation.genesis_hash);
        let opts = self.opts;
        within(
            "EL sync to the genesis anchor",
            opts.elsync_timeout + opts.engine_timeout,
            ensure_block(&self.engine, number, hash, opts.elsync_timeout, ELSYNC_POLL),
        )
        .await?;

        let header = self.el_header(number).await?;
        let found = header.hash_slow();
        if found != hash {
            return Err(AbciError::SafetyHalt(format!(
                "execution engine serves {found} at the genesis anchor {number}, expected H* {hash}"
            )));
        }

        let grandparent_timestamp = match number.checked_sub(1) {
            None => 0,
            Some(parent_number) => {
                let parent = self.el_header(parent_number).await?;
                if parent.hash_slow() != header.parent_hash {
                    return Err(AbciError::SafetyHalt(format!(
                        "execution engine block {parent_number} ({}) is not the parent {} of \
                         the genesis anchor",
                        parent.hash_slow(),
                        header.parent_hash
                    )));
                }
                parent.timestamp
            }
        };
        parent_info(&header, hash, grandparent_timestamp)
    }

    /// The EL's canonical header at `number`; a missing block is
    /// [`AbciError::ElBlockMissing`].
    async fn el_header(&self, number: u64) -> Result<Header, AbciError> {
        within("EL header read", self.opts.engine_timeout, self.engine.header_by_number(number))
            .await?
            .ok_or(AbciError::ElBlockMissing(number))
    }
}

/// The [`ParentInfo`] of the EL block `header` (whose hash is `hash`).
///
/// A block without a base fee is accepted only at height 0, where the next base fee does not
/// depend on it (it is recorded as 0).
fn parent_info(
    header: &Header,
    hash: B256,
    grandparent_timestamp: u64,
) -> Result<ParentInfo, AbciError> {
    let base_fee = match (header.base_fee_per_gas, header.number) {
        (Some(base_fee), _) => base_fee,
        (None, 0) => 0,
        (None, number) => return Err(AbciError::MissingBaseFee(number)),
    };
    Ok(ParentInfo {
        number: header.number,
        hash,
        timestamp: header.timestamp,
        gas_limit: header.gas_limit,
        gas_used: header.gas_used,
        base_fee,
        difficulty: header.difficulty,
        grandparent_timestamp,
    })
}

/// Requires the genesis validators to be exactly `members`: the same Ed25519 keys with the same
/// powers, in any order, without duplicates.
fn check_validators(validators: &[validator::Update], members: &[Member]) -> Result<(), AbciError> {
    let mismatch = |reason: String| AbciError::GenesisValidatorsMismatch(reason);
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
