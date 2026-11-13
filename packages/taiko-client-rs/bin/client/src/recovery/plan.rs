//! The recovery plan file: authenticated public evidence and the exact genesis, nothing private.
use super::RecoveryCommandError;
use abci::{
    ChainParams,
    recovery::{RecoveryOrigin, RecoveryWitness},
};
use alloy_primitives::{Address, Bytes, U256};
use serde::{Deserialize, Serialize};
use std::{
    fs::{File, OpenOptions},
    io::{Read, Write},
    os::unix::fs::OpenOptionsExt,
    path::Path,
};

/// Maximum accepted plan size in bytes.
const MAX_PLAN_BYTES: u64 = 16 * 1024 * 1024;

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

/// What `prepare` authenticated on the node's own finalized L1, as one strict JSON document.
/// It holds no endpoint, path or credential, so operators can compare and share it.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct RecoveryPlan {
    /// Complete configured deployment identity.
    pub deployment: Deployment,
    /// Canonical RecoveryWitness RLP, including the latest authenticated observation.
    pub witness: Bytes,
    /// Independently verified fixed generation boundary (c, R and the reselected committee).
    pub origin: RecoveryOrigin,
    /// Exact deterministic Comet genesis JSON bytes.
    pub genesis: Bytes,
}

impl RecoveryPlan {
    /// Decodes the canonical witness and checks that the deployment, origin and genesis are
    /// exactly what it proves (RECOV-8.4-7..10): chain_id of the generation, initial_height
    /// c+1, genesis_time R.timestamp, app_hash ELHash(c), the R committee and the R witness.
    pub fn validate(&self) -> Result<RecoveryWitness, RecoveryCommandError> {
        let params = self.deployment.params()?;
        let witness: RecoveryWitness = alloy_rlp::decode_exact(&self.witness)
            .map_err(|_| RecoveryCommandError::PlanMismatch)?;
        // A witness that no longer verifies is an edited plan, whatever the proof error.
        if alloy_rlp::encode(&witness).as_slice() != self.witness.as_ref() ||
            abci::recovery::verify_recovery_witness(&witness, &params)
                .map_err(|_| RecoveryCommandError::PlanMismatch)? !=
                self.origin
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
        Ok(witness)
    }

    /// Creates `path` (never an existing one) with mode 0600, and makes its contents and its
    /// directory entry durable. A crash can leave a torn file, which [`Self::load`] refuses.
    pub fn write_new(&self, path: &Path) -> Result<(), RecoveryCommandError> {
        let bytes =
            serde_json::to_vec_pretty(self).map_err(|_| RecoveryCommandError::Parse("plan"))?;
        write_new(path, &bytes)?;
        sync_dir(parent(path))
    }

    /// Reads a bounded plan file and validates it.
    pub fn load(path: &Path) -> Result<Self, RecoveryCommandError> {
        let plan: Self = serde_json::from_slice(&read_bounded(path, MAX_PLAN_BYTES)?)
            .map_err(|_| RecoveryCommandError::Parse("plan"))?;
        plan.validate()?;
        Ok(plan)
    }
}

/// The directory holding `path`; a bare file name is in the current directory.
pub(super) fn parent(path: &Path) -> &Path {
    match path.parent() {
        Some(parent) if !parent.as_os_str().is_empty() => parent,
        _ => Path::new("."),
    }
}

/// Opens a regular file without following its final symlink.
fn open_regular(path: &Path) -> Result<File, RecoveryCommandError> {
    let file = OpenOptions::new()
        .read(true)
        .custom_flags(libc::O_NOFOLLOW | libc::O_NONBLOCK)
        .open(path)
        .map_err(|_| RecoveryCommandError::Io("open regular file"))?;
    if !file.metadata().map_err(|_| RecoveryCommandError::Io("file metadata"))?.is_file() {
        return Err(RecoveryCommandError::Parse("file type"));
    }
    Ok(file)
}

/// Reads a regular file with an allocation bound, detecting a concurrent size change.
pub(super) fn read_bounded(path: &Path, limit: u64) -> Result<Vec<u8>, RecoveryCommandError> {
    let file = open_regular(path)?;
    let size = file.metadata().map_err(|_| RecoveryCommandError::Io("file metadata"))?.len();
    if size > limit {
        return Err(RecoveryCommandError::Parse("file size"));
    }
    let mut bytes = Vec::new();
    file.take(limit + 1).read_to_end(&mut bytes).map_err(|_| RecoveryCommandError::Io("read"))?;
    if bytes.len() as u64 != size {
        return Err(RecoveryCommandError::Parse("file size"));
    }
    Ok(bytes)
}

/// Creates a new private (0600) file, writes all of `bytes` and syncs them.
pub(super) fn write_new(path: &Path, bytes: &[u8]) -> Result<(), RecoveryCommandError> {
    let mut file = OpenOptions::new()
        .write(true)
        .create_new(true)
        .mode(0o600)
        .custom_flags(libc::O_NOFOLLOW)
        .open(path)
        .map_err(|_| RecoveryCommandError::Io("create new file"))?;
    file.write_all(bytes)
        .and_then(|()| file.sync_all())
        .map_err(|_| RecoveryCommandError::Io("write and sync"))
}

/// Makes a directory's entries durable.
pub(super) fn sync_dir(path: &Path) -> Result<(), RecoveryCommandError> {
    File::open(path)
        .and_then(|f| f.sync_all())
        .map_err(|_| RecoveryCommandError::Io("sync directory"))
}
