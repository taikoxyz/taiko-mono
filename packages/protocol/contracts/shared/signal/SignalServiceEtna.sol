// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { LibTrieProof } from "../libs/LibTrieProof.sol";
import { IL1StateRootProvider } from "./IL1StateRootProvider.sol";
import { ISignalServiceEtna } from "./ISignalServiceEtna.sol";
import { SignalService } from "./SignalService.sol";

/// @title SignalServiceEtna
/// @notice Verifies L1 signals using execution state roots recorded by the L2 Anchor's oracle.
/// @dev Adds no storage slots. The immutable layout selection must match the existing proxy;
/// it never falls back to another namespace. L1 continues to use SignalService.
/// @custom:security-contact security@taiko.xyz
contract SignalServiceEtna is SignalService, ISignalServiceEtna {
    /// @notice Four-byte prefix identifying timestamp-indexed state-root proofs.
    bytes4 public constant STATE_ROOT_PROOF_MAGIC = bytes4(keccak256("TAIKO_STATE_ROOT_PROOF_V1"));

    /// @notice Whether checkpoint and received-signal cache mappings use the old flat layout.
    /// @dev False selects VERSION storage and never accepts deprecated unversioned records.
    bool public immutable usesLegacyStorage;

    /// @notice Initializes the L2 root provider, remote SignalService, pauser and storage layout.
    /// @param _authorizedSyncer L2 Anchor that saves legacy checkpoints and provides Etna roots.
    /// @param _remoteSignalService L1 SignalService whose account and signal slots are proven.
    /// @param _pauser Optional additional pause authority.
    /// @param _usesLegacyStorage True for flat-mapping proxies; false for VERSION storage.
    constructor(
        address _authorizedSyncer,
        address _remoteSignalService,
        address _pauser,
        bool _usesLegacyStorage
    )
        SignalService(_authorizedSyncer, _remoteSignalService, _pauser)
    {
        usesLegacyStorage = _usesLegacyStorage;
    }

    /// @inheritdoc ISignalServiceEtna
    function stateRootProvider() external view returns (address provider_) {
        return _authorizedSyncer;
    }

    /// @dev Returns the cache in exactly the selected layout, without fallback.
    /// @return cache_ Storage reference to the active cache mapping.
    function _receivedSignalCache()
        internal
        view
        override
        returns (mapping(bytes32 signalSlot => bool received) storage cache_)
    {
        if (!usesLegacyStorage) return super._receivedSignalCache();
        assembly {
            cache_.slot := _receivedSignals.slot
        }
    }

    /// @dev Returns a checkpoint record in exactly the selected layout, without fallback.
    /// @param _blockNumber Source block number.
    /// @return record_ Storage reference to the selected checkpoint record.
    function _checkpointRecord(uint48 _blockNumber)
        internal
        view
        override
        returns (CheckpointRecord storage record_)
    {
        if (!usesLegacyStorage) return super._checkpointRecord(_blockNumber);
        uint256 mappingSlot;
        assembly {
            mappingSlot := _checkpoints.slot
        }
        bytes32 recordSlot = keccak256(abi.encode(_blockNumber, mappingSlot));
        assembly {
            record_.slot := recordSlot
        }
    }

    /// @dev Verifies an Etna envelope, or delegates legacy/cached proofs to the base verifier.
    /// @param _chainId Source chain ID.
    /// @param _app Source application that sent the signal.
    /// @param _signal Signal being proven.
    /// @param _proof Magic-prefixed StateRootProof, legacy HopProof[], or empty cached proof.
    function _verifySignalReceived(
        uint64 _chainId,
        address _app,
        bytes32 _signal,
        bytes calldata _proof
    )
        internal
        view
        override
    {
        if (_proof.length < 4 || bytes4(_proof[:4]) != STATE_ROOT_PROOF_MAGIC) {
            super._verifySignalReceived(_chainId, _app, _signal, _proof);
            return;
        }
        require(_app != address(0), ZERO_ADDRESS());
        require(_signal != bytes32(0), ZERO_VALUE());

        StateRootProof memory proof = abi.decode(_proof[4:], (StateRootProof));
        if (proof.accountProof.length == 0 || proof.storageProof.length == 0) {
            revert SS_EMPTY_PROOF();
        }
        bytes32 stateRoot =
            IL1StateRootProvider(_authorizedSyncer).getL1StateRoot(proof.l2Timestamp);
        if (stateRoot == bytes32(0)) revert SS_INVALID_CHECKPOINT();
        LibTrieProof.verifyMerkleProof(
            stateRoot,
            _remoteSignalService,
            getSignalSlot(_chainId, _app, _signal),
            _signal,
            proof.accountProof,
            proof.storageProof
        );
    }
}
