//! Pure genesis verification shared by the document builder and ABCI initialization.

use alloy_primitives::B256;

use super::GenesisError;
use crate::{
    config::ChainParams,
    l1::{RawL1Header, verify_genesis_inbox, witness::anchor_state},
    types::{AccountWitness, AnchorState, GenesisRecord},
};

/// Authenticated bootstrap facts of the deployment.
pub(crate) struct GenesisContext {
    /// The initialized Inbox's genesis record, with the Etna start height S.
    pub(crate) genesis: GenesisRecord,
    /// The L1 initialization header and its proven Inbox facts.
    pub(crate) anchor: AnchorState,
    /// The fourth word of generation 0's origin record: the hash of the fallback key list whose
    /// keys sign S + 1 and S + 2, each at power 1.
    pub(crate) fallback_keys_hash: B256,
}

/// Verifies the Inbox proofs, the initialization header's number and generation zero.
///
/// The caller authenticates the header's canonicality and finality independently. No L1 or EL
/// operations occur here. The origin record must bind the same L2 start height S.
pub(crate) fn verify_context(
    header: &RawL1Header,
    inbox: &AccountWitness,
    params: &ChainParams,
) -> Result<GenesisContext, GenesisError> {
    let context = verify_deployment_context(header, inbox, params)?;
    if context.anchor.inbox.recovery_generation != 0 {
        return Err(GenesisError::UnsupportedRecovery("generation must be zero".into()));
    }
    Ok(context)
}

/// Verifies immutable deployment facts, allowing recovery in the initialization L1 block.
///
/// End-of-block L1_0 state may already include governance recovery. Generation-zero startup
/// must use `verify_context`; recovery separately authenticates its requested generation and R.
/// The Inbox's configuration hash (slot 269) must be the one of the built-in L2 chain id,
/// staking proxy and U ([`ChainParams::config_hash`]), and generation 0's origin record must
/// name `L1_0` with its timestamp. Canonicality and finality remain the caller's responsibility.
pub(crate) fn verify_deployment_context(
    header: &RawL1Header,
    inbox: &AccountWitness,
    params: &ChainParams,
) -> Result<GenesisContext, GenesisError> {
    let (genesis, facts, origin) = verify_genesis_inbox(header.state_root(), inbox, params.inbox)?;
    if header.number() != genesis.l1_0 {
        return Err(GenesisError::InitializationMismatch {
            l1_0: header.number(),
            proven: genesis.l1_0,
        });
    }
    if origin.l1_timestamp != header.timestamp() {
        return Err(GenesisError::Witness(Box::new(crate::l1::WitnessError::InvalidOrigin)));
    }
    let local = params.config_hash();
    if local != genesis.config_hash {
        return Err(GenesisError::ConfigMismatch { local, proven: genesis.config_hash });
    }
    Ok(GenesisContext {
        genesis,
        anchor: anchor_state(header, facts),
        fallback_keys_hash: origin.fallback_keys_hash,
    })
}
