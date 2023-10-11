// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

/// @title Lib4844
/// @notice A library for handling EIP-4844 blobs
library Lib4844 {
    address public constant POINT_EVALUATION_PRECOMPILE_ADDRESS = address(0x0A);
    uint32 public constant FIELD_ELEMENTS_PERBLOB = 4096;
    uint256 public constant BLS_MODULUS =
        52_435_875_175_126_190_479_447_740_508_185_965_837_690_552_500_527_637_822_603_658_699_938_581_184_513;

    bytes1 public constant BLOBHASH = bytes1(0x49);

    error POINT_X_TOO_LARGE();
    error POINT_Y_TOO_LARGE();
    error EVAL_FAILED();

    /// @param versionHash The versioned hash
    /// @param x The evaluation point
    /// @param y The expected output
    /// @param commitment The input kzg point
    /// @param proof The quotient kzg
    function point_evaluation_precompile(
        bytes32 versionHash,
        uint256 x,
        uint256 y,
        bytes1[48] memory commitment,
        bytes1[48] memory proof
    )
        internal
        view
    {
        if (x >= FIELD_ELEMENTS_PERBLOB) revert POINT_X_TOO_LARGE();
        if (y >= BLS_MODULUS) revert POINT_Y_TOO_LARGE();

        (bool ok,) = POINT_EVALUATION_PRECOMPILE_ADDRESS.staticcall(
            abi.encodePacked(versionHash, x, y, commitment, proof)
        );
        if (!ok) revert EVAL_FAILED();
    }

    function blobhash(uint256 index) internal pure returns (bytes32) {
        // bytes32 result;
        // assembly {
        //       let idx := index
        //     // Opcode for BLOBHASH (replace HASH_OPCODE_BYTE with the actual
        // opcode)
        //     let opcode := 0x49
        //     push(0x49)
        //     // push(opcode)
        //     // call
        //     result := mload(add(0x20, 0))
        // }
        // return result;
    }
}
