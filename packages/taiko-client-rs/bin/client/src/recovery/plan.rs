//! Content-addressed public recovery evidence and exhaustive deployment parameters.
use super::RecoveryCommandError;
use abci::{
    ChainParams,
    recovery::{RecoveryOrigin, RecoveryWitness},
};
use alloy_primitives::{Address, B256, Bytes, U256, keccak256};
use serde::{Deserialize, Serialize};
use std::collections::BTreeMap;

/// Exhaustive serializable ChainParams, validated through the consensus implementation.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Deployment {
    /// L2 EVM chain identifier.
    pub l2_chain_id: u64,
    /// Authenticated Inbox address.
    pub inbox: Address,
    /// Authenticated registry address.
    pub registry: Address,
    /// Full 256-bit L1 chain identifier.
    pub l1_chain_id: U256,
    /// Maximum unsettled depth in L2 blocks.
    pub unsettled_limit: u64,
    /// Local execution beneficiary.
    pub fee_recipient: Address,
    /// Effective stake per unit of voting power.
    pub vp_unit: U256,
    /// Minimum eligible effective stake.
    pub s_min: U256,
    /// Maximum committee membership.
    pub n_max: usize,
    /// L2 block gas limit.
    pub block_gas_limit: u64,
}
impl From<&ChainParams> for Deployment {
    /// Copies every configured field without narrowing identifiers.
    fn from(p: &ChainParams) -> Self {
        Self {
            l2_chain_id: p.l2_chain_id,
            inbox: p.inbox,
            registry: p.registry,
            l1_chain_id: p.l1_chain_id,
            unsettled_limit: p.unsettled_limit,
            fee_recipient: p.fee_recipient,
            vp_unit: p.vp_unit,
            s_min: p.s_min,
            n_max: p.n_max,
            block_gas_limit: p.block_gas_limit,
        }
    }
}
impl Deployment {
    /// Restores and validates the exact original consensus parameters.
    pub fn params(&self) -> Result<ChainParams, RecoveryCommandError> {
        let p = ChainParams {
            l2_chain_id: self.l2_chain_id,
            inbox: self.inbox,
            registry: self.registry,
            l1_chain_id: self.l1_chain_id,
            unsettled_limit: self.unsettled_limit,
            fee_recipient: self.fee_recipient,
            vp_unit: self.vp_unit,
            s_min: self.s_min,
            n_max: self.n_max,
            block_gas_limit: self.block_gas_limit,
        };
        p.validate().map_err(|_| RecoveryCommandError::ConfigMismatch)?;
        Ok(p)
    }
}

/// Public missing prerequisite; none of these observations is signing authorization.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "kebab-case")]
pub enum Prerequisite {
    /// Stateful origin build requires fencing and is always deferred from prepare.
    ActivationBuildProbe,
    /// Nonmutating origin state read was unsuccessful or unavailable.
    HistoricalState,
    /// Finalized EL boundary could not be observed.
    FinalizedHeader,
    /// Comet template is missing or unsupported for the requested role.
    CometTemplate,
    /// Choose a shorter private root so future Unix sockets fit platform sockaddr bounds.
    RuntimeSocketPath,
    /// Optional sender must reconcile its original account journal after ownership fencing.
    LanderReconciliation,
    /// Existing stock P2P node identity must be supplied before activation; never rotate it.
    CometNodeKey,
}

/// Schema-one immutable plan; its ID is computed from canonical serialization of all fields.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct RecoveryPlan {
    /// Exactly one; incompatible formats are never migrated.
    pub schema: u32,
    /// Commitment to the privately stored original profile.
    pub profile_digest: B256,
    /// Complete configured deployment identity.
    pub deployment: Deployment,
    /// Canonical RecoveryWitness RLP, including latest authenticated observation.
    pub witness: Bytes,
    /// Independently verified fixed generation boundary.
    pub origin: RecoveryOrigin,
    /// Exact deterministic Comet genesis JSON bytes.
    pub genesis: Bytes,
    /// Relative immutable staged artifact names mapped to their keccak256 hashes.
    pub artifacts: BTreeMap<String, B256>,
    /// Preliminary observations which must be resolved after fencing.
    pub prerequisites: Vec<Prerequisite>,
    /// Software version used to derive the staged bundle.
    pub client_version: String,
}

impl RecoveryPlan {
    /// Hashes canonical fields; no self-ID, timestamps or private credentials are serialized.
    pub fn id(&self) -> B256 {
        keccak256(serde_json::to_vec(self).expect("fixed plan serialization"))
    }

    /// Decodes canonical evidence and verifies the deployment, origin and artifact manifest.
    pub fn validate(&self) -> Result<RecoveryWitness, RecoveryCommandError> {
        if self.schema != 1 || !self.prerequisites.contains(&Prerequisite::ActivationBuildProbe) {
            return Err(RecoveryCommandError::PlanMismatch);
        }
        let params = self.deployment.params()?;
        let witness: RecoveryWitness = alloy_rlp::decode_exact(&self.witness)
            .map_err(|_| RecoveryCommandError::PlanMismatch)?;
        if alloy_rlp::encode(&witness).as_slice() != self.witness.as_ref() ||
            abci::recovery::verify_recovery_witness(&witness, &params)? != self.origin
        {
            return Err(RecoveryCommandError::PlanMismatch);
        }
        let doc: abci::GenesisDoc = serde_json::from_slice(&self.genesis)
            .map_err(|_| RecoveryCommandError::PlanMismatch)?;
        let mut fixed = witness.clone();
        fixed.finalized_header = fixed.recovery_header.clone();
        fixed.finalized_inbox = fixed.recovery_inbox.clone();
        let expected_time = tendermint::Time::from_unix_timestamp(
            self.origin.l1_timestamp.try_into().map_err(|_| RecoveryCommandError::PlanMismatch)?,
            0,
        )
        .map_err(|_| RecoveryCommandError::PlanMismatch)?
        .to_rfc3339();
        if doc.genesis_time != expected_time ||
            doc.chain_id !=
                abci::rules::chain_id_for(&params, self.origin.generation)
                    .map_err(|_| RecoveryCommandError::PlanMismatch)? ||
            doc.initial_height != (self.origin.height + 1).to_string() ||
            doc.app_hash != alloy_primitives::hex::encode_upper(self.origin.el_hash) ||
            doc.consensus_params != abci::genesis::GenesisConsensusParams::etna() ||
            doc.validators !=
                self.origin
                    .committee
                    .members
                    .iter()
                    .map(abci::genesis::GenesisValidator::from_member)
                    .collect::<Vec<_>>() ||
            doc.app_state != abci::genesis::AppStateJson::from(&fixed)
        {
            return Err(RecoveryCommandError::PlanMismatch);
        }
        if self.artifacts.get("comet/config/genesis.json") != Some(&keccak256(&self.genesis)) ||
            !self.artifacts.contains_key("app-chain.toml") ||
            (!self.artifacts.contains_key("comet/config/config.toml") &&
                !self.prerequisites.contains(&Prerequisite::CometTemplate)) ||
            (!self.artifacts.contains_key("comet/config/node_key.json") &&
                !self.prerequisites.contains(&Prerequisite::CometNodeKey)) ||
            self.artifacts.keys().any(|name| !valid_artifact(name))
        {
            return Err(RecoveryCommandError::PlanMismatch);
        }
        Ok(witness)
    }
}

/// Only fixed configuration filenames may enter the immutable manifest; never arbitrary paths.
pub fn valid_artifact(name: &str) -> bool {
    matches!(
        name,
        "comet/config/genesis.json" |
            "comet/config/config.toml" |
            "comet/config/node_key.json" |
            "app-chain.toml"
    )
}
