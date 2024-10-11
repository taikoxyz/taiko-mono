// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../fixtures/BlocksFixtures.sol";

import "src/layer1/preconf/avs/PreconfConstants.sol";
import "src/layer1/preconf/interfaces/IPreconfTaskManager.sol";
import "src/layer1/preconf/interfaces/taiko/ITaikoL1.sol";

contract IncorrectPreconfirmations is BlocksFixtures {
    function setUp() public override {
        super.setUp();
    }

    function test_proveIncorrectPreconfirmation_slashesPreconferForIncorrectExecutionPreconf()
        external
    {
        // Sets address 1 as the proposer of block id 1 in task manager
        proposeBlock();

        // Sets the block metadata for block id 1 in taikoL1
        ITaikoL1.BlockMetadata memory metadata =
            setupTaikoBlock(1, vm.getBlockTimestamp(), keccak256("taiko_blobhash"));

        // Get addr_1 to sign a preconfirmation header for block id 1 with a different transaction
        // hash
        IPreconfTaskManager.PreconfirmationHeader memory header = IPreconfTaskManager
            .PreconfirmationHeader({
            blockId: 1,
            chainId: block.chainid,
            txListHash: keccak256("incorrect_tx_hash")
        });
        bytes32 headerHash =
            keccak256(abi.encodePacked(header.blockId, header.chainId, header.txListHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(1, headerHash); // Using private key of addr_1 i.e
            // 1
        bytes memory signature = abi.encodePacked(r, s, v);

        // Prove incorrect preconfirmation
        preconfTaskManager.proveIncorrectPreconfirmation(metadata, header, signature);

        // Verify that the preconfirmation signer i.e addr_1 is slashed
        assertEq(preconfServiceManager.operatorSlashed(addr_1), true);
    }

    function test_proveIncorrectPreconfirmation_slashesPreconferForMissedInclusion() external {
        // Sets address 1 as the proposer of block id 1 in task manager
        proposeBlock();

        // Sets the block metadata for block id 1 in taikoL1
        ITaikoL1.BlockMetadata memory metadata =
            setupTaikoBlock(1, vm.getBlockTimestamp(), keccak256("taiko_blobhash"));

        // Get addr_2 to sign a preconfirmation header for block id 1
        IPreconfTaskManager.PreconfirmationHeader memory header = IPreconfTaskManager
            .PreconfirmationHeader({
            blockId: 1,
            chainId: block.chainid,
            txListHash: keccak256("taiko_blobhash")
        });
        bytes32 headerHash =
            keccak256(abi.encodePacked(header.blockId, header.chainId, header.txListHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(2, headerHash); // Using private key of addr_2 i.e
            // 2
        bytes memory signature = abi.encodePacked(r, s, v);

        // Prove incorrect preconfirmation i.e. addr_2 has preconfirmed the block but it was not
        // proposed by them.
        // It was proposed by addr_1
        preconfTaskManager.proveIncorrectPreconfirmation(metadata, header, signature);

        // Verify that the preconfirmation signer i.e addr_2 is slashed
        assertEq(preconfServiceManager.operatorSlashed(addr_2), true);
    }

    function test_proveIncorrectPreconfirmation_revertWhenDisputeWindowIsMissed() external {
        // Sets address 1 as the proposer of block id 1 in task manager
        proposeBlock();

        // Sets the block metadata for block id 1 in taikoL1
        ITaikoL1.BlockMetadata memory metadata =
            setupTaikoBlock(1, vm.getBlockTimestamp(), keccak256("taiko_blobhash"));

        // Get addr_1 to sign a preconfirmation header for block id 1
        IPreconfTaskManager.PreconfirmationHeader memory header = IPreconfTaskManager
            .PreconfirmationHeader({
            blockId: 1,
            chainId: block.chainid,
            txListHash: keccak256("incorrect_tx_hash")
        });
        bytes32 headerHash =
            keccak256(abi.encodePacked(header.blockId, header.chainId, header.txListHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(1, headerHash); // Using private key of addr_1 i.e
            // 1
        bytes memory signature = abi.encodePacked(r, s, v);

        // Warp time to just after the dispute window
        vm.warp(
            vm.getBlockTimestamp() + PreconfConstants.DISPUTE_PERIOD
                + PreconfConstants.SECONDS_IN_SLOT
        );

        // Attempt to prove incorrect preconfirmation after dispute window
        vm.expectRevert(IPreconfTaskManager.MissedDisputeWindow.selector);
        preconfTaskManager.proveIncorrectPreconfirmation(metadata, header, signature);
    }

    function test_proveIncorrectPreconfirmation_revertWhenChainIdMismatch() external {
        // Sets address 1 as the proposer of block id 1 in task manager
        proposeBlock();

        // Sets the block metadata for block id 1 in taikoL1
        ITaikoL1.BlockMetadata memory metadata =
            setupTaikoBlock(1, vm.getBlockTimestamp(), keccak256("taiko_blobhash"));

        // Get addr_1 to sign a preconfirmation header for block id 1 with incorrect chain ID
        IPreconfTaskManager.PreconfirmationHeader memory header = IPreconfTaskManager
            .PreconfirmationHeader({
            blockId: 1,
            chainId: block.chainid + 1, // Incorrect chain ID
            txListHash: keccak256("taiko_blobhash")
        });
        bytes32 headerHash =
            keccak256(abi.encodePacked(header.blockId, header.chainId, header.txListHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(1, headerHash); // Using private key of addr_1 i.e
            // 1
        bytes memory signature = abi.encodePacked(r, s, v);

        // Attempt to prove incorrect preconfirmation with mismatched chain ID
        vm.expectRevert(IPreconfTaskManager.PreconfirmationChainIdMismatch.selector);
        preconfTaskManager.proveIncorrectPreconfirmation(metadata, header, signature);
    }

    function test_proveIncorrectPreconfirmation_revertWhenMetadataMismatch() external {
        // Sets address 1 as the proposer of block id 1 in task manager
        proposeBlock();

        // Sets the block metadata for block id 1 in taikoL1
        ITaikoL1.BlockMetadata memory correctMetadata =
            setupTaikoBlock(1, vm.getBlockTimestamp(), keccak256("taiko_blobhash"));

        // Create incorrect metadata
        ITaikoL1.BlockMetadata memory incorrectMetadata = correctMetadata;
        incorrectMetadata.blobHash = keccak256("incorrect_blobhash");

        // Get addr_1 to sign a preconfirmation header for block id 1
        IPreconfTaskManager.PreconfirmationHeader memory header = IPreconfTaskManager
            .PreconfirmationHeader({
            blockId: 1,
            chainId: block.chainid,
            txListHash: keccak256("taiko_blobhash")
        });
        bytes32 headerHash =
            keccak256(abi.encodePacked(header.blockId, header.chainId, header.txListHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(1, headerHash); // Using private key of addr_1 i.e
            // 1
        bytes memory signature = abi.encodePacked(r, s, v);

        // Attempt to prove incorrect preconfirmation with mismatched metadata
        vm.expectRevert(IPreconfTaskManager.MetadataMismatch.selector);
        preconfTaskManager.proveIncorrectPreconfirmation(incorrectMetadata, header, signature);
    }

    function test_proveIncorrectPreconfirmation_revertWhenPreconfirmationIsCorrect() external {
        // Sets address 1 as the proposer of block id 1 in task manager
        proposeBlock();

        // Sets the block metadata for block id 1 in taikoL1
        ITaikoL1.BlockMetadata memory metadata =
            setupTaikoBlock(1, vm.getBlockTimestamp(), keccak256("taiko_blobhash"));

        // Get addr_1 to sign a correct preconfirmation header for block id 1
        IPreconfTaskManager.PreconfirmationHeader memory header = IPreconfTaskManager
            .PreconfirmationHeader({
            blockId: 1,
            chainId: block.chainid,
            txListHash: keccak256("taiko_blobhash")
        });
        bytes32 headerHash =
            keccak256(abi.encodePacked(header.blockId, header.chainId, header.txListHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(1, headerHash); // Using private key of addr_1 i.e
            // 1
        bytes memory signature = abi.encodePacked(r, s, v);

        // Attempt to prove incorrect preconfirmation when it's actually correct
        vm.expectRevert(IPreconfTaskManager.PreconfirmationIsCorrect.selector);
        preconfTaskManager.proveIncorrectPreconfirmation(metadata, header, signature);
    }

    function test_proveIncorrectPreconfirmation_emitsProvedIncorrectPreconfirmationEvent()
        external
    {
        // Sets address 1 as the proposer of block id 1 in task manager
        proposeBlock();

        // Sets the block metadata for block id 1 in taikoL1
        ITaikoL1.BlockMetadata memory metadata =
            setupTaikoBlock(1, vm.getBlockTimestamp(), keccak256("taiko_blobhash"));

        // Get addr_2 to sign an incorrect preconfirmation header for block id 1
        IPreconfTaskManager.PreconfirmationHeader memory header = IPreconfTaskManager
            .PreconfirmationHeader({
            blockId: 1,
            chainId: block.chainid,
            txListHash: keccak256("incorrect_blobhash")
        });
        bytes32 headerHash =
            keccak256(abi.encodePacked(header.blockId, header.chainId, header.txListHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(2, headerHash); // Using private key of addr_2 i.e
            // 2
        bytes memory signature = abi.encodePacked(r, s, v);

        // Expect the ProvedIncorrectPreconfirmation event to be emitted
        vm.expectEmit();
        emit IPreconfTaskManager.ProvedIncorrectPreconfirmation(addr_1, 1, address(this));

        // Prove incorrect preconfirmation
        preconfTaskManager.proveIncorrectPreconfirmation(metadata, header, signature);
    }

    //=========
    // Helpers
    //=========

    /// @dev Makes preliminary setup and has address 1 propose a block
    function proposeBlock() internal {
        // Push preconfer Address 1 to slot 13 and Address 3 to slot 23 of the next epoch
        prepareLookahead(13, 23);

        uint256 currentEpochStart =
            PreconfConstants.MAINNET_BEACON_GENESIS + PreconfConstants.SECONDS_IN_EPOCH;
        // Warp to an arbitrary timestamp before the preconfer's slot
        uint256 currentSlotTimestamp = currentEpochStart + (10 * PreconfConstants.SECONDS_IN_SLOT);
        vm.warp(currentSlotTimestamp);

        // Force set the block id to an arbitrary value
        taikoL1.setBlockId(1);

        // Arbitrary lookahead for the next epoch just to avoid fallback selection in this test
        IPreconfTaskManager.LookaheadSetParam[] memory lookaheadSetParams =
            new IPreconfTaskManager.LookaheadSetParam[](1);
        lookaheadSetParams[0] = IPreconfTaskManager.LookaheadSetParam({
            preconfer: addr_2,
            timestamp: currentEpochStart + PreconfConstants.SECONDS_IN_EPOCH
        });

        // Address 1 proposes the block
        vm.prank(addr_1);
        preconfTaskManager.newBlockProposal("Block Params", "Txn List", 1, lookaheadSetParams);
    }
}
