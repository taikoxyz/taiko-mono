// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "../common/EssentialContract.sol";
import "../L1/ITaikoL1.sol";
import "./IVerifier.sol";
import "./libs/LibPublicInputHash.sol";

import "../thirdparty/risczero/IRiscZeroRemoteVerifier.sol";

/// @title RiscZeroVerifier
/// @custom:security-contact security@taiko.xyz
contract RiscZeroVerifier is EssentialContract, IVerifier {
    /// @notice RISC Zero verifier contract address.
    IRiscZeroRemoteVerifier public riscZeroVerifier;
    /// @notice Trusted imageId mapping
    mapping(bytes32 imageId => bool trusted) public isImageTrusted;

    uint256[48] private __gap;

    /// @dev Emitted when a trusted image is set / unset.
    /// @param imageId The id of the image
    /// @param trusted The block's assigned prover.
    event SetImageTrusted(bytes32 imageId, bool trusted);

    error RISC_ZERO_INVALID_IMAGE_ID();
    error RISC_ZERO_INVALID_PROOF();

    /// @notice Initializes the contract with the provided address manager.
    /// @param _owner The address of the owner.
    /// @param _addressManager The address of the AddressManager.
    /// @param _riscZeroVerifier The address of the risc zero verifier contract.
    function init(
        address _owner,
        address _addressManager,
        address _riscZeroVerifier
    )
        external
        initializer
    {
        __Essential_init(_owner, _addressManager);
        riscZeroVerifier = IRiscZeroRemoteVerifier(_riscZeroVerifier);
    }

    /// @notice Sets/unsets an the imageId as trusted entity
    /// @param _imageId The id of the image.
    /// @param _trusted True if trusted, false otherwise.
    function setImageIdTrusted(bytes32 _imageId, bool _trusted) external onlyOwner {
        isImageTrusted[_imageId] = _trusted;

        emit SetImageTrusted(_imageId, _trusted);
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
        (bytes memory seal, bytes32 imageId, bytes32 postStateDigest) =
            abi.decode(_proof.data, (bytes, bytes32, bytes32));

        if (!isImageTrusted[imageId]) {
            revert RISC_ZERO_INVALID_IMAGE_ID();
        }

        uint64 chainId = ITaikoL1(resolve("taiko", false)).getConfig().chainId;
        bytes32 hash = LibPublicInputHash.hashPublicInputs(
            _tran, address(this), address(0), _ctx.prover, _ctx.metaHash, chainId
        );

        // journalDigest is the sha256 hash of the hashed public input
        bytes32 journalDigest = sha256(bytes.concat(hash));

        if (!riscZeroVerifier.verify(seal, imageId, postStateDigest, journalDigest)) {
            revert RISC_ZERO_INVALID_PROOF();
        }
    }
}
