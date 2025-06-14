// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./PreconfSlasherBase.sol";

contract TestPreconfSlasher is PreconfSlasherBase {
    using LibBlockHeader for LibBlockHeader.BlockHeader;

    // Preconfirmation Violations
    // ------------------------------------------------------------------------------------------------

    function test_preconfSlasher_slashesViolatedPreconfirmation_blockHashMismatch_Case1()
        external
        InsertBatchAndTransition(BlockPosition.BATCH_START, preconfSigner)
        transactBy(urc)
    {
        // Manipulate the preconfed block header to create a violation
        LibBlockHeader.BlockHeader memory preconfedBlockHeader = actualBlockHeader;
        preconfedBlockHeader.nonce = 0x0000000000000001;

        // Build a commitment on the preconfed block header
        ISlasher.Commitment memory commitment =
            _buildPreconfirmationCommitment(preconfedBlockHeader);

        // Slash the violated preconf
        uint256 slashedAmount =
            _slashViolatedPreconfirmation(commitment, preconfSigner, preconfedBlockHeader);

        // Correct slashing amount is returned
        assertEq(slashedAmount, preconfSlasher.getSlashAmount().invalidPreconf);
    }

    function test_preconfSlasher_slashesViolatedPreconfirmation_blockHashMismatch_Case2()
        external
        InsertBatchAndTransition(BlockPosition.BATCH_MIDDLE, preconfSigner)
        transactBy(urc)
    {
        // Manipulate the preconfed block header to create a violation
        LibBlockHeader.BlockHeader memory preconfedBlockHeader = actualBlockHeader;
        preconfedBlockHeader.nonce = 0x0000000000000001;

        // Build a commitment on the preconfed block header
        ISlasher.Commitment memory commitment =
            _buildPreconfirmationCommitment(preconfedBlockHeader);

        // Slash the violated preconf
        uint256 slashedAmount =
            _slashViolatedPreconfirmation(commitment, preconfSigner, preconfedBlockHeader);

        // Correct slashing amount is returned
        assertEq(slashedAmount, preconfSlasher.getSlashAmount().invalidPreconf);
    }

    function test_preconfSlasher_slashesViolatedPreconfirmation_blockHashMismatch_Case3()
        external
        InsertBatchAndTransition(BlockPosition.BATCH_END, preconfSigner)
        transactBy(urc)
    {
        // Manipulate the preconfed block header to create a violation
        LibBlockHeader.BlockHeader memory preconfedBlockHeader = actualBlockHeader;
        preconfedBlockHeader.nonce = 0x0000000000000001;

        // Build a commitment on the preconfed block header
        ISlasher.Commitment memory commitment =
            _buildPreconfirmationCommitment(preconfedBlockHeader);

        // Slash the violated preconf
        uint256 slashedAmount =
            _slashViolatedPreconfirmation(commitment, preconfSigner, preconfedBlockHeader);

        // Correct slashing amount is returned
        assertEq(slashedAmount, preconfSlasher.getSlashAmount().invalidPreconf);
    }

    function test_preconfSlasher_slashesViolatedPreconfirmation_anchorIdMismatch()
        external
        InsertBatchAndTransition(BlockPosition.BATCH_MIDDLE, preconfSigner)
        transactBy(urc)
    {
        LibBlockHeader.BlockHeader memory preconfedBlockHeader = actualBlockHeader;

        // Build a commitment on the preconfed block header with incorrect anchor id
        ISlasher.Commitment memory commitment = _buildPreconfirmationCommitment(
            LibPreconfConstants.PRECONF_DOMAIN_SEPARATOR,
            LibNetwork.TAIKO_MAINNET,
            uint64(uint256(keccak256("incorrect_anchor_id"))), // Insert an incorrect anchor id
            correctAnchorBlockHash,
            preconfedBlockHeader
        );

        // Slash the violated preconf
        uint256 slashedAmount =
            _slashViolatedPreconfirmation(commitment, preconfSigner, preconfedBlockHeader);

        // Correct slashing amount is returned
        assertEq(slashedAmount, preconfSlasher.getSlashAmount().invalidPreconf);
    }

    function test_preconfSlasher_slashesViolatedPreconfirmation_reorgedOriginBlock()
        external
        InsertBatchAndTransition(BlockPosition.BATCH_MIDDLE, Alice)
        transactBy(urc)
    {
        LibBlockHeader.BlockHeader memory preconfedBlockHeader = actualBlockHeader;

        // Build a commitment on the preconfed block header
        ISlasher.Commitment memory commitment =
            _buildPreconfirmationCommitment(preconfedBlockHeader);

        // The beacon root contract does not have an entry for `commitment.preconferSlotTimestamp`
        // indicating a reorg

        // Slash the violated preconf
        uint256 slashedAmount =
            _slashViolatedPreconfirmation(commitment, preconfSigner, preconfedBlockHeader);

        // Correct slashing amount is returned
        assertEq(slashedAmount, preconfSlasher.getSlashAmount().reorgedPreconf);
    }
}
