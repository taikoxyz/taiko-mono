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

        vm.chainId(1);
        uint256 epochOneStart = LibPreconfConstants.getGenesisTimestamp(block.chainid);
        uint256 currentEpoch = epochOneStart
            + LibPreconfConstants.RANDOMNESS_DELAY_EPOCHS * LibPreconfConstants.SECONDS_IN_EPOCH;
        _setupMockBeacon(epochOneStart, new MockBeaconBlockRoot());

        // Setup Carol with bond tokens
        vm.deal(Carol, 100 ether);
        bondToken.transfer(Carol, 1000 ether);
        vm.startPrank(Carol);
        bondToken.approve(address(inbox), 1000 ether);
        inbox.depositBond(200 ether);
        vm.stopPrank();

        ITaikoInbox.BlockParams[] memory blockParams = new ITaikoInbox.BlockParams[](1);
        blockParams[0] = ITaikoInbox.BlockParams({
            numTransactions: 1,
            timeShift: 0, // First block must have timeShift = 0
            signalSlots: new bytes32[](0)
        });

        ITaikoInbox.BlobParams memory blobParams;
        blobParams.numBlobs = 1; // Required for normal batches
        blobParams.firstBlobIndex = 0;

        ITaikoInbox.BatchParams memory params;
        params.proposer = Carol;
        params.blobParams = blobParams;
        params.blocks = blockParams;

        vm.warp(currentEpoch + 2 * LibPreconfConstants.SECONDS_IN_SLOT);

        // TaikoWrapper expects (bytes, bytes): first is forced inclusion, second is normal batch
        bytes memory wrappedParams = abi.encode(bytes(""), abi.encode(params));

        vm.startSnapshotGas("ProposeAndProve", "proposeBatchWithRouter");
        vm.prank(Carol);
        (, ITaikoInbox.BatchMetadata memory meta) = router.proposeBatch(wrappedParams, "");
        vm.stopSnapshotGas();

        assertEq(meta.proposer, Carol);
    }

    function test_preconfRouter_proposeBatch_notOperator() external {
        address[] memory operators = new address[](3);
        operators[0] = Bob;
        operators[1] = Carol;
        operators[2] = David;
        addOperators(operators);

        vm.chainId(1);
        uint256 epochOneStart = LibPreconfConstants.getGenesisTimestamp(block.chainid);
        uint256 currentEpoch = epochOneStart
            + LibPreconfConstants.RANDOMNESS_DELAY_EPOCHS * LibPreconfConstants.SECONDS_IN_EPOCH;
        _setupMockBeacon(epochOneStart, new MockBeaconBlockRoot());

        vm.warp(currentEpoch + 2 * LibPreconfConstants.SECONDS_IN_SLOT);

        // David is not the selected operator (Carol is)
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

        vm.chainId(1);
        uint256 epochOneStart = LibPreconfConstants.getGenesisTimestamp(block.chainid);
        uint256 currentEpoch = epochOneStart
            + LibPreconfConstants.RANDOMNESS_DELAY_EPOCHS * LibPreconfConstants.SECONDS_IN_EPOCH;
        _setupMockBeacon(epochOneStart, new MockBeaconBlockRoot());

        // Setup Bob with bond tokens
        vm.deal(Bob, 100 ether);
        bondToken.transfer(Bob, 1000 ether);
        vm.startPrank(Bob);
        bondToken.approve(address(inbox), 1000 ether);
        inbox.depositBond(200 ether);
        vm.stopPrank();

        ITaikoInbox.BlockParams[] memory blockParams = new ITaikoInbox.BlockParams[](1);
        blockParams[0] = ITaikoInbox.BlockParams({
            numTransactions: 1,
            timeShift: 0,
            signalSlots: new bytes32[](0)
        });

        ITaikoInbox.BlobParams memory blobParams;
        blobParams.numBlobs = 1;
        blobParams.firstBlobIndex = 0;

        ITaikoInbox.BatchParams memory params;
        params.proposer = Bob; // Different from sender (Carol)
        params.blobParams = blobParams;
        params.blocks = blockParams;

        vm.warp(currentEpoch + 2 * LibPreconfConstants.SECONDS_IN_SLOT);

        bytes memory wrappedParams = abi.encode(bytes(""), abi.encode(params));

        // Carol is the selected operator but tries to propose with Bob as proposer
        vm.prank(Carol);
        vm.expectRevert(IPreconfRouter.ProposerIsNotPreconfer.selector);
        router.proposeBatch(wrappedParams, "");
    }

    function _setupMockBeacon(uint256 epochOneStart, MockBeaconBlockRoot mockBeacon) internal {
        bytes32 mockRoot = bytes32(uint256(1)); // This will select Carol as operator
        vm.etch(LibPreconfConstants.getBeaconBlockRootContract(), address(mockBeacon).code);
        MockBeaconBlockRoot(payable(LibPreconfConstants.getBeaconBlockRootContract())).set(
            epochOneStart + LibPreconfConstants.SECONDS_IN_SLOT, mockRoot
        );
    }
}