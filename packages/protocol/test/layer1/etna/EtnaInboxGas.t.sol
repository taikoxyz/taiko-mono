// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { EtnaInboxSwitchTestBase } from "./EtnaInboxSwitchTestBase.sol";
import { EtnaLandTestBase } from "./EtnaLandTestBase.sol";
import { EtnaTestKeys } from "./EtnaTestKeys.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { DeployEtnaDevnet } from "script/layer1/etna/DeployEtnaDevnet.s.sol";
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
/// @notice The owner's recovery at c = 6 forcing out Bob's bond 1 and blanking queued forced
/// inclusion 2.
contract EtnaInboxRecoverGasTest is EtnaInboxGasBase {
    /// @dev Bob's consensus private key; Alice registered `VALIDATOR_PK` before initialization.
    uint256 private constant _BOB_PK = 0xB0B;

    /// @dev The recovery lists the test passes.
    uint256[] internal exclusions;
    uint256[] internal fiToClear;

    function setUp() public override {
        super.setUp();
        assertEq(_registerValidator(registry, Bob, _BOB_PK), 1, "Bob's bond 1");
        _landHonestly(0, 6);
        vm.roll(block.number + 1);

        exclusions.push(1);
        fiToClear.push(2);
        assertEq(_inbox().owner(), address(this), "this test is the owner");
        _assertQueue(1, LEAN_FORCED_INCLUSIONS);
    }

    function test_gas_RecoverWithOneExclusionAndOneBlank() external {
        EtnaInbox target = EtnaInbox(inboxProxy);
        uint256[] memory exclusionList = exclusions;
        uint256[] memory blanks = fiToClear;
        vm.startSnapshotGas("recover_1_exclusion_1_blank");
        target.recover(0, 6, 0, type(uint256).max, exclusionList, blanks, 0);
        _stopSnapshot("recover_1_exclusion_1_blank");

        assertEq(_inbox().recoveryGeneration(), 1, "generation");
        assertEq(registry.entryAt(1).exitEffectiveL1, block.number, "forced out");
        assertEq(_inbox().getForcedInclusion(2).txHash, keccak256(""), "blanked");
    }
}

/// @title EtnaInboxFullRegistryGasBase
/// @notice An Inbox at c = 6 whose registry holds all 4,096 slots, each bond at the minimum stake
/// in its own slot (bond i in slot i): the full-capacity state of ACCEPTANCE section 7.
abstract contract EtnaInboxFullRegistryGasBase is EtnaInboxGasBase {
    /// @dev The registry's capacity.
    uint256 internal constant CAPACITY = 4096;

    /// @dev The first prefilled consensus key.
    uint256 private constant _PREFILL_KEY = 0x10000;

    /// @dev Registrations per `prefillBatch` call: one call frame's memory must stay within the
    /// transaction gas cap.
    uint256 private constant _PREFILL_CALL = 128;

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

    function setUp() public virtual override {
        super.setUp();
        _landHonestly(0, 6);

        uint256 count = CAPACITY - registry.entryCount();
        taikoToken.mint(Carol, count * MIN_STAKE);
        vm.prank(Carol);
        taikoToken.approve(address(registry), type(uint256).max);
        vm.pauseGasMetering();
        for (uint256 done; done < count; done += _PREFILL_CALL) {
            uint256 batch = count - done < _PREFILL_CALL ? count - done : _PREFILL_CALL;
            this.prefillBatch(_PREFILL_KEY + done, batch);
            vm.roll(block.number + 1);
        }
        vm.resumeGasMetering();
        assertEq(registry.entryCount(), CAPACITY, "every slot used");
        assertEq(registry.bondCount(), CAPACITY, "one bond per slot");
    }
}

/// @title EtnaInboxRecoverFullRegistryGasTest
/// @notice The owner's recovery at c = 6 with all 4,096 registry slots held at the minimum stake,
/// forcing out one bond and then 16, with no blanking: the full-registry exclusion cost of
/// ACCEPTANCE section 7. Each exclusion rewrites its slot's path through the entries tree, so the
/// 16 bonds sit 256 slots apart and share only the top four levels of their paths.
contract EtnaInboxRecoverFullRegistryGasTest is EtnaInboxFullRegistryGasBase {
    /// @dev The longest exclusion list measured; it must stay below `GAS_LIMIT`.
    uint256 private constant _MAX_EXCLUSIONS = 16;

    /// @dev The distance between the excluded bonds, which hold the slots of the same number.
    uint256 private constant _EXCLUSION_STRIDE = CAPACITY / _MAX_EXCLUSIONS;

    /// @dev Bonds 1, 1 + `_EXCLUSION_STRIDE`, ..., strictly increasing.
    uint256[] internal exclusions;

    function setUp() public override {
        super.setUp();
        for (uint256 i; i < _MAX_EXCLUSIONS; ++i) {
            uint256 bondId = 1 + i * _EXCLUSION_STRIDE;
            assertEq(registry.bondAt(bondId).slot, bondId, "bond in its own slot");
            exclusions.push(bondId);
        }
        assertEq(_inbox().owner(), address(this), "this test is the owner");
    }

    function test_gas_RecoverWithOneExclusionAtFullCapacity() external {
        _measureRecover("recover_1_exclusion_at_4096", 1);
    }

    function test_gas_RecoverWithSixteenExclusionsAtFullCapacity() external {
        _measureRecover("recover_16_exclusions_at_4096", _MAX_EXCLUSIONS);
    }

    /// @dev Recovers at c = 6 forcing out the first `_count` bonds of `exclusions`.
    function _measureRecover(string memory _label, uint256 _count) private {
        EtnaInbox target = EtnaInbox(inboxProxy);
        uint256[] memory exclusionList = new uint256[](_count);
        for (uint256 i; i < _count; ++i) {
            exclusionList[i] = exclusions[i];
        }
        uint256[] memory blanks = new uint256[](0);
        vm.startSnapshotGas(_label);
        target.recover(0, 6, 0, type(uint256).max, exclusionList, blanks, 0);
        _stopSnapshot(_label);

        assertEq(_inbox().recoveryGeneration(), 1, "generation");
        uint256 last = exclusions[_count - 1];
        assertEq(registry.entryAt(last).exitEffectiveL1, block.number, "last bond forced out");
        assertEq(registry.entryAt(last + 1).exitEffectiveL1, 2 ** 48 - 1, "neighbor kept");
    }
}

/// @title EtnaRecoveryCapacityGasBase
/// @notice The START-10-18 capacity measurement shared by `EtnaInboxRecoveryCapacityGasTest` below
/// and the mainnet-fork DAO path tests in `EtnaRecoveryDaoPathGas.t.sol`. The recovery is the
/// worst-case ordinary `recover` at c = 6: exclusions that are all real registered bonds holding a
/// slot and without an exit, spread evenly over the 4,096 slots, which maximizes the entries tree
/// nodes they write (every path has 13 levels), one forced inclusion to clear, and ruleset 1
/// installed over an all-zero slot 293 (a zero-to-nonzero write).
/// @dev A transaction fits when it succeeds with EIP-7825's 2^24 gas limit. That limit must exceed
/// the gas the transaction uses: a call forwards at most 63/64 of the caller's remaining gas
/// (EIP-150), so every frame above the Inbox holds back 1/64 of what the frames below it still
/// need. A probe runs the transaction's top-level call with exactly the execution budget a gas
/// limit leaves after the intrinsic cost (21,000 plus 4 gas per calldata token), in a frame that
/// then reverts, so it leaves no state change and no warm account or slot behind; every probe and
/// the final send start cold, as a real transaction does, because `setUp` is a separate
/// transaction. EIP-7623's floor (21,000 plus 10 gas per token) must also fit. Foundry's isolation
/// mode, which runs a call as a real transaction, agrees at the controller-only boundary: 202
/// exclusions succeed with a 2^24 gas limit and 203 do not, as the bisection finds. Bisecting the
/// exact required gas limit takes about 26 probes of up to 2^25 gas each, more than the suite's
/// 80M block gas limit, so it runs only with `FOUNDRY_BLOCK_GAS_LIMIT=2000000000`; the pass/fail
/// checks need two transactions' worth and always run.
abstract contract EtnaRecoveryCapacityGasBase is EtnaInboxFullRegistryGasBase {
    /// @dev EIP-7825's per-transaction gas cap.
    uint256 internal constant TX_GAS_CAP = 2 ** 24;

    /// @dev The gas the test needs left to bisect a gas limit.
    uint256 private constant _BISECTION_GAS = 28 * 2 * TX_GAS_CAP;

    /// @notice Calls `_to` with `_data` and exactly `_gas` as `_from`, then reverts with whether
    /// the call succeeded.
    /// @dev Called by this contract only. The revert undoes the call's state changes and warm
    /// accesses.
    function probeCall(
        address _from,
        address _to,
        bytes calldata _data,
        uint256 _gas
    )
        external
    {
        require(msg.sender == address(this), "self only");
        vm.prank(_from);
        (bool ok,) = _to.call{ gas: _gas }(_data);
        bytes memory outcome = abi.encode(ok);
        assembly ("memory-safe") {
            revert(add(outcome, 32), mload(outcome))
        }
    }

    /// @dev The default recovery capacity F of the deploy scripts.
    function _F() internal returns (uint256) {
        return new DeployEtnaDevnet().DEFAULT_RECOVERY_CAPACITY();
    }

    /// @dev `abi.encode` of the controller actions of the recovery with `_count` exclusions: the
    /// bytes `MainnetDAOController.execute` takes.
    function _recoveryActionData(uint256 _count) internal view returns (bytes memory) {
        uint256[] memory exclusionList = new uint256[](_count);
        for (uint256 i; i < _count; ++i) {
            exclusionList[i] = i * CAPACITY / _count;
            if (i != 0) require(exclusionList[i] > exclusionList[i - 1], "strictly increasing");
        }
        uint256[] memory blanks = new uint256[](1);
        blanks[0] = 2;
        Controller.Action[] memory actions = new Controller.Action[](1);
        actions[0] = Controller.Action({
            target: inboxProxy,
            value: 0,
            data: abi.encodeCall(
                EtnaInbox.recover, (0, 6, 0, type(uint256).max, exclusionList, blanks, 1)
            )
        });
        return abi.encode(actions);
    }

    /// @dev Whether the transaction from `_from` calling `_to` with `_data` succeeds with a
    /// gas limit of `TX_GAS_CAP - _margin`.
    function _fitsWithMargin(
        address _from,
        address _to,
        bytes memory _data,
        uint256 _margin
    )
        internal
        returns (bool)
    {
        uint256 tokens = _tokens(_data);
        if (21_000 + 10 * tokens + _margin > TX_GAS_CAP) return false;
        return _succeeds(_from, _to, _data, TX_GAS_CAP - _margin - 21_000 - 4 * tokens);
    }

    /// @dev Logs the smallest gas limit with which the transaction succeeds and its distance from
    /// 2^24, when the test has the gas to bisect it.
    function _logRequiredGasLimit(
        string memory _label,
        address _from,
        address _to,
        bytes memory _data
    )
        internal
    {
        if (gasleft() < _BISECTION_GAS) {
            emit log(string.concat(_label, ": exact gas limit needs FOUNDRY_BLOCK_GAS_LIMIT"));
            return;
        }
        uint256 low;
        uint256 high = 2 * TX_GAS_CAP;
        require(_succeeds(_from, _to, _data, high), "fails with 2^25 gas");
        while (high - low > 1) {
            uint256 mid = (low + high) / 2;
            if (_succeeds(_from, _to, _data, mid)) high = mid;
            else low = mid;
        }
        uint256 gasLimit = _withIntrinsic(_data, high);
        emit log_named_uint(string.concat(_label, "_gas_limit"), gasLimit);
        if (gasLimit <= TX_GAS_CAP) {
            emit log_named_uint(string.concat(_label, "_headroom"), TX_GAS_CAP - gasLimit);
        } else {
            emit log_named_uint(string.concat(_label, "_excess"), gasLimit - TX_GAS_CAP);
        }
    }

    /// @dev Sends the transaction with a 2^24 gas limit, requires it to succeed and logs its gas
    /// before refunds. The measured execution includes the 2,600 gas cold access to `_to` that a
    /// real transaction prepays.
    function _send(
        string memory _label,
        address _from,
        address _to,
        bytes memory _data
    )
        internal
    {
        uint256 budget = TX_GAS_CAP - 21_000 - 4 * _tokens(_data);
        vm.prank(_from);
        uint256 gasBefore = gasleft();
        (bool ok,) = _to.call{ gas: budget }(_data);
        uint256 execution = gasBefore - gasleft();
        require(ok, "the transaction reverted");
        emit log_named_uint(string.concat(_label, "_tx_gas"), _withIntrinsic(_data, execution));
    }

    /// @dev Checks the recovery with `_count` exclusions took effect.
    function _assertRecovered(uint256 _count) internal view {
        assertEq(_inbox().recoveryGeneration(), 1, "recovered");
        uint256 last = (_count - 1) * CAPACITY / _count;
        assertEq(registry.entryAt(last).exitEffectiveL1, block.number, "last bond forced out");
        assertEq(_inbox().getForcedInclusion(2).txHash, keccak256(""), "blanked");
    }

    /// @dev Runs one probe of `probeCall`.
    function _succeeds(
        address _from,
        address _to,
        bytes memory _data,
        uint256 _gas
    )
        private
        returns (bool ok_)
    {
        try this.probeCall(_from, _to, _data, _gas) {
            revert("probe returned");
        } catch (bytes memory outcome) {
            require(outcome.length == 32, "probe failed");
            ok_ = abi.decode(outcome, (bool));
        }
    }

    /// @dev The gas a transaction with calldata `_data` and `_execution` gas of execution is
    /// charged before refunds: the intrinsic cost plus execution, or EIP-7623's floor.
    function _withIntrinsic(
        bytes memory _data,
        uint256 _execution
    )
        private
        pure
        returns (uint256)
    {
        uint256 tokens = _tokens(_data);
        uint256 standard = 21_000 + 4 * tokens + _execution;
        uint256 floor = 21_000 + 10 * tokens;
        return standard > floor ? standard : floor;
    }

    /// @dev EIP-7623 calldata tokens: one per zero byte, four per nonzero byte.
    function _tokens(bytes memory _data) private pure returns (uint256 tokens_) {
        for (uint256 i; i < _data.length; ++i) {
            tokens_ += _data[i] == 0 ? 1 : 4;
        }
    }
}

/// @title EtnaInboxRecoveryCapacityGasTest
/// @notice The capacity recovery sent straight to a `MainnetDAOController` that owns the Inbox: a
/// fast regression without a fork. It is not the binding START-10-18 measurement. The DAO reaches
/// the controller only through its Aragon plugins, whose extra frames, storage and calldata
/// `EtnaRecoveryDaoPathGas.t.sol` measures on a mainnet fork, where F is the largest count that
/// fits and F + 1 does not. This test requires the controller-only transaction at F to fit 2^24
/// less the extra gas the costliest DAO path measured there, so a change to the Inbox or registry
/// that would push the DAO path past the cap fails here too, to within the small part of that
/// extra that scales with the call depth.
contract EtnaInboxRecoveryCapacityGasTest is EtnaRecoveryCapacityGasBase {
    /// @dev The gas limit the Emergency Multisig's `execute` of the recovery with F = 131
    /// exclusions needs (16,694,489) less what the controller-only transaction needs (11,596,041),
    /// measured at mainnet block 26,460,000.
    uint256 private constant _DAO_PATH_EXTRA = 5_098_448;

    /// @dev The DAO executor that owns the Inbox.
    MainnetDAOController internal controller;

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
        _assertQueue(1, LEAN_FORCED_INCLUSIONS);
    }

    function test_gas_RecoverAtRecoveryCapacityThroughTheController() external {
        uint256 count = _F();
        bytes memory txData =
            abi.encodeCall(MainnetDAOController.execute, (_recoveryActionData(count)));
        address target = address(controller);
        _logRequiredGasLimit("controller_at_capacity", address(this), target, txData);
        assertTrue(
            _fitsWithMargin(address(this), target, txData, _DAO_PATH_EXTRA),
            "fits 2^24 with the DAO path's extra gas"
        );
        _send("controller_at_capacity", address(this), target, txData);
        _assertRecovered(count);
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
