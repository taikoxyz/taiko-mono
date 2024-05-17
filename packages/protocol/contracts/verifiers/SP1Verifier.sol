// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "../common/EssentialContract.sol";
import "../common/LibStrings.sol";
import "../thirdparty/succinct/SP1VerifierBase.sol";
import "../L1/ITaikoL1.sol";
import "./IVerifier.sol";
import "./libs/LibPublicInput.sol";

/// @title SuccinctVerifier
/// @custom:security-contact security@taiko.xyz
contract SP1Verifier is EssentialContract, IVerifier, SP1VerifierBase {
    /// @notice The verification keys mappings for the proving programs.
    mapping(bytes32 provingProgramVKey => bool trusted) public isProgramTrusted;

    uint256[49] private __gap;

    /// @dev Emitted when a trusted image is set / unset.
    /// @param programVKey The id of the image
    /// @param trusted The block's assigned prover.
    event ProgramTrusted(bytes32 programVKey, bool trusted);

    error SP1_INVALID_PROGRAM_VKEY();

    /// @notice Initializes the contract with the provided address manager.
    /// @param _owner The address of the owner.
    /// @param _addressManager The address of the AddressManager.
    function init(
        address _owner,
        address _addressManager
    )
        external
        initializer
    {
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

        // Decode will throw if not proper length/encoding
        (bytes32 programVKey, bytes memory proof) =
            abi.decode(_proof.data, (bytes32, bytes));

        if (!isProgramTrusted[programVKey]) {
            revert SP1_INVALID_PROGRAM_VKEY();
        }

        uint64 chainId = ITaikoL1(resolve(LibStrings.B_TAIKO, false)).getConfig().chainId;

        bytes memory encodedPublicInput = LibPublicInput.abiEncodePublicInputs(
            _tran, address(this), address(0), _ctx.prover, _ctx.metaHash, chainId
        );

        // @Brecht: Is 'hash' var the public value ? OR the input params of the LibPublicInput.hashPublicInputs() encoded as a bytes stream ?
        this.verifyProof(programVKey, encodedPublicInput, proof);
        // SP1VerifierBase.verifyProof() will revert if invalid
    }
}
