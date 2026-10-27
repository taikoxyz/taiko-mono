// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { EtnaLandTestBase } from "./EtnaLandTestBase.sol";
import { IEtnaInbox } from "src/layer1/etna/iface/IEtnaInbox.sol";
import { IEtnaStakingRegistry } from "src/layer1/etna/iface/IEtnaStakingRegistry.sol";
import { EtnaInbox } from "src/layer1/etna/impl/EtnaInbox.sol";
import { LibEtnaKeys } from "src/layer1/etna/libs/LibEtnaKeys.sol";

/// @title EtnaInboxGasBase
/// @notice Gas snapshots of the Inbox's entry points on the `EtnaLandTestBase` chain.
/// @dev `setUp` and the measured test are separate transactions, so every contract's storage
/// starts cold in the test. Each test loads its target, caller and arguments into memory before
/// `vm.startSnapshotGas`, so the measured window holds only the call. Every landing suite lands
/// (0, 6] in `setUp` first, so the measured landing starts from non-zero checkpoint slots. Landings
/// carry two blobs and use the mock verifier, bound in `setUp` to the measured landing's honest
/// statement.
abstract contract EtnaInboxGasBase is EtnaLandTestBase {
    /// @dev Every measured call must stay below this.
    uint256 internal constant GAS_LIMIT = 3_000_000;

    /// @dev The checkpoint height when `setUp` bound the measured landing's statement.
    uint256 internal checkpointBefore;

    /// @dev Ends the measurement `_label`, logs it and checks it against `GAS_LIMIT`.
    function _stopSnapshot(string memory _label) internal returns (uint256 gasUsed_) {
        gasUsed_ = vm.stopSnapshotGas();
        emit log_named_uint(_label, gasUsed_);
        assertLt(gasUsed_, GAS_LIMIT, _label);
    }

    /// @dev Bob lands the committed chain's `(_p, _h]` with its honest leaves, first saving the
    /// forced inclusions its queue head needs.
    function _landHonestly(uint256 _p, uint256 _h) internal {
        _bindStatement(_p, _h);
        vm.blobhashes(blobHashes);
        vm.prank(Bob);
        _inbox().land(_input(_p, _h), _leaves(_p, _h), PROOF);
        _assertCheckpoint(_h, bytes32(100 + _h));
    }

    /// @dev Saves the forced inclusions the landing of `(_p, _h]` needs, makes the verifier
    /// accept only its honest statement over the current state and records the checkpoint height.
    function _bindStatement(uint256 _p, uint256 _h) internal {
        (, uint48 tail) = _inbox().getForcedInclusionState();
        if (tail < _h / K) _saveForcedInclusions(_h / K - tail);
        IEtnaInbox.LandInput memory input = _input(_p, _h);
        landVerifier.setExpectedStatementHash(
            _statement(input, _inbox().landings(_p), _cutHash(input, _leaves(_p, _h)))
        );
        checkpointBefore = _inbox().lastCheckpoint().height;
    }

    /// @dev Measures Bob's landing of the committed chain's `(_p, _h]` as `_label`; `setUp` must
    /// have bound its statement.
    function _measureLand(string memory _label, uint256 _p, uint256 _h) internal {
        EtnaInbox target = EtnaInbox(inboxProxy);
        IEtnaInbox.LandInput memory input = _input(_p, _h);
        bytes32[] memory leaves = _leaves(_p, _h);
        bytes memory proof = PROOF;
        vm.blobhashes(blobHashes);
        vm.startPrank(Bob);
        vm.startSnapshotGas(_label);
        target.land(input, leaves, proof);
        _stopSnapshot(_label);
        vm.stopPrank();

        _assertCheckpoint(_h, bytes32(100 + _h));
        (uint48 head,) = _inbox().getForcedInclusionState();
        assertEq(head, _h / K, "queue head");
        assertEq(_inbox().landings(_h).parentHeight, checkpointBefore, "settled on c");
    }
}

/// @title EtnaInboxLand6BlocksGasTest
/// @notice A 6-block landing with no leaf, from the checkpoint at 6 to 12.
contract EtnaInboxLand6BlocksGasTest is EtnaInboxGasBase {
    function setUp() public override {
        super.setUp();
        _landHonestly(0, 6);
        _bindStatement(6, 12);
    }

    function test_gas_Land6Blocks() external {
        _measureLand("land_6_blocks", 6, 12);
    }
}

/// @title EtnaInboxLand300BlocksGasTest
/// @notice A 300-block landing with 49 leaves, from the checkpoint at 6 to 306.
contract EtnaInboxLand300BlocksGasTest is EtnaInboxGasBase {
    function setUp() public override {
        super.setUp();
        _landHonestly(0, 6);
        _bindStatement(6, 306);
    }

    function test_gas_Land300Blocks() external {
        _measureLand("land_300_blocks_49_leaves", 6, 306);
    }
}

/// @title EtnaInboxLand300FrontierGasTest
/// @notice A 300-block landing from 6 to 306 whose checkpoint c = 156 is 150 blocks past p, so
/// the leaf at c is checked against c's landing record.
contract EtnaInboxLand300FrontierGasTest is EtnaInboxGasBase {
    function setUp() public override {
        super.setUp();
        _landHonestly(0, 6);
        _landHonestly(6, 156);
        _bindStatement(6, 306);
    }

    function test_gas_Land300BlocksWithFrontier() external {
        _measureLand("land_300_blocks_frontier_at_150", 6, 306);
    }
}

/// @title EtnaInboxLand3600BlocksGasTest
/// @notice A 3,600-block landing with 599 leaves, from the checkpoint at 6 to 3,606, on an
/// implementation with `maxBatchBlocks = 3600`.
contract EtnaInboxLand3600BlocksGasTest is EtnaInboxGasBase {
    function setUp() public override {
        super.setUp();
        _upgradeWithMaxBatchBlocks(3600);
        _landHonestly(0, 6);
        _bindStatement(6, 3606);
    }

    function test_gas_Land3600Blocks() external {
        _measureLand("land_3600_blocks_599_leaves", 6, 3606);
    }
}

/// @title EtnaInboxRecoverGasTest
/// @notice The owner's recovery at c = 6 forcing out Bob's bond 1 and blanking queued forced
/// inclusion 2.
contract EtnaInboxRecoverGasTest is EtnaInboxGasBase {
    /// @dev Bob's consensus private key; Alice registered `VALIDATOR_PK` before initialization.
    uint256 private constant _BOB_PK = 0xB0B;

    /// @dev The recovery lists the test passes.
    IEtnaInbox.Exclusion[] internal exclusions;
    uint256[] internal fiToClear;

    function setUp() public override {
        super.setUp();
        assertEq(_registerValidator(registry, Bob, _BOB_PK), 1, "Bob's bond 1");
        _landHonestly(0, 6);
        vm.roll(block.number + 1);

        IEtnaStakingRegistry.Entry memory entry = registry.entryAt(1);
        exclusions.push(
            IEtnaInbox.Exclusion({
                bondId: 1, entryKey: LibEtnaKeys.entryKey(entry.ckPrefix, entry.ckX)
            })
        );
        fiToClear.push(2);
        assertEq(_inbox().owner(), address(this), "this test is the owner");
        _assertQueue(1, LEAN_FORCED_INCLUSIONS);
    }

    function test_gas_RecoverWithOneExclusionAndOneBlank() external {
        EtnaInbox target = EtnaInbox(inboxProxy);
        IEtnaInbox.Exclusion[] memory exclusionList = exclusions;
        uint256[] memory blanks = fiToClear;
        vm.startSnapshotGas("recover_1_exclusion_1_blank");
        target.recover(0, 6, exclusionList, blanks);
        _stopSnapshot("recover_1_exclusion_1_blank");

        assertEq(_inbox().recoveryGeneration(), 1, "generation");
        assertEq(registry.entryAt(1).exitEffectiveL1, block.number, "forced out");
        assertEq(_inbox().getForcedInclusion(2).txHash, keccak256(""), "blanked");
    }
}

/// @title EtnaInboxForcedInclusionGasTest
/// @notice Saving a forced inclusion behind the three queued ones, and sweeping their fees.
/// @dev The fee recipient already exists, so the sweep is not charged for creating it.
contract EtnaInboxForcedInclusionGasTest is EtnaInboxGasBase {
    /// @dev About the size of a signed EIP-1559 ETH transfer.
    uint256 private constant _FORCED_TX_BYTES = 120;

    /// @dev The forced transaction the test saves and its exact fee in wei.
    bytes internal forcedTx;
    uint256 internal forcedInclusionFee;

    /// @dev The Inbox's balance after `setUp`: the three queued fees.
    uint256 internal feesWei;

    function setUp() public override {
        super.setUp();
        vm.deal(PROTOCOL_FEE_RECIPIENT, 1);
        forcedTx = new bytes(_FORCED_TX_BYTES);
        for (uint256 i; i < _FORCED_TX_BYTES; ++i) {
            forcedTx[i] = bytes1(uint8(i + 1));
        }
        forcedInclusionFee = uint256(_inbox().getCurrentForcedInclusionFee()) * 1 gwei;
        feesWei = inboxProxy.balance;
        assertGt(feesWei, 0, "the forced inclusion fees");
        _assertQueue(0, LEAN_FORCED_INCLUSIONS);
    }

    function test_gas_SaveForcedInclusion() external {
        EtnaInbox target = EtnaInbox(inboxProxy);
        bytes memory txBytes = forcedTx;
        uint256 fee = forcedInclusionFee;
        vm.startPrank(Alice);
        vm.startSnapshotGas("save_forced_inclusion");
        target.saveForcedInclusion{ value: fee }(txBytes);
        _stopSnapshot("save_forced_inclusion");
        vm.stopPrank();
        _assertQueue(0, LEAN_FORCED_INCLUSIONS + 1);
        assertEq(
            _inbox().getForcedInclusion(uint48(LEAN_FORCED_INCLUSIONS)).txHash, keccak256(txBytes)
        );
    }

    function test_gas_SweepProtocolFees() external {
        EtnaInbox target = EtnaInbox(inboxProxy);
        vm.startPrank(Carol);
        vm.startSnapshotGas("sweep");
        target.sweepProtocolFees();
        _stopSnapshot("sweep");
        vm.stopPrank();
        assertEq(inboxProxy.balance, 0, "swept");
        assertEq(PROTOCOL_FEE_RECIPIENT.balance, feesWei + 1, "to the treasury");
    }
}
