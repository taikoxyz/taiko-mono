// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { ICheckpointStore } from "src/shared/shasta/iface/ICheckpointStore.sol";
import { IInbox } from "../iface/IInbox.sol";
import { ICodec } from "../iface/ICodec.sol";

/// @title SimpleCodec
/// @notice Codec contract for standard Inbox with abi.encode/decode and keccak256 hashing
/// functions
/// @custom:security-contact security@taiko.xyz
contract SimpleCodec is ICodec {
    // ---------------------------------------------------------------
    // ProposedEventEncoder Functions
    // ---------------------------------------------------------------

    /// @inheritdoc ICodec
    function encodeProposedEvent(IInbox.ProposedEventPayload calldata _payload)
        external
        pure
        returns (bytes memory encoded_)
    {
        return abi.encode(_payload);
    }

    /// @inheritdoc ICodec
    function decodeProposedEvent(bytes calldata _data)
        external
        pure
        returns (IInbox.ProposedEventPayload memory payload_)
    {
        return abi.decode(_data, (IInbox.ProposedEventPayload));
    }

    // ---------------------------------------------------------------
    // ProvedEventEncoder Functions
    // ---------------------------------------------------------------

    /// @inheritdoc ICodec
    function encodeProvedEvent(IInbox.ProvedEventPayload calldata _payload)
        external
        pure
        returns (bytes memory encoded_)
    {
        return abi.encode(_payload);
    }

    /// @inheritdoc ICodec
    function decodeProvedEvent(bytes calldata _data)
        external
        pure
        returns (IInbox.ProvedEventPayload memory payload_)
    {
        return abi.decode(_data, (IInbox.ProvedEventPayload));
    }

    // ---------------------------------------------------------------
    // ProposeInputDecoder Functions
    // ---------------------------------------------------------------

    /// @inheritdoc ICodec
    function encodeProposeInput(IInbox.ProposeInput calldata _input)
        external
        pure
        returns (bytes memory encoded_)
    {
        return abi.encode(_input);
    }

    /// @inheritdoc ICodec
    function decodeProposeInput(bytes calldata _data)
        external
        pure
        returns (IInbox.ProposeInput memory input_)
    {
        return abi.decode(_data, (IInbox.ProposeInput));
    }

    // ---------------------------------------------------------------
    // ProveInputDecoder Functions
    // ---------------------------------------------------------------

    /// @inheritdoc ICodec
    function encodeProveInput(IInbox.ProveInput calldata _input)
        external
        pure
        returns (bytes memory encoded_)
    {
        return abi.encode(_input);
    }

    /// @inheritdoc ICodec
    function decodeProveInput(bytes calldata _data)
        external
        pure
        returns (IInbox.ProveInput memory input_)
    {
        return abi.decode(_data, (IInbox.ProveInput));
    }

    // ---------------------------------------------------------------
    // Hashing Functions
    // ---------------------------------------------------------------

    /// @inheritdoc ICodec
    function hashCheckpoint(ICheckpointStore.Checkpoint calldata _checkpoint)
        external
        pure
        returns (bytes32)
    {
        return keccak256(abi.encode(_checkpoint));
    }

    /// @inheritdoc ICodec
    function hashCoreState(IInbox.CoreState calldata _coreState) external pure returns (bytes32) {
        return keccak256(abi.encode(_coreState));
    }

    /// @inheritdoc ICodec
    function hashDerivation(IInbox.Derivation calldata _derivation)
        external
        pure
        returns (bytes32)
    {
        return keccak256(abi.encode(_derivation));
    }

    /// @inheritdoc ICodec
    function hashProposal(IInbox.Proposal calldata _proposal) external pure returns (bytes32) {
        return keccak256(abi.encode(_proposal));
    }

    /// @inheritdoc ICodec
    function hashTransition(IInbox.Transition calldata _transition)
        external
        pure
        returns (bytes32)
    {
        return keccak256(abi.encode(_transition));
    }

    /// @inheritdoc ICodec
    function hashTransitionRecord(IInbox.TransitionRecord calldata _transitionRecord)
        external
        pure
        returns (bytes26)
    {
        return bytes26(keccak256(abi.encode(_transitionRecord)));
    }

    /// @inheritdoc ICodec
    function hashTransitions(IInbox.Transition[] calldata _transitions)
        external
        pure
        returns (bytes32)
    {
        // return keccak256(abi.encode(_transitions));

        /// forge-lint: disable-next-line(asm-keccak256)
        // assert(_transitions.length == _metadatas.length);
        // bytes32[] memory transitionHashes = new bytes32[](_transitions.length);
        // for (uint256 i; i < _transitions.length; ++i) {
        //     bytes32 transitionHash = _hashTransition(_transitions[i]);
        //     transitionHashes[i] = keccak256(abi.encodePacked(transitionHash,
        // _metadatas[i].designatedProver, _metadatas[i].actualProver));
        // }
        // return keccak256(abi.encode(transitionHashes));
    }
}
