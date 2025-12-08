// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { ICodec } from "../iface/ICodec.sol";
import { IInbox } from "../iface/IInbox.sol";
import { LibHashOptimized } from "../libs/LibHashOptimized.sol";
import { LibProposeInputCodec } from "../libs/LibProposeInputCodec.sol";
import { LibProposedEventCodec } from "../libs/LibProposedEventCodec.sol";
import { LibProveInputCodec } from "../libs/LibProveInputCodec.sol";
import { LibProvedEventCodec } from "../libs/LibProvedEventCodec.sol";
import { LibBonds } from "src/shared/libs/LibBonds.sol";

/// @title Codec
/// @notice Codec contract wrapping LibHashOptimized for optimized hashing
/// @custom:security-contact security@taiko.xyz
contract Codec is ICodec {
    // ---------------------------------------------------------------
    // ProposedEventCodec Functions
    // ---------------------------------------------------------------

    /// @inheritdoc ICodec
    function encodeProposedEvent(IInbox.ProposedEventPayload calldata _payload)
        external
        pure
        returns (bytes memory encoded_)
    {
        return LibProposedEventCodec.encode(_payload);
    }

    /// @inheritdoc ICodec
    function decodeProposedEvent(bytes calldata _data)
        external
        pure
        returns (IInbox.ProposedEventPayload memory payload_)
    {
        return LibProposedEventCodec.decode(_data);
    }

    // ---------------------------------------------------------------
    // ProvedEventCodec Functions
    // ---------------------------------------------------------------

    /// @inheritdoc ICodec
    function encodeProvedEvent(IInbox.ProvedEventPayload calldata _payload)
        external
        pure
        returns (bytes memory encoded_)
    {
        return LibProvedEventCodec.encode(_payload);
    }

    /// @inheritdoc ICodec
    function decodeProvedEvent(bytes calldata _data)
        external
        pure
        returns (IInbox.ProvedEventPayload memory payload_)
    {
        return LibProvedEventCodec.decode(_data);
    }

    // ---------------------------------------------------------------
    // ProposeInputCodec Functions
    // ---------------------------------------------------------------

    /// @inheritdoc ICodec
    function encodeProposeInput(IInbox.ProposeInput calldata _input)
        external
        pure
        returns (bytes memory encoded_)
    {
        return LibProposeInputCodec.encode(_input);
    }

    /// @inheritdoc ICodec
    function decodeProposeInput(bytes calldata _data)
        external
        pure
        returns (IInbox.ProposeInput memory input_)
    {
        return LibProposeInputCodec.decode(_data);
    }

    // ---------------------------------------------------------------
    // ProveInputCodec Functions
    // ---------------------------------------------------------------

    /// @inheritdoc ICodec
    function encodeProveInput(IInbox.ProveInput calldata _input)
        external
        pure
        returns (bytes memory encoded_)
    {
        return LibProveInputCodec.encode(_input);
    }

    /// @inheritdoc ICodec
    function decodeProveInput(bytes calldata _data)
        external
        pure
        returns (IInbox.ProveInput memory input_)
    {
        return LibProveInputCodec.decode(_data);
    }

    // ---------------------------------------------------------------
    // Hashing Functions
    // ---------------------------------------------------------------

    /// @inheritdoc ICodec
    function hashDerivation(IInbox.Derivation calldata _derivation)
        external
        pure
        returns (bytes32)
    {
        return LibHashOptimized.hashDerivation(_derivation);
    }

    /// @inheritdoc ICodec
    function hashProposal(IInbox.Proposal calldata _proposal) external pure returns (bytes32) {
        return LibHashOptimized.hashProposal(_proposal);
    }

    /// @inheritdoc ICodec
    function hashTransition(IInbox.Transition calldata _transition)
        external
        pure
        returns (bytes32)
    {
        return LibHashOptimized.hashTransition(_transition);
    }

    /// @inheritdoc ICodec
    function hashTransitions(IInbox.Transition[] calldata _transitions)
        external
        pure
        returns (bytes32)
    {
        return LibHashOptimized.hashTransitions(_transitions);
    }

    /// @inheritdoc ICodec
    function hashBondInstruction(LibBonds.BondInstruction calldata _bondInstruction)
        external
        pure
        returns (bytes32)
    {
        return LibBonds.hashBondInstruction(_bondInstruction);
    }
}
