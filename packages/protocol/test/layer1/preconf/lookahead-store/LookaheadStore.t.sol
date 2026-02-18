// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { ILookaheadStore } from "src/layer1/preconf/iface/ILookaheadStore.sol";
import { LookaheadStore } from "src/layer1/preconf/impl/LookaheadStore.sol";
import { LibLookaheadEncoder as Encoder } from "src/layer1/preconf/libs/LibLookaheadEncoder.sol";
import { LibPreconfConstants } from "src/layer1/preconf/libs/LibPreconfConstants.sol";
import { LibPreconfUtils } from "src/layer1/preconf/libs/LibPreconfUtils.sol";
import { CommonTest } from "test/shared/CommonTest.sol";

contract LookaheadStoreHarness is LookaheadStore {
    constructor(
        address _inbox,
        address _preconfSlasherL1,
        address _preconfWhitelist,
        address _urc
    )
        LookaheadStore(_inbox, _preconfSlasherL1, _preconfWhitelist, _urc)
    { }

    function setLookaheadHash(uint256 _epochTimestamp, bytes26 _hash) external {
        _setLookaheadHash(_epochTimestamp, _hash);
    }

    function updateLookahead(
        uint256 _nextEpochTimestamp,
        bytes calldata _encodedLookahead
    )
        external
        returns (bytes26)
    {
        return _updateLookahead(_nextEpochTimestamp, _encodedLookahead);
    }
}

contract TestLookaheadStore is CommonTest {
    LookaheadStoreHarness internal lookaheadStore;

    address internal overseer;
    address internal preconfSlasherL1;
    address internal inbox;
    address internal preconfWhitelist;
    address internal urc;

    uint256 internal constant EPOCH_OFFSET = 10_000;
    uint256 internal constant EPOCH_START = EPOCH_OFFSET * LibPreconfConstants.SECONDS_IN_EPOCH;

    function setUpOnEthereum() internal override {
        overseer = makeAddr("overseer");
        preconfSlasherL1 = makeAddr("preconfSlasherL1");
        inbox = makeAddr("inbox");
        preconfWhitelist = makeAddr("preconfWhitelist");
        urc = makeAddr("urc");

        LookaheadStoreHarness impl =
            new LookaheadStoreHarness(inbox, preconfSlasherL1, preconfWhitelist, urc);
        lookaheadStore = LookaheadStoreHarness(
            address(
                new ERC1967Proxy(
                    address(impl), abi.encodeCall(LookaheadStore.init, (address(this), overseer))
                )
            )
        );

        vm.warp(EPOCH_START);
    }

    function test_isLookaheadRequired_falseAtEpochStart_whenMissing() external view {
        assertFalse(lookaheadStore.isLookaheadRequired());
    }

    function test_isLookaheadRequired_falseWhenNextEpochLookaheadStored() external {
        uint256 nextEpochTimestamp = _nextEpochTimestamp();
        bytes memory empty = Encoder.encodeLookahead(new ILookaheadStore.LookaheadSlot[](0));
        bytes26 lookaheadHash = lookaheadStore.calculateLookaheadHash(nextEpochTimestamp, empty);
        lookaheadStore.setLookaheadHash(nextEpochTimestamp, lookaheadHash);

        assertFalse(lookaheadStore.isLookaheadRequired());
    }

    function test_updateLookahead_acceptsValidSlots() external {
        _warpAfterEpochStart();

        bytes32 registrationRoot = keccak256("operator");
        address committer = makeAddr("committer");

        uint256 nextEpochTimestamp = _nextEpochTimestamp();
        ILookaheadStore.LookaheadSlot[] memory slots = new ILookaheadStore.LookaheadSlot[](1);
        slots[0] = _buildSlot(nextEpochTimestamp, registrationRoot, committer, 0);

        bytes memory encoded = Encoder.encodeLookahead(slots);
        bytes26 expected = lookaheadStore.calculateLookaheadHash(nextEpochTimestamp, encoded);

        bytes26 actual = lookaheadStore.updateLookahead(nextEpochTimestamp, encoded);

        assertEq(actual, expected);
        assertEq(lookaheadStore.getLookaheadHash(nextEpochTimestamp), expected);
    }

    function test_updateLookahead_RevertWhen_InvalidSlotTimestamp() external {
        _warpAfterEpochStart();

        bytes32 registrationRoot = keccak256("operator");
        address committer = makeAddr("committer");

        uint256 nextEpochTimestamp = _nextEpochTimestamp();
        ILookaheadStore.LookaheadSlot[] memory slots = new ILookaheadStore.LookaheadSlot[](1);
        slots[0] = _buildSlot(nextEpochTimestamp + 1, registrationRoot, committer, 0);

        bytes memory encoded = Encoder.encodeLookahead(slots);
        vm.expectRevert(LookaheadStore.InvalidSlotTimestamp.selector);
        lookaheadStore.updateLookahead(nextEpochTimestamp, encoded);
    }

    function test_checkProposer_succeedsSameEpoch_withStoredLookahead() external {
        bytes32 registrationRoot = keccak256("operator");
        address committer = makeAddr("committer");

        uint256 epochTimestamp = LibPreconfUtils.getEpochTimestamp();
        uint256 nextEpochTimestamp = epochTimestamp + LibPreconfConstants.SECONDS_IN_EPOCH;

        ILookaheadStore.LookaheadSlot[] memory currSlots = new ILookaheadStore.LookaheadSlot[](1);
        currSlots[0] = _buildSlot(epochTimestamp, registrationRoot, committer, 0);
        bytes memory currEncoded = Encoder.encodeLookahead(currSlots);

        bytes26 currHash = lookaheadStore.calculateLookaheadHash(epochTimestamp, currEncoded);
        lookaheadStore.setLookaheadHash(epochTimestamp, currHash);

        bytes memory nextEncoded = Encoder.encodeLookahead(new ILookaheadStore.LookaheadSlot[](0));
        bytes26 nextHash = lookaheadStore.calculateLookaheadHash(nextEpochTimestamp, nextEncoded);
        lookaheadStore.setLookaheadHash(nextEpochTimestamp, nextHash);

        ILookaheadStore.LookaheadData memory data = ILookaheadStore.LookaheadData({
            slotIndex: 0,
            currLookahead: currEncoded,
            nextLookahead: nextEncoded,
            commitmentSignature: ""
        });

        vm.prank(inbox);
        uint48 end = lookaheadStore.checkProposer(committer, abi.encode(data));

        assertEq(uint256(end), currSlots[0].timestamp);
    }

    function test_checkProposer_succeedsAtEpochStart_withoutNextLookahead() external {
        bytes32 registrationRoot = keccak256("operator");
        address committer = makeAddr("committer");

        uint256 epochTimestamp = LibPreconfUtils.getEpochTimestamp();
        uint256 nextEpochTimestamp = epochTimestamp + LibPreconfConstants.SECONDS_IN_EPOCH;

        ILookaheadStore.LookaheadSlot[] memory currSlots = new ILookaheadStore.LookaheadSlot[](1);
        currSlots[0] = _buildSlot(epochTimestamp, registrationRoot, committer, 0);
        bytes memory currEncoded = Encoder.encodeLookahead(currSlots);

        bytes26 currHash = lookaheadStore.calculateLookaheadHash(epochTimestamp, currEncoded);
        lookaheadStore.setLookaheadHash(epochTimestamp, currHash);

        // Next epoch lookahead is intentionally missing. Slot 0 exemption should allow proposing.
        assertEq(lookaheadStore.getLookaheadHash(nextEpochTimestamp), bytes26(0));

        bytes memory emptyEncoded = Encoder.encodeLookahead(new ILookaheadStore.LookaheadSlot[](0));

        ILookaheadStore.LookaheadData memory data = ILookaheadStore.LookaheadData({
            slotIndex: 0,
            currLookahead: currEncoded,
            nextLookahead: emptyEncoded,
            commitmentSignature: ""
        });

        vm.prank(inbox);
        uint48 end = lookaheadStore.checkProposer(committer, abi.encode(data));

        assertEq(uint256(end), currSlots[0].timestamp);
        assertEq(lookaheadStore.getLookaheadHash(nextEpochTimestamp), bytes26(0));
    }

    function _buildSlot(
        uint256 _timestamp,
        bytes32 _registrationRoot,
        address _committer,
        uint16 _validatorLeafIndex
    )
        internal
        pure
        returns (ILookaheadStore.LookaheadSlot memory)
    {
        return ILookaheadStore.LookaheadSlot({
            committer: _committer,
            timestamp: uint48(_timestamp),
            registrationRoot: _registrationRoot,
            validatorLeafIndex: _validatorLeafIndex
        });
    }

    function _nextEpochTimestamp() internal pure returns (uint256) {
        return EPOCH_START + LibPreconfConstants.SECONDS_IN_EPOCH;
    }

    function _warpAfterEpochStart() internal {
        vm.warp(EPOCH_START + 1);
    }
}
