// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "./RouterTestBase.sol";
import "../mocks/MockBeaconBlockRoot.sol";
import "src/layer1/based/ITaikoInbox.sol";
import "src/layer1/preconf/iface/IPreconfRouter.sol";

contract RouterTest is RouterTestBase {
    function test_proposePreconfedBlocks() external {
        address[] memory operators = new address[](3);
        operators[0] = Bob;
        operators[1] = Carol;
        operators[2] = David;
        addOperators(operators);

        // Setup mock beacon for operator selection
        vm.chainId(1);
        uint256 epochOneStart = LibPreconfConstants.getGenesisTimestamp(block.chainid);
        // Current epoch
        uint256 epochTwoStart = epochOneStart + LibPreconfConstants.SECONDS_IN_EPOCH;

        MockBeaconBlockRoot mockBeacon = new MockBeaconBlockRoot();
        bytes32 mockRoot = bytes32(uint256(1)); // This will select Carol

        address beaconBlockRootContract = LibPreconfConstants.getBeaconBlockRootContract();
        vm.etch(beaconBlockRootContract, address(mockBeacon).code);
        MockBeaconBlockRoot(payable(beaconBlockRootContract)).set(
            epochOneStart + LibPreconfConstants.SECONDS_IN_SLOT, mockRoot
        );

        // Setup block params
        ITaikoInbox.BlockParams[] memory blockParams = new ITaikoInbox.BlockParams[](1);
        blockParams[0] = ITaikoInbox.BlockParams({ numTransactions: 1, timeShift: 1 });

        ITaikoInbox.BlobParams memory blobParams;

        // Create batch params with correct structure
        ITaikoInbox.BatchParams memory params = ITaikoInbox.BatchParams({
            proposer: Carol,
            coinbase: address(0),
            parentMetaHash: bytes32(0),
            anchorBlockId: 0,
            anchorInput: bytes32(0),
            lastBlockTimestamp: uint64(block.timestamp),
            revertIfNotFirstProposal: false,
            signalSlots: new bytes32[](0),
            blobParams: blobParams,
            blocks: blockParams
        });

        // Warp to arbitrary slot in epoch 2
        vm.warp(epochTwoStart + 2 * LibPreconfConstants.SECONDS_IN_SLOT);

        // Prank as Carol (selected operator) and propose blocks
        vm.prank(Carol);
        ITaikoInbox.BatchMetadata memory meta =
            router.proposePreconfedBlocks("", abi.encode(params), "", false);

        // Assert the proposer was set correctly in the metadata
        assertEq(meta.proposer, Carol);
    }

    function test_proposePreconfedBlocks_notOperator() external {
        address[] memory operators = new address[](3);
        operators[0] = Bob;
        operators[1] = Carol;
        operators[2] = David;
        addOperators(operators);

        // Setup mock beacon for operator selection
        vm.chainId(1);
        uint256 epochOneStart = LibPreconfConstants.getGenesisTimestamp(block.chainid);
        MockBeaconBlockRoot mockBeacon = new MockBeaconBlockRoot();
        // Current epoch
        uint256 epochTwoStart = epochOneStart + LibPreconfConstants.SECONDS_IN_EPOCH;

        bytes32 mockRoot = bytes32(uint256(1)); // This will select Carol

        address beaconBlockRootContract = LibPreconfConstants.getBeaconBlockRootContract();
        vm.etch(beaconBlockRootContract, address(mockBeacon).code);
        MockBeaconBlockRoot(payable(beaconBlockRootContract)).set(
            epochOneStart + LibPreconfConstants.SECONDS_IN_SLOT, mockRoot
        );

        // Warp to arbitrary slot in epoch 2
        vm.warp(epochTwoStart + 2 * LibPreconfConstants.SECONDS_IN_SLOT);

        // Prank as David (not the selected operator) and propose blocks
        vm.prank(David);
        vm.expectRevert(IPreconfRouter.NotTheOperator.selector);
        router.proposePreconfedBlocks("", "", "", false);
    }

    function test_proposePreconfedBlocks_proposerNotSender() external {
        address[] memory operators = new address[](3);
        operators[0] = Bob;
        operators[1] = Carol;
        operators[2] = David;
        addOperators(operators);

        // Setup mock beacon for operator selection
        vm.chainId(1);
        uint256 epochOneStart = LibPreconfConstants.getGenesisTimestamp(block.chainid);
        // Current epoch
        uint256 epochTwoStart = epochOneStart + LibPreconfConstants.SECONDS_IN_EPOCH;

        MockBeaconBlockRoot mockBeacon = new MockBeaconBlockRoot();
        bytes32 mockRoot = bytes32(uint256(1)); // This will select Carol

        address beaconBlockRootContract = LibPreconfConstants.getBeaconBlockRootContract();
        vm.etch(beaconBlockRootContract, address(mockBeacon).code);
        MockBeaconBlockRoot(payable(beaconBlockRootContract)).set(
            epochOneStart + LibPreconfConstants.SECONDS_IN_SLOT, mockRoot
        );

        // Setup block params
        ITaikoInbox.BlockParams[] memory blockParams = new ITaikoInbox.BlockParams[](1);
        blockParams[0] = ITaikoInbox.BlockParams({ numTransactions: 1, timeShift: 1 });

        ITaikoInbox.BlobParams memory blobParams;

        // Create batch params with DIFFERENT proposer than sender
        ITaikoInbox.BatchParams memory params = ITaikoInbox.BatchParams({
            proposer: Bob, // Set different proposer than sender (Carol)
            coinbase: address(0),
            parentMetaHash: bytes32(0),
            anchorBlockId: 0,
            anchorInput: bytes32(0),
            lastBlockTimestamp: uint64(block.timestamp),
            revertIfNotFirstProposal: false,
            signalSlots: new bytes32[](0),
            blobParams: blobParams,
            blocks: blockParams
        });

        // Warp to arbitrary slot in epoch 2
        vm.warp(epochTwoStart + 2 * LibPreconfConstants.SECONDS_IN_SLOT);

        // Prank as Carol (selected operator) and propose blocks
        vm.prank(Carol);
        vm.expectRevert(IPreconfRouter.ProposerIsNotTheSender.selector);
        router.proposePreconfedBlocks("", abi.encode(params), "", false);
    }

    function test_canProposeFallback_notExpired() external {
        // Store a forced transaction
        vm.deal(address(this), 1 ether);
        router.storeForcedTx{value: 0.1 ether}(testTxList);

        // Ensure fallback cannot be proposed before the inclusion window expires
        assertFalse(router.canProposeFallback(testTxListHash));
    }

    function test_canProposeFallback_expired() external {
        // Store a forced transaction
        vm.deal(address(this), 1 ether);
        router.storeForcedTx{value: 0.1 ether}(testTxList);

        // Warp time beyond the inclusion window
        vm.warp(block.timestamp + router.inclusionWindow() + 1);

        // Ensure fallback can now be proposed
        assertTrue(router.canProposeFallback(testTxListHash));
    }

    function test_storeForcedTx_success() external {
        // Ensure the initial balance is sufficient
        vm.deal(address(this), 10 ether);

        // Store forced transaction with the correct stake
        uint256 requiredStake = router.baseStakeAmount();
        router.storeForcedTx{value: requiredStake}(testTxList);

        // Validate stored transaction data
        (bytes memory storedTxList, uint256 timestamp, bool included, uint256 stakeAmount) = 
            router.forcedTxLists(testTxListHash);

        assertEq(storedTxList, testTxList);
        assertEq(timestamp, block.timestamp);
        assertEq(included, false);
        assertEq(stakeAmount, requiredStake);

        // Ensure the pendingForcedTxHashes count is incremented
        assertEq(router.pendingForcedTxHashes(), 1);
    }

    function test_storeForcedTx_insufficientStake() external {
        vm.deal(address(this), 10 ether);

        uint256 incorrectStake = router.getRequiredStakeAmount() - 1;
        console2.log(router.getRequiredStakeAmount());
        vm.expectRevert(IPreconfRouter.InsufficientStakeAmount.selector);
        router.storeForcedTx{value: incorrectStake}(testTxList);
    }


    function test_storeForcedTx_dynamicStakeIncrease() external {
        vm.deal(address(this), 10 ether);

        uint256 baseStake = router.baseStakeAmount();

        for (uint256 i = 0; i < 3; i++) {
            uint256 expectedStake = baseStake * (i + 1);
            bytes memory newTx = abi.encodePacked(testTxList, i);
            bytes32 newTxHash = keccak256(newTx);

            router.storeForcedTx{value: expectedStake}(newTx);

            (, , , uint256 stakeAmount) = router.forcedTxLists(newTxHash);
            assertEq(stakeAmount, expectedStake);
        }

        assertEq(router.pendingForcedTxHashes(), 3);
    }

    function test_storeForcedTx_duplicate() external {
        vm.deal(address(this), 10 ether);

        router.storeForcedTx{value: router.getRequiredStakeAmount()}(testTxList);

        uint256 requiredStake = router.getRequiredStakeAmount();
        vm.expectRevert(IPreconfRouter.ForcedTxListAlreadyStored.selector);
        router.storeForcedTx{value: requiredStake}(testTxList);
    }

    function test_storeForcedTx_pendingTxCount() external {
        vm.deal(address(this), 10 ether);

        router.storeForcedTx{value: router.baseStakeAmount()}(testTxList);

        assertEq(router.pendingForcedTxHashes(), 1);
    }

}
