// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "../verifiers/compose/ZkVMVerifier.sol";

/// @title MainnetZkVMVerifier
/// @custom:security-contact security@taiko.xyz
contract MainnetZkVMVerifier is ZkVMVerifier {
    constructor() ZkVMVerifier(address(0), address(0)) { }

    /// @inheritdoc ZkVMVerifier
    // TODO(daniel|smtm): Add RiscZero verifier
    function risc0Verifier() public pure override returns (address) {
        return address(0x1);
    }

    /// @inheritdoc ZkVMVerifier
    // TODO(daniel|smtm): Add RiscZero verifier
    function sp1Verifier() public pure override returns (address) {
        return address(0x2);
    }
}
