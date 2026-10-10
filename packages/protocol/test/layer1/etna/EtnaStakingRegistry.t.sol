// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { IEtnaStakingRegistry } from "src/layer1/etna/iface/IEtnaStakingRegistry.sol";
import { EtnaStakingRegistry } from "src/layer1/etna/impl/EtnaStakingRegistry.sol";
import { LibEntriesTree } from "src/layer1/etna/libs/LibEntriesTree.sol";
import { TaikoToken } from "src/layer1/mainnet/TaikoToken.sol";
import { EssentialContract } from "src/shared/common/EssentialContract.sol";
import { CommonTest } from "test/shared/CommonTest.sol";

contract EtnaStakingRegistryTest is CommonTest {
    uint256 internal constant MIN_STAKE = 1000 ether;
    uint64 internal constant ACTIVATION_DELAY = 10;
    uint64 internal constant EXIT_DELAY = 20;
    uint64 internal constant WITHDRAWAL_DELAY = 30;
    uint64 internal constant HEARTBEAT_WINDOW = 50;
    uint64 internal constant START_BLOCK = 1001;
    uint64 internal constant NO_EXIT = type(uint64).max;

    /// @dev The ERC-7201 base slot pinned by taiko-client-rs `l1::layout::registry::base()`.
    bytes32 internal constant REGISTRY_BASE =
        0x46e4e2fea4a7d0ac18aca03baa3a1f64e1be04ec23c1ca0c7b901af7b59b8000;

    bytes32 internal constant KEY_A = bytes32(uint256(0xa1));
    bytes32 internal constant KEY_B = bytes32(uint256(0xb2));
    bytes32 internal constant KEY_C = bytes32(uint256(0xc3));

    TaikoToken internal token;
    EtnaStakingRegistry internal registry;

    function setUpOnEthereum() internal virtual override {
        token = deployTaikoToken();
        registry = EtnaStakingRegistry(
            address(
                new ERC1967Proxy(
                    address(_newRegistry(address(token), MIN_STAKE, HEARTBEAT_WINDOW)),
                    abi.encodeCall(EtnaStakingRegistry.init, (address(0)))
                )
            )
        );
    }

    function setUp() public virtual override {
        super.setUp();
        vm.roll(START_BLOCK);

        address[3] memory stakers = [Alice, Bob, Carol];
        for (uint256 i; i < stakers.length; ++i) {
            assertTrue(token.transfer(stakers[i], 100 * MIN_STAKE));
            vm.prank(stakers[i]);
            token.approve(address(registry), type(uint256).max);
        }
    }

    // ---------------------------------------------------------------
    // constructor and init
    // ---------------------------------------------------------------

    function test_init_SetsOwnerAndParameters() external view {
        assertEq(registry.owner(), deployer);
        assertEq(address(registry.taikoToken()), address(token));
        assertEq(registry.minStake(), MIN_STAKE);
        assertEq(registry.activationDelay(), ACTIVATION_DELAY);
        assertEq(registry.exitDelay(), EXIT_DELAY);
        assertEq(registry.withdrawalDelay(), WITHDRAWAL_DELAY);
        assertEq(registry.heartbeatWindow(), HEARTBEAT_WINDOW);
        assertEq(registry.MAX_ENTRIES(), 4096);
        assertEq(registry.entryCount(), 0);
        assertEq(registry.checkpointCount(), 0);
        assertEq(registry.entriesRoot(), bytes32(0));
    }

    function test_constructor_RevertWhen_TaikoTokenIsZero() external {
        vm.expectRevert(EssentialContract.ZERO_ADDRESS.selector);
        _newRegistry(address(0), MIN_STAKE, HEARTBEAT_WINDOW);
    }

    function test_constructor_RevertWhen_MinStakeIsZero() external {
        vm.expectRevert(EssentialContract.ZERO_VALUE.selector);
        _newRegistry(address(token), 0, HEARTBEAT_WINDOW);
    }

    function test_constructor_RevertWhen_HeartbeatWindowIsZero() external {
        vm.expectRevert(EtnaStakingRegistry.InvalidHeartbeatWindow.selector);
        _newRegistry(address(token), MIN_STAKE, 0);
    }

    // ---------------------------------------------------------------
    // register
    // ---------------------------------------------------------------

    function test_register_AppendsTheEntryWithoutAHeartbeat() external {
        uint256 amount = MIN_STAKE + 1;
        uint64 activeFromL1 = START_BLOCK + ACTIVATION_DELAY;
        bytes32 root = LibEntriesTree.leaf(0, _entry(KEY_A, amount, activeFromL1, NO_EXIT, 0, 0));

        vm.expectEmit();
        emit IEtnaStakingRegistry.CheckpointWritten(0, START_BLOCK, 1, root);
        vm.expectEmit();
        emit IEtnaStakingRegistry.Registered(0, Alice, KEY_A, amount, activeFromL1);
        vm.prank(Alice);
        uint256 bondId = registry.register(KEY_A, amount);

        assertEq(bondId, 0);
        _assertEntry(0, KEY_A, amount, activeFromL1, NO_EXIT, 0, 0);
        assertEq(registry.entryCount(), 1);
        assertEq(registry.bondOwnerOf(0), Alice);
        assertFalse(registry.isWithdrawn(0));
        assertEq(registry.entriesRoot(), root);
        _assertCheckpoint(0, START_BLOCK, 1, root);
        assertEq(token.balanceOf(address(registry)), amount);
        assertEq(token.balanceOf(Alice), 100 * MIN_STAKE - amount);
    }

    function test_register_AssignsSequentialBondIds() external {
        assertEq(_register(Alice, KEY_A), 0);
        assertEq(_register(Bob, KEY_B), 1);
        assertEq(_register(Alice, KEY_C), 2);
        assertEq(registry.bondOwnerOf(1), Bob);
        assertEq(registry.bondOwnerOf(2), Alice);
        assertEq(registry.entryCount(), 3);
    }

    function test_register_RevertWhen_StakeTooLow() external {
        vm.expectRevert(EtnaStakingRegistry.StakeTooLow.selector);
        vm.prank(Alice);
        registry.register(KEY_A, MIN_STAKE - 1);
    }

    function test_register_RevertWhen_PubkeyIsZero() external {
        vm.expectRevert(EtnaStakingRegistry.ZeroPubkey.selector);
        vm.prank(Alice);
        registry.register(bytes32(0), MIN_STAKE);
    }

    function test_register_RevertWhen_PubkeyHeldWithoutExit() external {
        _register(Alice, KEY_A);

        vm.expectRevert(EtnaStakingRegistry.PubkeyInUse.selector);
        vm.prank(Bob);
        registry.register(KEY_A, MIN_STAKE);
    }

    function test_register_RevertWhen_PubkeyHolderExitNotYetEffective() external {
        _register(Alice, KEY_A);
        vm.prank(Alice);
        registry.requestExit(0);
        uint64 exitEffectiveL1 = registry.entryAt(0).exitEffectiveL1;

        vm.roll(exitEffectiveL1 - 1);
        vm.expectRevert(EtnaStakingRegistry.PubkeyInUse.selector);
        vm.prank(Bob);
        registry.register(KEY_A, MIN_STAKE);
    }

    function test_register_ReusesAPubkeyOnceTheHolderExitIsEffective() external {
        _register(Alice, KEY_A);
        vm.prank(Alice);
        registry.requestExit(0);
        vm.roll(registry.entryAt(0).exitEffectiveL1);

        assertEq(_register(Bob, KEY_A), 1);
        assertEq(registry.entryAt(1).pubkey, KEY_A);

        // Bob's entry now holds the key and has not exited.
        vm.expectRevert(EtnaStakingRegistry.PubkeyInUse.selector);
        vm.prank(Carol);
        registry.register(KEY_A, MIN_STAKE);
    }

    function test_register_RevertWhen_RegistryFull() external {
        uint256 maxEntries = registry.MAX_ENTRIES();
        token.approve(address(registry), type(uint256).max);

        vm.pauseGasMetering();
        for (uint256 i; i < maxEntries; ++i) {
            registry.register(bytes32(i + 1), MIN_STAKE);
        }
        bytes32 naiveRoot = _naiveEntriesRoot();
        vm.resumeGasMetering();

        assertEq(registry.entryCount(), maxEntries);
        assertEq(registry.checkpointCount(), 1);
        _assertCheckpoint(0, START_BLOCK, uint32(maxEntries), naiveRoot);
        assertEq(registry.entriesRoot(), naiveRoot);

        vm.expectRevert(EtnaStakingRegistry.RegistryFull.selector);
        registry.register(bytes32(maxEntries + 1), MIN_STAKE);
    }

    // ---------------------------------------------------------------
    // heartbeat
    // ---------------------------------------------------------------

    function test_heartbeat_RecordsTheWindowStartAndTheSeq() external {
        _register(Alice, KEY_A);
        vm.roll(1234);
        uint64 windowStart = 1200;
        bytes32 root = LibEntriesTree.leaf(
            0, _entry(KEY_A, MIN_STAKE, START_BLOCK + ACTIVATION_DELAY, NO_EXIT, windowStart, 1)
        );

        vm.expectEmit();
        emit IEtnaStakingRegistry.CheckpointWritten(1, 1234, 1, root);
        vm.expectEmit();
        emit IEtnaStakingRegistry.HeartbeatRecorded(0, windowStart, 1);
        vm.prank(Alice);
        registry.heartbeat(0);

        assertEq(registry.entryAt(0).lastHeartbeatAt, windowStart);
        assertEq(registry.entryAt(0).lastHeartbeatSeq, 1);
        assertEq(registry.entriesRoot(), root);
        _assertCheckpoint(1, 1234, 1, root);
    }

    function test_heartbeat_SucceedsInTheRegistrationBlock() external {
        _register(Alice, KEY_A);
        assertEq(registry.entryAt(0).lastHeartbeatAt, 0);
        assertEq(registry.entryAt(0).lastHeartbeatSeq, 0);

        vm.prank(Alice);
        registry.heartbeat(0);

        assertEq(registry.entryAt(0).lastHeartbeatAt, 1000);
        assertEq(registry.entryAt(0).lastHeartbeatSeq, 1);
        assertEq(registry.checkpointCount(), 1);
    }

    function test_heartbeat_RevertWhen_AlreadyRecordedInTheWindow() external {
        _register(Alice, KEY_A);
        vm.roll(1200);
        vm.prank(Alice);
        registry.heartbeat(0);

        vm.roll(1249);
        vm.expectRevert(EtnaStakingRegistry.HeartbeatAlreadyRecorded.selector);
        vm.prank(Alice);
        registry.heartbeat(0);
    }

    function test_heartbeat_IncreasesInTheNextWindow() external {
        _register(Alice, KEY_A);
        vm.roll(1249);
        vm.prank(Alice);
        registry.heartbeat(0);
        assertEq(registry.entryAt(0).lastHeartbeatAt, 1200);
        assertEq(registry.entryAt(0).lastHeartbeatSeq, 1);

        vm.roll(1250);
        vm.prank(Alice);
        registry.heartbeat(0);
        assertEq(registry.entryAt(0).lastHeartbeatAt, 1250);
        assertEq(registry.entryAt(0).lastHeartbeatSeq, 2);

        vm.roll(1999);
        vm.prank(Alice);
        registry.heartbeat(0);
        assertEq(registry.entryAt(0).lastHeartbeatAt, 1950);
        assertEq(registry.entryAt(0).lastHeartbeatSeq, 3);
    }

    function test_heartbeat_SucceedsFirstInWindowZero() external {
        vm.roll(HEARTBEAT_WINDOW - 1);
        _register(Alice, KEY_A);
        bytes32 root = LibEntriesTree.leaf(
            0, _entry(KEY_A, MIN_STAKE, HEARTBEAT_WINDOW - 1 + ACTIVATION_DELAY, NO_EXIT, 0, 1)
        );

        vm.expectEmit();
        emit IEtnaStakingRegistry.CheckpointWritten(0, HEARTBEAT_WINDOW - 1, 1, root);
        vm.expectEmit();
        emit IEtnaStakingRegistry.HeartbeatRecorded(0, 0, 1);
        vm.prank(Alice);
        registry.heartbeat(0);

        // lastHeartbeatAt stays 0; only the sequence shows the heartbeat.
        assertEq(registry.entryAt(0).lastHeartbeatAt, 0);
        assertEq(registry.entryAt(0).lastHeartbeatSeq, 1);
        assertEq(registry.entriesRoot(), root);
    }

    function test_heartbeat_RevertWhen_SecondInWindowZero() external {
        vm.roll(1);
        _register(Alice, KEY_A);
        vm.prank(Alice);
        registry.heartbeat(0);

        vm.roll(HEARTBEAT_WINDOW - 1);
        vm.expectRevert(EtnaStakingRegistry.HeartbeatAlreadyRecorded.selector);
        vm.prank(Alice);
        registry.heartbeat(0);
    }

    function test_heartbeat_IncrementsTheSeqAfterWindowZero() external {
        vm.roll(HEARTBEAT_WINDOW - 1);
        _register(Alice, KEY_A);
        vm.prank(Alice);
        registry.heartbeat(0);

        vm.roll(HEARTBEAT_WINDOW);
        vm.expectEmit();
        emit IEtnaStakingRegistry.HeartbeatRecorded(0, HEARTBEAT_WINDOW, 2);
        vm.prank(Alice);
        registry.heartbeat(0);

        assertEq(registry.entryAt(0).lastHeartbeatAt, HEARTBEAT_WINDOW);
        assertEq(registry.entryAt(0).lastHeartbeatSeq, 2);
    }

    function test_heartbeat_SucceedsAfterTheExitRequestUntilItIsEffective() external {
        _register(Alice, KEY_A);
        vm.prank(Alice);
        registry.requestExit(0);
        uint64 exitEffectiveL1 = registry.entryAt(0).exitEffectiveL1;

        vm.roll(exitEffectiveL1 - 1);
        vm.prank(Alice);
        registry.heartbeat(0);
        assertEq(
            registry.entryAt(0).lastHeartbeatAt,
            (exitEffectiveL1 - 1) / HEARTBEAT_WINDOW * HEARTBEAT_WINDOW
        );
    }

    function test_heartbeat_RevertWhen_ExitIsEffective() external {
        _register(Alice, KEY_A);
        vm.prank(Alice);
        registry.requestExit(0);
        vm.roll(registry.entryAt(0).exitEffectiveL1);

        vm.expectRevert(EtnaStakingRegistry.AlreadyExited.selector);
        vm.prank(Alice);
        registry.heartbeat(0);
    }

    function test_heartbeat_RevertWhen_NotBondOwner() external {
        _register(Alice, KEY_A);

        vm.expectRevert(EtnaStakingRegistry.NotBondOwner.selector);
        vm.prank(Bob);
        registry.heartbeat(0);
    }

    function test_heartbeat_RevertWhen_UnknownBond() external {
        vm.expectRevert(EtnaStakingRegistry.UnknownBond.selector);
        vm.prank(Alice);
        registry.heartbeat(0);
    }

    // ---------------------------------------------------------------
    // requestExit
    // ---------------------------------------------------------------

    function test_requestExit_CountsTheDelayFromTheActivation() external {
        _register(Alice, KEY_A);
        uint64 exitEffectiveL1 = START_BLOCK + ACTIVATION_DELAY + EXIT_DELAY;
        bytes32 root = LibEntriesTree.leaf(
            0, _entry(KEY_A, MIN_STAKE, START_BLOCK + ACTIVATION_DELAY, exitEffectiveL1, 0, 0)
        );

        vm.expectEmit();
        emit IEtnaStakingRegistry.CheckpointWritten(0, START_BLOCK, 1, root);
        vm.expectEmit();
        emit IEtnaStakingRegistry.ExitRequested(0, exitEffectiveL1);
        vm.prank(Alice);
        registry.requestExit(0);

        assertEq(registry.entryAt(0).exitEffectiveL1, exitEffectiveL1);
        assertEq(registry.entriesRoot(), root);
        _assertCheckpoint(0, START_BLOCK, 1, root);
    }

    function test_requestExit_CountsTheDelayFromTheCurrentBlock() external {
        _register(Alice, KEY_A);
        vm.roll(START_BLOCK + ACTIVATION_DELAY + 5);

        vm.prank(Alice);
        registry.requestExit(0);

        assertEq(
            registry.entryAt(0).exitEffectiveL1, START_BLOCK + ACTIVATION_DELAY + 5 + EXIT_DELAY
        );
        assertEq(registry.checkpointCount(), 2);
    }

    function test_requestExit_RevertWhen_AlreadyRequested() external {
        _register(Alice, KEY_A);
        vm.prank(Alice);
        registry.requestExit(0);

        vm.expectRevert(EtnaStakingRegistry.ExitAlreadyRequested.selector);
        vm.prank(Alice);
        registry.requestExit(0);
    }

    function test_requestExit_RevertWhen_NotBondOwner() external {
        _register(Alice, KEY_A);

        vm.expectRevert(EtnaStakingRegistry.NotBondOwner.selector);
        vm.prank(Bob);
        registry.requestExit(0);
    }

    function test_requestExit_RevertWhen_UnknownBond() external {
        vm.expectRevert(EtnaStakingRegistry.UnknownBond.selector);
        vm.prank(Alice);
        registry.requestExit(0);
    }

    // ---------------------------------------------------------------
    // withdraw
    // ---------------------------------------------------------------

    function test_withdraw_TransfersTheStakeAfterTheDelay() external {
        _register(Alice, KEY_A);
        vm.prank(Alice);
        registry.requestExit(0);
        IEtnaStakingRegistry.Entry memory entry = registry.entryAt(0);
        IEtnaStakingRegistry.Checkpoint memory checkpoint = registry.checkpointAt(0);

        vm.roll(entry.exitEffectiveL1 + WITHDRAWAL_DELAY);
        vm.expectEmit();
        emit IEtnaStakingRegistry.StakeWithdrawn(0, Carol, MIN_STAKE);
        vm.prank(Alice);
        registry.withdraw(0, Carol);

        assertTrue(registry.isWithdrawn(0));
        assertEq(token.balanceOf(Carol), 100 * MIN_STAKE + MIN_STAKE);
        assertEq(token.balanceOf(address(registry)), 0);
        // The entry and the checkpoints are unchanged.
        _assertEntry(
            0,
            entry.pubkey,
            entry.effStake,
            entry.activeFromL1,
            entry.exitEffectiveL1,
            entry.lastHeartbeatAt,
            entry.lastHeartbeatSeq
        );
        assertEq(registry.checkpointCount(), 1);
        _assertCheckpoint(0, checkpoint.l1Block, checkpoint.count, checkpoint.entriesRoot);
    }

    function test_withdraw_RevertWhen_DelayNotElapsed() external {
        _register(Alice, KEY_A);
        vm.prank(Alice);
        registry.requestExit(0);

        vm.roll(registry.entryAt(0).exitEffectiveL1 + WITHDRAWAL_DELAY - 1);
        vm.expectRevert(EtnaStakingRegistry.WithdrawalNotReady.selector);
        vm.prank(Alice);
        registry.withdraw(0, Alice);
    }

    function test_withdraw_RevertWhen_ExitNotRequested() external {
        _register(Alice, KEY_A);

        vm.expectRevert(EtnaStakingRegistry.ExitNotRequested.selector);
        vm.prank(Alice);
        registry.withdraw(0, Alice);
    }

    function test_withdraw_RevertWhen_AlreadyWithdrawn() external {
        _register(Alice, KEY_A);
        vm.prank(Alice);
        registry.requestExit(0);
        vm.roll(registry.entryAt(0).exitEffectiveL1 + WITHDRAWAL_DELAY);
        vm.prank(Alice);
        registry.withdraw(0, Alice);

        vm.expectRevert(EtnaStakingRegistry.AlreadyWithdrawn.selector);
        vm.prank(Alice);
        registry.withdraw(0, Alice);
    }

    function test_withdraw_RevertWhen_NotBondOwner() external {
        _register(Alice, KEY_A);
        vm.prank(Alice);
        registry.requestExit(0);
        vm.roll(registry.entryAt(0).exitEffectiveL1 + WITHDRAWAL_DELAY);

        vm.expectRevert(EtnaStakingRegistry.NotBondOwner.selector);
        vm.prank(Bob);
        registry.withdraw(0, Bob);
    }

    function test_withdraw_RevertWhen_UnknownBond() external {
        vm.expectRevert(EtnaStakingRegistry.UnknownBond.selector);
        vm.prank(Alice);
        registry.withdraw(0, Alice);
    }

    function test_withdraw_RevertWhen_RecipientIsZero() external {
        _register(Alice, KEY_A);
        vm.prank(Alice);
        registry.requestExit(0);
        vm.roll(registry.entryAt(0).exitEffectiveL1 + WITHDRAWAL_DELAY);

        vm.expectRevert(EssentialContract.ZERO_ADDRESS.selector);
        vm.prank(Alice);
        registry.withdraw(0, address(0));
    }

    // ---------------------------------------------------------------
    // Checkpoints and entriesRoot
    // ---------------------------------------------------------------

    function test_checkpoint_OverwritesWithinOneBlock() external {
        _register(Alice, KEY_A);
        _register(Bob, KEY_B);
        vm.prank(Alice);
        registry.heartbeat(0);
        vm.prank(Bob);
        registry.requestExit(1);

        assertEq(registry.checkpointCount(), 1);
        _assertCheckpoint(0, START_BLOCK, 2, _naiveEntriesRoot());
    }

    function test_checkpoint_AppendsInALaterBlock() external {
        _register(Alice, KEY_A);
        _register(Bob, KEY_B);
        IEtnaStakingRegistry.Checkpoint memory first = registry.checkpointAt(0);

        bytes32 l0 = LibEntriesTree.leaf(0, registry.entryAt(0));
        bytes32 l1 = LibEntriesTree.leaf(1, registry.entryAt(1));
        bytes32 l2 = LibEntriesTree.leaf(
            2, _entry(KEY_C, MIN_STAKE, START_BLOCK + 1 + ACTIVATION_DELAY, NO_EXIT, 0, 0)
        );
        bytes32 root = _hash(_hash(l0, l1), _hash(l2, bytes32(0)));

        vm.roll(START_BLOCK + 1);
        vm.expectEmit();
        emit IEtnaStakingRegistry.CheckpointWritten(1, START_BLOCK + 1, 3, root);
        _register(Carol, KEY_C);

        assertEq(registry.checkpointCount(), 2);
        assertEq(first.count, 2);
        assertEq(first.entriesRoot, _hash(l0, l1));
        _assertCheckpoint(0, START_BLOCK, 2, first.entriesRoot);
        _assertCheckpoint(1, START_BLOCK + 1, 3, root);
        assertEq(registry.entriesRoot(), root);
    }

    function test_entriesRoot_MatchesTheTreeOverEntryAt() external {
        _register(Alice, KEY_A);
        _register(Bob, KEY_B);
        vm.roll(1300);
        _register(Carol, KEY_C);
        vm.prank(Bob);
        registry.heartbeat(1);
        vm.roll(1400);
        vm.prank(Alice);
        registry.requestExit(0);
        _register(Alice, bytes32(uint256(0xd4)));
        vm.roll(1450);
        vm.prank(Bob);
        registry.heartbeat(1);
        assertEq(registry.entryAt(1).lastHeartbeatSeq, 2);

        bytes32 root = registry.entriesRoot();
        assertEq(root, _naiveEntriesRoot());
        assertEq(registry.checkpointCount(), 4);
        _assertCheckpoint(3, 1450, 4, root);
        uint64 previous;
        for (uint256 i; i < registry.checkpointCount(); ++i) {
            uint64 l1Block = registry.checkpointAt(i).l1Block;
            assertGt(l1Block, previous);
            previous = l1Block;
        }
    }

    // ---------------------------------------------------------------
    // Views
    // ---------------------------------------------------------------

    function test_checkpointAt_RevertWhen_UnknownCheckpoint() external {
        vm.expectRevert(EtnaStakingRegistry.UnknownCheckpoint.selector);
        registry.checkpointAt(0);
    }

    function test_entryAt_RevertWhen_UnknownBond() external {
        _register(Alice, KEY_A);
        vm.expectRevert(EtnaStakingRegistry.UnknownBond.selector);
        registry.entryAt(1);
    }

    function test_bondOwnerOf_ReturnsZeroForAnUnknownBond() external view {
        assertEq(registry.bondOwnerOf(7), address(0));
        assertFalse(registry.isWithdrawn(7));
    }

    // ---------------------------------------------------------------
    // Storage layout read by the Etna node
    // ---------------------------------------------------------------

    function test_storage_BaseSlotMatchesErc7201() external pure {
        bytes32 base = keccak256(abi.encode(uint256(keccak256("taiko.etna.registry")) - 1))
            & ~bytes32(uint256(0xff));
        assertEq(base, REGISTRY_BASE);
        // taiko-client-rs `checkpoint_slots(0)[0]` and `entry_slots(0)[0]`.
        assertEq(
            _checkpointSlot(0, 0),
            bytes32(0xd9a608a417f242366fbd54f054137bf7eb45998d56e782c42e929a940d78cebf)
        );
        assertEq(
            _entrySlot(0, 0),
            bytes32(0x4d419ea4bc25ad27df001f0b7723b9f336aaf0c5d43f32d8ebc7877436afbcba)
        );
    }

    function test_storage_CheckpointsAndEntriesAtTheNodeSlots() external {
        _register(Alice, KEY_A);
        vm.roll(1250);
        _register(Bob, KEY_B);
        vm.prank(Bob);
        registry.requestExit(1);
        vm.prank(Alice);
        registry.heartbeat(0);

        // checkpoints: length at R; element i at keccak256(R) + 2i (+1).
        assertEq(_load(REGISTRY_BASE), 2);
        for (uint256 i; i < 2; ++i) {
            IEtnaStakingRegistry.Checkpoint memory c = registry.checkpointAt(i);
            uint256 head = _load(_checkpointSlot(i, 0));
            assertEq(uint64(head), c.l1Block);
            assertEq(uint32(head >> 64), c.count);
            assertEq(head >> 96, 0);
            assertEq(bytes32(_load(_checkpointSlot(i, 1))), c.entriesRoot);
        }
        assertEq(uint64(_load(_checkpointSlot(1, 0))), 1250);
        assertEq(uint32(_load(_checkpointSlot(1, 0)) >> 64), 2);

        // entries: length at R + 1; element j at keccak256(R + 1) + 3j (+1, +2).
        assertEq(_load(bytes32(uint256(REGISTRY_BASE) + 1)), 2);
        for (uint256 j; j < 2; ++j) {
            IEtnaStakingRegistry.Entry memory e = registry.entryAt(j);
            assertEq(bytes32(_load(_entrySlot(j, 0))), e.pubkey);
            assertEq(_load(_entrySlot(j, 1)), e.effStake);
            uint256 packed = _load(_entrySlot(j, 2));
            assertEq(uint64(packed), e.activeFromL1);
            assertEq(uint64(packed >> 64), e.exitEffectiveL1);
            assertEq(uint64(packed >> 128), e.lastHeartbeatAt);
            assertEq(packed >> 192, e.lastHeartbeatSeq);
        }
        uint256 bobPacked = _load(_entrySlot(1, 2));
        assertEq(uint64(bobPacked), 1250 + ACTIVATION_DELAY);
        assertEq(uint64(bobPacked >> 64), 1250 + ACTIVATION_DELAY + EXIT_DELAY);
        assertEq(uint64(bobPacked >> 128), 0);
        assertEq(bobPacked >> 192, 0);
        assertEq(uint64(_load(_entrySlot(0, 2)) >> 128), 1250);
        assertEq(_load(_entrySlot(0, 2)) >> 192, 1);

        // Mappings at R + 2 (bondOwner), R + 4 (keyHolder) and R + 5 (tree, leaf 1 = node key 1).
        assertEq(_load(_mappingSlot(bytes32(uint256(1)), 2)), uint256(uint160(Bob)));
        assertEq(_load(_mappingSlot(KEY_B, 4)), 2);
        assertEq(
            bytes32(_load(_mappingSlot(bytes32(uint256(1)), 5))),
            LibEntriesTree.leaf(1, registry.entryAt(1))
        );
    }

    function test_storage_HeartbeatSeqInBits192To255() external {
        vm.roll(HEARTBEAT_WINDOW - 1);
        _register(Alice, KEY_A);
        uint64[3] memory blocks = [HEARTBEAT_WINDOW - 1, 3 * HEARTBEAT_WINDOW + 7, START_BLOCK];
        for (uint256 i; i < blocks.length; ++i) {
            vm.roll(blocks[i]);
            vm.prank(Alice);
            registry.heartbeat(0);

            uint256 packed = _load(_entrySlot(0, 2));
            assertEq(uint64(packed), HEARTBEAT_WINDOW - 1 + ACTIVATION_DELAY);
            assertEq(uint64(packed >> 64), NO_EXIT);
            assertEq(uint64(packed >> 128), blocks[i] / HEARTBEAT_WINDOW * HEARTBEAT_WINDOW);
            assertEq(packed >> 192, i + 1);
        }
    }

    function test_storage_WithdrawnFlagAtR3() external {
        _register(Alice, KEY_A);
        vm.prank(Alice);
        registry.requestExit(0);
        vm.roll(registry.entryAt(0).exitEffectiveL1 + WITHDRAWAL_DELAY);
        assertEq(_load(_mappingSlot(bytes32(0), 3)), 0);

        vm.prank(Alice);
        registry.withdraw(0, Alice);
        assertEq(_load(_mappingSlot(bytes32(0), 3)), 1);
    }

    // ---------------------------------------------------------------
    // Helpers
    // ---------------------------------------------------------------

    function _newRegistry(
        address _token,
        uint256 _minStake,
        uint64 _heartbeatWindow
    )
        private
        returns (EtnaStakingRegistry)
    {
        return new EtnaStakingRegistry(
            _token, _minStake, ACTIVATION_DELAY, EXIT_DELAY, WITHDRAWAL_DELAY, _heartbeatWindow
        );
    }

    function _register(address _staker, bytes32 _pubkey) private returns (uint256) {
        vm.prank(_staker);
        return registry.register(_pubkey, MIN_STAKE);
    }

    function _entry(
        bytes32 _pubkey,
        uint256 _effStake,
        uint64 _activeFromL1,
        uint64 _exitEffectiveL1,
        uint64 _lastHeartbeatAt,
        uint64 _lastHeartbeatSeq
    )
        private
        pure
        returns (IEtnaStakingRegistry.Entry memory)
    {
        return IEtnaStakingRegistry.Entry({
            pubkey: _pubkey,
            effStake: _effStake,
            activeFromL1: _activeFromL1,
            exitEffectiveL1: _exitEffectiveL1,
            lastHeartbeatAt: _lastHeartbeatAt,
            lastHeartbeatSeq: _lastHeartbeatSeq
        });
    }

    function _assertEntry(
        uint256 _bondId,
        bytes32 _pubkey,
        uint256 _effStake,
        uint64 _activeFromL1,
        uint64 _exitEffectiveL1,
        uint64 _lastHeartbeatAt,
        uint64 _lastHeartbeatSeq
    )
        private
        view
    {
        IEtnaStakingRegistry.Entry memory e = registry.entryAt(_bondId);
        assertEq(e.pubkey, _pubkey);
        assertEq(e.effStake, _effStake);
        assertEq(e.activeFromL1, _activeFromL1);
        assertEq(e.exitEffectiveL1, _exitEffectiveL1);
        assertEq(e.lastHeartbeatAt, _lastHeartbeatAt);
        assertEq(e.lastHeartbeatSeq, _lastHeartbeatSeq);
    }

    function _assertCheckpoint(
        uint256 _index,
        uint64 _l1Block,
        uint32 _count,
        bytes32 _entriesRoot
    )
        private
        view
    {
        IEtnaStakingRegistry.Checkpoint memory c = registry.checkpointAt(_index);
        assertEq(c.l1Block, _l1Block);
        assertEq(c.count, _count);
        assertEq(c.entriesRoot, _entriesRoot);
    }

    function _hash(bytes32 _left, bytes32 _right) private pure returns (bytes32) {
        return keccak256(abi.encodePacked(_left, _right));
    }

    /// @dev The entries root recomputed from `entryAt` with a zero-padded pairwise tree.
    function _naiveEntriesRoot() private view returns (bytes32) {
        uint256 count = registry.entryCount();
        if (count == 0) return bytes32(0);
        uint256 width = 1;
        while (width < count) {
            width <<= 1;
        }
        bytes32[] memory level = new bytes32[](width);
        for (uint256 i; i < count; ++i) {
            level[i] = LibEntriesTree.leaf(i, registry.entryAt(i));
        }
        while (width > 1) {
            width >>= 1;
            for (uint256 i; i < width; ++i) {
                level[i] = _hash(level[2 * i], level[2 * i + 1]);
            }
        }
        return level[0];
    }

    function _load(bytes32 _slot) private view returns (uint256) {
        return uint256(vm.load(address(registry), _slot));
    }

    function _checkpointSlot(uint256 _i, uint256 _word) private pure returns (bytes32) {
        return bytes32(uint256(keccak256(abi.encode(REGISTRY_BASE))) + 2 * _i + _word);
    }

    function _entrySlot(uint256 _j, uint256 _word) private pure returns (bytes32) {
        return bytes32(uint256(keccak256(abi.encode(uint256(REGISTRY_BASE) + 1))) + 3 * _j + _word);
    }

    function _mappingSlot(bytes32 _key, uint256 _field) private pure returns (bytes32) {
        return keccak256(abi.encode(_key, uint256(REGISTRY_BASE) + _field));
    }
}
