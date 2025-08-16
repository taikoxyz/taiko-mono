// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "./PreconfRouterTestBase.sol";
import "../mocks/MockBeaconBlockRoot.sol";
import "src/layer1/based/ITaikoInbox.sol";

contract PreconfRouterTest is PreconfRouterTestBase {
    /// forge-config: default.isolate = true
    function test_preconfRouter_proposeBatch() external {
        address[] memory operators = new address[](3);
        operators[0] = Bob;
        operators[1] = Carol;
        operators[2] = David;
        addOperators(operators);

        // Setup mock beacon for operator selection
        vm.chainId(1);
        uint256 epochOneStart = LibPreconfConstants.getGenesisTimestamp(block.chainid);
        // Set current epoch to `RANDOMNESS_DELAY_EPOCHS` epochs after genesis
        uint256 currentEpoch = epochOneStart
            + LibPreconfConstants.RANDOMNESS_DELAY_EPOCHS * LibPreconfConstants.SECONDS_IN_EPOCH;

        _setupMockBeacon(epochOneStart, new MockBeaconBlockRoot());

        // Setup Carol with bond tokens and deposit bond
        vm.deal(Carol, 100 ether);
        bondToken.transfer(Carol, 1000 ether);
        vm.startPrank(Carol);
        bondToken.approve(address(inbox), 1000 ether);
        inbox.depositBond(200 ether);
        vm.stopPrank();

        // Setup block params
        ITaikoInbox.BlockParams[] memory blockParams = new ITaikoInbox.BlockParams[](1);
        blockParams[0] = ITaikoInbox.BlockParams({
            numTransactions: 1,
            timeShift: 0, // First block must have timeShift = 0
            signalSlots: new bytes32[](0)
        });

        ITaikoInbox.BlobParams memory blobParams;
        // For normal batches through TaikoWrapper, we need to specify numBlobs
        blobParams.numBlobs = 1; // At least one blob is required for normal batches
        blobParams.firstBlobIndex = 0; // Start from first available blob

        // Create batch params with correct structure
        // Note: Most fields can be left as defaults (0/false/empty)
        ITaikoInbox.BatchParams memory params;
        params.proposer = Carol;
        params.blobParams = blobParams;
        params.blocks = blockParams;

        // Warp to arbitrary slot in current epoch
        vm.warp(currentEpoch + 2 * LibPreconfConstants.SECONDS_IN_SLOT);

        // Prank as Carol (selected operator) and propose blocks
        // TaikoWrapper expects (bytes, bytes) format where first is forced inclusion, second is
        // normal batch
        bytes memory wrappedParams = abi.encode(bytes(""), abi.encode(params));

        vm.startSnapshotGas("ProposeAndProve", "proposeBatchWithRouter");
        vm.prank(Carol);
        (ITaikoInbox.BatchInfo memory info, ITaikoInbox.BatchMetadata memory meta) =
            router.proposeBatch(wrappedParams, "");
        vm.stopSnapshotGas();

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
        // Current epoch
        uint256 currentEpoch = epochOneStart
            + LibPreconfConstants.RANDOMNESS_DELAY_EPOCHS * LibPreconfConstants.SECONDS_IN_EPOCH;
        _setupMockBeacon(epochOneStart, new MockBeaconBlockRoot());

        // Warp to arbitrary slot in current epoch
        vm.warp(currentEpoch + 2 * LibPreconfConstants.SECONDS_IN_SLOT);

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
        uint256 currentEpoch = epochOneStart
            + LibPreconfConstants.RANDOMNESS_DELAY_EPOCHS * LibPreconfConstants.SECONDS_IN_EPOCH;

        _setupMockBeacon(epochOneStart, new MockBeaconBlockRoot());

        // Setup Bob with bond tokens since he'll be the proposer
        vm.deal(Bob, 100 ether);
        bondToken.transfer(Bob, 1000 ether);
        vm.startPrank(Bob);
        bondToken.approve(address(inbox), 1000 ether);
        inbox.depositBond(200 ether);
        vm.stopPrank();

        // Setup block params
        ITaikoInbox.BlockParams[] memory blockParams = new ITaikoInbox.BlockParams[](1);
        blockParams[0] = ITaikoInbox.BlockParams({
            numTransactions: 1,
            timeShift: 0, // First block must have timeShift = 0
            signalSlots: new bytes32[](0)
        });

        ITaikoInbox.BlobParams memory blobParams;
        // For normal batches through TaikoWrapper, we need to specify numBlobs
        blobParams.numBlobs = 1; // At least one blob is required for normal batches
        blobParams.firstBlobIndex = 0; // Start from first available blob

        // Create batch params with DIFFERENT proposer than sender
        ITaikoInbox.BatchParams memory params;
        params.proposer = Bob; // Set different proposer than sender (Carol)
        params.blobParams = blobParams;
        params.blocks = blockParams;

        // Warp to arbitrary slot in current epoch
        vm.warp(currentEpoch + 2 * LibPreconfConstants.SECONDS_IN_SLOT);

        // Prank as Carol (selected operator) and propose blocks
        // TaikoWrapper expects (bytes, bytes) format where first is forced inclusion, second is
        // normal batch
        bytes memory wrappedParams = abi.encode(bytes(""), abi.encode(params));

        vm.prank(Carol);
        vm.expectRevert(IPreconfRouter.ProposerIsNotPreconfer.selector);
        router.proposeBatch(wrappedParams, "");
    }

    function _setupMockBeacon(uint256 epochOneStart, MockBeaconBlockRoot mockBeacon) internal {
        bytes32 mockRoot = bytes32(uint256(1)); // This will select Carol
        vm.etch(LibPreconfConstants.getBeaconBlockRootContract(), address(mockBeacon).code);
        MockBeaconBlockRoot(payable(LibPreconfConstants.getBeaconBlockRootContract())).set(
            epochOneStart + LibPreconfConstants.SECONDS_IN_SLOT, mockRoot
        );
    }
}