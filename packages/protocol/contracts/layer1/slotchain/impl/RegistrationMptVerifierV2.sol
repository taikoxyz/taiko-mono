// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { LibMptProof } from "../../../shared/slotchain/libs/LibMptProof.sol";
import { IRegistrationMptVerifierV2 } from "../iface/IRegistrationMptVerifierV2.sol";
import { LibRegistrationStatementV2 } from "../libs/LibRegistrationStatementV2.sol";

/// @title Immutable Slot Chain destination-registration MPT verifier
/// @notice Verifies one exact registrar-account and versioned storage-word membership statement.
/// @dev This contract is stateless, non-proxy, unpausable and has no authority surface.
/// @custom:security-contact security@taiko.xyz
contract RegistrationMptVerifierV2 is IRegistrationMptVerifierV2 {
    uint256 private constant _FIXED_CALLDATA_BYTES = 452;
    uint256 private constant _PROOF_OFFSET_WORD = 0x1a0;
    uint256 private constant _MAXIMUM_PROOF_BYTES = 78_264;
    uint256 private constant _MAXIMUM_TOTAL_NODES = 130;
    uint256 private constant _VERIFICATION_GAS_LIMIT = 11_000_000;

    bytes32 private constant _PROOF_SCHEMA_HASH =
        0x0027acbf8d87ef5b7c901c3dc27af4b56f1e4fb64953cf87f6fcd6ee878c963c;
    bytes32 private constant _CONFIGURATION_TYPEHASH =
        0x38f7fbc63e45f650bd5cbaffba0d81d5ca69f21ebdddfa74280d7e6eb5c319d6;

    /// @inheritdoc IRegistrationMptVerifierV2
    function registrationMptVerifierConfigHashV2() external pure returns (bytes32 configHash_) {
        return keccak256(
            abi.encode(
                _CONFIGURATION_TYPEHASH,
                LibRegistrationStatementV2.publicInputSchemaHash(),
                _PROOF_SCHEMA_HASH,
                IRegistrationMptVerifierV2.verifyRegistration.selector,
                uint16(LibMptProof.MAX_NODES_PER_PATH),
                uint16(_MAXIMUM_TOTAL_NODES),
                uint16(LibMptProof.MAX_NODE_BYTES),
                uint32(_MAXIMUM_PROOF_BYTES),
                uint64(_VERIFICATION_GAS_LIMIT)
            )
        );
    }

    /// @inheritdoc IRegistrationMptVerifierV2
    function verifyRegistration(
        RegistrationStorageStatementV2 calldata _statement,
        bytes calldata _proof
    )
        external
        pure
        returns (bytes32 statementHash_)
    {
        _requireCanonicalCalldata(_proof);
        _requireStatement(_statement);

        (LibMptProof.Path memory accountPath, LibMptProof.Path memory storagePath) =
            _parseProof(_proof);
        _verifyProof(_statement, _proof, accountPath, storagePath);
        return LibRegistrationStatementV2.hashStatement(_statement);
    }

    /// @dev Parses the complete two-path `MptProofV1` container without copying node bytes.
    function _parseProof(bytes calldata _proof)
        private
        pure
        returns (LibMptProof.Path memory accountPath_, LibMptProof.Path memory storagePath_)
    {
        if (_proof.length < 4 || _proof.length > _MAXIMUM_PROOF_BYTES) {
            revert InvalidRegistrationProofLength(_proof.length);
        }
        uint256 accountNodeCount = _readU16(_proof, 0);
        uint256 storageNodeCount = _readU16(_proof, 2);
        if (
            accountNodeCount + storageNodeCount > _MAXIMUM_TOTAL_NODES
                || accountNodeCount > LibMptProof.MAX_NODES_PER_PATH
                || storageNodeCount > LibMptProof.MAX_NODES_PER_PATH
        ) {
            revert InvalidRegistrationProofNodeCount();
        }

        uint256 cursor;
        (accountPath_, cursor) = LibMptProof.parsePath(_proof, 4, _proof.length, accountNodeCount);
        uint256 proofEnd;
        (storagePath_, proofEnd) =
            LibMptProof.parsePath(_proof, cursor, _proof.length, storageNodeCount);
        if (proofEnd != _proof.length) revert TrailingRegistrationProofBytes();
    }

    /// @dev Authenticates the account/code/storage-root join and exact nonzero storage word.
    function _verifyProof(
        RegistrationStorageStatementV2 calldata _statement,
        bytes calldata _proof,
        LibMptProof.Path memory _accountPath,
        LibMptProof.Path memory _storagePath
    )
        private
        pure
    {
        bytes32 storageRoot = LibMptProof.verifyAccount(
            _proof,
            _accountPath,
            _statement.stateRoot,
            _statement.terminalDomainRegistrar,
            _statement.registrarCodeHash
        );
        bytes32 value = LibMptProof.verifyStorageValue(
            _proof, _storagePath, storageRoot, _statement.storageTrieKey
        );
        if (value != _statement.expectedValue) revert RegistrationStorageValueMismatch();
    }

    /// @dev Rejects ABI-equivalent aliases, dirty narrow words, gaps, suffixes and nonzero padding.
    function _requireCanonicalCalldata(bytes calldata _proof) private pure {
        if (_proof.length > _MAXIMUM_PROOF_BYTES) {
            revert InvalidRegistrationProofLength(_proof.length);
        }

        uint256 proofOffsetWord;
        uint256 encodedProofLength;
        uint256 proofDataOffset;
        bool dirtyNarrowWords;
        assembly ("memory-safe") {
            proofOffsetWord := calldataload(388)
            encodedProofLength := calldataload(420)
            proofDataOffset := _proof.offset
            dirtyNarrowWords := iszero(
                iszero(
                    or(
                        or(shr(160, calldataload(36)), shr(160, calldataload(68))),
                        or(
                            or(shr(64, calldataload(164)), shr(64, calldataload(196))),
                            shr(160, calldataload(260))
                        )
                    )
                )
            )
        }
        if (
            dirtyNarrowWords || proofOffsetWord != _PROOF_OFFSET_WORD
                || proofDataOffset != _FIXED_CALLDATA_BYTES || encodedProofLength != _proof.length
        ) {
            revert NonCanonicalRegistrationCalldata();
        }

        uint256 paddedProofLength = (_proof.length + 31) & ~uint256(31);
        uint256 expectedLength = _FIXED_CALLDATA_BYTES + paddedProofLength;
        if (msg.data.length != expectedLength) revert NonCanonicalRegistrationCalldata();
        for (uint256 i = _FIXED_CALLDATA_BYTES + _proof.length; i < expectedLength; ++i) {
            if (msg.data[i] != 0) revert NonCanonicalRegistrationCalldata();
        }
    }

    /// @dev Rejects zero identities and commitments before any trie hashing.
    function _requireStatement(RegistrationStorageStatementV2 calldata _statement) private pure {
        if (
            _statement.settlementChainId == 0 || _statement.activeSettlementRouter == address(0)
                || _statement.bridgeDomainRegistry == address(0)
                || _statement.routeKey == bytes32(0) || _statement.destinationChainId == 0
                || _statement.protocolVersion == 0 || _statement.stateRoot == bytes32(0)
                || _statement.terminalDomainRegistrar == address(0)
                || _statement.registrarCodeHash == bytes32(0)
                || _statement.storageTrieKey == bytes32(0) || _statement.expectedValue == bytes32(0)
        ) {
            revert InvalidRegistrationStatement();
        }
    }

    /// @dev Reads one big-endian u16 from the already length-bounded proof prefix.
    function _readU16(
        bytes calldata _proof,
        uint256 _offset
    )
        private
        pure
        returns (uint256 value_)
    {
        return (uint256(uint8(_proof[_offset])) << 8) | uint8(_proof[_offset + 1]);
    }

    error InvalidRegistrationProofLength(uint256 actual);
    error InvalidRegistrationProofNodeCount();
    error InvalidRegistrationStatement();
    error NonCanonicalRegistrationCalldata();
    error RegistrationStorageValueMismatch();
    error TrailingRegistrationProofBytes();
}
