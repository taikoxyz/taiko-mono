//! The complete Unzen driver's finalized origin handoff and the Anchor implementation slot.

use alloy_primitives::{B256, b256};

/// EIP-1967 implementation storage key: keccak256("eip1967.proxy.implementation") - 1.
pub(crate) const ANCHOR_IMPLEMENTATION_SLOT: B256 =
    b256!("360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc");

/// The last Unzen block derived by the complete driver from the node's own finalized L1.
/// This is an in-process attestation, never peer or operator input. Its producer must establish
/// that proposals are closed at the configured Etna cutoff and execute every accepted proposal,
/// including forced inclusions, before handing over. ABCI independently checks its finalized L1
/// identity, the authenticated start record, the EL header and the Anchor implementation proof.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct SwitchOrigin {
    /// Own finalized L1 observation that established proposal closure and completed derivation.
    pub l1_number: u64,
    /// Canonical hash of that same finalized L1 observation.
    pub l1_hash: B256,
    /// Last fully derived Unzen execution height, which must equal the Etna start S.
    pub height: u64,
    /// Hash of that last fully derived Unzen block, which must equal ELHash(S).
    pub hash: B256,
}
