// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@sp1-contracts/src/ISP1Verifier.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "src/shared/libs/LibNames.sol";
import "./LibPublicInput.sol";
import "../iface/IProofVerifier.sol";

/// @title ShastaSP1Verifier
/// @custom:security-contact security@taiko.xyz
contract ShastaSP1Verifier is IProofVerifier, Ownable {
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

    constructor(uint64 _taikoChainId, address _sp1RemoteVerifier, address _owner) {
        taikoChainId = _taikoChainId;
        sp1RemoteVerifier = _sp1RemoteVerifier;

        _transferOwnership(_owner);
    }

    /// @notice Sets/unsets an the program's verification key as trusted entity
    /// @param _programVKey The verification key of the program.
    /// @param _trusted True if trusted, false otherwise.
    function setProgramTrusted(bytes32 _programVKey, bool _trusted) external onlyOwner {
        isProgramTrusted[_programVKey] = _trusted;
        emit ProgramTrusted(_programVKey, _trusted);
    }

    /// @inheritdoc IProofVerifier
    function verifyProof(bytes32 _transitionsHash, bytes calldata _proof) external view {
        require(_transitionsHash != bytes32(0) && _proof.length > 64, SP1_INVALID_PARAMS());
        // Extract the necessary data
        bytes32 aggregationProgram = bytes32(_proof[0:32]);
        bytes32 blockProvingProgram = bytes32(_proof[32:64]);

        // Check if the aggregation program is trusted
        require(isProgramTrusted[aggregationProgram], SP1_INVALID_AGGREGATION_VKEY());
        // Check if the block proving program is trusted
        require(isProgramTrusted[blockProvingProgram], SP1_INVALID_PROGRAM_VKEY());

        bytes32 publicInput = LibPublicInput.hashPublicInputs(
            _transitionsHash, address(this), address(0), taikoChainId
        );

        // _proof[64:] is the succinct's proof position
        (bool success,) = sp1RemoteVerifier.staticcall(
            abi.encodeCall(
                ISP1Verifier.verifyProof,
                (aggregationProgram, abi.encodePacked(publicInput), _proof[64:])
            )
        );

        require(success, SP1_INVALID_PROOF());
    }
}
