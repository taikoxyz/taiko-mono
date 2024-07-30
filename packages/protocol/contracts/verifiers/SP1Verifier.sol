// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "../common/EssentialContract.sol";
import "../common/LibStrings.sol";
import "../L1/ITaikoL1.sol";
import "./IVerifier.sol";
import "./libs/LibPublicInput.sol";

/// @title SuccinctVerifier
/// @custom:security-contact security@taiko.xyz
contract SP1Verifier is EssentialContract, IVerifier {
    /// @notice The address of the SP1 remote verifier contract.
    /// @dev This can either be a specific SP1Verifier for a specific version, or the
    ///      SP1VerifierGateway which can be used to verify proofs for any version of SP1.
    ///      For the list of supported verifiers on each chain, see:
    ///      https://github.com/succinctlabs/sp1-contracts/tree/main/contracts/deployments
    address public remoteVerifier;

    /// @notice The verification keys mappings for the proving programs.
    mapping(bytes32 provingProgramVKey => bool trusted) public isProgramTrusted;

    uint256[48] private __gap;

    /// @dev Emitted when a trusted image is set / unset.
    /// @param programVKey The id of the image
    /// @param trusted The block's assigned prover.
    event ProgramTrusted(bytes32 programVKey, bool trusted);

    /// @dev Emitted when a new verifier address is set.
    /// @param newRemoteVerifier The address of the remoteVerifier.
    event NewVerifierAddress(address newRemoteVerifier);

    error SP1_INVALID_PROGRAM_VKEY();
    error SP1_INVALID_PROOF();

    /// @notice Initializes the contract with the provided address manager.
    /// @param _owner The address of the owner.
    /// @param _addressManager The address of the AddressManager.
    /// @param _remoteVerifier The address of the SP1Verifiers.
    function init(
        address _owner,
        address _addressManager,
        address _remoteVerifier
    )
        external
        initializer
    {
        __Essential_init(_owner, _addressManager);

        remoteVerifier = _remoteVerifier;
    }

    /// @notice Sets/unsets an the program's verification key as trusted entity
    /// @param _programVKey The verification key of the program.
    /// @param _trusted True if trusted, false otherwise.
    function setProgramTrusted(bytes32 _programVKey, bool _trusted) external onlyOwner {
        isProgramTrusted[_programVKey] = _trusted;

        emit ProgramTrusted(_programVKey, _trusted);
    }

    /// @notice Sets the remoteVerifier contract.
    /// @param _remoteVerifier The address of the remoteVerifier contract.
    function setRemoteVerifierContract(address _remoteVerifier) external onlyOwner {
        remoteVerifier = _remoteVerifier;

        emit NewVerifierAddress(_remoteVerifier);
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
        (bytes32 programVKey, bytes memory proof) = abi.decode(_proof.data, (bytes32, bytes));

        if (!isProgramTrusted[programVKey]) {
            revert SP1_INVALID_PROGRAM_VKEY();
        }

        uint64 chainId = ITaikoL1(resolve(LibStrings.B_TAIKO, false)).getConfig().chainId;

        // Need to be converted from bytes32 to bytes
        bytes32 hashedPublicInput = LibPublicInput.hashPublicInputs(
            _tran, address(this), address(0), _ctx.prover, _ctx.metaHash, chainId
        );

        // call sp1 verifier (gateway) contract
        (bool success,) = address(remoteVerifier).staticcall(
            abi.encodeCall(
                ISP1Verifier.verifyProof, (programVKey, abi.encode(hashedPublicInput), proof)
            )
        );

        if (!success) {
            revert SP1_INVALID_PROOF();
        }
    }
}
