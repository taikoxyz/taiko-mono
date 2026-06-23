// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { BaseSgxVerifier } from "./BaseSgxVerifier.sol";
import { TCBStatus } from "@automata-network/on-chain-pccs/helpers/FmspcTcbHelper.sol";

/// @title TestnetSgxVerifier
/// @notice SGX verifier with a lenient TCB-status acceptance policy for testnet/devnet only.
/// @custom:security-contact security@taiko.xyz
contract TestnetSgxVerifier is BaseSgxVerifier {
    constructor(
        uint64 _taikoChainId,
        address _owner,
        address _automataDcapAttestation,
        address _registrar
    )
        BaseSgxVerifier(_taikoChainId, _owner, _automataDcapAttestation, _registrar)
    { }

    /// @dev Lenient policy for testnet/devnet ONLY: in addition to the up-to-date statuses, it also
    /// accepts out-of-date platforms (`TCB_OUT_OF_DATE` / `TCB_OUT_OF_DATE_CONFIGURATION_NEEDED`)
    /// and `TCB_CONFIGURATION_AND_SW_HARDENING_NEEDED` to preserve liveness on development hardware
    /// that lags on microcode/configuration. This MUST NOT be used on mainnet: out-of-date platforms
    /// may be missing the microcode that patches SGX key-extraction vulnerabilities. It still rejects
    /// `TCB_CONFIGURATION_NEEDED`, `TCB_REVOKED`, and `TCB_UNRECOGNIZED`. The policy is expressed
    /// against Automata's `TCBStatus` enum (the same pinned on-chain-pccs package the attestation
    /// entrypoint uses to produce `tcbStatus`), so a dependency bump that reorders the enum is caught
    /// at compile time.
    /// @param _status The TCB status code from the attestation output.
    /// @return Whether the status is accepted.
    function _isTcbStatusAccepted(uint8 _status) internal pure override returns (bool) {
        return _status == uint8(TCBStatus.OK) || _status == uint8(TCBStatus.TCB_SW_HARDENING_NEEDED)
            || _status == uint8(TCBStatus.TCB_CONFIGURATION_AND_SW_HARDENING_NEEDED)
            || _status == uint8(TCBStatus.TCB_OUT_OF_DATE)
            || _status == uint8(TCBStatus.TCB_OUT_OF_DATE_CONFIGURATION_NEEDED);
    }
}
