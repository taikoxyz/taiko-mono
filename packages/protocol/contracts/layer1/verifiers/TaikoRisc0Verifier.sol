// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@risc0/contracts/IRiscZeroVerifier.sol";
import "src/shared/common/EssentialContract.sol";
import "src/shared/libs/LibNames.sol";
import "../based/ITaikoInbox.sol";
import "./LibPublicInput.sol";
import "./IVerifier.sol";

/// @title TaikoRisc0Verifier
/// @custom:security-contact security@taiko.xyz
contract TaikoRisc0Verifier is EssentialContract, IVerifier {
    bytes32 internal constant RISCZERO_GROTH16_VERIFIER = bytes32("risc0_groth16_verifier");

    // [32, 0, 0, 0] -- big-endian uint32(32) for hash bytes len
    bytes private constant FIXED_JOURNAL_HEADER = hex"20000000";
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

    constructor(uint64 _taikoChainId, address _riscoGroth16Verifier) EssentialContract() {
        taikoChainId = _taikoChainId;
        riscoGroth16Verifier = _riscoGroth16Verifier;
    }

    /// @notice Initializes the contract with the provided address manager.
    /// @param _owner The address of the owner.
    function init(address _owner) external initializer {
        __Essential_init(_owner);
    }

    /// @notice Sets/unsets an the imageId as trusted entity
    /// @param _imageId The id of the image.
    /// @param _trusted True if trusted, false otherwise.
    function setImageIdTrusted(bytes32 _imageId, bool _trusted) external onlyOwner {
        isImageTrusted[_imageId] = _trusted;
        emit ImageTrusted(_imageId, _trusted);
    }

    /// @inheritdoc IVerifier
    function verifyProof(Context[] calldata _ctxs, bytes calldata _proof) external view {
        // Decode will throw if not proper length/encoding
        (bytes memory seal, bytes32 blockImageId, bytes32 aggregationImageId) =
            abi.decode(_proof, (bytes, bytes32, bytes32));

        // Check if the aggregation program is trusted
        require(isImageTrusted[aggregationImageId], RISC_ZERO_INVALID_AGGREGATION_IMAGE_ID());
        // Check if the block proving program is trusted
        require(isImageTrusted[blockImageId], RISC_ZERO_INVALID_BLOCK_PROOF_IMAGE_ID());

        // Collect public inputs
        bytes32[] memory publicInputs = new bytes32[](_ctxs.length + 1);
        // First public input is the block proving program key
        publicInputs[0] = blockImageId;
        // All other inputs are the block program public inputs (a single 32 byte value)
        uint256 size = _ctxs.length;
        for (uint256 i; i < size; ++i) {
            publicInputs[i + 1] = LibPublicInput.hashPublicInputs(
                _ctxs[i].transition, address(this), address(0), _ctxs[i].metaHash, taikoChainId
            );
        }

        // journalDigest is the sha256 hash of the hashed public input
        bytes32 journalDigest = sha256(abi.encodePacked(publicInputs));

        // call risc0 verifier contract
        (bool success,) = riscoGroth16Verifier.staticcall(
            abi.encodeCall(IRiscZeroVerifier.verify, (seal, aggregationImageId, journalDigest))
        );
        require(success, RISC_ZERO_INVALID_PROOF());
    }
}
