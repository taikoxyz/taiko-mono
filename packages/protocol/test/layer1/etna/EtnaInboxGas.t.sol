// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { EtnaInboxSwitchTestBase } from "./EtnaInboxSwitchTestBase.sol";
import { EtnaInboxTestBase } from "./EtnaInboxTestBase.sol";
import { EtnaLandTestBase } from "./EtnaLandTestBase.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { IEtnaInbox } from "src/layer1/etna/iface/IEtnaInbox.sol";
import { EtnaInbox } from "src/layer1/etna/impl/EtnaInbox.sol";
import { MainnetDAOController } from "src/layer1/mainnet/MainnetDAOController.sol";
import { EssentialContract } from "src/shared/common/EssentialContract.sol";
import { Controller } from "src/shared/governance/Controller.sol";

/// @title EtnaInboxGasBase
/// @notice Gas snapshots of the Inbox's entry points on the `EtnaLandTestBase` chain.
/// @dev `setUp` and the measured test are separate transactions, so every contract's storage
/// starts cold in the test. Each test loads its target, caller and arguments into memory before
/// `vm.startSnapshotGas`, so the measured window holds only the call. Every landing suite lands
/// (0, 6] in `setUp` first, so the measured landing starts from non-zero checkpoint slots. Landings
/// carry two blobs and use the mock verifier, bound in `setUp` to the measured landing's honest
/// statement.
abstract contract EtnaInboxGasBase is EtnaLandTestBase {
    /// @dev Every measured call must stay below this, except those that store 128 fallback keys;
    /// `EtnaFallbackRecoveryGasBase` checks the DAO transaction that does so against the
    /// transaction gas cap.
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
/// @notice A 300-block landing with 299 leaves, from the checkpoint at 6 to 306.
contract EtnaInboxLand300BlocksGasTest is EtnaInboxGasBase {
    function setUp() public override {
        super.setUp();
        _landHonestly(0, 6);
        _bindStatement(6, 306);
    }

    function test_gas_Land300Blocks() external {
        _measureLand("land_300_blocks_299_leaves", 6, 306);
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
/// @notice A 3,600-block landing with 3,599 leaves, from the checkpoint at 6 to 3,606, on an
/// implementation with `maxBatchBlocks = 3600`.
contract EtnaInboxLand3600BlocksGasTest is EtnaInboxGasBase {
    function setUp() public override {
        super.setUp();
        _upgradeWithMaxBatchBlocks(3600);
        _landHonestly(0, 6);
        _bindStatement(6, 3606);
    }

    function test_gas_Land3600Blocks() external {
        _measureLand("land_3600_blocks_3599_leaves", 6, 3606);
    }
}

/// @title EtnaInboxRecoverGasTest
/// @notice The owner's recovery at c = 6 blanking queued forced inclusion 2.
contract EtnaInboxRecoverGasTest is EtnaInboxGasBase {
    /// @dev The forced inclusions the recovery blanks.
    uint256[] internal fiToClear;

    function setUp() public override {
        super.setUp();
        _landHonestly(0, 6);
        vm.roll(block.number + 1);

        fiToClear.push(2);
        assertEq(_inbox().owner(), address(this), "this test is the owner");
        _assertQueue(1, LEAN_FORCED_INCLUSIONS);
    }

    function test_gas_RecoverWithOneBlank() external {
        EtnaInbox target = EtnaInbox(inboxProxy);
        uint256[] memory blanks = fiToClear;
        vm.startSnapshotGas("recover_1_blank");
        target.recover(0, 6, 0, type(uint256).max, blanks, 0);
        _stopSnapshot("recover_1_blank");

        assertEq(_inbox().recoveryGeneration(), 1, "generation");
        assertEq(_inbox().getForcedInclusion(2).txHash, keccak256(""), "blanked");
    }
}

/// @title EtnaFallbackRecoveryGasBase
/// @notice The DAO's recovery that first replaces the fallback key set, shared by
/// `EtnaInboxFallbackRecoveryGasTest` below and the mainnet-fork DAO path tests in
/// `EtnaRecoveryDaoPathGas.t.sol`: one call of `MainnetDAOController.execute` whose first action
/// sets 128 fallback keys over the [K1] that `init` stored, the most a list holds, and whose second
/// recovers at c = 6, blanking either none or all of the `FI_TO_CLEAR_MEASURED` forced inclusions
/// queued, the longest list measured. The complete transaction, with its calldata, call
/// forwarding, key writes, blanking, origin write and events, must fit the per-transaction gas
/// cap with either list.
/// @dev A transaction fits when it succeeds with EIP-7825's 2^24 gas limit. The measured call gets
/// exactly the execution gas such a limit leaves after the intrinsic cost (21,000 plus 4 gas per
/// calldata token), so it also fails if a frame above the Inbox has to hold back too much of what
/// it forwards (EIP-150's 63/64 rule). Its gas before refunds is that intrinsic cost plus the
/// gas of the call's frame, or EIP-7623's floor of 21,000 plus 10 gas per token if that is
/// higher. The queue and every calldata that reads the Inbox are built in `setUp`, so the measured
/// call, a separate transaction, finds every account and slot cold.
abstract contract EtnaFallbackRecoveryGasBase is EtnaInboxGasBase {
    /// @dev EIP-7825's per-transaction gas cap.
    uint256 internal constant TX_GAS_CAP = 2 ** 24;

    /// @dev The longest blank list measured, and the number of forced inclusions queued.
    uint256 internal constant FI_TO_CLEAR_MEASURED = 16;

    function setUp() public virtual override {
        super.setUp();
        _landHonestly(0, 6);
        (uint48 head, uint48 tail) = _inbox().getForcedInclusionState();
        _saveForcedInclusions(head + FI_TO_CLEAR_MEASURED - tail);
        _assertQueue(head, head + FI_TO_CLEAR_MEASURED);
    }

    /// @dev The controller actions of the recovery that blanks the first `_blanks` queued forced
    /// inclusions: `setFallbackKeys` with the keys of private keys 1 to 128, then `recover` at the
    /// current generation, checkpoint and nonce, valid until 2^256 - 1, with ruleset 0. It reads
    /// the Inbox, so only `setUp` calls it.
    function _recoveryActions(uint256 _blanks)
        internal
        returns (Controller.Action[] memory actions_)
    {
        EtnaInbox inbox = _inbox();
        (uint48 head,) = inbox.getForcedInclusionState();
        uint256[] memory fiToClear = new uint256[](_blanks);
        for (uint256 i; i < _blanks; ++i) {
            fiToClear[i] = head + i;
        }
        actions_ = new Controller.Action[](2);
        actions_[0] = Controller.Action({
            target: inboxProxy,
            value: 0,
            data: abi.encodeCall(EtnaInbox.setFallbackKeys, (_sortedKeys(128)))
        });
        actions_[1] = Controller.Action({
            target: inboxProxy,
            value: 0,
            data: abi.encodeCall(
                EtnaInbox.recover,
                (
                    inbox.recoveryGeneration(),
                    inbox.lastCheckpoint().height,
                    inbox.recoveryNonce(),
                    type(uint256).max,
                    fiToClear,
                    0
                )
            )
        });
    }

    /// @dev The execution gas a 2^24 gas limit leaves a transaction with calldata `_data`.
    function _executionBudget(bytes memory _data) internal pure returns (uint256) {
        uint256 tokens = _tokens(_data);
        require(21_000 + 10 * tokens <= TX_GAS_CAP, "calldata floor above 2^24");
        return TX_GAS_CAP - 21_000 - 4 * tokens;
    }

    /// @dev Requires the transaction with calldata `_data`, whose call used `_execution` gas in its
    /// frame, to fit 2^24 before refunds, and logs its gas and the headroom as `_label`.
    function _assertFitsTxGasCap(
        string memory _label,
        bytes memory _data,
        uint256 _execution
    )
        internal
    {
        uint256 tokens = _tokens(_data);
        uint256 standard = 21_000 + 4 * tokens + _execution;
        uint256 floor = 21_000 + 10 * tokens;
        uint256 txGas = standard > floor ? standard : floor;
        emit log_named_uint(string.concat(_label, "_tx_gas"), txGas);
        assertLe(txGas, TX_GAS_CAP, _label);
        emit log_named_uint(string.concat(_label, "_headroom"), TX_GAS_CAP - txGas);
    }

    /// @dev Checks the recovery that blanked the first `_blanks` queued forced inclusions: the new
    /// generation, the 128 keys stored, the new origin recording their hash, and exactly the
    /// listed queue entries blanked.
    function _assertRecovered(uint256 _blanks) internal {
        bytes32 keysHash = _fallbackKeysHash(_sortedKeys(128));
        EtnaInbox inbox = _inbox();
        assertEq(inbox.recoveryGeneration(), 1, "recovered");
        assertEq(inbox.fallbackKeysHash(), keysHash, "the 128 keys");
        assertEq(inbox.origins(1).fallbackKeysHash, keysHash, "the new origin records them");
        (uint48 head, uint48 tail) = inbox.getForcedInclusionState();
        assertEq(tail - head, FI_TO_CLEAR_MEASURED, "the queue kept");
        for (uint48 i = head; i < tail; ++i) {
            assertEq(
                inbox.getForcedInclusion(i).txHash == keccak256(""),
                i < head + _blanks,
                "only the listed entries blanked"
            );
        }
    }

    /// @dev EIP-7623 calldata tokens: one per zero byte, four per nonzero byte.
    function _tokens(bytes memory _data) private pure returns (uint256 tokens_) {
        for (uint256 i; i < _data.length; ++i) {
            tokens_ += _data[i] == 0 ? 1 : 4;
        }
    }
}

/// @title EtnaInboxFallbackRecoveryGasTest
/// @notice The recovery of `EtnaFallbackRecoveryGasBase` sent straight to a `MainnetDAOController`
/// that owns the Inbox, with no blank and with `FI_TO_CLEAR_MEASURED`: a fast regression without a
/// fork. The DAO reaches the controller only through its Aragon plugins, whose extra frames,
/// storage and calldata `EtnaRecoveryDaoPathGas.t.sol` measures on a mainnet fork. A snapshot is
/// the gas of the controller's frame, as `vm.snapshotGasLastCall` records it; the logged
/// transaction gas adds the intrinsic cost.
contract EtnaInboxFallbackRecoveryGasTest is EtnaFallbackRecoveryGasBase {
    /// @dev The DAO executor that owns the Inbox.
    MainnetDAOController internal controller;

    /// @dev The measured calls of the controller's `execute`, built in `setUp`: the recovery with
    /// no blank and the one with `FI_TO_CLEAR_MEASURED` blanks.
    bytes internal noBlankData;
    bytes internal sixteenBlanksData;

    function setUp() public override {
        super.setUp();
        controller = MainnetDAOController(
            payable(address(
                    new ERC1967Proxy(
                        address(new MainnetDAOController()),
                        abi.encodeCall(MainnetDAOController.init, (address(this)))
                    )
                ))
        );
        EssentialContract(inboxProxy).transferOwnership(address(controller));
        controller.acceptOwnershipOf(inboxProxy);
        assertEq(_inbox().owner(), address(controller), "the controller owns the Inbox");

        noBlankData = _executeCall(0);
        sixteenBlanksData = _executeCall(FI_TO_CLEAR_MEASURED);
    }

    function test_gas_Set128FallbackKeysThenRecoverThroughTheControllerWithNoBlank() external {
        _measureRecovery("controller_set_128_keys_recover_no_blank", noBlankData, 0);
    }

    function test_gas_Set128FallbackKeysThenRecoverThroughTheControllerWithSixteenBlanks()
        external
    {
        _measureRecovery(
            "controller_set_128_keys_recover_16_blanks", sixteenBlanksData, FI_TO_CLEAR_MEASURED
        );
    }

    /// @dev The controller call of the recovery that blanks `_blanks` forced inclusions.
    function _executeCall(uint256 _blanks) private returns (bytes memory) {
        return abi.encodeCall(MainnetDAOController.execute, (abi.encode(_recoveryActions(_blanks))));
    }

    /// @dev Measures, as `_label`, the DAO's controller call `_data` with the execution gas of a
    /// 2^24 gas limit, which must succeed and fit 2^24, and checks the recovery blanked `_blanks`.
    function _measureRecovery(
        string memory _label,
        bytes memory _data,
        uint256 _blanks
    )
        private
    {
        address target = address(controller);
        uint256 budget = _executionBudget(_data);
        (bool ok,) = target.call{ gas: budget }(_data);
        uint256 gasUsed = vm.snapshotGasLastCall(_label);

        assertTrue(ok, "succeeds with a 2^24 gas limit");
        emit log_named_uint(_label, gasUsed);
        _assertFitsTxGasCap(_label, _data, gasUsed);
        _assertRecovered(_blanks);
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

/// @title EtnaInboxLandFromStartGasTest
/// @notice The first landing (0, 6] on a new network, where c is the start S = 0; the queue head
/// stays 0, as in `EtnaInboxLandFromUnzenStartGasTest`.
contract EtnaInboxLandFromStartGasTest is EtnaInboxGasBase {
    function setUp() public override {
        super.setUp();
        IEtnaInbox.LandInput memory input = _input(0, 6);
        landVerifier.setExpectedStatementHash(
            _statement(input, _inbox().landings(0), _cutHash(input, _leaves(0, 6)))
        );
    }

    /// @dev The committed chain with queue head 0 throughout.
    function _cut(uint256 _x) internal pure override returns (bytes32, bytes32, uint256) {
        return (bytes32(100 + _x), _x == 0 ? bytes32(0) : bytes32(200 + _x), 0);
    }

    function test_gas_LandFromStart() external {
        EtnaInbox target = EtnaInbox(inboxProxy);
        IEtnaInbox.LandInput memory input = _input(0, 6);
        bytes32[] memory leaves = _leaves(0, 6);
        bytes memory proof = PROOF;
        vm.blobhashes(blobHashes);
        vm.startPrank(Bob);
        vm.startSnapshotGas("land_6_blocks_from_start");
        target.land(input, leaves, proof);
        _stopSnapshot("land_6_blocks_from_start");
        vm.stopPrank();
        _assertCheckpoint(6, bytes32(uint256(106)));
    }
}

/// @title EtnaInboxLandFromUnzenStartGasTest
/// @notice The first landing (S, S + 6] on a switching network. `setOrigin` checked the Unzen tip,
/// so the landing reads no Unzen state (vector 8a.e) and costs what a landing from S = 0 does.
contract EtnaInboxLandFromUnzenStartGasTest is EtnaInboxSwitchTestBase {
    function setUp() public override {
        super.setUp();
        _writeStart();
        IEtnaInbox.LandInput memory input = _input(S, S + 6);
        landVerifier.setExpectedStatementHash(
            _statement(input, _inbox().landings(S), _cutHash(input, _leaves(S, S + 6)))
        );
    }

    function test_gas_LandFromUnzenStart() external {
        EtnaInbox target = EtnaInbox(inboxProxy);
        IEtnaInbox.LandInput memory input = _input(S, S + 6);
        bytes32[] memory leaves = _leaves(S, S + 6);
        bytes memory proof = PROOF;
        vm.blobhashes(blobHashes);
        vm.startPrank(Bob);
        vm.startSnapshotGas("land_6_blocks_from_unzen_start");
        target.land(input, leaves, proof);
        emit log_named_uint("land_6_blocks_from_unzen_start", vm.stopSnapshotGas());
        vm.stopPrank();
        _assertCheckpoint(S + 6, bytes32(100 + S + 6));
    }
}

/// @title EtnaInboxSetOriginGasTest
/// @notice The permissionless start write on a switching network, with the Unzen proposals
/// closed and finalized up to S and its checkpoint forwarded (START-10-5a, LAND-6.1-8a).
contract EtnaInboxSetOriginGasTest is EtnaInboxSwitchTestBase {
    function setUp() public override {
        super.setUp();
        _finalizeUnzen();
        vm.warp(FORK_TIME);
    }

    function test_gas_SetOrigin() external {
        EtnaInbox target = EtnaInbox(inboxProxy);
        uint48 s = uint48(S);
        vm.startPrank(Carol);
        vm.startSnapshotGas("set_origin");
        target.setOrigin(s);
        emit log_named_uint("set_origin", vm.stopSnapshotGas());
        vm.stopPrank();
        _assertCheckpoint(S, _startHash());
    }
}

/// @title EtnaInboxScheduleRulesGasTest
/// @notice The owner scheduling ruleset 1 from slot 293's initial zero.
contract EtnaInboxScheduleRulesGasTest is EtnaInboxGasBase {
    function test_gas_ScheduleRules() external {
        EtnaInbox target = EtnaInbox(inboxProxy);
        uint48 time = uint48(block.timestamp + MAX_ANCHOR_AGE);
        vm.startSnapshotGas("schedule_rules");
        target.scheduleRules(0, 1, time);
        _stopSnapshot("schedule_rules");
        assertEq(_inbox().rulesSchedule().nextRules, 1, "scheduled");
    }
}

/// @title EtnaInboxFallbackKeysGasTest
/// @notice The owner replacing the fallback key list [K1] that `init` stored, with the single key
/// [K2] and with the 128 keys of private keys 1 to 128, the most a list holds, which writes 127
/// entries from zero. A snapshot is the gas of the Inbox's frame, as `vm.snapshotGasLastCall`
/// records it.
contract EtnaInboxFallbackKeysGasTest is EtnaInboxGasBase {
    /// @dev The measured calls, built in `setUp`, and the hashes of their lists.
    bytes internal oneKeyData;
    bytes32 internal oneKeyHash;
    bytes internal keys128Data;
    bytes32 internal keys128Hash;

    function setUp() public override {
        super.setUp();
        uint256[] memory pks = new uint256[](1);
        pks[0] = 2;
        IEtnaInbox.FallbackKey[] memory keys = _keys(pks);
        oneKeyData = abi.encodeCall(EtnaInbox.setFallbackKeys, (keys));
        oneKeyHash = _fallbackKeysHash(keys);

        keys = _sortedKeys(128);
        keys128Data = abi.encodeCall(EtnaInbox.setFallbackKeys, (keys));
        keys128Hash = _fallbackKeysHash(keys);
        assertEq(_inbox().fallbackKeysHash(), DEFAULT_FALLBACK_KEYS_HASH, "init stored [K1]");
    }

    function test_gas_SetFallbackKeys1() external {
        uint256 gasUsed = _measureSetFallbackKeys("set_fallback_keys_1", oneKeyData, oneKeyHash);
        assertLt(gasUsed, GAS_LIMIT, "set_fallback_keys_1");
    }

    function test_gas_SetFallbackKeys128() external {
        _measureSetFallbackKeys("set_fallback_keys_128", keys128Data, keys128Hash);
    }

    /// @dev Measures, as `_label`, the owner's call `_data`, which must store the list of hash
    /// `_hash`.
    function _measureSetFallbackKeys(
        string memory _label,
        bytes memory _data,
        bytes32 _hash
    )
        private
        returns (uint256 gasUsed_)
    {
        address target = inboxProxy;
        (bool ok,) = target.call(_data);
        gasUsed_ = vm.snapshotGasLastCall(_label);

        assertTrue(ok, _label);
        emit log_named_uint(_label, gasUsed_);
        assertEq(_inbox().fallbackKeysHash(), _hash, "the new list");
    }
}

/// @title EtnaInboxSetMinTotalStakeGasTest
/// @notice The owner doubling the `minTotalStake` that `init` stored. A snapshot is the gas of the
/// Inbox's frame, as `vm.snapshotGasLastCall` records it.
contract EtnaInboxSetMinTotalStakeGasTest is EtnaInboxGasBase {
    function test_gas_SetMinTotalStake() external {
        EtnaInbox target = EtnaInbox(inboxProxy);
        uint256 value = 2 * MIN_TOTAL_STAKE;
        target.setMinTotalStake(value);
        uint256 gasUsed = vm.snapshotGasLastCall("set_min_total_stake");

        emit log_named_uint("set_min_total_stake", gasUsed);
        assertLt(gasUsed, GAS_LIMIT, "set_min_total_stake");
        assertEq(_inbox().minTotalStake(), value, "the new threshold");
    }
}

/// @title EtnaInboxInit128KeysGasTest
/// @notice The owner's transaction that upgrades a new network's Inbox proxy from the bootstrap
/// implementation to `EtnaInbox` and calls `init` with the 128 keys of private keys 1 to 128, the
/// longest fallback key list; `init` also performs the start write and saves the block-0
/// SignalService checkpoint. A snapshot is the gas of the proxy's frame, as
/// `vm.snapshotGasLastCall` records it.
contract EtnaInboxInit128KeysGasTest is EtnaInboxTestBase {
    /// @dev The measured call, built in `setUp`, and the hash of its key list.
    bytes internal initData;
    bytes32 internal keysHash;

    function setUp() public override {
        super.setUp();
        IEtnaInbox.InitParams memory params = _defaultInitParams();
        params.fallbackKeys = _sortedKeys(128);
        keysHash = _fallbackKeysHash(params.fallbackKeys);
        initData = abi.encodeCall(
            EtnaInbox.upgradeToAndCall,
            (address(inboxImpl), abi.encodeCall(EtnaInbox.init, (params)))
        );
    }

    /// @dev The proxy stays on the bootstrap implementation until the measured call.
    function _initializeOnSetUp() internal pure override returns (bool) {
        return false;
    }

    function test_gas_Init128Keys() external {
        address target = inboxProxy;
        bytes memory data = initData;
        (bool ok,) = target.call(data);
        uint256 gasUsed = vm.snapshotGasLastCall("init_128_keys");

        assertTrue(ok, "init_128_keys");
        emit log_named_uint("init_128_keys", gasUsed);
        EtnaInbox inbox = EtnaInbox(inboxProxy);
        assertEq(inbox.fallbackKeysHash(), keysHash, "the 128 keys");
        assertEq(inbox.origins(0).fallbackKeysHash, keysHash, "the start write records them");
    }
}

contract EtnaRecoveryNonceGasTest is EtnaInboxTestBase {
    function test_gas_InvalidateRecoveryNonce() external {
        EtnaInbox target = EtnaInbox(inboxProxy);
        vm.startSnapshotGas("invalidate_recovery_nonce");
        target.invalidateRecoveryNonce(0);
        uint256 gasUsed = vm.stopSnapshotGas();
        emit log_named_uint("invalidate_recovery_nonce", gasUsed);
        assertLt(gasUsed, 3_000_000);
        assertEq(target.recoveryNonce(), 1);
    }
}
