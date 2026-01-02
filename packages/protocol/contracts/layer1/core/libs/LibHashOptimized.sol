// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IInbox } from "../iface/IInbox.sol";
import { EfficientHashLib } from "solady/src/utils/EfficientHashLib.sol";

/// @title LibHashOptimized
/// @notice Optimized hashing functions using Solady's EfficientHashLib(when more efficient than keccak256)
/// @dev This library provides gas-optimized implementations of all hashing functions
///      used in the Inbox contract, replacing standard keccak256(abi.encode(...)) calls
///      with more efficient alternatives from Solady's EfficientHashLib(when more efficient than keccak256).
/// @custom:security-contact security@taiko.xyz
library LibHashOptimized {
    // ---------------------------------------------------------------
    // Core Structure Hashing Functions
    // ---------------------------------------------------------------

    /// @notice Hashing for proposal data.
    /// @dev Uses keccak256(abi.encode(...)) to hash the proposal. Contrarty to the intuition,
    /// this is as efficient if not more than using `EfficientHashLib` in this case because
    /// the structure of the data(nested dynamic arryas).
    /// @param _proposal The proposal to hash
    /// @return The hash of the proposal
    function hashProposal(IInbox.Proposal memory _proposal) internal pure returns (bytes32) {
        /// forge-lint: disable-start(asm-keccak256)
        return keccak256(abi.encode(_proposal));
    }

    /// @notice Optimized hashing for commitment data.
    /// @param _commitment The commitment data to hash.
    /// @return The hash of the commitment.
    function hashCommitment(IInbox.Commitment memory _commitment) internal pure returns (bytes32) {
        unchecked {
            IInbox.Transition[] memory transitions = _commitment.transitions;
            uint256 transitionsLength = transitions.length;

            // Commitment layout (abi.encode):
            // [0] offset to commitment (0x20)
            //
            // Commitment static section (starts at word 1):
            // [1] firstProposalId
            // [2] firstProposalParentBlockHash
            // [3] lastProposalHash
            // [4] actualProver
            // [5] endBlockNumber
            // [6] endStateRoot
            // [7] offset to transitions (0xe0)
            //
            // Transitions array (starts at word 8):
            // [8] length
            // [9...] transition elements (3 words each: designatedProver, timestamp, blockHash)
            uint256 totalWords = 9 + transitionsLength * 3;

            bytes32[] memory buffer = EfficientHashLib.malloc(totalWords);

            // Top-level head
            EfficientHashLib.set(buffer, 0, bytes32(uint256(0x20)));

            // Commitment static fields
            EfficientHashLib.set(buffer, 1, bytes32(uint256(_commitment.firstProposalId)));
            EfficientHashLib.set(buffer, 2, _commitment.firstProposalParentBlockHash);
            EfficientHashLib.set(buffer, 3, _commitment.lastProposalHash);
            EfficientHashLib.set(buffer, 4, bytes32(uint256(uint160(_commitment.actualProver))));
            EfficientHashLib.set(buffer, 5, bytes32(uint256(_commitment.endBlockNumber)));
            EfficientHashLib.set(buffer, 6, _commitment.endStateRoot);
            EfficientHashLib.set(buffer, 7, bytes32(uint256(0xe0)));

            // Transitions array
            EfficientHashLib.set(buffer, 8, bytes32(transitionsLength));

            uint256 base = 9;
            for (uint256 i; i < transitionsLength; ++i) {
                IInbox.Transition memory transition = transitions[i];
                EfficientHashLib.set(
                    buffer, base, bytes32(uint256(uint160(transition.designatedProver)))
                );
                EfficientHashLib.set(buffer, base + 1, bytes32(uint256(transition.timestamp)));
                EfficientHashLib.set(buffer, base + 2, transition.blockHash);
                base += 3;
            }

            bytes32 result = EfficientHashLib.hash(buffer);
            EfficientHashLib.free(buffer);
            return result;
        }
    }
}
