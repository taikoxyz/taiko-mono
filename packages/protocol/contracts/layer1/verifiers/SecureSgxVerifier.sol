// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { SgxVerifier } from "./SgxVerifier.sol";
import { TCBInfoStruct } from "src/layer1/automata-attestation/lib/TCBInfoStruct.sol";

/// @title SecureSgxVerifier
/// @notice SGX verifier with the strict TCB-status acceptance policy intended for mainnet/production.
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

    /// @inheritdoc SgxVerifier
    /// @dev Strict policy: accept only TCB statuses that indicate an up-to-date platform — `OK` and
    /// `TCB_SW_HARDENING_NEEDED`, whose mitigation lives in the enclave software (pinned by the
    /// MRENCLAVE allowlist), so it is safe to accept. Every other status is rejected, notably the
    /// out-of-date statuses where the platform may be missing the microcode that patches SGX
    /// key-extraction vulnerabilities (so the in-enclave signing key could be extractable). The
    /// policy is expressed against the attestation's `TCBInfoStruct.TCBStatus` enum so an enum
    /// reorder is caught at compile time.
    function isTcbStatusAccepted(uint8 _status) public pure override returns (bool) {
        return _status == uint8(TCBInfoStruct.TCBStatus.OK)
            || _status == uint8(TCBInfoStruct.TCBStatus.TCB_SW_HARDENING_NEEDED);
    }
}
