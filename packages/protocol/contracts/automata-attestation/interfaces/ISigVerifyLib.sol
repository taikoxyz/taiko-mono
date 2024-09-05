//SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

/// @title ISigVerifyLib
/// @custom:security-contact security@taiko.xyz
interface ISigVerifyLib {
    function verifyES256Signature(
        bytes memory tbs,
        bytes memory signature,
        bytes memory publicKey
    )
        external
        view
        returns (bool sigValid);
}
