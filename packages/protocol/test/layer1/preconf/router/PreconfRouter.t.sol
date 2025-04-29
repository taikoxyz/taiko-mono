// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "./PreconfRouterTestBase.sol";
import "../mocks/MockBeaconBlockRoot.sol";
import "src/layer1/based/ITaikoInbox.sol";

contract PreconfRouterTest is PreconfRouterTestBase {
    function test_preconfRouter_proposeBatch() external {
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
        blockParams[0] = ITaikoInbox.BlockParams({
            numTransactions: 1,
            timeShift: 1,
            signalSlots: new bytes32[](0)
        });

        ITaikoInbox.BlobParams memory blobParams;

        // Create batch params with correct structure
        ITaikoInbox.BatchParams memory params = ITaikoInbox.BatchParams({
            proposer: Carol,
            coinbase: address(0),
            parentMetaHash: bytes32(0),
            anchorBlockId: 0,
            lastBlockTimestamp: uint64(block.timestamp),
            revertIfNotFirstProposal: false,
            blobParams: blobParams,
            blocks: blockParams
        });

        // Warp to arbitrary slot in epoch 2
        vm.warp(epochTwoStart + 2 * LibPreconfConstants.SECONDS_IN_SLOT);

        // Prank as Carol (selected operator) and propose blocks
        vm.prank(Carol);
        (, ITaikoInbox.BatchMetadata memory meta) = router.proposeBatch(abi.encode(params), "");

        // Assert the proposer was set correctly in the metadata
        assertEq(meta.proposer, Carol);
    }

    function test_preconfRouter_proposeBatch_notOperator() external {
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
        vm.expectRevert(IPreconfRouter.NotPreconferOrFallback.selector);
        router.proposeBatch("", "");
    }

    function test_preconfRouter_proposeBatch_proposerNotSender() external {
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
        blockParams[0] = ITaikoInbox.BlockParams({
            numTransactions: 1,
            timeShift: 1,
            signalSlots: new bytes32[](0)
        });

        ITaikoInbox.BlobParams memory blobParams;

        // Create batch params with DIFFERENT proposer than sender
        ITaikoInbox.BatchParams memory params = ITaikoInbox.BatchParams({
            proposer: Bob, // Set different proposer than sender (Carol)
            coinbase: address(0),
            parentMetaHash: bytes32(0),
            anchorBlockId: 0,
            lastBlockTimestamp: uint64(block.timestamp),
            revertIfNotFirstProposal: false,
            blobParams: blobParams,
            blocks: blockParams
        });

        // Warp to arbitrary slot in epoch 2
        vm.warp(epochTwoStart + 2 * LibPreconfConstants.SECONDS_IN_SLOT);

        // Prank as Carol (selected operator) and propose blocks
        vm.prank(Carol);
        vm.expectRevert(IPreconfRouter.ProposerIsNotPreconfer.selector);
        router.proposeBatch(abi.encode(params), "");
    }
}
