// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@sp1-contracts/src/ISP1Verifier.sol";
import "src/shared/common/EssentialContract.sol";
import "src/shared/libs/LibNames.sol";
import "../based/ITaikoInbox.sol";
import "./LibPublicInput.sol";
import "./IVerifier.sol";

/// @title TaikoSP1Verifier
/// @custom:security-contact security@taiko.xyz
contract TaikoSP1Verifier is EssentialContract, IVerifier {
    bytes32 internal constant SP1_REMOTE_VERIFIER = bytes32("sp1_remote_verifier");

    uint64 public immutable taikoChainId;
    address public immutable sp1RemoteVerifier;

    /// @notice The verification keys mappings for the proving programs.
    mapping(bytes32 provingProgramVKey => bool trusted) public isProgramTrusted;

    uint256[49] private __gap;

    /// @dev Emitted when a trusted image is set / unset.
    /// @param programVKey The id of the image
    /// @param trusted The block's assigned prover.
    event ProgramTrusted(bytes32 programVKey, bool trusted);

    error SP1_INVALID_PROGRAM_VKEY();
    error SP1_INVALID_AGGREGATION_VKEY();
    error SP1_INVALID_PARAMS();
    error SP1_INVALID_PROOF();

    constructor(uint64 _taikoChainId, address _sp1RemoteVerifier) EssentialContract() {
        taikoChainId = _taikoChainId;
        sp1RemoteVerifier = _sp1RemoteVerifier;
    }

    /// @notice Initializes the contract with the provided address manager.
    /// @param _owner The address of the owner.
    function init(address _owner) external initializer {
        __Essential_init(_owner);
    }

    /// @notice Sets/unsets an the program's verification key as trusted entity
    /// @param _programVKey The verification key of the program.
    /// @param _trusted True if trusted, false otherwise.
    function setProgramTrusted(bytes32 _programVKey, bool _trusted) external onlyOwner {
        isProgramTrusted[_programVKey] = _trusted;
        emit ProgramTrusted(_programVKey, _trusted);
    }

    /// @inheritdoc IVerifier
    function verifyProof(Context[] calldata _ctxs, bytes calldata _proof) external view {
        require(_ctxs.length != 0 && _proof.length > 64, SP1_INVALID_PARAMS());
        // Extract the necessary data
        bytes32 aggregationProgram = bytes32(_proof[0:32]);
        bytes32 blockProvingProgram = bytes32(_proof[32:64]);

        // Check if the aggregation program is trusted
        require(isProgramTrusted[aggregationProgram], SP1_INVALID_AGGREGATION_VKEY());
        // Check if the block proving program is trusted
        require(isProgramTrusted[blockProvingProgram], SP1_INVALID_PROGRAM_VKEY());

        // Collect public inputs
        bytes32[] memory publicInputs = new bytes32[](_ctxs.length + 1);
        // First public input is the block proving program key
        publicInputs[0] = blockProvingProgram;
        // All other inputs are the block program public inputs (a single 32 byte value)

        uint256 size = _ctxs.length;
        for (uint256 i; i < size; ++i) {
            publicInputs[i + 1] = LibPublicInput.hashPublicInputs(
                _ctxs[i].transition, address(this), address(0), _ctxs[i].metaHash, taikoChainId
            );
        }

        // _proof[64:] is the succinct's proof position
        (bool success,) = sp1RemoteVerifier.staticcall(
            abi.encodeCall(
                ISP1Verifier.verifyProof,
                (aggregationProgram, abi.encodePacked(publicInputs), _proof[64:])
            )
        );

        require(success, SP1_INVALID_PROOF());
    }
}
