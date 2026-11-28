//! Offline plan summary for comparing with other operators; never a trust or signing signal.
use super::{RecoveryCommandError, plan::RecoveryPlan};
use abci::{key::ConsensusKey, l1::layout::inbox};
use alloy_primitives::{B256, U256, keccak256};
use serde::{Deserialize, Serialize};
use std::path::Path;

/// What a plan fixes, and whether a home holds its genesis. Trust is read from the running
/// app's `/status`, never from this report (SYNC-9-15).
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct RecoveryStatus {
    /// Requested authenticated generation.
    pub generation: u64,
    /// The generation's full Comet chain ID.
    pub chain_id: String,
    /// Fixed retained L2 origin c.
    pub origin_height: u64,
    /// Fixed L1 recovery execution block R.
    pub recovery_l1_block: u64,
    /// Genesis time, R's timestamp.
    pub genesis_time: String,
    /// keccak256 of the exact genesis.json bytes; equal across honest operators.
    pub genesis_hash: B256,
    /// The `fallbackKeysHash` of the generation's origin record: slot 278 when `recover`
    /// executed, whatever list the Inbox holds later.
    pub fallback_keys_hash: B256,
    /// The keys of the list with that hash, in ascending order: the genesis validators, each at
    /// power 1, which sign c + 1 and c + 2.
    pub origin_keys: Vec<ConsensusKey>,
    /// `minTotalStake` (slot 279) in the proof at R, for display only. With 2^256 − 1 no
    /// candidate is usable while the anchors still prove that value, so the fallback key set
    /// keeps signing after c + 2.
    pub min_total_stake: U256,
    /// Latest checkpoint height `prepare` observed on own finalized L1; not a runtime fact.
    pub observed_checkpoint_height: u64,
    /// Whether the given home holds this plan's genesis.json; absent without a home.
    pub installed: Option<bool>,
    /// Whether the given public key is one of [`Self::origin_keys`]; absent without a key.
    pub local_key_is_origin_key: Option<bool>,
}

/// Summarizes `plan` and, with `home`, whether it is installed there, and with `local_key`,
/// whether that key is an origin key. No network, no writes. A home holding another genesis is
/// a mismatch, not "not installed".
pub fn status(
    plan: &RecoveryPlan,
    home: Option<&Path>,
    local_key: Option<ConsensusKey>,
) -> Result<RecoveryStatus, RecoveryCommandError> {
    let witness = plan.validate()?;
    let word = |proof: &abci::AccountWitness, slot: u64| {
        proof
            .storage
            .iter()
            .find(|word| word.slot == inbox::slot(slot))
            .map(|word| word.value)
            .ok_or(RecoveryCommandError::PlanMismatch)
    };
    let observed_checkpoint_height: u64 =
        word(&witness.finalized_inbox, inbox::LAST_CHECKPOINT_HEIGHT)?
            .try_into()
            .map_err(|_| RecoveryCommandError::PlanMismatch)?;
    let min_total_stake = word(&witness.recovery_inbox, inbox::MIN_TOTAL_STAKE)?;
    let doc: abci::GenesisDoc =
        serde_json::from_slice(&plan.genesis).map_err(|_| RecoveryCommandError::PlanMismatch)?;
    // `validate` checked that the genesis validators are the list with the origin record's hash.
    let origin_keys: Vec<_> = doc.validators.iter().map(|validator| validator.pub_key.0).collect();
    let installed = home
        .map(|home| {
            let genesis = home.join("config/genesis.json");
            if std::fs::symlink_metadata(&genesis).is_err() {
                return Ok(false);
            }
            let bytes = super::plan::read_bounded(&genesis, plan.genesis.len() as u64 + 1)
                .map_err(|_| RecoveryCommandError::PlanMismatch)?;
            if bytes != plan.genesis.as_ref() {
                return Err(RecoveryCommandError::PlanMismatch);
            }
            Ok(true)
        })
        .transpose()?;
    Ok(RecoveryStatus {
        generation: plan.origin.generation,
        chain_id: doc.chain_id,
        origin_height: plan.origin.height,
        recovery_l1_block: plan.origin.l1_number,
        genesis_time: doc.genesis_time,
        genesis_hash: keccak256(&plan.genesis),
        fallback_keys_hash: plan.origin.fallback_keys_hash,
        local_key_is_origin_key: local_key.map(|key| origin_keys.contains(&key)),
        origin_keys,
        min_total_stake,
        observed_checkpoint_height,
        installed,
    })
}

impl std::fmt::Display for RecoveryStatus {
    /// The text report: the plan's identity on one line, R's `minTotalStake`, then the origin
    /// keys, one per line.
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        let installed = self.installed.map_or("unchecked", |yes| if yes { "yes" } else { "no" });
        writeln!(
            f,
            "Recovery plan: generation {}, chain_id {}, c={}, R={}, genesis_hash {}, observed checkpoint {}, installed {installed}",
            self.generation,
            self.chain_id,
            self.origin_height,
            self.recovery_l1_block,
            self.genesis_hash,
            self.observed_checkpoint_height,
        )?;
        if self.min_total_stake == U256::MAX {
            writeln!(f, "minTotalStake at R: 2^256-1 (no candidate is usable)")?;
        } else {
            writeln!(f, "minTotalStake at R: {}", self.min_total_stake)?;
        }
        let local = match self.local_key_is_origin_key {
            None => "local key unchecked",
            Some(true) => "local key is an origin key",
            Some(false) => "local key is not an origin key",
        };
        write!(
            f,
            "{} origin keys at power 1, fallback_keys_hash {}, {local}:",
            self.origin_keys.len(),
            self.fallback_keys_hash,
        )?;
        for key in &self.origin_keys {
            write!(f, "\n  {key}")?;
        }
        Ok(())
    }
}
