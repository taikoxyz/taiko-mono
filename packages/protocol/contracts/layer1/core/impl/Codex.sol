// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { ICodex } from "../iface/ICodex.sol";
import { IInbox } from "../iface/IInbox.sol";
import { LibHashOptimized as H } from "../libs/LibHashOptimized.sol";
import { LibProposeInputCodec } from "../libs/LibProposeInputCodec.sol";
import { LibProposedEventCodec } from "../libs/LibProposedEventCodec.sol";
import { LibProveInputCodec } from "../libs/LibProveInputCodec.sol";
import { LibProvedEventCodec } from "../libs/LibProvedEventCodec.sol";
import { LibBonds } from "src/shared/libs/LibBonds.sol";
import { ICheckpointStore } from "src/shared/signal/ICheckpointStore.sol";

/// @title Codex
/// @notice Codec contract wrapping lib functions for encoding, decoding, and hashing
/// @custom:security-contact security@taiko.xyz
contract Codex is ICodex {
    // ---------------------------------------------------------------
    // ProposeInput Codec Functions
    // ---------------------------------------------------------------

    /// @inheritdoc ICodex
    function encodeProposeInput(IInbox.ProposeInput calldata _input)
        external
        pure
        returns (bytes memory encoded_)
    {
        return LibProposeInputCodec.encode(_input);
    }

    /// @inheritdoc ICodex
    function decodeProposeInput(bytes calldata _data)
        external
        pure
        returns (IInbox.ProposeInput memory input_)
    {
        return LibProposeInputCodec.decode(_data);
    }

    // ---------------------------------------------------------------
    // ProveInput Codec Functions
    // ---------------------------------------------------------------

    /// @inheritdoc ICodex
    function encodeProveInput(IInbox.ProveInput[] calldata _inputs)
        external
        pure
        returns (bytes memory encoded_)
    {
        return LibProveInputCodec.encode(_inputs);
    }

    /// @inheritdoc ICodex
    function decodeProveInput(bytes calldata _data)
        external
        pure
        returns (IInbox.ProveInput[] memory inputs_)
    {
        return LibProveInputCodec.decode(_data);
    }

    // ---------------------------------------------------------------
    // ProposedEvent Codec Functions
    // ---------------------------------------------------------------

    /// @inheritdoc ICodex
    function encodeProposedEventData(IInbox.ProposedEventPayload calldata _payload)
        external
        pure
        returns (bytes memory encoded_)
    {
        return LibProposedEventCodec.encode(_payload);
    }

    /// @inheritdoc ICodex
    function decodeProposedEventData(bytes calldata _data)
        external
        pure
        returns (IInbox.ProposedEventPayload memory payload_)
    {
        return LibProposedEventCodec.decode(_data);
    }

    // ---------------------------------------------------------------
    // ProvedEvent Codec Functions
    // ---------------------------------------------------------------

    /// @inheritdoc ICodex
    function encodeProvedEventData(IInbox.ProvedEventPayload calldata _payload)
        external
        pure
        returns (bytes memory encoded_)
    {
        return LibProvedEventCodec.encode(_payload);
    }

    /// @inheritdoc ICodex
    function decodeProvedEventData(bytes calldata _data)
        external
        pure
        returns (IInbox.ProvedEventPayload memory payload_)
    {
        return LibProvedEventCodec.decode(_data);
    }

    // ---------------------------------------------------------------
    // Hashing Functions
    // ---------------------------------------------------------------

    /// @inheritdoc ICodex
    function hashCheckpoint(ICheckpointStore.Checkpoint calldata _checkpoint)
        external
        pure
        returns (bytes32)
    {
        return H.hashCheckpoint(_checkpoint);
    }

    /// @inheritdoc ICodex
    function hashCoreState(IInbox.CoreState calldata _coreState) external pure returns (bytes32) {
        return H.hashCoreState(_coreState);
    }

    /// @inheritdoc ICodex
    function hashDerivation(IInbox.Derivation calldata _derivation)
        external
        pure
        returns (bytes32)
    {
        return H.hashDerivation(_derivation);
    }

    /// @inheritdoc ICodex
    function hashProposal(IInbox.Proposal calldata _proposal) external pure returns (bytes32) {
        return H.hashProposal(_proposal);
    }

    /// @inheritdoc ICodex
    function hashTransition(IInbox.Transition calldata _transition)
        external
        pure
        returns (bytes27)
    {
        return H.hashTransition(_transition);
    }

    /// @inheritdoc ICodex
    function hashBondInstruction(LibBonds.BondInstruction calldata _bondInstruction)
        external
        pure
        returns (bytes32)
    {
        return H.hashBondInstruction(_bondInstruction);
    }

    /// @inheritdoc ICodex
    function hashBondInstructionMessage(IInbox.BondInstructionMessage calldata _change)
        external
        pure
        returns (bytes32)
    {
        return H.hashBondInstructionMessage(_change);
    }

    /// @inheritdoc ICodex
    function hashAggregatedBondInstructionsHash(
        bytes32 _aggregatedBondInstructionHash,
        bytes32 _bondInstructionHash
    )
        external
        pure
        returns (bytes32)
    {
        return H.hashAggregatedBondInstructionsHash(
            _aggregatedBondInstructionHash, _bondInstructionHash
        );
    }

    /// @inheritdoc ICodex
    function hashBlobHashesArray(bytes32[] calldata _blobHashes) external pure returns (bytes32) {
        return H.hashBlobHashesArray(_blobHashes);
    }

    /// @inheritdoc ICodex
    function hashProveInputArray(IInbox.ProveInput[] calldata _inputs)
        external
        pure
        returns (bytes32)
    {
        return H.hashProveInputArray(_inputs);
    }
}
