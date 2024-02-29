// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @title Lib4844
/// @notice A library for handling EIP-4844 blobs
/// @dev `solc contracts/libs/Lib4844.sol --ir > contracts/libs/Lib4844.yul`
/// @custom:security-contact security@taiko.xyz
library Lib4844 {
    /// @notice The address of the point evaluation precompile
    address public constant POINT_EVALUATION_PRECOMPILE_ADDRESS = address(0x0A);

    /// @notice The number of field elements per blob
    uint32 public constant FIELD_ELEMENTS_PER_BLOB = 4096;

    /// @notice The modulus of the BLS curve
    uint256 public constant BLS_MODULUS =
        52_435_875_175_126_190_479_447_740_508_185_965_837_690_552_500_527_637_822_603_658_699_938_581_184_513;

    error EVAL_FAILED_1();
    error EVAL_FAILED_2();
    error POINT_X_TOO_LARGE();
    error POINT_Y_TOO_LARGE();

    /// @notice Evaluates the 4844 point using the precompile.
    /// @param blobHash The versioned hash
    /// @param x The evaluation point
    /// @param y The expected output
    /// @param commitment The input kzg point
    /// @param pointProof The quotient kzg
    function evaluatePoint(
        bytes32 blobHash,
        uint256 x,
        uint256 y,
        bytes1[48] memory commitment,
        bytes1[48] memory pointProof
    )
        internal
        view
    {
        if (x >= BLS_MODULUS) revert POINT_X_TOO_LARGE();
        if (y >= BLS_MODULUS) revert POINT_Y_TOO_LARGE();

        (bool ok, bytes memory ret) = POINT_EVALUATION_PRECOMPILE_ADDRESS.staticcall(
            abi.encodePacked(blobHash, x, y, commitment, pointProof)
        );

        if (!ok) revert EVAL_FAILED_1();

        if (ret.length != 64) revert EVAL_FAILED_2();

        bytes32 first;
        bytes32 second;
        assembly {
            first := mload(add(ret, 32))
            second := mload(add(ret, 64))
        }
        if (uint256(first) != FIELD_ELEMENTS_PER_BLOB || uint256(second) != BLS_MODULUS) {
            revert EVAL_FAILED_2();
        }
    }
}
