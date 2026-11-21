//! The complete Unzen driver's finalized origin handoff and the L2 SignalService proxy whose
//! implementation slot authenticates the switch (SYNC-9-5a).

use alloy_primitives::{Address, B256, b256};

/// EIP-1967 implementation storage key: keccak256("eip1967.proxy.implementation") - 1.
pub(crate) const IMPLEMENTATION_SLOT: B256 =
    b256!("360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc");

/// The L2 SignalService proxy predeploy: the L2 chain id's decimal digits, zero padding and
/// `5`, as `0x1670000000000000000000000000000000000005` on mainnet.
pub fn l2_signal_service_address(l2_chain_id: u64) -> Address {
    let prefix = l2_chain_id.to_string();
    format!("0x{prefix}{}5", "0".repeat(39 - prefix.len()))
        .parse()
        .expect("a u64 chain id leaves room for the predeploy suffix")
}

/// The last Unzen block derived by the complete driver from the node's own finalized L1.
/// This is an in-process attestation, never peer or operator input. Its producer must establish
/// that proposals are closed at the configured Etna cutoff and execute every accepted proposal,
/// including forced inclusions, before handing over. ABCI independently checks its finalized L1
/// identity, the authenticated start record, the EL header and the L2 SignalService
/// implementation proof.
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

#[cfg(test)]
mod tests {
    use alloy_primitives::address;

    use super::*;

    #[test]
    fn l2_signal_service_address_matches_the_deployed_proxies() {
        // Mainnet and Hoodi L2 SignalService proxies, from the deployment logs.
        assert_eq!(
            l2_signal_service_address(167_000),
            address!("0x1670000000000000000000000000000000000005")
        );
        assert_eq!(
            l2_signal_service_address(167_013),
            address!("0x1670130000000000000000000000000000000005")
        );
    }
}
