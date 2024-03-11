//SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @title ISigVerifyLib
/// @custom:security-contact security@taiko.xyz
interface ISigVerifyLib {
    enum Algorithm {
        RS256,
        ES256,
        RS1
    }

    function verifyES256Signature(
        bytes memory tbs,
        bytes memory signature,
        bytes memory publicKey
    )
        external
        view
        returns (bool sigValid);
}
