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
                data: abi.encodeCall(PreconfWhitelist.init, (whitelistOwner, 2, 2, 0))
            })
        );

        whitelistNoDelay = PreconfWhitelist(
            deploy({
                name: "preconf_whitelist_nodelay",
                impl: address(new PreconfWhitelist()),
                data: abi.encodeCall(PreconfWhitelist.init, (whitelistOwner, 0, 2, 0))
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

        vm.prank(whitelistOwner);
        whitelist.addOperator(Bob, _getSequencerAddress(Bob));

        assertEq(whitelist.operatorCount(), 1);
        assertEq(whitelist.operatorMapping(0), Bob);
        assertEq(whitelist.havingPerfectOperators(), false);

        whitelist.consolidate();
        assertEq(whitelist.operatorCount(), 1);
        assertEq(whitelist.operatorMapping(0), Bob);
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
        assertEq(whitelist.getOperatorForNextEpoch(), Bob);

        _advanceOneEpoch();
        assertEq(whitelist.getOperatorForCurrentEpoch(), Bob);
        assertEq(whitelist.getOperatorForNextEpoch(), Bob);

        whitelist.consolidate();
        assertEq(whitelist.havingPerfectOperators(), true);

        vm.prank(whitelistOwner);
        whitelist.removeOperator(Bob, false);

        assertEq(whitelist.operatorCount(), 1);
        assertEq(whitelist.operatorMapping(0), Bob);
        assertEq(whitelist.havingPerfectOperators(), false);

        whitelist.consolidate();
        assertEq(whitelist.operatorCount(), 1);
        assertEq(whitelist.operatorMapping(0), Bob);
        assertEq(whitelist.havingPerfectOperators(), false);

        (activeSince, inactiveSince, index, sequencerAddress) = whitelist.operators(Bob);
        assertEq(activeSince, 0);
        assertEq(inactiveSince, whitelist.epochStartTimestamp(2));
        assertEq(index, 0);

        assertEq(whitelist.getOperatorForCurrentEpoch(), Bob);
        assertEq(whitelist.getOperatorForNextEpoch(), Bob);

        _advanceOneEpoch();
        assertEq(whitelist.getOperatorForCurrentEpoch(), Bob);
        assertEq(whitelist.getOperatorForNextEpoch(), address(0));

        _advanceOneEpoch();
        assertEq(whitelist.getOperatorForCurrentEpoch(), address(0));
        assertEq(whitelist.getOperatorForNextEpoch(), address(0));

        whitelist.consolidate();
        assertEq(whitelist.operatorCount(), 0);
        assertEq(whitelist.operatorMapping(0), address(0));
        assertEq(whitelist.havingPerfectOperators(), true);
    }

    function test_whitelist_delay2epoch_addThenRemoveTwoOperators() external {
        _setBeaconBlockRoot(bytes32(uint256(7)));

        assertEq(whitelist.getOperatorForCurrentEpoch(), address(0));
        assertEq(whitelist.getOperatorForNextEpoch(), address(0));

        vm.prank(whitelistOwner);
        whitelist.addOperator(Alice, _getSequencerAddress(Alice));
        vm.prank(whitelistOwner);
        whitelist.addOperator(Bob, _getSequencerAddress(Bob));

        assertEq(whitelist.operatorCount(), 2);
        assertEq(whitelist.operatorMapping(0), Alice);
        assertEq(whitelist.operatorMapping(1), Bob);
        assertEq(whitelist.havingPerfectOperators(), false);

        whitelist.consolidate();
        assertEq(whitelist.operatorCount(), 2);
        assertEq(whitelist.operatorMapping(0), Alice);
        assertEq(whitelist.operatorMapping(1), Bob);
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
        assertEq(whitelist.getOperatorForNextEpoch(), Bob);

        _advanceOneEpoch();
        assertEq(whitelist.getOperatorForCurrentEpoch(), Bob);
        assertEq(whitelist.getOperatorForNextEpoch(), Bob);
        assertEq(whitelist.havingPerfectOperators(), false);

        vm.prank(whitelistOwner);
        whitelist.removeOperator(Alice, false);
        vm.prank(whitelistOwner);
        whitelist.removeOperator(Bob, false);

        assertEq(whitelist.operatorCount(), 2);
        assertEq(whitelist.operatorMapping(0), Alice);
        assertEq(whitelist.operatorMapping(1), Bob);

        whitelist.consolidate();
        assertEq(whitelist.operatorCount(), 2);
        assertEq(whitelist.operatorMapping(0), Alice);
        assertEq(whitelist.operatorMapping(1), Bob);
        assertEq(whitelist.havingPerfectOperators(), false);

        (activeSince, inactiveSince, index, sequencerAddress) = whitelist.operators(Alice);
        assertEq(activeSince, 0);
        assertEq(inactiveSince, whitelist.epochStartTimestamp(2));
        assertEq(index, 0);

        (activeSince, inactiveSince, index, sequencerAddress) = whitelist.operators(Bob);
        assertEq(activeSince, 0);
        assertEq(inactiveSince, whitelist.epochStartTimestamp(2));
        assertEq(index, 1);

        assertEq(whitelist.getOperatorForCurrentEpoch(), Bob);
        assertEq(whitelist.getOperatorForNextEpoch(), Bob);

        _advanceOneEpoch();
        assertEq(whitelist.getOperatorForCurrentEpoch(), Bob);
        assertEq(whitelist.getOperatorForNextEpoch(), address(0));

        _advanceOneEpoch();
        assertEq(whitelist.getOperatorForCurrentEpoch(), address(0));
        assertEq(whitelist.getOperatorForNextEpoch(), address(0));

        whitelist.consolidate();
        assertEq(whitelist.operatorCount(), 0);
        assertEq(whitelist.operatorMapping(0), address(0));
        assertEq(whitelist.operatorMapping(1), address(0));
        assertEq(whitelist.havingPerfectOperators(), true);
    }

    function test_whitelist_addOrRemoveTheSameOperatorTwiceWillRevert() external {
        vm.startPrank(whitelistOwner);
        whitelist.addOperator(Alice, _getSequencerAddress(Alice));
        vm.expectRevert(IPreconfWhitelist.OperatorAlreadyExists.selector);
        whitelist.addOperator(Alice, _getSequencerAddress(Alice));

        whitelist.removeOperator(Alice, false);
        vm.expectRevert(IPreconfWhitelist.OperatorAlreadyRemoved.selector);
        whitelist.removeOperator(Alice, false);
        vm.stopPrank();
    }

    function test_whitelist_addBackRemovedOperator() external {
        vm.startPrank(whitelistOwner);
        whitelist.addOperator(Alice, _getSequencerAddress(Alice));

        whitelist.removeOperator(Alice, false);

        whitelist.addOperator(Alice, _getSequencerAddress(Alice));
        vm.stopPrank();
    }

    function test_whitelist_selfRemoval() external {
        vm.startPrank(whitelistOwner);
        whitelist.addOperator(Alice, _getSequencerAddress(Alice));
        whitelist.addOperator(Bob, _getSequencerAddress(Bob));
        vm.stopPrank();

        vm.prank(Alice);
        whitelist.removeSelf();
        assertEq(whitelist.operatorCount(), 2);
        assertEq(whitelist.operatorMapping(0), Alice);
        assertEq(whitelist.operatorMapping(1), Bob);

        assertEq(whitelist.getOperatorForCurrentEpoch(), address(0));
        assertEq(whitelist.getOperatorForNextEpoch(), address(0));
        assertEq(whitelist.havingPerfectOperators(), false);

        whitelist.consolidate();
        assertEq(whitelist.operatorCount(), 1);
        assertEq(whitelist.operatorMapping(0), Bob);
        assertEq(whitelist.havingPerfectOperators(), false);

        vm.prank(Bob);
        whitelist.removeSelf();

        assertEq(whitelist.operatorCount(), 0);

        assertEq(whitelist.getOperatorForCurrentEpoch(), address(0));
        assertEq(whitelist.getOperatorForNextEpoch(), address(0));
        assertEq(whitelist.havingPerfectOperators(), false);

        whitelist.consolidate();
        assertEq(whitelist.operatorCount(), 0);
        assertEq(whitelist.havingPerfectOperators(), true);
    }

    function test_whitelist_removeNonExistingOperatorWillRevert() external {
        vm.startPrank(whitelistOwner);
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
        // Setup: add operator and set ejecter
        vm.prank(whitelistOwner);
        whitelist.addOperator(Bob, _getSequencerAddress(Bob));
        vm.prank(whitelistOwner);
        whitelist.setEjecter(ejecter, true);

        // Ejecter can remove operator by index
        vm.prank(ejecter);
        whitelist.removeOperator(0);

        // Verify removal
        (, uint32 inactiveSince,,) = whitelist.operators(Bob);
        assertTrue(inactiveSince > 0);
    }

    function test_whitelist_removeOperatorByEjecterByAddress() external {
        address ejecter2 = makeAddr("ejecter2");

        // Set multiple ejecters
        vm.startPrank(whitelistOwner);
        whitelist.setEjecter(ejecter, true);
        whitelist.setEjecter(ejecter2, true);
        whitelist.addOperator(Bob, _getSequencerAddress(Bob));
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

        vm.prank(whitelistOwner);
        whitelistNoDelay.addOperator(Bob, _getSequencerAddress(Bob));

        assertEq(whitelistNoDelay.operatorCount(), 1);
        assertEq(whitelistNoDelay.operatorMapping(0), Bob);
        assertEq(whitelistNoDelay.havingPerfectOperators(), true);

        (uint32 activeSince, uint32 inactiveSince, uint8 index,) = whitelistNoDelay.operators(Bob);
        assertEq(activeSince, whitelistNoDelay.epochStartTimestamp(0));
        assertEq(inactiveSince, 0);
        assertEq(index, 0);

        assertEq(whitelistNoDelay.getOperatorForCurrentEpoch(), Bob);
        assertEq(whitelistNoDelay.getOperatorForNextEpoch(), Bob);

        vm.prank(whitelistOwner);
        whitelistNoDelay.removeOperator(Bob, false);

        assertEq(whitelistNoDelay.operatorCount(), 0);
        assertEq(whitelistNoDelay.havingPerfectOperators(), true);

        whitelistNoDelay.consolidate();
        assertEq(whitelistNoDelay.operatorCount(), 0);
        assertEq(whitelistNoDelay.havingPerfectOperators(), true);

        assertEq(whitelistNoDelay.getOperatorForCurrentEpoch(), address(0));
        assertEq(whitelistNoDelay.getOperatorForNextEpoch(), address(0));
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

        // first we add carol to WL
        vm.prank(whitelistOwner);
        whitelist.addOperator(Carol, _getSequencerAddress(Carol));
        assertEq(whitelist.operatorCount(), 1);
        assertEq(whitelist.operatorMapping(0), Carol);

        // now remove her
        vm.prank(whitelistOwner);
        whitelist.removeOperator(Carol, false);
        assertEq(whitelist.operatorCount(), 1);
        assertEq(whitelist.operatorMapping(0), Carol);
        // re-add her
        vm.prank(whitelistOwner);
        whitelist.addOperator(Carol, _getSequencerAddress(Carol));
        assertEq(whitelist.operatorCount(), 1);
        assertEq(whitelist.operatorMapping(0), Carol);
        // ensure she was not double-added to mapping
        assertEq(whitelist.operatorMapping(1), address(0));

        // make sure she is correctly set to active now
        (uint32 activeSince, uint32 inactiveSince, uint8 index,) = whitelist.operators(Carol);
        assertEq(activeSince, whitelist.epochStartTimestamp(2));
        assertEq(inactiveSince, 0);
        assertEq(index, 0);
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

    function _setBeaconBlockRoot(bytes32 _root) internal {
        vm.etch(
            LibPreconfConstants.getBeaconBlockRootContract(),
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
