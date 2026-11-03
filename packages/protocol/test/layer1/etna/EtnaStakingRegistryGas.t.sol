// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { EtnaStakingRegistryTestBase } from "./EtnaStakingRegistryTestBase.sol";
import { EtnaTestKeys } from "./EtnaTestKeys.sol";
import { IEtnaStakingRegistry } from "src/layer1/etna/iface/IEtnaStakingRegistry.sol";
import { EtnaStakingRegistry } from "src/layer1/etna/impl/EtnaStakingRegistry.sol";
import { LibCometVote } from "src/layer1/etna/libs/LibCometVote.sol";

/// @title EtnaStakingRegistryGasBase
/// @notice Gas snapshots of the staking registry's entry points on real TAIKO and real keys.
/// @dev `setUp` and the measured test are separate transactions, so every contract's storage
/// starts cold in the test. Each test loads its target, caller and arguments into memory before
/// `vm.startSnapshotGas`, so the measured window holds only the call. The registry reads the Inbox
/// views from `MockEtnaInbox`.
abstract contract EtnaStakingRegistryGasBase is EtnaStakingRegistryTestBase {
    /// @dev Every measured call must stay below this.
    uint256 internal constant GAS_LIMIT = 3_000_000;

    /// @dev The registry's capacity.
    uint256 internal constant CAPACITY = 4096;

    /// @dev The consensus private keys of the first and second measured bonds.
    uint256 internal constant CK_A = 0xC0A;
    uint256 internal constant CK_B = 0xC0B;

    /// @dev The first prefilled consensus key.
    uint256 internal constant PREFILL_KEY = 0x10000;

    /// @dev Registrations per `prefillBatch` call: one call frame's memory must stay within the
    /// transaction gas cap.
    uint256 internal constant PREFILL_CALL = 128;

    /// @dev The registration the test measures: the key and proof of possession of its caller.
    bytes internal publicKey;
    bytes internal pop;

    /// @dev The conflicting votes a slashing test reports.
    IEtnaStakingRegistry.Vote internal voteA;
    IEtnaStakingRegistry.Vote internal voteB;

    /// @notice Carol registers `_count` minimum stakes with the consensus keys `_firstKey`,
    /// `_firstKey + 1`, ... in the current block.
    /// @dev Called by this contract only, as an external call so each batch starts with empty
    /// memory.
    function prefillBatch(uint256 _firstKey, uint256 _count) external {
        require(msg.sender == address(this), "self only");
        for (uint256 i; i < _count; ++i) {
            bytes memory key = EtnaTestKeys.publicKey(_firstKey + i);
            bytes memory proof = EtnaTestKeys.popSig(_firstKey + i, registry, Carol);
            vm.prank(Carol);
            registry.register(key, MIN_STAKE, proof);
        }
    }

    /// @dev Funds `_staker` and stores the key and proof of possession of `_pk` for `_staker`'s
    /// measured registration.
    function _prepareRegistration(address _staker, uint256 _pk) internal {
        _fund(_staker, MIN_STAKE + 1);
        publicKey = EtnaTestKeys.publicKey(_pk);
        pop = EtnaTestKeys.popSig(_pk, registry, _staker);
    }

    /// @dev Measures `_staker`'s registration of the stored key staking `_amount` as `_label`,
    /// and returns its bond id.
    function _measureRegister(
        string memory _label,
        address _staker,
        uint256 _amount
    )
        internal
        returns (uint256 bondId_)
    {
        EtnaStakingRegistry target = registry;
        bytes memory key = publicKey;
        bytes memory proof = pop;
        vm.startPrank(_staker);
        vm.startSnapshotGas(_label);
        bondId_ = target.register(key, _amount, proof);
        _stopSnapshot(_label);
        vm.stopPrank();
    }

    /// @dev Measures `_owner`'s exit request for `_bondId` as `_label`.
    function _measureExit(string memory _label, address _owner, uint256 _bondId) internal {
        EtnaStakingRegistry target = registry;
        vm.startPrank(_owner);
        vm.startSnapshotGas(_label);
        target.requestExit(_bondId);
        _stopSnapshot(_label);
        vm.stopPrank();
        assertLt(registry.entryAt(_bondId).exitEffectiveL1, type(uint48).max, "exit set");
    }

    /// @dev Ends the measurement `_label`, logs it and checks it against `GAS_LIMIT`.
    function _stopSnapshot(string memory _label) internal returns (uint256 gasUsed_) {
        gasUsed_ = vm.stopSnapshotGas();
        emit log_named_uint(_label, gasUsed_);
        assertLt(gasUsed_, GAS_LIMIT, _label);
    }

    /// @dev Two conflicting generation-0 precommits at height 1000, round 3, signed by `_pk` for
    /// this deployment.
    function _conflictingVotes(uint256 _pk)
        internal
        view
        returns (IEtnaStakingRegistry.Vote memory a_, IEtnaStakingRegistry.Vote memory b_)
    {
        bytes memory cometChainId = LibCometVote.chainId(
            LibCometVote.chainDomain(block.chainid, L2_CHAIN_ID, address(mockInbox), 0)
        );
        a_ = EtnaTestKeys.signVote(_pk, _precommit(keccak256("block a")), cometChainId);
        b_ = EtnaTestKeys.signVote(_pk, _precommit(keccak256("block b")), cometChainId);
    }

    /// @dev A precommit at height 1000, round 3, for `_blockHash` with a one-part part set
    /// header.
    function _precommit(bytes32 _blockHash)
        internal
        pure
        returns (IEtnaStakingRegistry.Vote memory v_)
    {
        v_.voteType = 2;
        v_.height = 1000;
        v_.round = 3;
        v_.blockHash = _blockHash;
        v_.partsTotal = 1;
        v_.partsHash = keccak256(abi.encode(_blockHash));
        v_.timestampSeconds = 1_700_000_000;
        v_.timestampNanos = 123;
    }

    /// @dev Measures Bob's double-sign report against `_bondId` with the stored votes as
    /// `_label`.
    function _measureSlash(string memory _label, uint256 _bondId) internal {
        EtnaStakingRegistry target = registry;
        IEtnaStakingRegistry.Vote memory a = voteA;
        IEtnaStakingRegistry.Vote memory b = voteB;
        vm.startPrank(Bob);
        vm.startSnapshotGas(_label);
        target.slashDoubleSign(_bondId, a, b);
        _stopSnapshot(_label);
        vm.stopPrank();
        assertEq(registry.bondAt(_bondId).entry.effStake, 0, "slashed");
    }

    /// @dev Measures the registry owner's forfeiture of `_bondId` as `_label`.
    function _measureForfeit(string memory _label, uint256 _bondId) internal {
        EtnaStakingRegistry target = registry;
        IEtnaStakingRegistry.Entry memory entry = registry.bondAt(_bondId).entry;
        bytes32 entryKey = keccak256(abi.encode(uint256(entry.ckPrefix), entry.ckX));
        uint256 validUntil = block.timestamp;
        vm.startSnapshotGas(_label);
        target.forfeit(_bondId, entryKey, bytes32(0), validUntil);
        _stopSnapshot(_label);
        assertTrue(registry.forfeited(entryKey), "forfeited");
    }

    /// @dev Measures `_owner`'s withdrawal of `_bondId` to itself as `_label`.
    function _measureWithdraw(string memory _label, address _owner, uint256 _bondId) internal {
        EtnaStakingRegistry target = registry;
        vm.startPrank(_owner);
        vm.startSnapshotGas(_label);
        target.withdraw(_bondId, _owner);
        _stopSnapshot(_label);
        vm.stopPrank();
        assertTrue(registry.bondAt(_bondId).withdrawn, "withdrawn");
    }

    /// @dev Carol registers `_count` minimum stakes, `PREFILL_CALL` per call and one L1 block per
    /// call, then the chain moves one more block so the measured call writes a new checkpoint.
    function _prefill(uint256 _count) internal {
        _fund(Carol, _count * MIN_STAKE);
        vm.pauseGasMetering();
        for (uint256 done; done < _count; done += PREFILL_CALL) {
            uint256 count = _count - done < PREFILL_CALL ? _count - done : PREFILL_CALL;
            this.prefillBatch(PREFILL_KEY + done, count);
            vm.roll(block.number + 1);
        }
        vm.resumeGasMetering();
        assertEq(registry.entryCount(), _count, "prefilled");
        assertEq(registry.bondCount(), _count, "one bond per slot");
    }
}

/// @title EtnaStakingRegistryInitialGasTest
/// @notice The first registration into an empty registry.
contract EtnaStakingRegistryInitialGasTest is EtnaStakingRegistryGasBase {
    function setUp() public override {
        super.setUp();
        vm.roll(10);
        _prepareRegistration(Alice, CK_A);
    }

    function test_gas_InitialRegistration() external {
        assertEq(_measureRegister("initial_register", Alice, MIN_STAKE), 0, "bond 0");
        assertEq(registry.checkpointCount(), 1, "first checkpoint");
    }
}

/// @title EtnaStakingRegistrySecondEntryGasTest
/// @notice With Alice's bond 0 registered in an earlier block: a second registration and bond 0's
/// exit request.
contract EtnaStakingRegistrySecondEntryGasTest is EtnaStakingRegistryGasBase {
    function setUp() public override {
        super.setUp();
        vm.roll(10);
        assertEq(_register(Alice, CK_A), 0, "bond 0");
        vm.roll(11);
        _prepareRegistration(Bob, CK_B);
    }

    function test_gas_SecondRegistration() external {
        assertEq(_measureRegister("second_register", Bob, MIN_STAKE), 1, "bond 1");
        assertEq(registry.checkpointCount(), 2, "checkpoint appended");
    }

    function test_gas_Exit() external {
        _measureExit("exit", Alice, 0);
        assertEq(registry.checkpointCount(), 2, "checkpoint appended");
    }
}

/// @title EtnaStakingRegistryConfirmExitGasTest
/// @notice Confirming bond 0's exit once a landed committee covers it.
contract EtnaStakingRegistryConfirmExitGasTest is EtnaStakingRegistryGasBase {
    function setUp() public override {
        super.setUp();
        vm.roll(10);
        assertEq(_register(Alice, CK_A), 0, "bond 0");
        vm.prank(Alice);
        registry.requestExit(0);
        uint256 exitEffectiveL1 = registry.entryAt(0).exitEffectiveL1;
        vm.roll(exitEffectiveL1 + 1);
        mockInbox.setInitialized(true);
        mockInbox.setActiveCommitteeSnapshot(exitEffectiveL1);
    }

    function test_gas_ConfirmExit() external {
        EtnaStakingRegistry target = registry;
        vm.startPrank(Carol);
        vm.startSnapshotGas("confirm_exit");
        target.confirmExit(0);
        _stopSnapshot("confirm_exit");
        vm.stopPrank();
        assertEq(registry.exitConfirmedAtL1(0), block.number, "confirmed");
    }
}

/// @title EtnaStakingRegistryWithdrawalGasTest
/// @notice Alice withdrawing bond 0's stake once its confirmed exit has waited the withdrawal
/// delay.
contract EtnaStakingRegistryWithdrawalGasTest is EtnaStakingRegistryGasBase {
    function setUp() public override {
        super.setUp();
        vm.roll(10);
        assertEq(_register(Alice, CK_A), 0, "bond 0");
        vm.prank(Alice);
        registry.requestExit(0);
        vm.roll(registry.entryAt(0).exitEffectiveL1);
        _confirmExit(0);
        vm.roll(block.number + WITHDRAWAL_DELAY);
    }

    function test_gas_Withdrawal() external {
        EtnaStakingRegistry target = registry;
        address staker = Alice;
        vm.startPrank(staker);
        vm.startSnapshotGas("withdrawal");
        target.withdraw(0, staker);
        _stopSnapshot("withdrawal");
        vm.stopPrank();
        assertEq(token.balanceOf(staker), MIN_STAKE, "stake returned");
        assertTrue(registry.bondAt(0).withdrawn, "withdrawn");
    }
}

/// @title EtnaStakingRegistrySlashGasTest
/// @notice Bob reporting two conflicting generation-0 precommits signed by bond 0's key.
contract EtnaStakingRegistrySlashGasTest is EtnaStakingRegistryGasBase {
    function setUp() public override {
        super.setUp();
        mockInbox.setInitialized(true);
        vm.roll(10);
        assertEq(_register(Alice, CK_A), 0, "bond 0");
        vm.roll(11);
        (voteA, voteB) = _conflictingVotes(CK_A);
    }

    function test_gas_SlashDoubleSign() external {
        _measureSlash("slash_double_sign", 0);
        assertEq(token.balanceOf(Bob), MIN_STAKE * SLASH_BOUNTY_BPS / 10_000, "bounty");
    }
}

/// @title EtnaStakingRegistryNearCapGasTest
/// @notice The registration into the last slot, with 4,095 slots used.
contract EtnaStakingRegistryNearCapGasTest is EtnaStakingRegistryGasBase {
    function setUp() public override {
        super.setUp();
        vm.roll(10);
        _prefill(CAPACITY - 1);
        _prepareRegistration(Alice, PREFILL_KEY + CAPACITY - 1);
    }

    function test_gas_RegistrationIntoLastSlot() external {
        assertEq(_measureRegister("register_at_4095", Alice, MIN_STAKE), CAPACITY - 1, "last slot");
        assertEq(registry.entryCount(), CAPACITY, "full");
    }
}

/// @title EtnaStakingRegistryFullCapGasTest
/// @notice With all 4,096 slots held at the minimum stake and active: an exit request, a top-up,
/// double-sign slashing and forfeiture of the bond in slot 0, and a registration displacing it.
contract EtnaStakingRegistryFullCapGasTest is EtnaStakingRegistryGasBase {
    function setUp() public override {
        super.setUp();
        vm.roll(10);
        _prefill(CAPACITY);
        vm.roll(block.number + ACTIVATION_DELAY);
        mockInbox.setInitialized(true);
        _prepareRegistration(Bob, CK_B);
        _fund(Carol, MIN_STAKE);
        (voteA, voteB) = _conflictingVotes(PREFILL_KEY);
    }

    function test_gas_ExitAtFullCapacity() external {
        _measureExit("exit_at_4096", Carol, 0);
    }

    function test_gas_DisplacingRegistration() external {
        assertEq(_measureRegister("register_displacing", Bob, MIN_STAKE + 1), CAPACITY, "bond");
        assertFalse(registry.bondAt(0).holdsSlot, "bond 0 displaced");
    }

    function test_gas_TopUpAtFullCapacity() external {
        EtnaStakingRegistry target = registry;
        vm.startPrank(Carol);
        vm.startSnapshotGas("top_up_at_4096");
        target.topUp(0, MIN_STAKE);
        _stopSnapshot("top_up_at_4096");
        vm.stopPrank();
        (uint256 slot,) = registry.admissionThreshold();
        assertEq(slot, 1, "slot 0 is no longer the smallest");
    }

    function test_gas_SlashAtFullCapacity() external {
        _measureSlash("slash_at_4096", 0);
    }

    function test_gas_ForfeitAtFullCapacity() external {
        _measureForfeit("forfeit_at_4096", 0);
    }
}

/// @title EtnaStakingRegistryDisplacedGasTest
/// @notice With all 4,096 slots held: bond 0 displaced by bond 4096 and bond 1 exiting, both
/// confirmed and past the withdrawal delay. Withdrawing the slot holder (bond 1) against
/// withdrawing, slashing and forfeiting the displaced bond 0, which touch no slot.
contract EtnaStakingRegistryDisplacedGasTest is EtnaStakingRegistryGasBase {
    function setUp() public override {
        super.setUp();
        vm.roll(10);
        _prefill(CAPACITY);
        mockInbox.setInitialized(true);
        _prepareRegistration(Bob, CK_B);
        vm.prank(Bob);
        registry.register(publicKey, MIN_STAKE + 1, pop);
        assertFalse(registry.bondAt(0).holdsSlot, "bond 0 displaced");
        vm.prank(Carol);
        registry.requestExit(1);
        vm.roll(registry.bondAt(1).entry.exitEffectiveL1);
        _confirmExit(0);
        _confirmExit(1);
        vm.roll(block.number + WITHDRAWAL_DELAY);
        (voteA, voteB) = _conflictingVotes(PREFILL_KEY);
    }

    function test_gas_WithdrawHolder() external {
        _measureWithdraw("withdraw_holder_at_4096", Carol, 1);
    }

    function test_gas_WithdrawDisplaced() external {
        _measureWithdraw("withdraw_displaced", Carol, 0);
    }

    function test_gas_SlashDisplaced() external {
        _measureSlash("slash_displaced", 0);
    }

    function test_gas_ForfeitDisplaced() external {
        _measureForfeit("forfeit_displaced", 0);
    }
}
