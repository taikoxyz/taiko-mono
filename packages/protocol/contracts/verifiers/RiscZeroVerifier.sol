// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "../common/EssentialContract.sol";
import "../common/LibStrings.sol";
import "../thirdparty/risczero/IRiscZeroVerifier.sol";
import "../L1/ITaikoL1.sol";
import "./IVerifier.sol";
import "./libs/LibPublicInput.sol";

import "forge-std/src/console2.sol";

/// @title RiscZeroVerifier
/// @custom:security-contact security@taiko.xyz
contract RiscZeroVerifier is EssentialContract, IVerifier {
    /// @notice RISC Zero remote verifier contract address, e.g.:
    /// https://sepolia.etherscan.io/address/0x3d24C84FC1A2B26f9229e58ddDf11A8dfba802d0
    IRiscZeroVerifier public receiptVerifier;
    /// @notice Trusted imageId mapping
    mapping(bytes32 imageId => bool trusted) public isImageTrusted;

    bytes private constant __fixed_jounal_header = hex"20000000"; // [32, 0, 0, 0] -- big-endian
        // uint32(32) for hash bytes len

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
        __Essential_init(_owner, _rollupAddressManager);
        receiptVerifier = IRiscZeroVerifier(_receiptVerifier);
    }

    /// @notice Sets/unsets an the imageId as trusted entity
    /// @param _imageId The id of the image.
    /// @param _trusted True if trusted, false otherwise.
    function setImageIdTrusted(bytes32 _imageId, bool _trusted) external onlyOwner {
        isImageTrusted[_imageId] = _trusted;

        emit ImageTrusted(_imageId, _trusted);
    }

    event DebugVerifyProof(bytes32 metaHash, bytes32 journalDigest, bytes32 piHash);

    /// @inheritdoc IVerifier
    function verifyProof(
        Context calldata _ctx,
        TaikoData.Transition calldata _tran,
        TaikoData.TierProof calldata _proof
    )
        external
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
        bytes32 journalDigest = sha256(bytes.concat(__fixed_jounal_header, hash));

        emit DebugVerifyProof(_ctx.metaHash, journalDigest, hash);
        // call risc0 verifier contract
        (bool success,) = address(receiptVerifier).staticcall(
            abi.encodeCall(IRiscZeroVerifier.verify, (seal, imageId, journalDigest))
        );

        if (!success) {
            revert RISC_ZERO_INVALID_PROOF();
        }
    }
}
