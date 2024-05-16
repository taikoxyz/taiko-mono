// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "../common/EssentialContract.sol";
import "../common/LibStrings.sol";
import "../thirdparty/risczero/IRiscZeroReceiptVerifier.sol";
import "../L1/ITaikoL1.sol";
import "./IVerifier.sol";
import "./libs/LibPublicInput.sol";

/// @title RiscZeroVerifier
/// @custom:security-contact security@taiko.xyz
contract RiscZeroVerifier is EssentialContract, IVerifier {
    /// @notice RISC Zero remote verifier contract address, e.g.:
    /// https://sepolia.etherscan.io/address/0x83c2e9cd64b2a16d3908e94c7654f3864212e2f8
    IRiscZeroReceiptVerifier public receiptVerifier;
    /// @notice Trusted imageId mapping
    mapping(bytes32 imageId => bool trusted) public isImageTrusted;

    uint256[48] private __gap;

    /// @dev Emitted when a trusted image is set / unset.
    /// @param imageId The id of the image
    /// @param trusted True if trusted, false otherwise
    event ImageTrusted(bytes32 imageId, bool trusted);

    error RISC_ZERO_INVALID_IMAGE_ID();
    error RISC_ZERO_INVALID_PROOF();

    /// @notice Initializes the contract with the provided address manager.
    /// @param _owner The address of the owner.
    /// @param _addressManager The address of the AddressManager.
    /// @param _receiptVerifier The address of the risc zero receipt verifier contract.
    function init(
        address _owner,
        address _addressManager,
        address _receiptVerifier
    )
        external
        initializer
    {
        __Essential_init(_owner, _addressManager);
        receiptVerifier = IRiscZeroReceiptVerifier(_receiptVerifier);
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
        (bytes memory seal, bytes32 imageId, bytes32 postStateDigest) =
            abi.decode(_proof.data, (bytes, bytes32, bytes32));

        if (!isImageTrusted[imageId]) {
            revert RISC_ZERO_INVALID_IMAGE_ID();
        }

        uint64 chainId = ITaikoL1(resolve(LibStrings.B_TAIKO, false)).getConfig().chainId;
        bytes32 hash = LibPublicInput.hashPublicInputs(
            _tran, address(this), address(0), _ctx.prover, _ctx.metaHash, chainId
        );

        // journalDigest is the sha256 hash of the hashed public input
        bytes32 journalDigest = sha256(bytes.concat(hash));

        if (!receiptVerifier.verify(seal, imageId, postStateDigest, journalDigest)) {
            revert RISC_ZERO_INVALID_PROOF();
        }
    }
}
