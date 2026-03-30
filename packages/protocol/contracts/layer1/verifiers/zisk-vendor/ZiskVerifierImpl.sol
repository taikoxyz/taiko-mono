// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.20;

import { IZiskVerifier } from "./IZiskVerifier.sol";
import { PlonkVerifier } from "./PlonkVerifier.sol";

/// @title Zisk Verifier
/// @author SilentSig
/// @notice This contracts implements a solidity verifier for Zisk.
contract ZiskVerifierImpl is PlonkVerifier, IZiskVerifier {
    /// @notice Thrown when the proof is invalid.
    error InvalidProof();

    function VERSION() external pure returns (string memory) {
        return "v0.16.0";
    }

    function getRootCVadcopFinal() external pure returns (uint64[4] memory) {
        return [
            uint64(9_211_010_158_316_595_036),
            uint64(7_055_235_338_110_277_438),
            uint64(2_391_371_252_028_311_145),
            uint64(10_691_781_997_660_262_077)
        ];
    }

    // Modulus zkSNARK
    uint256 internal constant _RFIELD =
        21_888_242_871_839_275_222_246_405_745_257_275_088_548_364_400_416_034_343_698_204_186_575_808_495_617;

    /// @notice Hashes the public values to a field elements inside Bn254.
    /// @param programVK The verification key for the RISC-V program.
    /// @param rootCVadcopFinal The rootC value for the Vadcop final.
    /// @param publicValues The public values.
    function hashPublicValues(
        uint64[4] calldata programVK,
        uint64[4] calldata rootCVadcopFinal,
        bytes calldata publicValues
    )
        public
        pure
        returns (uint256)
    {
        return uint256(
            sha256(
                abi.encodePacked(
                    bytes8(programVK[0]),
                    bytes8(programVK[1]),
                    bytes8(programVK[2]),
                    bytes8(programVK[3]),
                    publicValues,
                    bytes8(rootCVadcopFinal[0]),
                    bytes8(rootCVadcopFinal[1]),
                    bytes8(rootCVadcopFinal[2]),
                    bytes8(rootCVadcopFinal[3])
                )
            )
        ) % _RFIELD;
    }

    /// @notice Verifies a proof with given public values and vkey.
    /// @param programVK The verification key for the RISC-V program.
    /// @param rootCVadcopFinal The rootC value for the Vadcop final.
    /// @param publicValues The public values encoded as bytes.
    /// @param proofBytes The proof of the program execution the Zisk zkVM encoded as bytes.
    function verifySnarkProof(
        uint64[4] calldata programVK,
        uint64[4] calldata rootCVadcopFinal,
        bytes calldata publicValues,
        bytes calldata proofBytes
    )
        external
        view
    {
        uint256 publicValuesDigest = hashPublicValues(programVK, rootCVadcopFinal, publicValues);

        uint256[24] memory proofDecoded = abi.decode(proofBytes, (uint256[24]));

        bool success = this.verifyProof(proofDecoded, [publicValuesDigest]);

        if (!success) {
            revert InvalidProof();
        }
    }
}
