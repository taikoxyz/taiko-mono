// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { ILookaheadStore } from "src/layer1/preconf/iface/ILookaheadStore.sol";
import { LookaheadStore } from "src/layer1/preconf/impl/LookaheadStore.sol";
import { LibPreconfConstants } from "src/layer1/preconf/libs/LibPreconfConstants.sol";
import { LibPreconfUtils } from "src/layer1/preconf/libs/LibPreconfUtils.sol";
import { MockURC } from "test/layer1/preconf/mocks/MockURC.sol";
import { CommonTest } from "test/shared/CommonTest.sol";

contract LookaheadStoreHarness is LookaheadStore {
    constructor(
        address _urc,
        address _lookaheadSlasher,
        address _preconfSlasher,
        address _inbox,
        address _preconfWhitelist,
        address[] memory _overseers
    )
        LookaheadStore(
            _urc,
            _lookaheadSlasher,
            _preconfSlasher,
            _inbox,
            _preconfWhitelist,
            _overseers
        )
    { }

    function setLookaheadHash(uint256 _epochTimestamp, bytes26 _hash) external {
        _setLookaheadHash(_epochTimestamp, _hash);
    }

    function updateLookahead(
        uint256 _nextEpochTimestamp,
        ILookaheadStore.LookaheadSlot[] memory _lookaheadSlots
    )
        external
        returns (bytes26)
    {
        return _updateLookahead(_nextEpochTimestamp, _lookaheadSlots);
    }
}

contract TestLookaheadStore is CommonTest {
    MockURC internal urc;
    LookaheadStoreHarness internal lookaheadStore;

    address internal overseer;
    address internal lookaheadSlasher;
    address internal preconfSlasher;
    address internal inbox;
    address internal preconfWhitelist;

    uint256 internal constant EPOCH_OFFSET = 10000;
    uint256 internal constant EPOCH_START = EPOCH_OFFSET * LibPreconfConstants.SECONDS_IN_EPOCH;

    function setUpOnEthereum() internal override {
        overseer = makeAddr("overseer");
        lookaheadSlasher = makeAddr("lookaheadSlasher");
        preconfSlasher = makeAddr("preconfSlasher");
        inbox = makeAddr("inbox");
        preconfWhitelist = makeAddr("preconfWhitelist");

        urc = new MockURC();

        address[] memory overseers = new address[](1);
        overseers[0] = overseer;

        lookaheadStore = new LookaheadStoreHarness(
            address(urc), lookaheadSlasher, preconfSlasher, inbox, preconfWhitelist, overseers
        );

        vm.warp(EPOCH_START);
    }

    function test_isLookaheadRequired_falseAtEpochStart_whenMissing() external view {
        assertFalse(lookaheadStore.isLookaheadRequired());
    }

    function test_isLookaheadRequired_falseWhenNextEpochLookaheadStored() external {
        uint256 nextEpochTimestamp = _nextEpochTimestamp();
        ILookaheadStore.LookaheadSlot[] memory empty =
            new ILookaheadStore.LookaheadSlot[](0);
        bytes26 lookaheadHash = lookaheadStore.calculateLookaheadHash(nextEpochTimestamp, empty);
        lookaheadStore.setLookaheadHash(nextEpochTimestamp, lookaheadHash);

        assertFalse(lookaheadStore.isLookaheadRequired());
    }

    function test_updateLookahead_acceptsValidSlots() external {
        _warpAfterEpochStart();
        bytes32 registrationRoot = keccak256("operator");
        address committer = makeAddr("committer");
        _setupOperator(registrationRoot, committer, 1);

        uint256 nextEpochTimestamp = _nextEpochTimestamp();
        ILookaheadStore.LookaheadSlot[] memory slots = new ILookaheadStore.LookaheadSlot[](1);
        slots[0] = _buildSlot(nextEpochTimestamp, registrationRoot, committer, 0);

        bytes26 expected = lookaheadStore.calculateLookaheadHash(nextEpochTimestamp, slots);
        bytes26 actual = lookaheadStore.updateLookahead(nextEpochTimestamp, slots);

        assertEq(actual, expected);
        assertEq(lookaheadStore.getLookaheadHash(nextEpochTimestamp), expected);
    }

    function test_updateLookahead_RevertWhen_InvalidSlotTimestamp() external {
        _warpAfterEpochStart();
        bytes32 registrationRoot = keccak256("operator");
        address committer = makeAddr("committer");
        _setupOperator(registrationRoot, committer, 1);

        uint256 nextEpochTimestamp = _nextEpochTimestamp();
        ILookaheadStore.LookaheadSlot[] memory slots = new ILookaheadStore.LookaheadSlot[](1);
        slots[0] = _buildSlot(nextEpochTimestamp + 1, registrationRoot, committer, 0);

        vm.expectRevert(LookaheadStore.InvalidSlotTimestamp.selector);
        lookaheadStore.updateLookahead(nextEpochTimestamp, slots);
    }

    function test_updateLookahead_RevertWhen_InvalidValidatorLeafIndex() external {
        _warpAfterEpochStart();
        bytes32 registrationRoot = keccak256("operator");
        address committer = makeAddr("committer");
        _setupOperator(registrationRoot, committer, 1);

        uint256 nextEpochTimestamp = _nextEpochTimestamp();
        ILookaheadStore.LookaheadSlot[] memory slots = new ILookaheadStore.LookaheadSlot[](1);
        slots[0] = _buildSlot(nextEpochTimestamp, registrationRoot, committer, 1);

        vm.expectRevert(LookaheadStore.InvalidValidatorLeafIndex.selector);
        lookaheadStore.updateLookahead(nextEpochTimestamp, slots);
    }

    function test_updateLookahead_RevertWhen_CommitterMismatch() external {
        _warpAfterEpochStart();
        bytes32 registrationRoot = keccak256("operator");
        address committer = makeAddr("committer");
        _setupOperator(registrationRoot, committer, 1);

        uint256 nextEpochTimestamp = _nextEpochTimestamp();
        ILookaheadStore.LookaheadSlot[] memory slots = new ILookaheadStore.LookaheadSlot[](1);
        slots[0] = _buildSlot(nextEpochTimestamp, registrationRoot, makeAddr("other"), 0);

        vm.expectRevert(LookaheadStore.CommitterMismatch.selector);
        lookaheadStore.updateLookahead(nextEpochTimestamp, slots);
    }

    function test_updateLookahead_RevertWhen_OperatorBlacklistedAtReference() external {
        _warpAfterEpochStart();
        bytes32 registrationRoot = keccak256("operator");
        address committer = makeAddr("committer");
        _setupOperator(registrationRoot, committer, 1);

        uint256 referenceTimestamp = _referenceTimestamp();
        uint256 firstBlacklist = referenceTimestamp - 3 days;
        uint256 unblacklistAt = firstBlacklist + 1 days + 1;
        uint256 secondBlacklist = unblacklistAt + 1 days + 1;

        vm.warp(firstBlacklist);
        vm.prank(overseer);
        lookaheadStore.blacklistOperator(registrationRoot);

        vm.warp(unblacklistAt);
        vm.prank(overseer);
        lookaheadStore.unblacklistOperator(registrationRoot);

        vm.warp(secondBlacklist);
        vm.prank(overseer);
        lookaheadStore.blacklistOperator(registrationRoot);

        _warpAfterEpochStart();

        uint256 nextEpochTimestamp = _nextEpochTimestamp();
        ILookaheadStore.LookaheadSlot[] memory slots = new ILookaheadStore.LookaheadSlot[](1);
        slots[0] = _buildSlot(nextEpochTimestamp, registrationRoot, committer, 0);

        vm.expectRevert(LookaheadStore.OperatorHasBeenBlacklisted.selector);
        lookaheadStore.updateLookahead(nextEpochTimestamp, slots);
    }

    function test_checkProposer_succeedsSameEpoch_withStoredLookahead() external {
        bytes32 registrationRoot = keccak256("operator");
        address committer = makeAddr("committer");

        uint256 epochTimestamp = LibPreconfUtils.getEpochTimestamp();
        uint256 nextEpochTimestamp = epochTimestamp + LibPreconfConstants.SECONDS_IN_EPOCH;

        ILookaheadStore.LookaheadSlot[] memory currLookahead =
            new ILookaheadStore.LookaheadSlot[](1);
        currLookahead[0] = _buildSlot(epochTimestamp, registrationRoot, committer, 0);

        bytes26 currHash = lookaheadStore.calculateLookaheadHash(epochTimestamp, currLookahead);
        lookaheadStore.setLookaheadHash(epochTimestamp, currHash);

        ILookaheadStore.LookaheadSlot[] memory nextLookahead =
            new ILookaheadStore.LookaheadSlot[](0);
        bytes26 nextHash = lookaheadStore.calculateLookaheadHash(nextEpochTimestamp, nextLookahead);
        lookaheadStore.setLookaheadHash(nextEpochTimestamp, nextHash);

        ILookaheadStore.LookaheadData memory data = ILookaheadStore.LookaheadData({
            slotIndex: 0,
            registrationRoot: bytes32(0),
            currLookahead: currLookahead,
            nextLookahead: nextLookahead,
            commitmentSignature: ""
        });

        vm.prank(inbox);
        uint48 end = lookaheadStore.checkProposer(committer, abi.encode(data));

        assertEq(uint256(end), currLookahead[0].timestamp);
    }

    function test_checkProposer_succeedsAtEpochStart_withoutNextLookahead() external {
        bytes32 registrationRoot = keccak256("operator");
        address committer = makeAddr("committer");

        uint256 epochTimestamp = LibPreconfUtils.getEpochTimestamp();
        uint256 nextEpochTimestamp = epochTimestamp + LibPreconfConstants.SECONDS_IN_EPOCH;

        ILookaheadStore.LookaheadSlot[] memory currLookahead =
            new ILookaheadStore.LookaheadSlot[](1);
        currLookahead[0] = _buildSlot(epochTimestamp, registrationRoot, committer, 0);

        bytes26 currHash = lookaheadStore.calculateLookaheadHash(epochTimestamp, currLookahead);
        lookaheadStore.setLookaheadHash(epochTimestamp, currHash);

        // Next epoch lookahead is intentionally missing. Slot 0 exemption should allow proposing.
        assertEq(lookaheadStore.getLookaheadHash(nextEpochTimestamp), bytes26(0));

        ILookaheadStore.LookaheadData memory data = ILookaheadStore.LookaheadData({
            slotIndex: 0,
            registrationRoot: bytes32(0),
            currLookahead: currLookahead,
            nextLookahead: new ILookaheadStore.LookaheadSlot[](0),
            commitmentSignature: ""
        });

        vm.prank(inbox);
        uint48 end = lookaheadStore.checkProposer(committer, abi.encode(data));

        assertEq(uint256(end), currLookahead[0].timestamp);
        assertEq(lookaheadStore.getLookaheadHash(nextEpochTimestamp), bytes26(0));
    }

    function _setupOperator(
        bytes32 _registrationRoot,
        address _committer,
        uint16 _numKeys
    )
        internal
    {
        uint256 referenceTimestamp = _referenceTimestamp();
        uint256 registeredAt = referenceTimestamp - 1;
        uint256 optedInAt = referenceTimestamp - 1;

        uint256 minCollateral = lookaheadStore.getLookaheadStoreConfig().minCollateralForPreconfing;

        urc.setOperatorData(
            _registrationRoot,
            _committer,
            minCollateral,
            _numKeys,
            registeredAt,
            type(uint48).max,
            0
        );

        urc.setSlasherCommitment(
            _registrationRoot, preconfSlasher, optedInAt, 0, _committer
        );

        urc.setHistoricalCollateral(
            _registrationRoot, 0, minCollateral
        );
    }

    function _buildSlot(
        uint256 _timestamp,
        bytes32 _registrationRoot,
        address _committer,
        uint256 _validatorLeafIndex
    )
        internal
        pure
        returns (ILookaheadStore.LookaheadSlot memory)
    {
        return ILookaheadStore.LookaheadSlot({
            committer: _committer,
            timestamp: _timestamp,
            registrationRoot: _registrationRoot,
            validatorLeafIndex: _validatorLeafIndex
        });
    }

    function _nextEpochTimestamp() internal pure returns (uint256) {
        return EPOCH_START + LibPreconfConstants.SECONDS_IN_EPOCH;
    }

    function _referenceTimestamp() internal pure returns (uint256) {
        return EPOCH_START - LibPreconfConstants.SECONDS_IN_EPOCH;
    }

    function _warpAfterEpochStart() internal {
        vm.warp(EPOCH_START + 1);
    }
}
