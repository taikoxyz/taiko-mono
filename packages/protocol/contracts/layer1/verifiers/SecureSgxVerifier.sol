// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { SgxVerifier } from "./SgxVerifier.sol";
import { TCBStatus } from "@automata-network/on-chain-pccs/helpers/FmspcTcbHelper.sol";

/// @title SecureSgxVerifier
/// @notice SGX verifier with the strict TCB-status acceptance policy intended for mainnet.
/// @custom:security-contact security@taiko.xyz
contract SecureSgxVerifier is SgxVerifier {
    constructor(
        uint64 _taikoChainId,
        address _owner,
        address _automataDcapAttestation,
        address _registrar
    )
        SgxVerifier(_taikoChainId, _owner, _automataDcapAttestation, _registrar)
    { }

    /// @dev Strict mainnet policy: accept only TCB statuses that indicate an up-to-date platform —
    /// `OK` and `TCB_SW_HARDENING_NEEDED`. The latter's mitigation lives in the enclave software,
    /// which is pinned by the MRENCLAVE allowlist, so it is safe to accept on the allowlisted
    /// enclave. Every other status is rejected — notably `OUT_OF_DATE` /
    /// `OUT_OF_DATE_CONFIGURATION_NEEDED`, where the platform is missing the microcode that patches
    /// SGX key-extraction vulnerabilities (so the in-enclave signing key could be extractable), plus
    /// the configuration-needed and revoked/unrecognized statuses. The policy is expressed against
    /// Automata's `TCBStatus` enum (the same pinned on-chain-pccs package the attestation entrypoint
    /// uses to produce `tcbStatus`), so a dependency bump that reorders the enum is caught at
    /// compile time.
    /// @param _status The TCB status code from the attestation output.
    /// @return Whether the status is accepted.
    function _isTcbStatusAccepted(uint8 _status) internal pure override returns (bool) {
        return _status == uint8(TCBStatus.OK) || _status == uint8(TCBStatus.TCB_SW_HARDENING_NEEDED);
    }
}
