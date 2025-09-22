// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { ICheckpointStore } from "contracts/shared/shasta/iface/ICheckpointStore.sol";
import { IInbox } from "../iface/IInbox.sol";
// import { LibHashing } from "../libs/LibHashing.sol";
// import { LibProposeInputDecoder } from "../libs/LibProposeInputDecoder.sol";
// import { LibProposedEventEncoder } from "../libs/LibProposedEventEncoder.sol";
// import { LibProveInputDecoder } from "../libs/LibProveInputDecoder.sol";
// import { LibProvedEventEncoder } from "../libs/LibProvedEventEncoder.sol";

/// @title InboxHelper
/// @notice Unified helper contract for all Inbox encoder/decoder and hashing library functions
/// @custom:security-contact security@taiko.xyz
contract InboxHelper {
    // ---------------------------------------------------------------
    // ProposedEventEncoder Functions
    // ---------------------------------------------------------------

    /// @notice Encodes a ProposedEventPayload into bytes using standard ABI encoding
    /// @param _payload The payload to encode
    /// @return encoded_ The encoded bytes
    function encodeProposedEvent(IInbox.ProposedEventPayload memory _payload)
        external
        pure
        returns (bytes memory encoded_)
    {
        return abi.encode(_payload);
    }

    /// @notice Decodes bytes into a ProposedEventPayload using standard ABI decoding
    /// @param _data The encoded data
    /// @return payload_ The decoded payload
    function decodeProposedEvent(bytes memory _data)
        external
        pure
        returns (IInbox.ProposedEventPayload memory payload_)
    {
        // return abi.decode(_data, (IInbox.ProposedEventPayload));
    }

    /// @notice Decodes bytes into a ProposedEventPayload using optimized encoding
    /// @param _data The encoded data
    /// @return payload_ The decoded payload
    // function decodeProposedEventOptimized(bytes memory _data)
    //     external
    //     pure
    //     returns (IInbox.ProposedEventPayload memory payload_)
    // {
    //     return LibProposedEventEncoder.decode(_data);
    // }

    // ---------------------------------------------------------------
    // ProvedEventEncoder Functions
    // ---------------------------------------------------------------

    /// @notice Encodes a ProvedEventPayload into bytes using standard ABI encoding
    /// @param _payload The ProvedEventPayload to encode
    /// @return encoded_ The encoded bytes
    function encodeProvedEvent(IInbox.ProvedEventPayload memory _payload)
        external
        pure
        returns (bytes memory encoded_)
    {
        // return abi.encode(_payload);
    }

    /// @notice Encodes a ProvedEventPayload into bytes using optimized encoding
    /// @param _payload The ProvedEventPayload to encode
    /// @return encoded_ The encoded bytes
    // function encodeProvedEventOptimized(IInbox.ProvedEventPayload memory _payload)
    //     external
    //     pure
    //     returns (bytes memory encoded_)
    // {
    //     return LibProvedEventEncoder.encode(_payload);
    // }

    /// @notice Decodes bytes into a ProvedEventPayload using standard ABI decoding
    /// @param _data The bytes to decode
    /// @return payload_ The decoded ProvedEventPayload
    function decodeProvedEvent(bytes memory _data)
        external
        pure
        returns (IInbox.ProvedEventPayload memory payload_)
    {
        // return abi.decode(_data, (IInbox.ProvedEventPayload));
    }

    /// @notice Decodes bytes into a ProvedEventPayload using optimized encoding
    /// @param _data The bytes to decode
    /// @return payload_ The decoded ProvedEventPayload
    // function decodeProvedEventOptimized(bytes memory _data)
    //     external
    //     pure
    //     returns (IInbox.ProvedEventPayload memory payload_)
    // {
    //     return LibProvedEventEncoder.decode(_data);
    // }

    // ---------------------------------------------------------------
    // ProposeInputDecoder Functions
    // ---------------------------------------------------------------

    /// @notice Encodes propose input data using standard ABI encoding (compatible with all Inbox
    /// implementations)
    /// @param _input The ProposeInput to encode
    /// @return encoded_ The encoded data
    function encodeProposeInput(IInbox.ProposeInput memory _input)
        external
        pure
        returns (bytes memory encoded_)
    {
        return abi.encode(_input);
    }

    /// @notice Encodes propose input data using optimized encoding (for InboxOptimized3+)
    /// @param _input The ProposeInput to encode
    /// @return encoded_ The encoded data
    // function encodeProposeInputOptimized(IInbox.ProposeInput memory _input)
    //     external
    //     pure
    //     returns (bytes memory encoded_)
    // {
    //     return LibProposeInputDecoder.encode(_input);
    // }

    /// @notice Decodes propose data using standard ABI decoding
    /// @param _data The encoded data
    /// @return input_ The decoded ProposeInput
    function decodeProposeInput(bytes memory _data)
        external
        pure
        returns (IInbox.ProposeInput memory input_)
    {
        // return abi.decode(_data, (IInbox.ProposeInput));
    }

    /// @notice Decodes propose data using optimized operations
    /// @param _data The encoded data
    /// @return input_ The decoded ProposeInput
    // function decodeProposeInputOptimized(bytes memory _data)
    //     external
    //     pure
    //     returns (IInbox.ProposeInput memory input_)
    // {
    //     return LibProposeInputDecoder.decode(_data);
    // }

    // ---------------------------------------------------------------
    // ProveInputDecoder Functions
    // ---------------------------------------------------------------

    /// @notice Encodes prove input data using standard ABI encoding (compatible with all Inbox
    /// implementations)
    /// @param _input The ProveInput to encode
    /// @return encoded_ The encoded data
    function encodeProveInput(IInbox.ProveInput memory _input)
        external
        pure
        returns (bytes memory encoded_)
    {
        return abi.encode(_input);
    }

    /// @notice Encodes prove input data using optimized encoding (for InboxOptimized3+)
    /// @param _input The ProveInput to encode
    /// @return encoded_ The encoded data
    // function encodeProveInputOptimized(IInbox.ProveInput memory _input)
    //     external
    //     pure
    //     returns (bytes memory encoded_)
    // {
    //     return LibProveInputDecoder.encode(_input);
    // }

    /// @notice Decodes prove input data using standard ABI decoding
    /// @param _data The encoded data
    /// @return input_ The decoded ProveInput
    function decodeProveInput(bytes memory _data)
        external
        pure
        returns (IInbox.ProveInput memory input_)
    {
        // return abi.decode(_data, (IInbox.ProveInput));
    }

    /// @notice Decodes prove input data using optimized operations
    /// @param _data The encoded data
    /// @return input_ The decoded ProveInput
    // function decodeProveInputOptimized(bytes memory _data)
    //     external
    //     pure
    //     returns (IInbox.ProveInput memory input_)
    // {
    //     return LibProveInputDecoder.decode(_data);
    // }

    // ---------------------------------------------------------------
    // LibHashing Functions
    // ---------------------------------------------------------------

    /// @notice Standard hashing for Transition structs using keccak256(abi.encode())
    /// @param _transition The transition to hash
    /// @return The hash of the transition
    function hashTransition(IInbox.Transition memory _transition) external pure returns (bytes32) {
        // return keccak256(abi.encode(_transition));
    }

    /// @notice Optimized hashing for Transition structs
    /// @param _transition The transition to hash
    /// @return The hash of the transition
    // function hashTransitionOptimized(IInbox.Transition memory _transition)
    //     external
    //     pure
    //     returns (bytes32)
    // {
    //     return LibHashing.hashTransition(_transition);
    // }

    /// @notice Standard hashing for Checkpoint structs using keccak256(abi.encode())
    /// @param _checkpoint The checkpoint to hash
    /// @return The hash of the checkpoint
    function hashCheckpoint(ICheckpointStore.Checkpoint memory _checkpoint)
        external
        pure
        returns (bytes32)
    {
        // return keccak256(abi.encode(_checkpoint));
    }

    /// @notice Optimized hashing for Checkpoint structs
    /// @param _checkpoint The checkpoint to hash
    /// @return The hash of the checkpoint
    // function hashCheckpointOptimized(ICheckpointStore.Checkpoint memory _checkpoint)
    //     external
    //     pure
    //     returns (bytes32)
    // {
    //     return LibHashing.hashCheckpoint(_checkpoint);
    // }

    /// @notice Standard hashing for CoreState structs using keccak256(abi.encode())
    /// @param _coreState The core state to hash
    /// @return The hash of the core state
    function hashCoreState(IInbox.CoreState memory _coreState) external pure returns (bytes32) {
        // return keccak256(abi.encode(_coreState));
    }

    /// @notice Optimized hashing for CoreState structs
    /// @param _coreState The core state to hash
    /// @return The hash of the core state
    // function hashCoreStateOptimized(IInbox.CoreState memory _coreState)
    //     external
    //     pure
    //     returns (bytes32)
    // {
    //     return LibHashing.hashCoreState(_coreState);
    // }

    /// @notice Standard hashing for Proposal structs using keccak256(abi.encode())
    /// @param _proposal The proposal to hash
    /// @return The hash of the proposal
    function hashProposal(IInbox.Proposal memory _proposal) external pure returns (bytes32) {
        return keccak256(abi.encode(_proposal));
    }

    /// @notice Optimized hashing for Proposal structs
    /// @param _proposal The proposal to hash
    /// @return The hash of the proposal
    // function hashProposalOptimized(IInbox.Proposal memory _proposal)
    //     external
    //     pure
    //     returns (bytes32)
    // {
    //     return LibHashing.hashProposal(_proposal);
    // }

    /// @notice Standard hashing for Derivation structs using keccak256(abi.encode())
    /// @param _derivation The derivation to hash
    /// @return The hash of the derivation
    function hashDerivation(IInbox.Derivation memory _derivation) external pure returns (bytes32) {
        return keccak256(abi.encode(_derivation));
    }

    /// @notice Optimized hashing for Derivation structs
    /// @param _derivation The derivation to hash
    /// @return The hash of the derivation
    // function hashDerivationOptimized(IInbox.Derivation memory _derivation)
    //     external
    //     pure
    //     returns (bytes32)
    // {
    //     return LibHashing.hashDerivation(_derivation);
    // }

    /// @notice Standard hashing for arrays of Transitions using keccak256(abi.encode())
    /// @param _transitions The transitions array to hash
    /// @return The hash of the transitions array
    function hashTransitionsArray(IInbox.Transition[] memory _transitions)
        external
        pure
        returns (bytes32)
    {
        // return keccak256(abi.encode(_transitions));
    }

    /// @notice Optimized hashing for arrays of Transitions
    /// @param _transitions The transitions array to hash
    /// @return The hash of the transitions array
    // function hashTransitionsArrayOptimized(IInbox.Transition[] memory _transitions)
    //     external
    //     pure
    //     returns (bytes32)
    // {
    //     return LibHashing.hashTransitionsArray(_transitions);
    // }

    /// @notice Standard hashing for TransitionRecord structs using keccak256(abi.encode())
    /// @param _transitionRecord The transition record to hash
    /// @return The hash truncated to bytes26 for storage optimization
    function hashTransitionRecord(IInbox.TransitionRecord memory _transitionRecord)
        external
        pure
        returns (bytes26)
    {
        // return bytes26(keccak256(abi.encode(_transitionRecord)));
    }

    /// @notice Optimized hashing for TransitionRecord structs
    /// @param _transitionRecord The transition record to hash
    /// @return The hash truncated to bytes26 for storage optimization
    // function hashTransitionRecordOptimized(IInbox.TransitionRecord memory _transitionRecord)
    //     external
    //     pure
    //     returns (bytes26)
    // {
    //     return LibHashing.hashTransitionRecord(_transitionRecord);
    // }
}
