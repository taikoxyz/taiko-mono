// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Inbox } from "./Inbox.sol";
import { LibBonds } from "src/shared/based/libs/LibBonds.sol";
import { LibDecoder } from "../libs/LibDecoder.sol";

/// @title InboxWithClaimAggregation
/// @notice Extends Inbox with optimized claim aggregation for continuous proposals
/// @dev Aggregates continuous proposals into single claim records to optimize storage and gas usage
/// @custom:security-contact security@taiko.xyz
abstract contract InboxWithClaimAggregation is Inbox {
    using LibDecoder for bytes;

    /// @dev Builds claim records for multiple proposals and claims with aggregation for continuous
    /// proposals
    /// @param _config The configuration parameters.
    /// @param _proposals The proposals to prove.
    /// @param _claims The claims containing the proof details.
    /// @return claimRecords_ The built claim records with aggregated bond instructions for
    /// continuous proposals.
    function _buildClaimRecords(
        Config memory _config,
        Proposal[] memory _proposals,
        Claim[] memory _claims
    )
        internal
        view
        override
        returns (ClaimRecord[] memory claimRecords_)
    {
        // Start with array sized for all proposals
        claimRecords_ = new ClaimRecord[](_proposals.length);

        if (_proposals.length == 0) return claimRecords_;

        // Validate first proposal and create initial claim record
        _validateProposal(_config, _proposals[0], _claims[0]);
        LibBonds.BondInstruction[] memory currentInstructions =
            _calculateBondInstructions(_config, _proposals[0], _claims[0]);

        claimRecords_[0] = ClaimRecord({
            claim: _claims[0],
            nextProposalId: _proposals[0].id + 1,
            bondInstructions: currentInstructions
        });

        uint256 finalRecordCount = 1;
        uint256 currentRecordIndex;

        // Process remaining proposals
        for (uint256 i = 1; i < _proposals.length; ++i) {
            _validateProposal(_config, _proposals[i], _claims[i]);

            // Check if current proposal can be aggregated with the previous group
            if (_proposals[i].id == claimRecords_[currentRecordIndex].nextProposalId) {
                // Aggregate with current record
                LibBonds.BondInstruction[] memory newInstructions =
                    _calculateBondInstructions(_config, _proposals[i], _claims[i]);

                if (newInstructions.length > 0) {
                    // Get current instructions from the record
                    LibBonds.BondInstruction[] memory aggregatedInstructions =
                        claimRecords_[currentRecordIndex].bondInstructions;

                    // Resize and append using assembly
                    uint256 oldLen = aggregatedInstructions.length;
                    uint256 newLen = oldLen + newInstructions.length;

                    assembly {
                        // Update the length of aggregatedInstructions array
                        mstore(aggregatedInstructions, newLen)
                    }

                    // Copy new instructions to the resized array
                    for (uint256 j = 0; j < newInstructions.length; ++j) {
                        aggregatedInstructions[oldLen + j] = newInstructions[j];
                    }

                    // Update the bond instructions in the current record
                    claimRecords_[currentRecordIndex].bondInstructions = aggregatedInstructions;
                }

                // Update nextProposalId to skip this aggregated proposal
                claimRecords_[currentRecordIndex].nextProposalId = _proposals[i].id + 1;
            } else {
                // Start a new record for non-continuous proposal
                LibBonds.BondInstruction[] memory instructions =
                    _calculateBondInstructions(_config, _proposals[i], _claims[i]);

                currentRecordIndex = finalRecordCount;
                claimRecords_[currentRecordIndex] = ClaimRecord({
                    claim: _claims[i],
                    nextProposalId: _proposals[i].id + 1,
                    bondInstructions: instructions
                });
                finalRecordCount++;
            }
        }

        // Resize the claimRecords_ array to final size using assembly
        assembly {
            mstore(claimRecords_, finalRecordCount)
        }
    }
}
