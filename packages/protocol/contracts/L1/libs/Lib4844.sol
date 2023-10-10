// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

/// @title Lib4844
/// @notice A library for handling EIP-4844 blobs
library Lib4844 {
    address public constant POINT_EVALUATION_PRECOMPILE_ADDRESS = address(10);
    uint256 public constant BLS_MODULUS =
        52_435_875_175_126_190_479_447_740_508_185_965_837_690_552_500_527_637_822_603_658_699_938_581_184_513;
    // versioned hash: first 32 bytes
    // Evaluation point: next 32 bytes
    // Expected output: next 32 bytes
    // input kzg point: next 48 bytes
    // Quotient kzg: next 48 bytes

    error EVAL_POINT_TOO_LARGE();
    error EVAL_FAILED();

    function point_evaluation_precompile(
        bytes32 versionHash,
        uint256 x,
        uint256 y,
        bytes32[2] memory commitment,
        bytes32[2] memory proof
    )
        internal
        view
    {
        if (x >= BLS_MODULUS) revert EVAL_POINT_TOO_LARGE();
        (bool ok,) = POINT_EVALUATION_PRECOMPILE_ADDRESS.staticcall(
            abi.encodePacked(versionHash, x, y, commitment, proof)
        );
        if (!ok) revert EVAL_FAILED();
    }
}
