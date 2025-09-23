// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./PreconfSlasherBase.sol";

contract TestPreconfSlasher_PreconfViolation is PreconfSlasherBase {
    // Slashing
    // -------------------------------------------------------------------

    function test_slashesWhenPreconfedBlockHashIsMismatched_Case1()
        external
        InsertBatchAndTransition(BlockPosition.START_OF_BATCH, preconfSigner)
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

    function test_slashesWhenPreconfedBlockHashIsMismatched_Case2()
        external
        InsertBatchAndTransition(BlockPosition.MIDDLE_OF_BATCH, preconfSigner)
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

    function test_slashesWhenPreconfedBlockHashIsMismatched_Case3()
        external
        InsertBatchAndTransition(BlockPosition.END_OF_BATCH, preconfSigner)
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

    function test_slashesWhenAnchorIdIsMismatched()
        external
        InsertBatchAndTransition(BlockPosition.MIDDLE_OF_BATCH, preconfSigner)
        transactBy(urc)
    {
        LibBlockHeader.BlockHeader memory preconfedBlockHeader = actualBlockHeader;

        // Build a commitment on the preconfed block header with incorrect anchor id
        ISlasher.Commitment memory commitment = _buildPreconfirmationCommitment(
            LibPreconfConstants.PRECONF_DOMAIN_SEPARATOR,
            LibNetwork.TAIKO_MAINNET,
            uint64(uint256(keccak256("incorrect_anchor_id"))), // Insert an incorrect anchor id
            correctAnchorBlockHash,
            false,
            preconfedBlockHeader
        );

        // Slash the violated preconf
        uint256 slashedAmount =
            _slashViolatedPreconfirmation(commitment, preconfSigner, preconfedBlockHeader);

        // Correct slashing amount is returned
        assertEq(slashedAmount, preconfSlasher.getSlashAmount().invalidPreconf);
    }

    function test_slashesWhenProposerIsNotTheCommitterAndOriginBlockIsNotReorged()
        external
        InsertBatchAndTransition(BlockPosition.MIDDLE_OF_BATCH, Alice)
        transactBy(urc)
    {
        // Manipulate the preconfed block header to create a violation
        LibBlockHeader.BlockHeader memory preconfedBlockHeader = actualBlockHeader;
        preconfedBlockHeader.nonce = 0x0000000000000001;

        // Build a commitment on the preconfed block header
        ISlasher.Commitment memory commitment =
            _buildPreconfirmationCommitment(preconfedBlockHeader);

        // Set a non zero beacon block root at preconfer's slot
        MockBeaconBlockRoot(payable(LibPreconfConstants.BEACON_BLOCK_ROOT_CONTRACT)).set(
            preconferSlotTimestamp, bytes32(uint256(1))
        );

        // Slash the violated preconf
        uint256 slashedAmount =
            _slashViolatedPreconfirmation(commitment, preconfSigner, preconfedBlockHeader);

        // Correct slashing amount is returned
        assertEq(slashedAmount, preconfSlasher.getSlashAmount().invalidPreconf);
    }

    function test_slashesWhenProposerIsNotTheCommitterAndOriginBlockIsReorged()
        external
        InsertBatchAndTransition(BlockPosition.MIDDLE_OF_BATCH, Alice)
        transactBy(urc)
    {
        // Manipulate the preconfed block header to create a violation
        LibBlockHeader.BlockHeader memory preconfedBlockHeader = actualBlockHeader;
        preconfedBlockHeader.nonce = 0x0000000000000001;

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

    // Reverts
    // -------------------------------------------------------------------

    function test_revertsWhenPreconfedBlockHeaderIsInvalid()
        external
        InsertBatchAndTransition(BlockPosition.MIDDLE_OF_BATCH, preconfSigner)
        transactBy(urc)
    {
        // Manipulate the preconfed block header to create a violation
        LibBlockHeader.BlockHeader memory preconfedBlockHeader = actualBlockHeader;
        preconfedBlockHeader.nonce = 0x0000000000000001;

        // Build a commitment on the preconfed block header
        ISlasher.Commitment memory commitment =
            _buildPreconfirmationCommitment(preconfedBlockHeader);

        // Disturb the preconfed block header
        preconfedBlockHeader.nonce = 0x0000000000000002;

        // Attempt to slash reverts
        _slashViolatedPreconfirmation(
            commitment,
            preconfSigner,
            preconfedBlockHeader,
            IPreconfSlasher.InvalidBlockHeader.selector
        );
    }

    function test_revertsWhenBatchInfoIsInvalid()
        external
        InsertBatchAndTransition(BlockPosition.MIDDLE_OF_BATCH, preconfSigner)
        transactBy(urc)
    {
        // Manipulate the preconfed block header to create a violation
        LibBlockHeader.BlockHeader memory preconfedBlockHeader = actualBlockHeader;
        preconfedBlockHeader.nonce = 0x0000000000000001;

        // Build a commitment on the preconfed block header
        ISlasher.Commitment memory commitment =
            _buildPreconfirmationCommitment(preconfedBlockHeader);

        // Disturb the batch info
        _cachedBatchInfo.txsHash = bytes32(uint256(1));

        // Attempt to slash reverts
        _slashViolatedPreconfirmation(
            commitment,
            preconfSigner,
            preconfedBlockHeader,
            IPreconfSlasher.InvalidBatchInfo.selector
        );
    }

    function test_revertsWhenBatchMetadataIsInvalid()
        external
        InsertBatchAndTransition(BlockPosition.MIDDLE_OF_BATCH, preconfSigner)
        transactBy(urc)
    {
        // Manipulate the preconfed block header to create a violation
        LibBlockHeader.BlockHeader memory preconfedBlockHeader = actualBlockHeader;
        preconfedBlockHeader.nonce = 0x0000000000000001;

        // Build a commitment on the preconfed block header
        ISlasher.Commitment memory commitment =
            _buildPreconfirmationCommitment(preconfedBlockHeader);

        // Disturb the batch metadata
        _cachedBatchMetadata.prover = address(1);

        // Attempt to slash reverts
        _slashViolatedPreconfirmation(
            commitment,
            preconfSigner,
            preconfedBlockHeader,
            IPreconfSlasher.InvalidBatchMetadata.selector
        );
    }

    function test_revertsWhenPreconfedBlockIsNotInBatch_Case1()
        external
        InsertBatchAndTransition(BlockPosition.PREV_BATCH, preconfSigner)
        transactBy(urc)
    {
        // Manipulate the preconfed block header to create a violation
        LibBlockHeader.BlockHeader memory preconfedBlockHeader = actualBlockHeader;
        preconfedBlockHeader.nonce = 0x0000000000000001;

        // Build a commitment on the preconfed block header
        ISlasher.Commitment memory commitment =
            _buildPreconfirmationCommitment(preconfedBlockHeader);

        // Attempt to slash reverts
        _slashViolatedPreconfirmation(
            commitment,
            preconfSigner,
            preconfedBlockHeader,
            IPreconfSlasher.BlockNotInBatch.selector
        );
    }

    function test_revertsWhenPreconfedBlockIsNotInBatch_Case2()
        external
        InsertBatchAndTransition(BlockPosition.NEXT_BATCH, preconfSigner)
        transactBy(urc)
    {
        // Manipulate the preconfed block header to create a violation
        LibBlockHeader.BlockHeader memory preconfedBlockHeader = actualBlockHeader;
        preconfedBlockHeader.nonce = 0x0000000000000001;

        // Build a commitment on the preconfed block header
        ISlasher.Commitment memory commitment =
            _buildPreconfirmationCommitment(preconfedBlockHeader);

        // Attempt to slash reverts
        _slashViolatedPreconfirmation(
            commitment,
            preconfSigner,
            preconfedBlockHeader,
            IPreconfSlasher.BlockNotInBatch.selector
        );
    }

    function test_revertsWhenAnchorBlockIsReorged()
        external
        InsertBatchAndTransition(BlockPosition.MIDDLE_OF_BATCH, preconfSigner)
        transactBy(urc)
    {
        // Manipulate the preconfed block header to create a violation
        LibBlockHeader.BlockHeader memory preconfedBlockHeader = actualBlockHeader;
        preconfedBlockHeader.nonce = 0x0000000000000001;

        // Build a commitment on the preconfed block header
        ISlasher.Commitment memory commitment = _buildPreconfirmationCommitment(
            LibPreconfConstants.PRECONF_DOMAIN_SEPARATOR,
            LibNetwork.TAIKO_MAINNET,
            correctAnchorBlockId,
            bytes32("incorrect_anchor_hash"), // Insert an incorrect anchor block hash
            false,
            preconfedBlockHeader
        );

        // Attempt to slash reverts
        _slashViolatedPreconfirmation(
            commitment,
            preconfSigner,
            preconfedBlockHeader,
            IPreconfSlasher.PossibleReorgOfAnchorBlock.selector
        );
    }

    function test_revertsWhenPreconfedBlockAndActualBlockAreNotAtTheSameHeight()
        external
        InsertBatchAndTransition(BlockPosition.MIDDLE_OF_BATCH, preconfSigner)
        transactBy(urc)
    {
        // Put the preconfed block at a different height than the actual block
        LibBlockHeader.BlockHeader memory preconfedBlockHeader = actualBlockHeader;
        preconfedBlockHeader.number = actualBlockHeader.number + 1;

        // Build a commitment on the preconfed block header
        ISlasher.Commitment memory commitment =
            _buildPreconfirmationCommitment(preconfedBlockHeader);

        // Attempt to slash reverts
        _slashViolatedPreconfirmation(
            commitment,
            preconfSigner,
            preconfedBlockHeader,
            IPreconfSlasher.InvalidActualBlockHeader.selector
        );
    }

    function test_revertsWhenPreconfirmationIsValid()
        external
        InsertBatchAndTransition(BlockPosition.MIDDLE_OF_BATCH, preconfSigner)
        transactBy(urc)
    {
        // Preconfirmation is not manipulated, i.e the preconfed block hash matches
        // the actual block hash
        LibBlockHeader.BlockHeader memory preconfedBlockHeader = actualBlockHeader;

        // Build a commitment on the preconfed block header
        ISlasher.Commitment memory commitment =
            _buildPreconfirmationCommitment(preconfedBlockHeader);

        // Attempt to slash reverts
        _slashViolatedPreconfirmation(
            commitment,
            preconfSigner,
            preconfedBlockHeader,
            IPreconfSlasher.PreconfirmationIsValid.selector
        );
    }

    function test_revertsWhenVerifiedBlockHeaderIsInvalid()
        external
        InsertBatchAndTransition(BlockPosition.MIDDLE_OF_BATCH, preconfSigner)
        transactBy(urc)
    {
        // Manipulate the preconfed block header to create a violation
        LibBlockHeader.BlockHeader memory preconfedBlockHeader = actualBlockHeader;
        preconfedBlockHeader.nonce = 0x0000000000000001;

        // Build a commitment on the preconfed block header
        ISlasher.Commitment memory commitment =
            _buildPreconfirmationCommitment(preconfedBlockHeader);

        // Disturb the verified block header
        verifiedBlockHeader.nonce = 0x0000000000000001;

        // Attempt to slash reverts
        _slashViolatedPreconfirmation(
            commitment,
            preconfSigner,
            preconfedBlockHeader,
            IPreconfSlasher.InvalidVerifiedBlockHeader.selector
        );
    }

    function test_revertsWhenParentBlockHashProofIsInvalid()
        external
        InsertBatchAndTransition(BlockPosition.MIDDLE_OF_BATCH, preconfSigner)
        transactBy(urc)
    {
        // Mess up parent block hash
        actualBlockHeader.parentHash = bytes32(uint256(1));
        LibBlockHeader.BlockHeader memory preconfedBlockHeader = actualBlockHeader;

        // Build a commitment on the preconfed block header
        ISlasher.Commitment memory commitment =
            _buildPreconfirmationCommitment(preconfedBlockHeader);

        // Attempt to slash reverts
        _slashViolatedPreconfirmation(commitment, preconfSigner, preconfedBlockHeader, emptyRevert);
    }

    function test_revertsWhenActualBlockHashProofIsInvalid()
        external
        InsertBatchAndTransition(BlockPosition.MIDDLE_OF_BATCH, preconfSigner)
        transactBy(urc)
    {
        // Mess up actual block hash
        actualBlockHeader.nonce = 0x0000000000000001;
        LibBlockHeader.BlockHeader memory preconfedBlockHeader = actualBlockHeader;

        // Build a commitment on the preconfed block header
        ISlasher.Commitment memory commitment =
            _buildPreconfirmationCommitment(preconfedBlockHeader);

        // Attempt to slash reverts
        _slashViolatedPreconfirmation(commitment, preconfSigner, preconfedBlockHeader, emptyRevert);
    }
}
