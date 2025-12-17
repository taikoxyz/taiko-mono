// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { IProofVerifier } from "./IProofVerifier.sol";
import { LibPublicInput } from "./LibPublicInput.sol";
import { Ownable2Step } from "@openzeppelin/contracts/access/Ownable2Step.sol";
import { IRiscZeroVerifier } from "@risc0/contracts/IRiscZeroVerifier.sol";

/// @title Risc0Verifier
/// @custom:security-contact security@taiko.xyz
contract Risc0Verifier is IProofVerifier, Ownable2Step {
    uint64 public immutable taikoChainId;
    address public immutable riscoGroth16Verifier;

    /// @notice Trusted imageId mapping
    mapping(bytes32 imageId => bool trusted) public isImageTrusted;

    uint256[49] private __gap;

    /// @dev Emitted when a trusted image is set / unset.
    /// @param imageId The id of the image
    /// @param trusted True if trusted, false otherwise
    event ImageTrusted(bytes32 imageId, bool trusted);

    error RISC_ZERO_INVALID_BLOCK_PROOF_IMAGE_ID();
    error RISC_ZERO_INVALID_AGGREGATION_IMAGE_ID();
    error RISC_ZERO_INVALID_PROOF();
    error RISC_ZERO_INVALID_CHAIN_ID();
    error RISC_ZERO_INVALID_GROTH16_VERIFIER();

    constructor(uint64 _taikoChainId, address _riscoGroth16Verifier, address _owner) {
        require(_taikoChainId != 0, RISC_ZERO_INVALID_CHAIN_ID());
        require(_riscoGroth16Verifier != address(0), RISC_ZERO_INVALID_GROTH16_VERIFIER());
        taikoChainId = _taikoChainId;
        riscoGroth16Verifier = _riscoGroth16Verifier;

        _transferOwnership(_owner);
    }

    /// @notice Sets/unsets an the imageId as trusted entity
    /// @param _imageId The id of the image.
    /// @param _trusted True if trusted, false otherwise.
    function setImageIdTrusted(bytes32 _imageId, bool _trusted) external onlyOwner {
        isImageTrusted[_imageId] = _trusted;
        emit ImageTrusted(_imageId, _trusted);
    }

    /// @inheritdoc IProofVerifier
    function verifyProof(
        uint256, /* _proposalAge */
        bytes32 _aggregatedProvingHash,
        bytes calldata _proof
    )
        external
        view
    {
        // Decode will throw if not proper length/encoding
        (bytes memory seal, bytes32 blockImageId, bytes32 aggregationImageId) =
            abi.decode(_proof, (bytes, bytes32, bytes32));

        // Check if the aggregation program is trusted
        require(isImageTrusted[aggregationImageId], RISC_ZERO_INVALID_AGGREGATION_IMAGE_ID());
        // Check if the block proving program is trusted
        require(isImageTrusted[blockImageId], RISC_ZERO_INVALID_BLOCK_PROOF_IMAGE_ID());

        bytes32 publicInput = LibPublicInput.hashPublicInputs(
            _aggregatedProvingHash, address(this), address(0), taikoChainId
        );

        bytes32 r0AggregationPublicInput =
            LibPublicInput.hashZKAggregationPublicInputs(blockImageId, publicInput);

        // journalDigest is the sha256 hash of the hashed public input
        bytes32 journalDigest = sha256(abi.encodePacked(r0AggregationPublicInput));

        // call risc0 verifier contract
        (bool success,) = riscoGroth16Verifier.staticcall(
            abi.encodeCall(IRiscZeroVerifier.verify, (seal, aggregationImageId, journalDigest))
        );
        require(success, RISC_ZERO_INVALID_PROOF());
    }
}
