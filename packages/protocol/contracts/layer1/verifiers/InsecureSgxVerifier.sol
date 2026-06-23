// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { SgxVerifier } from "./SgxVerifier.sol";
import { TCBInfoStruct } from "src/layer1/automata-attestation/lib/TCBInfoStruct.sol";

/// @title InsecureSgxVerifier
/// @notice SGX verifier with a lenient TCB-status acceptance policy for testnet/devnet ONLY. In
/// addition to the up-to-date statuses it also accepts out-of-date platforms to preserve liveness on
/// development hardware that lags on microcode/configuration. This MUST NOT be used on mainnet.
/// @custom:security-contact security@taiko.xyz
contract InsecureSgxVerifier is SgxVerifier {
    constructor(
        uint64 _taikoChainId,
        address _owner,
        address _automataDcapAttestation,
        address _registrar
    )
        SgxVerifier(_taikoChainId, _owner, _automataDcapAttestation, _registrar)
    { }

    /// @inheritdoc SgxVerifier
    /// @dev Lenient policy for testnet/devnet ONLY: in addition to the up-to-date statuses (`OK`,
    /// `TCB_SW_HARDENING_NEEDED`) it also accepts `TCB_CONFIGURATION_AND_SW_HARDENING_NEEDED`,
    /// `TCB_OUT_OF_DATE` and `TCB_OUT_OF_DATE_CONFIGURATION_NEEDED` so dev hardware lagging on
    /// microcode/configuration stays usable. This MUST NOT be used on mainnet: out-of-date platforms
    /// may be missing the microcode that patches SGX key-extraction vulnerabilities. It still rejects
    /// `TCB_CONFIGURATION_NEEDED`, `TCB_REVOKED` and `TCB_UNRECOGNIZED`. The policy is expressed
    /// against the attestation's `TCBInfoStruct.TCBStatus` enum so an enum reorder is caught at
    /// compile time.
    function isTcbStatusAccepted(uint8 _status) public pure override returns (bool) {
        return _status == uint8(TCBInfoStruct.TCBStatus.OK)
            || _status == uint8(TCBInfoStruct.TCBStatus.TCB_SW_HARDENING_NEEDED)
            || _status == uint8(TCBInfoStruct.TCBStatus.TCB_CONFIGURATION_AND_SW_HARDENING_NEEDED)
            || _status == uint8(TCBInfoStruct.TCBStatus.TCB_OUT_OF_DATE)
            || _status == uint8(TCBInfoStruct.TCBStatus.TCB_OUT_OF_DATE_CONFIGURATION_NEEDED);
    }
}
