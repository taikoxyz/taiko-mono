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
    /// @dev Strict policy: accept the TCB statuses whose platform microcode is up to date — `OK`,
    /// `TCB_SW_HARDENING_NEEDED` and `TCB_CONFIGURATION_AND_SW_HARDENING_NEEDED` (their mitigations
    /// live in configuration / enclave software pinned by the MRENCLAVE allowlist, not in microcode).
    /// The out-of-date statuses (`TCB_OUT_OF_DATE`, `TCB_OUT_OF_DATE_CONFIGURATION_NEEDED`) are
    /// rejected, where the platform may be missing the microcode that patches SGX key-extraction
    /// vulnerabilities (so the in-enclave signing key could be extractable); `TCB_CONFIGURATION_NEEDED`,
    /// `TCB_REVOKED` and `TCB_UNRECOGNIZED` are rejected too. The policy is expressed against the
    /// attestation's `TCBInfoStruct.TCBStatus` enum so an enum reorder is caught at compile time.
    function isTcbStatusAccepted(uint8 _status) public pure override returns (bool) {
        return _status == uint8(TCBInfoStruct.TCBStatus.OK)
            || _status == uint8(TCBInfoStruct.TCBStatus.TCB_SW_HARDENING_NEEDED)
            || _status == uint8(TCBInfoStruct.TCBStatus.TCB_CONFIGURATION_AND_SW_HARDENING_NEEDED);
    }
}
