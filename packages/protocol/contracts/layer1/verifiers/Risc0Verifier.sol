// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@risc0/contracts/IRiscZeroVerifier.sol";
import "src/shared/common/EssentialContract.sol";
import "src/shared/common/LibStrings.sol";
import "../based/ITaikoL1.sol";
import "./LibPublicInput.sol";
import "./IVerifier.sol";

/// @title Risc0Verifier
/// @custom:security-contact security@taiko.xyz
contract Risc0Verifier is EssentialContract, IVerifier {
    // [32, 0, 0, 0] -- big-endian uint32(32) for hash bytes len
    bytes private constant FIXED_JOURNAL_HEADER = hex"20000000";

    /// @notice Trusted imageId mapping
    mapping(bytes32 imageId => bool trusted) public isImageTrusted;

    uint256[49] private __gap;

    /// @dev Emitted when a trusted image is set / unset.
    /// @param imageId The id of the image
    /// @param trusted True if trusted, false otherwise
    event ImageTrusted(bytes32 imageId, bool trusted);

    /// @dev Emitted when a proof is verified
    event ProofVerified(bytes32 metaHash, bytes32 publicInputHash);

    error RISC_ZERO_INVALID_BLOCK_PROOF_IMAGE_ID();
    error RISC_ZERO_INVALID_AGGREGATION_IMAGE_ID();
    error RISC_ZERO_INVALID_PROOF();

    /// @notice Initializes the contract with the provided address manager.
    /// @param _owner The address of the owner.
    /// @param _rollupAddressManager The address of the AddressManager.
    function init(address _owner, address _rollupAddressManager) external initializer {
        __Essential_init(_owner, _rollupAddressManager);
    }

    /// @notice Sets/unsets an the imageId as trusted entity
    /// @param _imageId The id of the image.
    /// @param _trusted True if trusted, false otherwise.
    function setImageIdTrusted(bytes32 _imageId, bool _trusted) external onlyOwner {
        isImageTrusted[_imageId] = _trusted;

        emit ImageTrusted(_imageId, _trusted);
    }

    /// @inheritdoc IVerifier
    function verifyProof(
        Context calldata _ctx,
        TaikoData.Transition calldata _tran,
        TaikoData.TierProof calldata _proof
    )
        external
        view
    {
        // Do not run proof verification to contest an existing proof
        if (_ctx.isContesting) return;

        // Decode will throw if not proper length/encoding
        (bytes memory seal, bytes32 imageId) = abi.decode(_proof.data, (bytes, bytes32));

        if (!isImageTrusted[imageId]) {
            revert RISC_ZERO_INVALID_BLOCK_PROOF_IMAGE_ID();
        }

        bytes32 publicInputHash = LibPublicInput.hashPublicInputs(
            _tran, address(this), address(0), _ctx.prover, _ctx.metaHash, taikoChainId()
        );

        // journalDigest is the sha256 hash of the hashed public input
        bytes32 journalDigest = sha256(bytes.concat(FIXED_JOURNAL_HEADER, publicInputHash));

        // call risc0 verifier contract
        (bool success,) = resolve(LibStrings.B_RISCZERO_GROTH16_VERIFIER, false).staticcall(
            abi.encodeCall(IRiscZeroVerifier.verify, (seal, imageId, journalDigest))
        );
        if (!success) {
            revert RISC_ZERO_INVALID_PROOF();
        }
    }

    /// @inheritdoc IVerifier
    function verifyBatchProof(
        ContextV2[] calldata _ctxs,
        TaikoData.TierProof calldata _proof
    )
        external
    {
        // Decode will throw if not proper length/encoding
        (bytes memory seal, bytes32 blockImageId, bytes32 aggregationImageId) =
            abi.decode(_proof.data, (bytes, bytes32, bytes32));

        // Check if the aggregation program is trusted
        if (!isImageTrusted[aggregationImageId]) {
            revert RISC_ZERO_INVALID_AGGREGATION_IMAGE_ID();
        }
        // Check if the block proving program is trusted
        if (!isImageTrusted[blockImageId]) {
            revert RISC_ZERO_INVALID_BLOCK_PROOF_IMAGE_ID();
        }

        // Collect public inputs
        bytes32[] memory publicInputs = new bytes32[](_ctxs.length + 1);
        // First public input is the block proving program key
        publicInputs[0] = blockImageId;
        // All other inputs are the block program public inputs (a single 32 byte value)
        for (uint256 i; i < _ctxs.length; ++i) {
            publicInputs[i + 1] = LibPublicInput.hashPublicInputs(
                _ctxs[i].tran,
                address(this),
                address(0),
                _ctxs[i].prover,
                _ctxs[i].metaHash,
                taikoChainId()
            );
            emit ProofVerified(_ctxs[i].metaHash, publicInputs[i + 1]);
        }

        // journalDigest is the sha256 hash of the hashed public input
        bytes32 journalDigest = sha256(abi.encodePacked(publicInputs));

        // call risc0 verifier contract
        (bool success,) = resolve(LibStrings.B_RISCZERO_GROTH16_VERIFIER, false).staticcall(
            abi.encodeCall(IRiscZeroVerifier.verify, (seal, aggregationImageId, journalDigest))
        );
        if (!success) {
            revert RISC_ZERO_INVALID_PROOF();
        }
    }

    function taikoChainId() internal view virtual returns (uint64) {
        return ITaikoL1(resolve(LibStrings.B_TAIKO, false)).getConfig().chainId;
    }
}
