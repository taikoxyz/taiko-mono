// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { EtnaStakingTestBase } from "./EtnaStakingTestBase.sol";
import { EtnaVoteKeys } from "./EtnaVoteKeys.sol";
import { IEtnaStaking } from "src/layer2/etna/iface/IEtnaStaking.sol";
import { LibCometVote } from "src/layer2/etna/libs/LibCometVote.sol";
import { EtnaTestKeys } from "test/shared/etna/EtnaTestKeys.sol";

/// @title EtnaStakingOnBlockStartWorstCaseGasTest
/// @notice A gas snapshot of the block-start call in its worst case, with every one of the 128
/// seats occupied, which must stay below the 30,000,000 gas of the call's frame. No call has run
/// since the 128 registrations, so the measured call takes every one of the 256 snapshot record
/// words, the height and the total from zero to nonzero.
/// @dev `setUp` registers the bonds and the measured test is a separate transaction. The measured
/// call therefore finds the staking storage cold and pays for each write against the storage
/// `setUp` committed, as a block's call does. The test reads no staking storage before the
/// measured call, since a read would warm it.
contract EtnaStakingOnBlockStartWorstCaseGasTest is EtnaStakingTestBase {
    /// @dev The gas the execution layer gives the call's frame.
    uint256 private constant _FRAME_GAS = 30_000_000;

    /// @dev The EIP-170 contract size limit in bytes.
    uint256 private constant _EIP170_LIMIT = 24_576;

    /// @dev The EIP-1967 implementation slot.
    bytes32 private constant _IMPLEMENTATION_SLOT =
        bytes32(uint256(keccak256("eip1967.proxy.implementation")) - 1);

    function setUp() public override {
        super.setUp();
        for (uint256 pk = 1; pk <= N_MAX; ++pk) {
            _register(pk, Bob, 2 * MIN_STAKE);
        }
        // Checked here, not in the test: reading the words there would warm them.
        for (uint256 offset; offset < 258; ++offset) {
            assertEq(_word(offset), 0, "no snapshot before the call");
        }
    }

    function test_gas_onBlockStart_WorstCaseFitsTheFrame() external {
        bytes memory data = abi.encodeCall(IEtnaStaking.onBlockStart, (uint48(1)));
        address target = address(staking);
        vm.roll(block.number + 1);
        vm.prank(SYSTEM_CALLER);
        (bool ok,) = target.call{ gas: _FRAME_GAS }(data);
        uint256 gasUsed = vm.snapshotGasLastCall("on_block_start_worst_case");

        assertTrue(ok, "the call succeeds within the frame");
        emit log_named_uint("on_block_start_worst_case", gasUsed);
        assertLt(gasUsed, _FRAME_GAS, "below the frame gas");
        for (uint8 seat; seat < N_MAX; ++seat) {
            _assertBondInSeat(seat, true, seat, "seat kept");
            assertGt(_word(2 + 2 * uint256(seat)), 0, "record word 1 written");
            assertGt(_word(3 + 2 * uint256(seat)), 0, "record word 2 written");
        }
        assertEq(_word(1), N_MAX * 2 * MIN_STAKE, "the total of every stake");
        assertEq(_word(0), block.number, "the height");
    }

    /// @dev The implementation stays deployable under EIP-170.
    function test_size_EtnaStakingBelowEip170() external {
        address impl = address(uint160(uint256(vm.load(address(staking), _IMPLEMENTATION_SLOT))));
        assertGt(impl.code.length, 0, "the proxy's implementation");
        emit log_named_uint("EtnaStaking runtime bytes", impl.code.length);
        assertLe(impl.code.length, _EIP170_LIMIT, "EIP-170");
    }

    /// @dev Returns the word at T + `_offset`.
    function _word(uint256 _offset) private view returns (uint256) {
        return uint256(vm.load(address(staking), bytes32(uint256(T) + _offset)));
    }
}

/// @dev The snapshot groups of the six staking transactions, one file each.
string constant REGISTER_GAS = "EtnaStakingRegisterGasTest";
string constant TOP_UP_GAS = "EtnaStakingTopUpGasTest";
string constant REQUEST_EXIT_GAS = "EtnaStakingRequestExitGasTest";
string constant WITHDRAW_GAS = "EtnaStakingWithdrawGasTest";
string constant SLASH_GAS = "EtnaStakingSlashGasTest";
string constant FORFEIT_GAS = "EtnaStakingForfeitGasTest";

/// @title EtnaStakingOperationGasBase
/// @notice Gas snapshots of the six staking transactions with cold storage and every one of the
/// 128 seats occupied, seats 0 to 127 by bonds 0 to 127 of m each, all owned by Bob. Each
/// operation is measured on the seats as setUp leaves them and again after another operation
/// changed them.
/// @dev `setUp` seats the bonds, makes every earlier operation and builds any calldata that reads
/// the staking contract, such as a registration's proof of possession. The measured test is a
/// separate transaction that touches no contract before the measured call, so that call finds
/// the implementation, the token and every slot cold and pays for each write against the storage
/// setUp committed. Cooling would not do instead: the `cool` cheatcode marks an account's storage
/// cold but not the account. A snapshot is the gas of the call's frame, before refunds, as
/// `vm.snapshotGasLastCall` records it; it leaves out the transaction's intrinsic and calldata
/// gas. Token transfers are those of the stand-in ERC-20.
abstract contract EtnaStakingOperationGasBase is EtnaStakingTestBase {
    /// @dev The highest seat.
    uint8 internal constant LAST_SEAT = 127;

    /// @dev The consensus keys of two newcomers; bond i has key i + 1.
    uint256 internal constant NEW_KEY = 129;
    uint256 internal constant NEXT_KEY = 130;

    /// @dev A withdrawal recipient that holds no token.
    address internal constant RECIPIENT = address(0xBEEF);

    /// @dev The incident id the DAO publishes.
    bytes32 internal constant INCIDENT = keccak256("incident");

    /// @dev The measured registration's calldata, built in setUp.
    bytes internal registerData;

    /// @dev Seats bonds 0 to 127 of m each.
    function _seatEveryBond() internal {
        for (uint256 pk = 1; pk <= N_MAX; ++pk) {
            _register(pk, Bob, MIN_STAKE);
        }
    }

    /// @dev Mints `_amount` to `_staker`, who approves exactly that for `staking`, so the
    /// measured transfer also spends the allowance.
    function _fundExact(address _staker, uint256 _amount) internal {
        token.mint(_staker, _amount);
        vm.prank(_staker);
        token.approve(address(staking), _amount);
    }

    /// @dev The call by which `_owner` registers the consensus key of `_pk` with m. It reads the
    /// staking contract, so only setUp builds it.
    function _registerCall(uint256 _pk, address _owner) internal returns (bytes memory) {
        bytes memory pop = EtnaVoteKeys.popSig(_pk, staking, _owner);
        return abi.encodeCall(IEtnaStaking.register, (EtnaTestKeys.publicKey(_pk), MIN_STAKE, pop));
    }

    /// @dev Two generation-0 precommits for different blocks at the same height and round,
    /// signed by `_pk` under the chain id of the base's deployment.
    function _conflictingVotes(uint256 _pk)
        internal
        pure
        returns (IEtnaStaking.Vote memory a_, IEtnaStaking.Vote memory b_)
    {
        bytes memory chainId =
            LibCometVote.chainId(LibCometVote.chainDomain(L1_CHAIN_ID, L2_CHAIN_ID, INBOX, 0));
        a_ = EtnaVoteKeys.signVote(_pk, _precommit(keccak256("block a")), chainId);
        b_ = EtnaVoteKeys.signVote(_pk, _precommit(keccak256("block b")), chainId);
    }

    /// @dev Bob reports the double sign of bond `_bondId`.
    function _slash(uint256 _bondId) internal {
        (IEtnaStaking.Vote memory a, IEtnaStaking.Vote memory b) = _conflictingVotes(_bondId + 1);
        vm.prank(Bob);
        staking.slashDoubleSign(_bondId, a, b);
    }

    /// @dev The staking owner forfeits bond `_bondId`.
    function _forfeit(uint256 _bondId) internal {
        vm.prank(STAKING_OWNER);
        staking.forfeit(_bondId, INCIDENT, block.timestamp);
    }

    /// @dev Measures, as `_name` in `_group`, the call `_data` from `_caller` against cold
    /// storage, which must succeed.
    function _measure(
        string memory _group,
        string memory _name,
        address _caller,
        bytes memory _data
    )
        internal
    {
        (bool ok,) = _measureCall(_group, _name, _caller, _data);
        assertTrue(ok, _name);
    }

    /// @dev Measures, as `_name` in `_group`, the call `_data` from `_caller` against cold
    /// storage, which must revert with `_error`.
    function _measureRevert(
        string memory _group,
        string memory _name,
        address _caller,
        bytes memory _data,
        bytes4 _error
    )
        internal
    {
        (bool ok, bytes memory returnData) = _measureCall(_group, _name, _caller, _data);
        assertFalse(ok, _name);
        assertEq(returnData, abi.encodeWithSelector(_error), _name);
    }

    /// @dev Makes the call and snapshots its gas.
    function _measureCall(
        string memory _group,
        string memory _name,
        address _caller,
        bytes memory _data
    )
        private
        returns (bool ok_, bytes memory returnData_)
    {
        address target = address(staking);
        vm.prank(_caller);
        (ok_, returnData_) = target.call(_data);
        uint256 gasUsed = vm.snapshotGasLastCall(_group, _name);
        emit log_named_uint(_name, gasUsed);
    }

    /// @dev An unsigned precommit at height 1000, round 3 and generation 0, timestamped
    /// 1,700,000,000.000000123, for `_blockHash` with a one-part part set header.
    function _precommit(bytes32 _blockHash) private pure returns (IEtnaStaking.Vote memory v_) {
        v_.voteType = 2;
        v_.height = 1000;
        v_.round = 3;
        v_.blockHash = abi.encodePacked(_blockHash);
        v_.partsTotal = 1;
        v_.partsHash = abi.encodePacked(keccak256(abi.encode(_blockHash)));
        v_.timestampSeconds = 1_700_000_000;
        v_.timestampNanos = 123;
        v_.signature = new bytes(65);
    }
}

// ---------------------------------------------------------------
// register
// ---------------------------------------------------------------

/// @title EtnaStakingRegisterGasTest
/// @notice Carol registers a new key with m into seat 127, the last empty seat, which bond 127's
/// exit freed.
contract EtnaStakingRegisterGasTest is EtnaStakingOperationGasBase {
    function setUp() public override {
        super.setUp();
        _seatEveryBond();
        _requestExit(127);
        _fundExact(Carol, MIN_STAKE);
        registerData = _registerCall(NEW_KEY, Carol);
    }

    function test_gas_register_TakesTheLastEmptySeat() external {
        _measure(REGISTER_GAS, "register_takes_last_empty_seat", Carol, registerData);

        _assertSeatOfBond(128, true, LAST_SEAT, "the new bond in seat 127");
        _assertBondInSeat(LAST_SEAT, true, 128, "seat 127 taken");
    }
}

/// @title EtnaStakingRegisterNoEmptySeatGasTest
/// @notice Carol's registration reverts `NoEmptySeat` with every seat held.
contract EtnaStakingRegisterNoEmptySeatGasTest is EtnaStakingOperationGasBase {
    function setUp() public override {
        super.setUp();
        _seatEveryBond();
        _fundExact(Carol, MIN_STAKE);
        registerData = _registerCall(NEW_KEY, Carol);
    }

    function test_gas_register_RevertWhen_NoEmptySeat() external {
        _measureRevert(
            REGISTER_GAS,
            "register_reverts_no_empty_seat",
            Carol,
            registerData,
            IEtnaStaking.NoEmptySeat.selector
        );

        assertEq(staking.bondCount(), N_MAX, "no bond issued");
        assertEq(token.balanceOf(Carol), MIN_STAKE, "nothing pulled");
    }
}

/// @title EtnaStakingRegisterAfterSeatChangesGasTest
/// @notice After bond 127's exit, Carol's bond 128 taking seat 127 and a double-sign slash of
/// bond 0 releasing seat 0, David registers into seat 0.
contract EtnaStakingRegisterAfterSeatChangesGasTest is EtnaStakingOperationGasBase {
    function setUp() public override {
        super.setUp();
        _seatEveryBond();
        _requestExit(127);
        _register(NEW_KEY, Carol, MIN_STAKE);
        _slash(0);
        _fundExact(David, MIN_STAKE);
        registerData = _registerCall(NEXT_KEY, David);
    }

    function test_gas_register_AfterSeatChanges() external {
        _measure(REGISTER_GAS, "register_after_seats_changed", David, registerData);

        _assertSeatOfBond(129, true, 0, "the new bond in seat 0");
        _assertBondInSeat(LAST_SEAT, true, 128, "seat 127 kept");
    }
}

// ---------------------------------------------------------------
// topUp
// ---------------------------------------------------------------

/// @title EtnaStakingTopUpGasTest
/// @notice Bob tops up bond 127, in seat 127, by m / 10; the bond keeps its seat.
contract EtnaStakingTopUpGasTest is EtnaStakingOperationGasBase {
    function setUp() public override {
        super.setUp();
        _seatEveryBond();
        _fundExact(Bob, MIN_STAKE / 10);
    }

    function test_gas_topUp_SeatedBond() external {
        bytes memory data = abi.encodeCall(IEtnaStaking.topUp, (127, MIN_STAKE / 10));
        _measure(TOP_UP_GAS, "top_up_seated_bond", Bob, data);

        _assertSeatOfBond(127, true, LAST_SEAT, "seat 127 kept");
        assertEq(staking.bondAt(127).effStake, MIN_STAKE + MIN_STAKE / 10, "the new stake");
    }
}

/// @title EtnaStakingTopUpAfterSeatChangesGasTest
/// @notice After bond 0's exit released seat 0 and Carol's bond 128 took it, Carol tops up bond
/// 128 by m / 10.
contract EtnaStakingTopUpAfterSeatChangesGasTest is EtnaStakingOperationGasBase {
    function setUp() public override {
        super.setUp();
        _seatEveryBond();
        _requestExit(0);
        _register(NEW_KEY, Carol, MIN_STAKE);
        _fundExact(Carol, MIN_STAKE / 10);
    }

    function test_gas_topUp_AfterSeatChanges() external {
        bytes memory data = abi.encodeCall(IEtnaStaking.topUp, (128, MIN_STAKE / 10));
        _measure(TOP_UP_GAS, "top_up_after_seats_changed", Carol, data);

        _assertSeatOfBond(128, true, 0, "seat 0 kept");
        _assertBondInSeat(0, true, 128, "seat 0 holds bond 128");
    }
}

// ---------------------------------------------------------------
// requestExit
// ---------------------------------------------------------------

/// @title EtnaStakingRequestExitGasTest
/// @notice Bob requests the exit of the bond in seat 0 and, separately, of the bond in seat 127.
contract EtnaStakingRequestExitGasTest is EtnaStakingOperationGasBase {
    function setUp() public override {
        super.setUp();
        _seatEveryBond();
    }

    function test_gas_requestExit_ReleasesSeat0() external {
        _measure(
            REQUEST_EXIT_GAS,
            "request_exit_releases_seat_0",
            Bob,
            abi.encodeCall(IEtnaStaking.requestExit, (0))
        );
        _assertBondInSeat(0, false, 0, "seat 0 released");
    }

    function test_gas_requestExit_ReleasesSeat127() external {
        _measure(
            REQUEST_EXIT_GAS,
            "request_exit_releases_seat_127",
            Bob,
            abi.encodeCall(IEtnaStaking.requestExit, (127))
        );
        _assertBondInSeat(LAST_SEAT, false, 0, "seat 127 released");
    }
}

/// @title EtnaStakingRequestExitAfterSeatChangesGasTest
/// @notice After a forfeiture of bond 0 released seat 0 and Carol's bond 128 took it, Carol
/// requests the exit of bond 128.
contract EtnaStakingRequestExitAfterSeatChangesGasTest is EtnaStakingOperationGasBase {
    function setUp() public override {
        super.setUp();
        _seatEveryBond();
        _forfeit(0);
        _register(NEW_KEY, Carol, MIN_STAKE);
    }

    function test_gas_requestExit_AfterSeatChanges() external {
        _measure(
            REQUEST_EXIT_GAS,
            "request_exit_after_seats_changed",
            Carol,
            abi.encodeCall(IEtnaStaking.requestExit, (128))
        );
        _assertBondInSeat(0, false, 0, "seat 0 released");
    }
}

// ---------------------------------------------------------------
// slashDoubleSign
// ---------------------------------------------------------------

/// @title EtnaStakingSlashGasTest
/// @notice David, holding no token, reports the double sign of the bond in seat 0 and,
/// separately, of the bond in seat 127; slashSink holds no token before.
contract EtnaStakingSlashGasTest is EtnaStakingOperationGasBase {
    function setUp() public override {
        super.setUp();
        _seatEveryBond();
    }

    function test_gas_slashDoubleSign_ReleasesSeat0() external {
        _measureSlash(0, "slash_double_sign_releases_seat_0");
        _assertBondInSeat(0, false, 0, "seat 0 released");
    }

    function test_gas_slashDoubleSign_ReleasesSeat127() external {
        _measureSlash(127, "slash_double_sign_releases_seat_127");
        _assertBondInSeat(LAST_SEAT, false, 0, "seat 127 released");
    }

    function _measureSlash(uint256 _bondId, string memory _name) private {
        (IEtnaStaking.Vote memory a, IEtnaStaking.Vote memory b) = _conflictingVotes(_bondId + 1);
        _measure(
            SLASH_GAS, _name, David, abi.encodeCall(IEtnaStaking.slashDoubleSign, (_bondId, a, b))
        );
        assertEq(staking.bondAt(_bondId).effStake, 0, "all principal taken");
        assertEq(token.balanceOf(David), MIN_STAKE / 10, "the bounty");
    }
}

/// @title EtnaStakingSlashAfterSeatChangesGasTest
/// @notice After bond 127's exit and Carol's bond 128 taking seat 127, David reports the double
/// sign of bond 128.
contract EtnaStakingSlashAfterSeatChangesGasTest is EtnaStakingOperationGasBase {
    function setUp() public override {
        super.setUp();
        _seatEveryBond();
        _requestExit(127);
        _register(NEW_KEY, Carol, MIN_STAKE);
    }

    function test_gas_slashDoubleSign_AfterSeatChanges() external {
        (IEtnaStaking.Vote memory a, IEtnaStaking.Vote memory b) = _conflictingVotes(NEW_KEY);
        _measure(
            SLASH_GAS,
            "slash_double_sign_after_seats_changed",
            David,
            abi.encodeCall(IEtnaStaking.slashDoubleSign, (128, a, b))
        );
        _assertBondInSeat(LAST_SEAT, false, 0, "seat 127 released");
    }
}

// ---------------------------------------------------------------
// forfeit
// ---------------------------------------------------------------

/// @title EtnaStakingForfeitGasTest
/// @notice The staking owner forfeits the bond in seat 0 and, separately, the bond in seat 127;
/// slashSink holds no token before.
/// @dev The forfeiture reaches the staking contract through an L1 -> L2 governance message,
/// whose L2 leg is the owner, `DelegateController`, executing the bridged call. The snapshot is
/// that call alone, from the owner; it leaves out the message's L1 leg, the L2 bridge's message
/// processing and the controller's dispatch.
contract EtnaStakingForfeitGasTest is EtnaStakingOperationGasBase {
    function setUp() public override {
        super.setUp();
        _seatEveryBond();
    }

    function test_gas_forfeit_ReleasesSeat0() external {
        _measureForfeit(0, "forfeit_releases_seat_0");
        _assertBondInSeat(0, false, 0, "seat 0 released");
    }

    function test_gas_forfeit_ReleasesSeat127() external {
        _measureForfeit(127, "forfeit_releases_seat_127");
        _assertBondInSeat(LAST_SEAT, false, 0, "seat 127 released");
    }

    function _measureForfeit(uint256 _bondId, string memory _name) private {
        _measure(
            FORFEIT_GAS,
            _name,
            STAKING_OWNER,
            abi.encodeCall(IEtnaStaking.forfeit, (_bondId, INCIDENT, block.timestamp))
        );
        assertTrue(staking.forfeited(_bondId), "forfeited");
        assertEq(token.balanceOf(SLASH_SINK), MIN_STAKE / 10, "the penalty");
    }
}

/// @title EtnaStakingForfeitAfterSeatChangesGasTest
/// @notice After a double-sign slash of bond 127 released seat 127 and Carol's bond 128 took it,
/// the staking owner forfeits bond 128.
/// @dev Measured as `EtnaStakingForfeitGasTest` is: the owner's call alone.
contract EtnaStakingForfeitAfterSeatChangesGasTest is EtnaStakingOperationGasBase {
    function setUp() public override {
        super.setUp();
        _seatEveryBond();
        _slash(127);
        _register(NEW_KEY, Carol, MIN_STAKE);
    }

    function test_gas_forfeit_AfterSeatChanges() external {
        _measure(
            FORFEIT_GAS,
            "forfeit_after_seats_changed",
            STAKING_OWNER,
            abi.encodeCall(IEtnaStaking.forfeit, (128, INCIDENT, block.timestamp))
        );
        _assertBondInSeat(LAST_SEAT, false, 0, "seat 127 released");
    }
}

// ---------------------------------------------------------------
// withdraw
// ---------------------------------------------------------------

/// @title EtnaStakingWithdrawGasTest
/// @notice Bond 0's exit released seat 0 `withdrawalDelay` blocks ago; Bob withdraws its whole
/// balance, m, to a recipient that holds no token.
contract EtnaStakingWithdrawGasTest is EtnaStakingOperationGasBase {
    function setUp() public override {
        super.setUp();
        _seatEveryBond();
        _requestExit(0);
        vm.roll(block.number + WITHDRAWAL_DELAY);
    }

    function test_gas_withdraw_PaysTheWholeBalance() external {
        _measure(
            WITHDRAW_GAS,
            "withdraw_whole_balance",
            Bob,
            abi.encodeCall(IEtnaStaking.withdraw, (0, RECIPIENT))
        );
        assertEq(token.balanceOf(RECIPIENT), MIN_STAKE, "the whole balance");
    }
}

/// @title EtnaStakingWithdrawAfterSeatChangesGasTest
/// @notice A forfeiture of bond 127 released seat 127 and Carol's bond 128 took it;
/// `withdrawalDelay` blocks later Bob withdraws bond 127's remaining 9m / 10.
contract EtnaStakingWithdrawAfterSeatChangesGasTest is EtnaStakingOperationGasBase {
    function setUp() public override {
        super.setUp();
        _seatEveryBond();
        _forfeit(127);
        _register(NEW_KEY, Carol, MIN_STAKE);
        vm.roll(block.number + WITHDRAWAL_DELAY);
    }

    function test_gas_withdraw_AfterSeatChanges() external {
        _measure(
            WITHDRAW_GAS,
            "withdraw_after_seats_changed",
            Bob,
            abi.encodeCall(IEtnaStaking.withdraw, (127, RECIPIENT))
        );
        assertEq(token.balanceOf(RECIPIENT), MIN_STAKE - MIN_STAKE / 10, "the remainder");
        _assertBondInSeat(LAST_SEAT, true, 128, "seat 127 kept");
    }
}
