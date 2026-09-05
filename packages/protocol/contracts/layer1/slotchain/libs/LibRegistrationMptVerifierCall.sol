// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { IRegistrationMptVerifierV2 } from "../iface/IRegistrationMptVerifierV2.sol";
import { LibRegistrationStatementV2 } from "./LibRegistrationStatementV2.sol";

/// @title Exact bounded calls to the destination-registration MPT verifier
/// @custom:security-contact security@taiko.xyz
library LibRegistrationMptVerifierCall {
    uint256 internal constant CONFIGURATION_READ_GAS = 50_000;
    uint256 internal constant VERIFICATION_GAS = 11_000_000;
    uint256 private constant _PRECALL_GAS_MARGIN = 10_000;

    /// @dev Authenticates the verifier artifact and its exact configuration read.
    /// @param _verifier The immutable verifier address.
    /// @param _runtimeHash The manifest-pinned verifier runtime hash.
    /// @param _configurationHash The independently recomputed configuration hash.
    function requireVerifier(
        address _verifier,
        bytes32 _runtimeHash,
        bytes32 _configurationHash
    )
        internal
        view
    {
        bytes32 actualRuntimeHash;
        assembly ("memory-safe") {
            actualRuntimeHash := extcodehash(_verifier)
        }
        if (
            _verifier == address(0) || _runtimeHash == bytes32(0)
                || actualRuntimeHash != _runtimeHash
        ) {
            revert RegistrationVerifierRuntimeMismatch();
        }
        if (_configurationHash == bytes32(0)) {
            revert RegistrationVerifierConfigurationMismatch();
        }

        bytes32 actualConfigurationHash = _staticcallWord(
            _verifier,
            abi.encodePacked(
                IRegistrationMptVerifierV2.registrationMptVerifierConfigHashV2.selector
            ),
            CONFIGURATION_READ_GAS
        );
        if (actualConfigurationHash != _configurationHash) {
            revert RegistrationVerifierConfigurationMismatch();
        }
    }

    /// @dev Dispatches a canonical proof call and authenticates its exact statement-hash return.
    /// @param _verifier The already runtime/configuration-authenticated verifier.
    /// @param _statement The complete caller-derived registration statement in memory.
    /// @param _proof The canonical packed `MptProofV1` bytes.
    /// @return statementHash_ The locally recomputed and verifier-confirmed statement hash.
    function verify(
        address _verifier,
        IRegistrationMptVerifierV2.RegistrationStorageStatementV2 memory _statement,
        bytes calldata _proof
    )
        internal
        view
        returns (bytes32 statementHash_)
    {
        statementHash_ = LibRegistrationStatementV2.hashStatement(_statement);
        bytes32 returnedHash = _staticcallWord(
            _verifier,
            abi.encodeCall(IRegistrationMptVerifierV2.verifyRegistration, (_statement, _proof)),
            VERIFICATION_GAS
        );
        if (returnedHash != statementHash_) revert RegistrationVerifierStatementMismatch();
    }

    /// @dev Makes a zero-value exact-size STATICCALL and copies its sole word only after checking.
    function _staticcallWord(
        address _target,
        bytes memory _input,
        uint256 _gasLimit
    )
        private
        view
        returns (bytes32 word_)
    {
        uint256 minimumGas = _gasLimit + _gasLimit / 63 + _PRECALL_GAS_MARGIN;
        if (gasleft() < minimumGas) revert InsufficientRegistrationVerifierCallGas();

        bool success;
        uint256 returnLength;
        assembly ("memory-safe") {
            success := staticcall(_gasLimit, _target, add(_input, 32), mload(_input), 0, 0)
            returnLength := returndatasize()
        }
        if (!success) revert RegistrationVerifierCallFailed();
        if (returnLength != 32) revert RegistrationVerifierReturnLengthMismatch(returnLength);
        assembly ("memory-safe") {
            returndatacopy(0, 0, 32)
            word_ := mload(0)
        }
    }

    error InsufficientRegistrationVerifierCallGas();
    error RegistrationVerifierCallFailed();
    error RegistrationVerifierConfigurationMismatch();
    error RegistrationVerifierReturnLengthMismatch(uint256 actual);
    error RegistrationVerifierRuntimeMismatch();
    error RegistrationVerifierStatementMismatch();
}
