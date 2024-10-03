// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@sp1-contracts/src/ISP1Verifier.sol";
import "../../shared/common/EssentialContract.sol";
import "../../shared/common/LibStrings.sol";
import "../based/ITaikoL1.sol";
import "./LibPublicInput.sol";
import "./IVerifier.sol";

/// @title SP1Verifier
/// @custom:security-contact security@taiko.xyz
contract SP1Verifier is EssentialContract, IVerifier {
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

    /// @notice Initializes the contract with the provided address manager.
    /// @param _owner The address of the owner.
    /// @param _addressManager The address of the AddressManager.
    function init(address _owner, address _addressManager) external initializer {
        __Essential_init(_owner, _addressManager);
    }

    /// @notice Sets/unsets an the program's verification key as trusted entity
    /// @param _programVKey The verification key of the program.
    /// @param _trusted True if trusted, false otherwise.
    function setProgramTrusted(bytes32 _programVKey, bool _trusted) external onlyOwner {
        isProgramTrusted[_programVKey] = _trusted;

        emit ProgramTrusted(_programVKey, _trusted);
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

        // Avoid in-memory decoding, so in-place decode with slicing.
        // e.g.: bytes32 programVKey = bytes32(_proof.data[0:32]);
        require(isProgramTrusted[bytes32(_proof.data[0:32])], SP1_INVALID_PROGRAM_VKEY());

        // Need to be converted from bytes32 to bytes
        bytes32 hashedPublicInput = LibPublicInput.hashPublicInputs(
            _tran, address(this), address(0), _ctx.prover, _ctx.metaHash, taikoChainId()
        );

        // _proof.data[32:] is the succinct's proof position
        (bool success,) = sp1RemoteVerifier().staticcall(
            abi.encodeCall(
                ISP1Verifier.verifyProof,
                (bytes32(_proof.data[0:32]), abi.encode(hashedPublicInput), _proof.data[32:])
            )
        );

        require(success, SP1_INVALID_PROOF());
    }

    /// @inheritdoc IVerifier
    function verifyBatchProof(
        ContextV2[] calldata _ctxs,
        TaikoData.TierProof calldata _proof
    )
        external
        view
    {
        require(_ctxs.length != 0 && _proof.data.length > 64, SP1_INVALID_PARAMS());
        // Extract the necessary data
        bytes32 aggregation_program = bytes32(_proof.data[0:32]);
        bytes32 block_proving_program = bytes32(_proof.data[32:64]);

        // Check if the aggregation program is trusted
        require(isProgramTrusted[aggregation_program], SP1_INVALID_AGGREGATION_VKEY());
        // Check if the block proving program is trusted
        require(isProgramTrusted[block_proving_program], SP1_INVALID_PROGRAM_VKEY());

        // Collect public inputs
        bytes32[] memory public_inputs = new bytes32[](_ctxs.length + 1);
        // First public input is the block proving program key
        public_inputs[0] = block_proving_program;
        // All other inputs are the block program public inputs (a single 32 byte value)
        for (uint256 i; i < _ctxs.length; ++i) {
            public_inputs[i + 1] = LibPublicInput.hashPublicInputs(
                _ctxs[i].tran,
                address(this),
                address(0),
                _ctxs[i].prover,
                _ctxs[i].metaHash,
                taikoChainId()
            );
        }

        // _proof.data[64:] is the succinct's proof position
        (bool success,) = sp1RemoteVerifier().staticcall(
            abi.encodeCall(
                ISP1Verifier.verifyProof,
                (aggregation_program, abi.encodePacked(public_inputs), _proof.data[64:])
            )
        );

        require(success, SP1_INVALID_PROOF());
    }

    function taikoChainId() internal view virtual returns (uint64) {
        return ITaikoL1(resolve(LibStrings.B_TAIKO, false)).getConfig().chainId;
    }

    function sp1RemoteVerifier() public view virtual returns (address) {
        return resolve(LibStrings.B_SP1_REMOTE_VERIFIER, false);
    }
}
