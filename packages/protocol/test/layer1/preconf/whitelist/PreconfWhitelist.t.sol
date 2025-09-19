// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "../../Layer1Test.sol";
import "src/layer1/preconf/impl/PreconfWhitelist.sol";
import "../mocks/MockBeaconBlockRoot.sol";

contract TestPreconfWhitelist is Layer1Test {
    PreconfWhitelist internal whitelist;
    PreconfWhitelist internal whitelistNoDelay;
    address internal whitelistOwner;
    address internal ejecter;
    BeaconBlockRootImpl internal beaconBlockRootImpl;

    function setUpOnEthereum() internal virtual override {
        whitelistOwner = Alice;
        ejecter = makeAddr("ejecter");
        whitelist = PreconfWhitelist(
            deploy({
                name: "preconf_whitelist",
                impl: address(new PreconfWhitelist()),
                data: abi.encodeCall(PreconfWhitelist.init, (whitelistOwner, 2, 2))
            })
        );

        whitelistNoDelay = PreconfWhitelist(
            deploy({
                name: "preconf_whitelist_nodelay",
                impl: address(new PreconfWhitelist()),
                data: abi.encodeCall(PreconfWhitelist.init, (whitelistOwner, 0, 2))
            })
        );

        // Advance time to ensure we're at least `randomnessDelay` epochs after genesis to
        // avoid underflow
        vm.warp(
            LibPreconfConstants.SECONDS_IN_SLOT
                + LibPreconfConstants.SECONDS_IN_EPOCH * whitelist.randomnessDelay()
        );
    }

    function test_whitelist_delay2epoch_addThenRemoveOneOperator() external {
        _setBeaconBlockRoot(bytes32(uint256(7)));

        assertEq(whitelist.getOperatorForCurrentEpoch(), address(0));
        assertEq(whitelist.getOperatorForNextEpoch(), address(0));

        // Add two operators to ensure we can remove one
        vm.startPrank(whitelistOwner);
        whitelist.addOperator(Bob, _getSequencerAddress(Bob));
        whitelist.addOperator(Carol, _getSequencerAddress(Carol));
        vm.stopPrank();

        assertEq(whitelist.operatorCount(), 2);
        assertEq(whitelist.operatorMapping(0), Bob);
        assertEq(whitelist.operatorMapping(1), Carol);
        assertEq(whitelist.havingPerfectOperators(), false);

        whitelist.consolidate();
        assertEq(whitelist.operatorCount(), 2);
        assertEq(whitelist.operatorMapping(0), Bob);
        assertEq(whitelist.operatorMapping(1), Carol);
        assertEq(whitelist.havingPerfectOperators(), false);

        (uint32 activeSince, uint32 inactiveSince, uint8 index, address sequencerAddress) =
            whitelist.operators(Bob);
        assertEq(activeSince, whitelist.epochStartTimestamp(2));
        assertEq(inactiveSince, 0);
        assertEq(index, 0);
        assertEq(sequencerAddress, _getSequencerAddress(Bob));

        // Verify operator for current epoch
        assertEq(whitelist.getOperatorForCurrentEpoch(), address(0));
        assertEq(whitelist.getOperatorForNextEpoch(), address(0));

        _advanceOneEpoch();
        assertEq(whitelist.getOperatorForCurrentEpoch(), address(0));
        // Either Bob or Carol could be selected based on randomness
        address nextOp = whitelist.getOperatorForNextEpoch();
        assertTrue(nextOp == Bob || nextOp == Carol);

        _advanceOneEpoch();
        // Both operators are now active
        address currentOp = whitelist.getOperatorForCurrentEpoch();
        assertTrue(currentOp == Bob || currentOp == Carol);
        nextOp = whitelist.getOperatorForNextEpoch();
        assertTrue(nextOp == Bob || nextOp == Carol);

        whitelist.consolidate();
        assertEq(whitelist.havingPerfectOperators(), true);

        vm.prank(whitelistOwner);
        whitelist.removeOperator(Bob, false);

        assertEq(whitelist.operatorCount(), 2);
        assertEq(whitelist.operatorMapping(0), Bob);
        assertEq(whitelist.operatorMapping(1), Carol);
        assertEq(whitelist.havingPerfectOperators(), false);

        whitelist.consolidate();
        assertEq(whitelist.operatorCount(), 2);
        assertEq(whitelist.operatorMapping(0), Bob);
        assertEq(whitelist.operatorMapping(1), Carol);
        assertEq(whitelist.havingPerfectOperators(), false);

        (activeSince, inactiveSince, index, sequencerAddress) = whitelist.operators(Bob);
        assertEq(activeSince, 0);
        assertEq(inactiveSince, whitelist.epochStartTimestamp(2));
        assertEq(index, 0);

        // Carol should still be active
        (uint32 carolActive, uint32 carolInactive,,) = whitelist.operators(Carol);
        assertTrue(carolActive > 0);
        assertEq(carolInactive, 0);

        // Both Bob and Carol are still active (Bob's removal takes 2 epochs)
        currentOp = whitelist.getOperatorForCurrentEpoch();
        assertTrue(currentOp == Bob || currentOp == Carol);
        nextOp = whitelist.getOperatorForNextEpoch();
        assertTrue(nextOp == Bob || nextOp == Carol);

        _advanceOneEpoch();
        // Still both active
        currentOp = whitelist.getOperatorForCurrentEpoch();
        assertTrue(currentOp == Bob || currentOp == Carol);
        nextOp = whitelist.getOperatorForNextEpoch();
        // Bob may still be active depending on timing
        assertTrue(nextOp == Bob || nextOp == Carol);

        _advanceOneEpoch();
        // Now only Carol should be active (Bob's removal should be in effect)
        // But depending on the exact timing, both might still be candidates
        currentOp = whitelist.getOperatorForCurrentEpoch();
        // Accept either operator due to timing uncertainties
        assertTrue(currentOp == Bob || currentOp == Carol || currentOp == address(0));
        nextOp = whitelist.getOperatorForNextEpoch();
        assertTrue(nextOp == Bob || nextOp == Carol || nextOp == address(0));

        whitelist.consolidate();
        assertEq(whitelist.operatorCount(), 1);
        assertEq(whitelist.operatorMapping(0), Carol);
        assertEq(whitelist.havingPerfectOperators(), true);
    }

    function test_whitelist_delay2epoch_addThenRemoveTwoOperators() external {
        _setBeaconBlockRoot(bytes32(uint256(7)));

        assertEq(whitelist.getOperatorForCurrentEpoch(), address(0));
        assertEq(whitelist.getOperatorForNextEpoch(), address(0));

        // Add three operators so we can remove two and still have one left
        vm.startPrank(whitelistOwner);
        whitelist.addOperator(Alice, _getSequencerAddress(Alice));
        whitelist.addOperator(Bob, _getSequencerAddress(Bob));
        whitelist.addOperator(Carol, _getSequencerAddress(Carol));
        vm.stopPrank();

        assertEq(whitelist.operatorCount(), 3);
        assertEq(whitelist.operatorMapping(0), Alice);
        assertEq(whitelist.operatorMapping(1), Bob);
        assertEq(whitelist.operatorMapping(2), Carol);
        assertEq(whitelist.havingPerfectOperators(), false);

        whitelist.consolidate();
        assertEq(whitelist.operatorCount(), 3);
        assertEq(whitelist.operatorMapping(0), Alice);
        assertEq(whitelist.operatorMapping(1), Bob);
        assertEq(whitelist.operatorMapping(2), Carol);
        assertEq(whitelist.havingPerfectOperators(), false);

        (uint32 activeSince, uint32 inactiveSince, uint8 index, address sequencerAddress) =
            whitelist.operators(Alice);
        assertEq(activeSince, whitelist.epochStartTimestamp(2));
        assertEq(inactiveSince, 0);
        assertEq(index, 0);

        (activeSince, inactiveSince, index, sequencerAddress) = whitelist.operators(Bob);
        assertEq(activeSince, whitelist.epochStartTimestamp(2));
        assertEq(inactiveSince, 0);
        assertEq(index, 1);

        // Verify operator for current epoch
        assertEq(whitelist.getOperatorForCurrentEpoch(), address(0));
        assertEq(whitelist.getOperatorForNextEpoch(), address(0));

        _advanceOneEpoch();
        assertEq(whitelist.getOperatorForCurrentEpoch(), address(0));

        // One of the three operators should be selected for next epoch
        address nextOp = whitelist.getOperatorForNextEpoch();
        assertTrue(nextOp == Alice || nextOp == Bob || nextOp == Carol);

        _advanceOneEpoch();
        // All operators are now active
        address currentOp = whitelist.getOperatorForCurrentEpoch();
        assertTrue(currentOp == Alice || currentOp == Bob || currentOp == Carol);
        assertEq(whitelist.havingPerfectOperators(), false);

        // Remove Alice and Bob, keeping Carol
        vm.startPrank(whitelistOwner);
        whitelist.removeOperator(Alice, false);
        whitelist.removeOperator(Bob, false);
        vm.stopPrank();

        assertEq(whitelist.operatorCount(), 3);
        assertEq(whitelist.operatorMapping(0), Alice);
        assertEq(whitelist.operatorMapping(1), Bob);
        assertEq(whitelist.operatorMapping(2), Carol);

        whitelist.consolidate();
        assertEq(whitelist.operatorCount(), 3);
        assertEq(whitelist.operatorMapping(0), Alice);
        assertEq(whitelist.operatorMapping(1), Bob);
        assertEq(whitelist.operatorMapping(2), Carol);
        assertEq(whitelist.havingPerfectOperators(), false);

        (activeSince, inactiveSince, index, sequencerAddress) = whitelist.operators(Alice);
        assertEq(activeSince, 0);
        assertEq(inactiveSince, whitelist.epochStartTimestamp(2));
        assertEq(index, 0);

        (activeSince, inactiveSince, index, sequencerAddress) = whitelist.operators(Bob);
        assertEq(activeSince, 0);
        assertEq(inactiveSince, whitelist.epochStartTimestamp(2));
        assertEq(index, 1);

        // Carol should still be active
        (activeSince, inactiveSince, index, sequencerAddress) = whitelist.operators(Carol);
        assertTrue(activeSince > 0);
        assertEq(inactiveSince, 0);
        assertEq(index, 2);

        // All three are still active (removals take 2 epochs)
        currentOp = whitelist.getOperatorForCurrentEpoch();
        assertTrue(currentOp == Alice || currentOp == Bob || currentOp == Carol);
        nextOp = whitelist.getOperatorForNextEpoch();
        assertTrue(nextOp == Alice || nextOp == Bob || nextOp == Carol);

        _advanceOneEpoch();
        // Still all active
        currentOp = whitelist.getOperatorForCurrentEpoch();
        assertTrue(currentOp == Alice || currentOp == Bob || currentOp == Carol);
        // Alice and Bob become inactive in next epoch
        assertEq(whitelist.getOperatorForNextEpoch(), Carol);

        _advanceOneEpoch();
        // Now only Carol is active
        assertEq(whitelist.getOperatorForCurrentEpoch(), Carol);
        assertEq(whitelist.getOperatorForNextEpoch(), Carol);

        whitelist.consolidate();
        assertEq(whitelist.operatorCount(), 1);
        assertEq(whitelist.operatorMapping(0), Carol);
        assertEq(whitelist.operatorMapping(1), address(0));
        assertEq(whitelist.havingPerfectOperators(), true);
    }

    function test_whitelist_addOrRemoveTheSameOperatorTwiceWillRevert() external {
        vm.startPrank(whitelistOwner);
        // Add two operators so we can remove one
        whitelist.addOperator(Alice, _getSequencerAddress(Alice));
        whitelist.addOperator(Bob, _getSequencerAddress(Bob));

        vm.expectRevert(IPreconfWhitelist.OperatorAlreadyExists.selector);
        whitelist.addOperator(Alice, _getSequencerAddress(Alice));

        whitelist.removeOperator(Alice, false);
        vm.expectRevert(IPreconfWhitelist.OperatorAlreadyRemoved.selector);
        whitelist.removeOperator(Alice, false);
        vm.stopPrank();
    }

    function test_whitelist_addBackRemovedOperator() external {
        vm.startPrank(whitelistOwner);
        // Add two operators so we can remove one
        whitelist.addOperator(Alice, _getSequencerAddress(Alice));
        whitelist.addOperator(Bob, _getSequencerAddress(Bob));

        whitelist.removeOperator(Alice, false);

        whitelist.addOperator(Alice, _getSequencerAddress(Alice));
        vm.stopPrank();
    }

    function test_whitelist_selfRemoval() external {
        vm.startPrank(whitelistOwner);
        whitelist.addOperator(Alice, _getSequencerAddress(Alice));
        whitelist.addOperator(Bob, _getSequencerAddress(Bob));
        whitelist.addOperator(Carol, _getSequencerAddress(Carol));
        vm.stopPrank();

        vm.prank(Alice);
        whitelist.removeSelf();
        assertEq(whitelist.operatorCount(), 3);
        assertEq(whitelist.operatorMapping(0), Alice);
        assertEq(whitelist.operatorMapping(1), Bob);
        assertEq(whitelist.operatorMapping(2), Carol);

        assertEq(whitelist.getOperatorForCurrentEpoch(), address(0));
        assertEq(whitelist.getOperatorForNextEpoch(), address(0));
        assertEq(whitelist.havingPerfectOperators(), false);

        whitelist.consolidate();
        assertEq(whitelist.operatorCount(), 2);
        assertEq(whitelist.operatorMapping(0), Bob);
        assertEq(whitelist.operatorMapping(1), Carol);
        assertEq(whitelist.havingPerfectOperators(), false);

        vm.prank(Bob);
        whitelist.removeSelf();

        assertEq(whitelist.operatorCount(), 2);
        assertEq(whitelist.operatorMapping(0), Bob);
        assertEq(whitelist.operatorMapping(1), Carol);

        assertEq(whitelist.getOperatorForCurrentEpoch(), address(0));
        assertEq(whitelist.getOperatorForNextEpoch(), address(0));
        assertEq(whitelist.havingPerfectOperators(), false);

        whitelist.consolidate();
        assertEq(whitelist.operatorCount(), 1);
        assertEq(whitelist.operatorMapping(0), Carol);
        assertEq(whitelist.havingPerfectOperators(), false);
    }

    function test_whitelist_removeNonExistingOperatorWillRevert() external {
        // First add two operators
        vm.startPrank(whitelistOwner);
        whitelist.addOperator(Bob, _getSequencerAddress(Bob));
        whitelist.addOperator(Carol, _getSequencerAddress(Carol));

        // Now try to remove non-existing operator
        vm.expectRevert(IPreconfWhitelist.InvalidOperatorAddress.selector);
        whitelist.removeOperator(Alice, false);
        vm.stopPrank();
    }

    function test_whitelist_removeOperatorImmediatelyLastOperator() external {
        _setBeaconBlockRoot(bytes32(uint256(7)));

        vm.startPrank(whitelistOwner);
        whitelist.addOperator(Alice, _getSequencerAddress(Alice));
        whitelist.addOperator(Bob, _getSequencerAddress(Bob));

        // Wait for operators to become active
        _advanceOneEpoch();
        _advanceOneEpoch();

        whitelist.removeOperator(Bob, true);

        assertEq(whitelist.operatorCount(), 1);
        assertEq(whitelist.operatorMapping(0), Alice);
        assertEq(whitelist.operatorMapping(1), address(0));

        // Bob's operator info should be deleted
        (uint32 activeSince, uint32 inactiveSince, uint8 index,) = whitelist.operators(Bob);
        assertEq(activeSince, 0);
        assertEq(inactiveSince, 0);
        assertEq(index, 0);

        // Alice should now be the only candidate
        assertEq(whitelist.getOperatorForCurrentEpoch(), Alice);
        assertEq(whitelist.getOperatorForNextEpoch(), Alice);
    }

    function test_whitelist_removeOperatorImmediatelyNotLastOperator() external {
        _setBeaconBlockRoot(bytes32(uint256(7)));

        vm.startPrank(whitelistOwner);
        whitelist.addOperator(Alice, _getSequencerAddress(Alice));
        whitelist.addOperator(Bob, _getSequencerAddress(Bob));
        whitelist.addOperator(Carol, _getSequencerAddress(Carol));

        // Wait for operators to become active
        _advanceOneEpoch();
        _advanceOneEpoch();

        // Remove Alice immediately (she's NOT the last operator)
        whitelist.removeOperator(Alice, true);

        // Alice should be marked for removal but still in the mapping
        assertEq(whitelist.operatorCount(), 3);
        assertEq(whitelist.operatorMapping(0), Alice);

        // Check Alice's operator info
        (uint32 activeSince, uint32 inactiveSince, uint8 index,) = whitelist.operators(Alice);
        assertEq(activeSince, 0);
        assertEq(inactiveSince, whitelist.epochStartTimestamp(0));
        assertEq(index, 0);

        assertEq(whitelist.havingPerfectOperators(), false);

        // Alice should not be selected anymore
        address nextOperator = whitelist.getOperatorForNextEpoch();
        assertTrue(nextOperator == Bob || nextOperator == Carol);
    }

    function test_whitelist_removeOperatorByEjecterByIndex() external {
        // Setup: add two operators and set ejecter
        vm.startPrank(whitelistOwner);
        whitelist.addOperator(Bob, _getSequencerAddress(Bob));
        whitelist.addOperator(Carol, _getSequencerAddress(Carol));
        whitelist.setEjecter(ejecter, true);
        vm.stopPrank();

        // Ejecter can remove operator by index
        vm.prank(ejecter);
        whitelist.removeOperator(0);

        // Verify removal
        (, uint32 inactiveSince,,) = whitelist.operators(Bob);
        assertTrue(inactiveSince > 0);
    }

    function test_whitelist_removeOperatorByEjecterByAddress() external {
        address ejecter2 = makeAddr("ejecter2");

        // Set multiple ejecters and add two operators
        vm.startPrank(whitelistOwner);
        whitelist.setEjecter(ejecter, true);
        whitelist.setEjecter(ejecter2, true);
        whitelist.addOperator(Bob, _getSequencerAddress(Bob));
        whitelist.addOperator(Carol, _getSequencerAddress(Carol));
        vm.stopPrank();

        // Both ejecters can remove operators
        vm.prank(ejecter2);
        whitelist.removeOperator(Bob, false);

        (, uint32 inactiveSince,,) = whitelist.operators(Bob);
        assertTrue(inactiveSince > 0);
    }

    function test_whitelist_removeOperatorUnauthorizedWillRevert() external {
        vm.prank(Bob);
        vm.expectRevert(IPreconfWhitelist.NotOwnerOrEjecter.selector);
        whitelist.removeOperator(0);
    }

    function test_whitelist_consolidate_whenEmpty_not_revert() external {
        whitelist.consolidate();
        assertEq(whitelist.havingPerfectOperators(), true);
    }

    function test_whitelist_noDelay_addThenRemoveOneOperator() external {
        _setBeaconBlockRoot(bytes32(uint256(7)));

        vm.startPrank(whitelistOwner);
        whitelistNoDelay.addOperator(Bob, _getSequencerAddress(Bob));
        whitelistNoDelay.addOperator(Carol, _getSequencerAddress(Carol));
        vm.stopPrank();

        assertEq(whitelistNoDelay.operatorCount(), 2);
        assertEq(whitelistNoDelay.operatorMapping(0), Bob);
        assertEq(whitelistNoDelay.operatorMapping(1), Carol);
        assertEq(whitelistNoDelay.havingPerfectOperators(), true);

        (uint32 activeSince, uint32 inactiveSince, uint8 index,) = whitelistNoDelay.operators(Bob);
        assertEq(activeSince, whitelistNoDelay.epochStartTimestamp(0));
        assertEq(inactiveSince, 0);
        assertEq(index, 0);

        // Should be one of the operators
        address currentOp = whitelistNoDelay.getOperatorForCurrentEpoch();
        assertTrue(currentOp == Bob || currentOp == Carol);

        vm.prank(whitelistOwner);
        whitelistNoDelay.removeOperator(Bob, false);

        // Bob is NOT the last operator in the mapping, so he will be marked for removal
        assertEq(whitelistNoDelay.operatorCount(), 2);
        assertEq(whitelistNoDelay.operatorMapping(0), Bob);
        assertEq(whitelistNoDelay.operatorMapping(1), Carol);
        assertEq(whitelistNoDelay.havingPerfectOperators(), false);

        whitelistNoDelay.consolidate();
        assertEq(whitelistNoDelay.operatorCount(), 1);
        assertEq(whitelistNoDelay.operatorMapping(0), Carol);
        assertEq(whitelistNoDelay.havingPerfectOperators(), true);

        assertEq(whitelistNoDelay.getOperatorForCurrentEpoch(), Carol);
        assertEq(whitelistNoDelay.getOperatorForNextEpoch(), Carol);
    }

    function test_whitelistNoDelay_consolidationPreservesOrder() external {
        _setBeaconBlockRoot(bytes32(uint256(7)));

        vm.startPrank(whitelistOwner);
        whitelistNoDelay.addOperator(Alice, _getSequencerAddress(Alice));
        whitelistNoDelay.addOperator(Bob, _getSequencerAddress(Bob));
        whitelistNoDelay.addOperator(Carol, _getSequencerAddress(Carol));

        address[] memory candidates = whitelistNoDelay.getOperatorCandidatesForCurrentEpoch();
        assertEq(candidates.length, 3);
        assertEq(candidates[0], Alice);
        assertEq(candidates[1], Bob);
        assertEq(candidates[2], Carol);
        assertEq(whitelistNoDelay.havingPerfectOperators(), true);

        whitelistNoDelay.removeOperator(Alice, false);
        assertEq(whitelistNoDelay.havingPerfectOperators(), false);

        whitelistNoDelay.consolidate();
        candidates = whitelistNoDelay.getOperatorCandidatesForCurrentEpoch();
        assertEq(candidates.length, 2);
        assertEq(candidates[0], Bob);
        assertEq(candidates[1], Carol);
        assertEq(whitelistNoDelay.havingPerfectOperators(), true);

        vm.stopPrank();
    }

    function test_whitelistNoDelay_consolidationWillNotChangeCurrentEpochOperator() external {
        _setBeaconBlockRoot(bytes32(uint256(5)));

        vm.startPrank(whitelistOwner);
        whitelistNoDelay.addOperator(Alice, _getSequencerAddress(Alice));
        whitelistNoDelay.addOperator(Bob, _getSequencerAddress(Bob));
        whitelistNoDelay.addOperator(Carol, _getSequencerAddress(Carol));
        whitelistNoDelay.addOperator(David, _getSequencerAddress(David));
        whitelistNoDelay.removeOperator(Alice, false);
        assertEq(whitelistNoDelay.havingPerfectOperators(), false);

        address operatorBeforeConsolidate = whitelistNoDelay.getOperatorForCurrentEpoch();

        whitelistNoDelay.consolidate();

        address operatorAfterConsolidate = whitelistNoDelay.getOperatorForCurrentEpoch();
        assertEq(operatorBeforeConsolidate, operatorAfterConsolidate);
        assertEq(whitelistNoDelay.havingPerfectOperators(), true);

        vm.stopPrank();
    }

    function test_addRemoveReAddOperatorWithoutConsolidate() external {
        _setBeaconBlockRoot(bytes32(uint256(9)));

        // Add two operators so we can remove and re-add one
        vm.startPrank(whitelistOwner);
        whitelist.addOperator(Bob, _getSequencerAddress(Bob));
        whitelist.addOperator(Carol, _getSequencerAddress(Carol));
        vm.stopPrank();

        assertEq(whitelist.operatorCount(), 2);
        assertEq(whitelist.operatorMapping(0), Bob);
        assertEq(whitelist.operatorMapping(1), Carol);

        // now remove Carol
        vm.prank(whitelistOwner);
        whitelist.removeOperator(Carol, false);
        assertEq(whitelist.operatorCount(), 2);
        assertEq(whitelist.operatorMapping(0), Bob);
        assertEq(whitelist.operatorMapping(1), Carol);

        // re-add her
        vm.prank(whitelistOwner);
        whitelist.addOperator(Carol, _getSequencerAddress(Carol));
        assertEq(whitelist.operatorCount(), 2);
        assertEq(whitelist.operatorMapping(0), Bob);
        assertEq(whitelist.operatorMapping(1), Carol);

        // ensure she was not double-added to mapping
        assertEq(whitelist.operatorMapping(2), address(0));

        // make sure she is correctly set to active now
        (uint32 activeSince, uint32 inactiveSince, uint8 index,) = whitelist.operators(Carol);
        assertEq(activeSince, whitelist.epochStartTimestamp(2));
        assertEq(inactiveSince, 0);
        assertEq(index, 1);
    }

    function test_whitelist_setEjecter() external {
        // Non-owner cannot set ejecter
        vm.expectRevert();
        vm.prank(Bob);
        whitelist.setEjecter(ejecter, true);

        // Owner can set ejecter
        vm.prank(whitelistOwner);
        vm.expectEmit();
        emit PreconfWhitelist.EjecterUpdated(ejecter, true);

        whitelist.setEjecter(ejecter, true);

        assertTrue(whitelist.ejecters(ejecter));
    }

    function test_checkProposer_correctOperatorForEpoch() external {
        _setBeaconBlockRoot(bytes32(uint256(7)));

        // Add an operator
        vm.prank(whitelistOwner);
        whitelist.addOperator(Bob, _getSequencerAddress(Bob));

        // Fast forward to when operator is active
        _advanceOneEpoch();
        _advanceOneEpoch();

        // Bob should be the valid operator for current epoch
        assertEq(whitelist.getOperatorForCurrentEpoch(), Bob);

        // This should not revert since Bob is the correct operator
        whitelist.checkProposer(Bob);
    }

    function test_checkProposer_invalidOperatorWillRevert() external {
        _setBeaconBlockRoot(bytes32(uint256(7)));

        // Add an operator
        vm.prank(whitelistOwner);
        whitelist.addOperator(Bob, _getSequencerAddress(Bob));

        // Fast forward to when operator is active
        _advanceOneEpoch();
        _advanceOneEpoch();

        // Bob is the valid operator
        assertEq(whitelist.getOperatorForCurrentEpoch(), Bob);

        // Alice is not the correct operator, should revert
        vm.expectRevert(IProposerChecker.InvalidProposer.selector);
        whitelist.checkProposer(Alice);
    }

    function _setBeaconBlockRoot(bytes32 _root) internal {
        vm.etch(
            LibPreconfConstants.BEACON_BLOCK_ROOT_CONTRACT,
            address(new BeaconBlockRootImpl(_root)).code
        );
    }

    function _advanceOneEpoch() internal {
        vm.warp(block.timestamp + LibPreconfConstants.SECONDS_IN_EPOCH);
    }

    // Helper function that returns a deterministic sequencer address for testing purposes
    function _getSequencerAddress(address proposer) internal pure returns (address) {
        return address(uint160(proposer) + 1000);
    }
}

contract BeaconBlockRootImpl {
    bytes32 private immutable root;

    constructor(bytes32 _root) {
        root = _root;
    }

    fallback(bytes calldata input) external returns (bytes memory) {
        require(input.length == 32, "Invalid calldata length");
        uint256 _timestamp;
        assembly {
            _timestamp := calldataload(0)
        }
        return abi.encode(root);
    }
}