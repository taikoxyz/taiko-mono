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

        // Wait for operators to become active (2 epochs delay)
        uint256 activeEpoch = epochOneStart
            + (LibPreconfConstants.RANDOMNESS_DELAY_EPOCHS + 2) * LibPreconfConstants.SECONDS_IN_EPOCH;

        _setupMockBeacon(activeEpoch, new MockBeaconBlockRoot());

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
            isForcedInclusion: false,
            blobParams: blobParams,
            blocks: blockParams,
            proverAuth: ""
        });

        // Warp to when operators are active
        vm.warp(activeEpoch + 2 * LibPreconfConstants.SECONDS_IN_SLOT);

        // Prank as Carol (selected operator) and propose blocks
        vm.prank(Carol);
        (ITaikoInbox.BatchInfo memory info,) = router.v4ProposeBatch(abi.encode(params), "", "");

        // Assert the proposer was set correctly in the metadata
        assertEq(info.proposer, Carol);
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
        // Wait for operators to become active (2 epochs delay)
        uint256 activeEpoch = epochOneStart
            + (LibPreconfConstants.RANDOMNESS_DELAY_EPOCHS + 2) * LibPreconfConstants.SECONDS_IN_EPOCH;
        _setupMockBeacon(activeEpoch, new MockBeaconBlockRoot());

        // Warp to when operators are active
        vm.warp(activeEpoch + 2 * LibPreconfConstants.SECONDS_IN_SLOT);

        // Prank as David (not the selected operator) and propose blocks
        vm.prank(David);
        vm.expectRevert(PreconfRouter.NotPreconfer.selector);
        router.v4ProposeBatch("", "", "");
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
        // Wait for operators to become active (2 epochs delay)
        uint256 activeEpoch = epochOneStart
            + (LibPreconfConstants.RANDOMNESS_DELAY_EPOCHS + 2) * LibPreconfConstants.SECONDS_IN_EPOCH;

        _setupMockBeacon(activeEpoch, new MockBeaconBlockRoot());

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
            isForcedInclusion: false,
            blobParams: blobParams,
            blocks: blockParams,
            proverAuth: ""
        });

        // Warp to when operators are active
        vm.warp(activeEpoch + 2 * LibPreconfConstants.SECONDS_IN_SLOT);

        // Prank as Carol (selected operator) and propose blocks
        vm.prank(Carol);
        vm.expectRevert(PreconfRouter.ProposerIsNotPreconfer.selector);
        router.v4ProposeBatch(abi.encode(params), "", "");
    }

    function _setupMockBeacon(uint256 epochTimestamp, MockBeaconBlockRoot mockBeacon) internal {
        bytes32 mockRoot = bytes32(uint256(1)); // This will select Carol
        vm.etch(LibPreconfConstants.BEACON_BLOCK_ROOT_CONTRACT, address(mockBeacon).code);
        // Set the beacon root for the current epoch timestamp
        MockBeaconBlockRoot(payable(LibPreconfConstants.BEACON_BLOCK_ROOT_CONTRACT)).set(
            epochTimestamp, mockRoot
        );
    }
}
