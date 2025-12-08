// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import { IProposerChecker } from "src/layer1/core/iface/IProposerChecker.sol";
import { IPreconfWhitelist } from "src/layer1/preconf/iface/IPreconfWhitelist.sol";
import { PreconfWhitelist } from "src/layer1/preconf/impl/PreconfWhitelist.sol";
import { LibPreconfConstants } from "src/layer1/preconf/libs/LibPreconfConstants.sol";
import { CommonTest } from "test/shared/CommonTest.sol";

contract TestPreconfWhitelist is CommonTest {
    PreconfWhitelist internal whitelist;
    address internal whitelistOwner;
    address internal ejecter;

    function setUpOnEthereum() internal virtual override {
        whitelistOwner = Alice;
        ejecter = makeAddr("ejecter");
        whitelist = PreconfWhitelist(
            deploy({
                name: "preconf_whitelist",
                impl: address(new PreconfWhitelist()),
                data: abi.encodeCall(PreconfWhitelist.init, (whitelistOwner))
            })
        );

        // Ensure the beacon root contract returns a stable value and randomness delay is satisfied.
        _setBeaconBlockRoot(bytes32(uint256(0x1234)));
        vm.warp(
            LibPreconfConstants.SECONDS_IN_SLOT + LibPreconfConstants.SECONDS_IN_EPOCH
                * whitelist.RANDOMNESS_DELAY()
        );
    }

    function test_addOperator_setsExpectedState() external {
        vm.expectEmit();
        emit IPreconfWhitelist.OperatorAdded(Bob, _sequencer(Bob), whitelist.epochStartTimestamp(2));

        _addOperator(Bob);

        assertEq(whitelist.operatorCount(), 1);
        assertEq(whitelist.operatorMapping(0), Bob);

        (uint32 activeSince,, uint8 index, address sequencer) = whitelist.operators(Bob);
        assertEq(activeSince, whitelist.epochStartTimestamp(2));
        assertEq(index, 0);
        assertEq(sequencer, _sequencer(Bob));
        assertFalse(whitelist.isOperatorActive(Bob, whitelist.epochStartTimestamp(0)));

        _advanceEpochs(whitelist.OPERATOR_CHANGE_DELAY());
        assertTrue(whitelist.isOperatorActive(Bob, whitelist.epochStartTimestamp(0)));
    }

    function test_addOperator_RevertWhen_Duplicate() external {
        _addOperator(Bob);
        vm.prank(whitelistOwner);
        vm.expectRevert(PreconfWhitelist.OperatorAlreadyExists.selector);
        whitelist.addOperator(Bob, _sequencer(Bob));
    }

    function test_addOperator_RevertWhen_InvalidAddresses() external {
        vm.startPrank(whitelistOwner);
        vm.expectRevert(PreconfWhitelist.InvalidOperatorAddress.selector);
        whitelist.addOperator(address(0), Bob);

        vm.expectRevert(PreconfWhitelist.InvalidOperatorAddress.selector);
        whitelist.addOperator(Bob, address(0));
        vm.stopPrank();
    }

    function test_getOperatorForEpoch_respectsActivationDelay() external {
        _setBeaconBlockRoot(bytes32(uint256(7)));
        _addOperator(Bob);
        _addOperator(Carol);

        assertEq(whitelist.getOperatorForCurrentEpoch(), address(0));
        assertEq(whitelist.getOperatorForNextEpoch(), address(0));

        _advanceEpochs(whitelist.OPERATOR_CHANGE_DELAY());

        address current = whitelist.getOperatorForCurrentEpoch();
        address nextOp = whitelist.getOperatorForNextEpoch();
        assertTrue(current == Bob || current == Carol);
        assertTrue(nextOp == Bob || nextOp == Carol);
    }

    function test_getOperatorForEpoch_returnsZeroWhenNoActive() external {
        _addOperator(Bob);
        assertEq(whitelist.getOperatorForCurrentEpoch(), address(0));
        assertEq(whitelist.getOperatorForNextEpoch(), address(0));
    }

    function test_getOperatorForEpoch_pendingOperatorNotSelectedUntilActive() external {
        _setBeaconBlockRoot(bytes32(uint256(5)));

        _addOperator(Bob);
        _addOperator(Carol);
        _advanceEpochs(whitelist.OPERATOR_CHANGE_DELAY());

        address[] memory activeSet = new address[](2);
        activeSet[0] = Bob;
        activeSet[1] = Carol;

        address selectedBefore = whitelist.getOperatorForCurrentEpoch();
        _expectAddressInSet(selectedBefore, activeSet, "selected operator must be active");

        _addOperator(David);

        address selectedWithPending = whitelist.getOperatorForCurrentEpoch();
        _expectAddressInSet(selectedWithPending, activeSet, "pending operator must not be selected");
        assertNotEq(selectedWithPending, David, "pending operator must remain inactive");

        _advanceEpochs(whitelist.OPERATOR_CHANGE_DELAY());
        address selectedAfterActivation = whitelist.getOperatorForCurrentEpoch();
        assertEq(selectedAfterActivation, David, "new operator should join rotation once active");
    }

    function test_getOperatorForEpoch_handlesStaggeredActivations() external {
        _setBeaconBlockRoot(bytes32(uint256(11)));

        _addOperator(Bob);
        _addOperator(Carol);
        uint256 changeDelay = whitelist.OPERATOR_CHANGE_DELAY();
        _advanceEpochs(changeDelay);

        _addOperator(David);
        uint256 spacing = 1;
        assertGt(changeDelay, spacing, "spacing must be less than change delay");
        _advanceEpochs(spacing);
        _addOperator(Emma);

        address[] memory initialSet = new address[](2);
        initialSet[0] = Bob;
        initialSet[1] = Carol;
        _expectAddressInSet(
            whitelist.getOperatorForCurrentEpoch(), initialSet, "only active operators selectable"
        );

        _advanceEpochs(changeDelay - spacing);
        address[] memory afterDaveSet = new address[](3);
        afterDaveSet[0] = Bob;
        afterDaveSet[1] = Carol;
        afterDaveSet[2] = David;

        address selectedAfterDave = whitelist.getOperatorForCurrentEpoch();
        _expectAddressInSet(
            selectedAfterDave, afterDaveSet, "newly active operator must be considered"
        );
        assertNotEq(selectedAfterDave, Emma, "later activation must still be pending");

        _advanceEpochs(spacing);
        address[] memory afterEmmaSet = new address[](4);
        afterEmmaSet[0] = Bob;
        afterEmmaSet[1] = Carol;
        afterEmmaSet[2] = David;
        afterEmmaSet[3] = Emma;

        _expectAddressInSet(
            whitelist.getOperatorForCurrentEpoch(),
            afterEmmaSet,
            "all operators selectable once fully active"
        );
    }

    function test_removeOperatorByIndex_keepsMappingPacked() external {
        _addOperator(Alice);
        _addOperator(Bob);
        _addOperator(Carol);

        vm.prank(whitelistOwner);
        whitelist.removeOperator(1);

        assertEq(whitelist.operatorCount(), 2);
        assertEq(whitelist.operatorMapping(0), Alice);
        assertEq(whitelist.operatorMapping(1), Carol);
        assertEq(whitelist.operatorMapping(2), address(0));

        (uint32 activeSince,, uint8 index,) = whitelist.operators(Carol);
        assertEq(index, 1);
        assertEq(activeSince, whitelist.epochStartTimestamp(2));

        (activeSince,, index,) = whitelist.operators(Bob);
        assertEq(activeSince, 0);
        assertEq(index, 0);
    }

    function test_removeOperator_RevertWhen_NoOtherActive() external {
        _addOperator(Bob);
        _advanceEpochs(whitelist.OPERATOR_CHANGE_DELAY());
        _addOperator(Carol);

        vm.prank(whitelistOwner);
        vm.expectRevert(PreconfWhitelist.NoActiveOperatorRemaining.selector);
        whitelist.removeOperator(0);
    }

    function test_removeOperatorByAddress_allowedForEjecter() external {
        _addOperator(Bob);
        _addOperator(Carol);

        vm.prank(whitelistOwner);
        whitelist.setEjecter(ejecter, true);

        vm.expectEmit();
        emit IPreconfWhitelist.OperatorRemoved(Bob, _sequencer(Bob), block.timestamp);
        vm.prank(ejecter);
        whitelist.removeOperatorByAddress(Bob);

        assertEq(whitelist.operatorCount(), 1);
        assertEq(whitelist.operatorMapping(0), Carol);
        (uint32 activeSince,, uint8 index,) = whitelist.operators(Bob);
        assertEq(activeSince, 0);
        assertEq(index, 0);
    }

    function test_removeOperator_RevertWhen_LastOperator() external {
        _addOperator(Bob);
        vm.prank(whitelistOwner);
        vm.expectRevert(PreconfWhitelist.CannotRemoveLastOperator.selector);
        whitelist.removeOperator(0);
    }

    function test_checkProposer_allowsSelectedOperator() external {
        _setBeaconBlockRoot(bytes32(uint256(3)));
        _addOperator(Bob);
        _addOperator(Carol);
        _advanceEpochs(whitelist.OPERATOR_CHANGE_DELAY());

        address selected = whitelist.getOperatorForCurrentEpoch();
        vm.expectRevert(IProposerChecker.InvalidProposer.selector);
        whitelist.checkProposer(Alice, bytes(""));

        uint48 deadline = whitelist.checkProposer(selected, bytes(""));
        assertEq(deadline, 0);
    }

    function test_isOperatorActive_reportsLifecycle() external {
        _addOperator(Bob);
        _addOperator(Carol);
        uint32 currentEpoch = whitelist.epochStartTimestamp(0);
        assertFalse(whitelist.isOperatorActive(Bob, currentEpoch));

        _advanceEpochs(whitelist.OPERATOR_CHANGE_DELAY());
        uint32 activeEpoch = whitelist.epochStartTimestamp(0);
        assertTrue(whitelist.isOperatorActive(Bob, activeEpoch));

        vm.prank(whitelistOwner);
        whitelist.removeOperator(0);
        assertFalse(whitelist.isOperatorActive(Bob, activeEpoch));
    }

    function test_setEjecter_updatesAccessControl() external {
        vm.expectEmit();
        emit IPreconfWhitelist.EjecterUpdated(ejecter, true);
        vm.prank(whitelistOwner);
        whitelist.setEjecter(ejecter, true);

        vm.expectRevert(PreconfWhitelist.InvalidOperatorIndex.selector);
        vm.prank(ejecter);
        whitelist.removeOperator(0);
    }

    function test_constantsHaveExpectedValues() external view {
        assertEq(whitelist.OPERATOR_CHANGE_DELAY(), 2);
        assertEq(whitelist.RANDOMNESS_DELAY(), 2);
    }

    function _addOperator(address proposer) internal {
        vm.prank(whitelistOwner);
        whitelist.addOperator(proposer, _sequencer(proposer));
    }

    function _setBeaconBlockRoot(bytes32 _root) internal {
        vm.etch(
            LibPreconfConstants.BEACON_BLOCK_ROOT_CONTRACT,
            address(new BeaconBlockRootImpl(_root)).code
        );
    }

    function _advanceEpochs(uint256 _count) internal {
        for (uint256 i; i < _count; ++i) {
            vm.warp(block.timestamp + LibPreconfConstants.SECONDS_IN_EPOCH);
        }
    }

    function _sequencer(address proposer) internal pure returns (address) {
        return address(uint160(proposer) + 1000);
    }

    function _expectAddressInSet(
        address actual,
        address[] memory expected,
        string memory reason
    )
        internal
        pure
    {
        bool found;
        for (uint256 i; i < expected.length; ++i) {
            if (actual == expected[i]) {
                found = true;
                break;
            }
        }
        assertTrue(found, reason);
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
        if (_timestamp > block.timestamp) {
            return abi.encode(bytes32(0));
        }
        return abi.encode(root);
    }
}
