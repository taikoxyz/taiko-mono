// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { EtnaVoteKeys } from "../EtnaVoteKeys.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { CommonBase } from "forge-std/src/Base.sol";
import { StdUtils } from "forge-std/src/StdUtils.sol";
import { EtnaStaking } from "src/layer2/etna/EtnaStaking.sol";
import { IEtnaStaking } from "src/layer2/etna/iface/IEtnaStaking.sol";
import { LibCometVote } from "src/layer2/etna/libs/LibCometVote.sol";
import { TestERC20 } from "test/mocks/TestERC20.sol";
import { EtnaTestKeys } from "test/shared/etna/EtnaTestKeys.sol";

/// @title EtnaStakingHandler
/// @notice Drives an EtnaStaking deployment through registrations, top-ups, exits, withdrawals,
/// double-sign slashes, forfeitures, block-start calls and L2 blocks, and keeps ghost sums of the
/// stake that entered and left it.
/// @dev Each action predicts its outcome from the state before it, success or the exact error,
/// and records a violation when the contract disagrees, so the campaign runs with
/// `fail_on_revert`. After every action it records each bond's exit height and forfeiture flag,
/// so a later action that moves an exit later or clears a flag is a violation. Right after each
/// block-start call it checks that the call changed no stake or seat and captures the snapshot
/// words the call wrote and the words the seat table implies.
contract EtnaStakingHandler is CommonBase, StdUtils {
    // ---------------------------------------------------------------
    // Constants
    // ---------------------------------------------------------------

    /// @dev Consensus keys are the private keys 1 to `KEY_COUNT`.
    uint256 public constant KEY_COUNT = 40;

    /// @dev The snapshot words, in order: T (`snapshotHeight`), T + 1 (`snapshotTotalStake`) and
    /// the 256 words of the 128 records at T + 2 to T + 257.
    uint256 public constant SNAPSHOT_WORDS = 258;

    /// @dev The `exitHeight` of a bond with no exit set.
    uint48 internal constant NO_EXIT = type(uint48).max;

    /// @dev The only caller of `onBlockStart`.
    address internal constant SYSTEM_CALLER = 0xffffFFFfFFffffffffffffffFfFFFfffFFFfFFfE;

    /// @dev The ERC-7201 base slot T of `taiko.etna.staking`.
    bytes32 internal constant T =
        0x5cfa9ae4fa3ccb6db5189dbaff84335bb566ebd2f7442638272a1d81ccb19e00;

    /// @dev The basis points of a whole stake.
    uint256 internal constant BPS = 10_000;

    // ---------------------------------------------------------------
    // Configuration
    // ---------------------------------------------------------------

    EtnaStaking public immutable staking;
    TestERC20 public immutable token;
    /// @dev The staking owner, the DAO's execution address on L2.
    address public immutable stakingOwner;
    uint256 public immutable minStake;
    uint256 public immutable vpUnit;
    uint256 public immutable nMax;
    uint256 public immutable withdrawalDelay;
    uint256 public immutable slashBountyBps;
    address public immutable slashSink;
    uint256 public immutable forfeitBps;

    /// @dev The bond owners registrations draw from.
    address[] internal _owners;
    /// @dev The reporters, withdrawal recipients and callers of zero-balance withdrawals.
    address[] internal _others;

    // ---------------------------------------------------------------
    // Ghost state
    // ---------------------------------------------------------------

    /// @dev Stake pulled in by registrations and top-ups.
    uint256 public ghostDeposited;
    /// @dev Stake paid out by withdrawals.
    uint256 public ghostWithdrawn;
    /// @dev Principal taken by double-sign slashes, the bounties included.
    uint256 public ghostSlashed;
    /// @dev The part of `ghostSlashed` paid to reporters.
    uint256 public ghostBounties;
    /// @dev Penalties of forfeitures.
    uint256 public ghostForfeitPenalties;

    /// @dev The private key and the owner of each bond, by bond id.
    uint256[] internal _keyOfBond;
    address[] internal _ownerOfBond;
    /// @dev Bond id + 1 of each private key a registration used; 0 if unused.
    mapping(uint256 pk => uint256 bondIdPlusOne) internal _bondOfKey;

    /// @dev Each bond's exit height after the last action, and whether a forfeiture of it
    /// succeeded.
    mapping(uint256 bondId => uint48 exitHeight) public seenExitHeight;
    mapping(uint256 bondId => bool forfeited) public ghostForfeited;

    /// @dev Whether a block-start call has run, and the snapshot words the last one wrote and
    /// those the seat table it left implies.
    bool public captured;
    bytes32[] internal _capturedWords;
    bytes32[] internal _expectedWords;

    uint256 public violations;
    string public firstViolation;

    // ---------------------------------------------------------------
    // Statistics
    // ---------------------------------------------------------------

    uint256 public registrations;
    uint256 public topUps;
    uint256 public exits;
    uint256 public withdrawals;
    uint256 public slashes;
    uint256 public forfeitures;
    uint256 public blockStarts;
    /// @dev Registrations the model expected to find every seat held.
    uint256 public fullTableRejections;
    uint256 public rejected;

    // ---------------------------------------------------------------
    // Constructor
    // ---------------------------------------------------------------

    constructor(EtnaStaking _staking, TestERC20 _token, address _stakingOwner) {
        staking = _staking;
        token = _token;
        stakingOwner = _stakingOwner;
        minStake = _staking.minStake();
        vpUnit = _staking.vpUnit();
        nMax = _staking.nMax();
        withdrawalDelay = _staking.withdrawalDelay();
        slashBountyBps = _staking.slashBountyBps();
        slashSink = _staking.slashSink();
        forfeitBps = _staking.forfeitBps();

        for (uint256 i; i < 3; ++i) {
            _owners.push(vm.addr(0xe7a0000 + i));
            _others.push(vm.addr(0xe7a1000 + i));
        }
    }

    // ---------------------------------------------------------------
    // Fuzzed actions
    // ---------------------------------------------------------------

    /// @notice A burst of one to four registrations, so the seat table fills: each by one of
    /// three owners, of key 1 to 40, with a stake in [m, 3m]. A used key reverts `KeyAlreadyUsed`
    /// and, failing that, a full seat table `NoEmptySeat`; otherwise the next bond id takes the
    /// lowest empty seat.
    function register(uint256 _keySeed, uint256 _amountSeed, uint256 _ownerSeed) external {
        uint256 burst = 1 + (_ownerSeed >> 8) % 4;
        for (uint256 i; i < burst; ++i) {
            if (i == 0) {
                _register(_keySeed, _amountSeed, _ownerSeed);
            } else {
                _register(_rand(_keySeed, i), _rand(_amountSeed, i), _rand(_ownerSeed, i));
            }
        }
        _afterAction();
    }

    /// @notice The owner of an issued bond tops it up by 1 to m. A withdrawn bond reverts
    /// `BondWithdrawn` and one with an exit `ExitAlreadySet`; otherwise the stake rises and the
    /// bond keeps the seat it holds, since a bond with no exit always holds one.
    function topUp(uint256 _bondSeed, uint256 _amountSeed) external {
        if (_keyOfBond.length == 0) return;
        uint256 bondId = _bondSeed % _keyOfBond.length;
        uint256 amount = _bound(_amountSeed, 1, minStake);
        address owner = _ownerOfBond[bondId];
        IEtnaStaking.Bond memory bond = staking.bondAt(bondId);
        bytes4 expected = _expectUnwithdrawn(bond);
        if (expected == 0 && bond.exitHeight != NO_EXIT) {
            expected = IEtnaStaking.ExitAlreadySet.selector;
        }
        _fund(owner, amount);

        vm.prank(owner);
        try staking.topUp(bondId, amount) {
            _checkAccepted("topUp", expected);
            ghostDeposited += amount;
            ++topUps;
            if (staking.bondAt(bondId).effStake != bond.effStake + amount) {
                _violate("topUp: wrong stake");
            }
            if (!bond.holdsSeat) _violate("topUp: a bond with no exit held no seat");
            _checkSeat(bondId, true, bond.seat, "topUp");
        } catch (bytes memory reason) {
            _checkRejected("topUp", expected, reason);
        }
        _afterAction();
    }

    /// @notice The owner of an issued bond requests its exit. A withdrawn bond reverts
    /// `BondWithdrawn` and one with an exit `ExitAlreadySet`; otherwise the exit is the current
    /// block and the bond holds no seat.
    function requestExit(uint256 _bondSeed) external {
        if (_keyOfBond.length == 0) return;
        uint256 bondId = _bondSeed % _keyOfBond.length;
        IEtnaStaking.Bond memory bond = staking.bondAt(bondId);
        bytes4 expected = _expectUnwithdrawn(bond);
        if (expected == 0 && bond.exitHeight != NO_EXIT) {
            expected = IEtnaStaking.ExitAlreadySet.selector;
        }

        vm.prank(_ownerOfBond[bondId]);
        try staking.requestExit(bondId) {
            _checkAccepted("requestExit", expected);
            ++exits;
            if (staking.bondAt(bondId).exitHeight != block.number) {
                _violate("requestExit: exit not at the current block");
            }
            _checkSeat(bondId, false, 0, "requestExit");
        } catch (bytes memory reason) {
            _checkRejected("requestExit", expected, reason);
        }
        _afterAction();
    }

    /// @notice Rolls `withdrawalDelay` blocks, then withdraws an issued bond: the owner pays its
    /// whole balance to one of three recipients, or anyone closes a bond without balance. A
    /// withdrawn bond reverts `BondWithdrawn` and one without an exit `ExitNotSet`.
    function withdraw(uint256 _bondSeed, uint256 _toSeed) external {
        if (_keyOfBond.length == 0) return;
        vm.roll(block.number + withdrawalDelay);
        uint256 bondId = _bondSeed % _keyOfBond.length;
        address to = _others[_toSeed % _others.length];
        IEtnaStaking.Bond memory bond = staking.bondAt(bondId);
        bytes4 expected = _expectUnwithdrawn(bond);
        if (expected == 0 && bond.exitHeight == NO_EXIT) {
            expected = IEtnaStaking.ExitNotSet.selector;
        }
        address caller = bond.effStake != 0 ? _ownerOfBond[bondId] : _others[_toSeed % 2];
        uint256 toBefore = token.balanceOf(to);

        vm.prank(caller);
        try staking.withdraw(bondId, to) {
            _checkAccepted("withdraw", expected);
            if (token.balanceOf(to) - toBefore != bond.effStake) {
                _violate("withdraw: not the whole balance paid");
            }
            ghostWithdrawn += bond.effStake;
            ++withdrawals;
            IEtnaStaking.Bond memory after_ = staking.bondAt(bondId);
            if (!after_.withdrawn || after_.effStake != 0 || after_.owner != address(0)) {
                _violate("withdraw: bond not closed");
            }
        } catch (bytes memory reason) {
            _checkRejected("withdraw", expected, reason);
        }
        _afterAction();
    }

    /// @notice One of three reporters submits two conflicting precommits or prevotes that the
    /// bond's key signed for the generation `onBlockStart` last stored. A withdrawn bond reverts
    /// `BondWithdrawn` and an empty one `NothingToSlash`; otherwise the whole principal goes,
    /// the bounty to the reporter and the rest to slashSink.
    function slashDoubleSign(uint256 _bondSeed, uint256 _voteSeed) external {
        if (_keyOfBond.length == 0) return;
        uint256 bondId = _bondSeed % _keyOfBond.length;
        address reporter = _others[_voteSeed % _others.length];
        (IEtnaStaking.Vote memory a, IEtnaStaking.Vote memory b) =
            _doubleSign(_keyOfBond[bondId], _voteSeed);
        IEtnaStaking.Bond memory bond = staking.bondAt(bondId);
        bytes4 expected = _expectUnwithdrawn(bond);
        if (expected == 0 && bond.effStake == 0) expected = IEtnaStaking.NothingToSlash.selector;
        uint256 bounty = Math.mulDiv(bond.effStake, slashBountyBps, BPS);
        uint256 reporterBefore = token.balanceOf(reporter);
        uint256 sinkBefore = token.balanceOf(slashSink);

        vm.prank(reporter);
        try staking.slashDoubleSign(bondId, a, b) {
            _checkAccepted("slashDoubleSign", expected);
            if (token.balanceOf(reporter) - reporterBefore != bounty) {
                _violate("slashDoubleSign: wrong bounty");
            }
            if (token.balanceOf(slashSink) - sinkBefore != bond.effStake - bounty) {
                _violate("slashDoubleSign: wrong share to slashSink");
            }
            ghostSlashed += bond.effStake;
            ghostBounties += bounty;
            ++slashes;
            IEtnaStaking.Bond memory after_ = staking.bondAt(bondId);
            if (after_.effStake != 0 || after_.exitHeight > block.number) {
                _violate("slashDoubleSign: principal or exit not taken");
            }
            _checkSeat(bondId, false, 0, "slashDoubleSign");
        } catch (bytes memory reason) {
            _checkRejected("slashDoubleSign", expected, reason);
        }
        _afterAction();
    }

    /// @notice The staking owner forfeits forfeitBps of an issued bond, valid until the current
    /// time. A withdrawn bond reverts `BondWithdrawn`, a forfeited one `AlreadyForfeited` and an
    /// empty one `NothingToForfeit`; otherwise the penalty goes to slashSink, the bond is flagged,
    /// gets an exit and holds no seat.
    function forfeit(uint256 _bondSeed) external {
        if (_keyOfBond.length == 0) return;
        uint256 bondId = _bondSeed % _keyOfBond.length;
        IEtnaStaking.Bond memory bond = staking.bondAt(bondId);
        bytes4 expected = _expectUnwithdrawn(bond);
        if (expected == 0 && ghostForfeited[bondId]) {
            expected = IEtnaStaking.AlreadyForfeited.selector;
        }
        if (expected == 0 && bond.effStake == 0) {
            expected = IEtnaStaking.NothingToForfeit.selector;
        }
        uint256 penalty = Math.mulDiv(bond.effStake, forfeitBps, BPS, Math.Rounding.Up);
        uint256 sinkBefore = token.balanceOf(slashSink);

        vm.prank(stakingOwner);
        try staking.forfeit(bondId, keccak256(abi.encode(bondId)), block.timestamp) {
            _checkAccepted("forfeit", expected);
            if (token.balanceOf(slashSink) - sinkBefore != penalty) {
                _violate("forfeit: wrong penalty");
            }
            ghostForfeitPenalties += penalty;
            ghostForfeited[bondId] = true;
            ++forfeitures;
            IEtnaStaking.Bond memory after_ = staking.bondAt(bondId);
            if (after_.effStake != bond.effStake - penalty || after_.exitHeight > block.number) {
                _violate("forfeit: balance or exit wrong");
            }
            _checkSeat(bondId, false, 0, "forfeit");
        } catch (bytes memory reason) {
            _checkRejected("forfeit", expected, reason);
        }
        _afterAction();
    }

    /// @notice Rolls one block and makes its block-start call with `_generation`, which always
    /// succeeds, stores the generation and changes no stake, seat, exit or token balance,
    /// whichever members signed. The handler then captures the snapshot.
    function blockStart(uint48 _generation) external {
        vm.roll(block.number + 1);
        IEtnaStaking.Bond[] memory before = new IEtnaStaking.Bond[](_keyOfBond.length);
        for (uint256 bondId; bondId < before.length; ++bondId) {
            before[bondId] = staking.bondAt(bondId);
        }
        uint256 sinkBefore = token.balanceOf(slashSink);
        uint256 heldBefore = token.balanceOf(address(staking));

        vm.prank(SYSTEM_CALLER);
        try staking.onBlockStart(_generation) {
            ++blockStarts;
            if (
                token.balanceOf(slashSink) != sinkBefore
                    || token.balanceOf(address(staking)) != heldBefore
            ) {
                _violate("blockStart: tokens moved");
            }
            if (staking.lastGeneration() != _generation) {
                _violate("blockStart: generation not stored");
            }
            _checkBlockStart(before);
            _capture();
        } catch {
            _violate("blockStart: reverted");
        }
        _afterAction();
    }

    /// @notice Rolls `_n` blocks.
    function roll(uint8 _n) external {
        vm.roll(block.number + _n);
        _afterAction();
    }

    // ---------------------------------------------------------------
    // Views for the invariants
    // ---------------------------------------------------------------

    /// @notice The number of bonds the handler registered.
    function bondTotal() external view returns (uint256) {
        return _keyOfBond.length;
    }

    /// @notice The private key of a bond.
    function keyOfBond(uint256 _bondId) external view returns (uint256) {
        return _keyOfBond[_bondId];
    }

    /// @notice Whether a registration used private key `_pk`, and its bond id.
    function bondOfKey(uint256 _pk) external view returns (bool used_, uint256 bondId_) {
        uint256 bondIdPlusOne = _bondOfKey[_pk];
        if (bondIdPlusOne != 0) return (true, bondIdPlusOne - 1);
    }

    /// @notice Stake paid out of the contract: withdrawals, slashes and forfeiture penalties.
    function ghostPaidOut() external view returns (uint256) {
        return ghostWithdrawn + ghostSlashed + ghostForfeitPenalties;
    }

    /// @notice Stake paid to slashSink.
    function ghostToSink() external view returns (uint256) {
        return ghostSlashed - ghostBounties + ghostForfeitPenalties;
    }

    /// @notice The snapshot words the last block-start call wrote, read right after it, and those
    /// the seat table it left implies.
    function capturedSnapshot()
        external
        view
        returns (bytes32[] memory written_, bytes32[] memory expected_)
    {
        return (_capturedWords, _expectedWords);
    }

    /// @notice The slot of snapshot word `_index`, T + `_index`.
    function snapshotSlot(uint256 _index) public pure returns (bytes32) {
        return bytes32(uint256(T) + _index);
    }

    // ---------------------------------------------------------------
    // Internal functions
    // ---------------------------------------------------------------

    /// @dev One registration of the burst `register` makes.
    function _register(uint256 _keySeed, uint256 _amountSeed, uint256 _ownerSeed) internal {
        uint256 pk = _bound(_keySeed, 1, KEY_COUNT);
        uint256 amount = _bound(_amountSeed, minStake, 3 * minStake);
        address owner = _owners[_ownerSeed % _owners.length];
        bytes memory publicKey = EtnaTestKeys.publicKey(pk);
        bytes memory pop = EtnaVoteKeys.popSig(pk, staking, owner);
        _fund(owner, amount);

        (bool full, uint8 seat) = _lowestEmptySeat();
        bytes4 expected = _bondOfKey[pk] != 0
            ? IEtnaStaking.KeyAlreadyUsed.selector
            : full ? IEtnaStaking.NoEmptySeat.selector : bytes4(0);
        if (expected == IEtnaStaking.NoEmptySeat.selector) ++fullTableRejections;
        uint256 bondId = _keyOfBond.length;

        vm.prank(owner);
        try staking.register(publicKey, amount, pop) returns (uint256 issued) {
            _checkAccepted("register", expected);
            if (issued != bondId) _violate("register: not the next bond id");
            _keyOfBond.push(pk);
            _ownerOfBond.push(owner);
            _bondOfKey[pk] = issued + 1;
            seenExitHeight[issued] = NO_EXIT;
            ghostDeposited += amount;
            ++registrations;
            _checkSeat(issued, true, seat, "register");
        } catch (bytes memory reason) {
            _checkRejected("register", expected, reason);
        }
    }

    /// @dev Mints `_amount` to `_owner`, which approves exactly that for the staking contract.
    function _fund(address _owner, uint256 _amount) internal {
        token.mint(_owner, _amount);
        vm.prank(_owner);
        token.approve(address(staking), _amount);
    }

    /// @dev Whether every seat is held and, if not, the lowest empty seat.
    function _lowestEmptySeat() internal view returns (bool full_, uint8 seat_) {
        for (uint256 seat; seat < nMax; ++seat) {
            (bool occupied,) = staking.bondInSeat(uint8(seat));
            if (!occupied) return (false, uint8(seat));
        }
        return (true, 0);
    }

    /// @dev `BondWithdrawn` for a withdrawn bond, else no error.
    function _expectUnwithdrawn(IEtnaStaking.Bond memory _bond) internal pure returns (bytes4) {
        return _bond.withdrawn ? IEtnaStaking.BondWithdrawn.selector : bytes4(0);
    }

    /// @dev Two conflicting votes of the same type, height and round for the generation
    /// `onBlockStart` last stored, both signed by `_pk` under this deployment's chain id.
    function _doubleSign(
        uint256 _pk,
        uint256 _seed
    )
        internal
        view
        returns (IEtnaStaking.Vote memory a_, IEtnaStaking.Vote memory b_)
    {
        uint48 generation = staking.lastGeneration();
        bytes memory chainId = LibCometVote.chainId(
            LibCometVote.chainDomain(
                staking.l1ChainId(), block.chainid, staking.inbox(), generation
            )
        );
        a_ = EtnaVoteKeys.signVote(_pk, _vote(_seed, "a", generation), chainId);
        b_ = EtnaVoteKeys.signVote(_pk, _vote(_seed, "b", generation), chainId);
    }

    /// @dev An unsigned vote for a block named by `_seed` and `_block`, typed, placed and
    /// timestamped by `_seed`.
    function _vote(
        uint256 _seed,
        string memory _block,
        uint48 _generation
    )
        internal
        pure
        returns (IEtnaStaking.Vote memory v_)
    {
        bytes32 blockHash = keccak256(abi.encode(_seed, _block));
        v_.voteType = uint8(1 + (_seed >> 8) % 2);
        v_.height = uint64(1 + (_seed >> 16) % 1_000_000);
        v_.round = uint32((_seed >> 40) % 16);
        v_.blockHash = abi.encodePacked(blockHash);
        v_.partsTotal = 1;
        v_.partsHash = abi.encodePacked(keccak256(abi.encode(blockHash)));
        v_.timestampSeconds = uint64(1_700_000_000 + (_seed >> 48) % 1_000_000);
        v_.generation = _generation;
        v_.signature = new bytes(65);
    }

    /// @dev Checks a bond's seat through `seatOfBond` and, if it holds one, `bondInSeat`.
    function _checkSeat(
        uint256 _bondId,
        bool _holdsSeat,
        uint8 _seat,
        string memory _action
    )
        internal
    {
        (bool holdsSeat, uint8 seat) = staking.seatOfBond(_bondId);
        if (holdsSeat != _holdsSeat || seat != (_holdsSeat ? _seat : 0)) {
            _violate(string.concat(_action, ": wrong seat"));
        }
        if (!_holdsSeat) return;
        (bool occupied, uint256 bondId) = staking.bondInSeat(_seat);
        if (!occupied || bondId != _bondId) _violate(string.concat(_action, ": seat not taken"));
    }

    /// @dev Checks that a block-start call left every bond record as it was before the call:
    /// the same stake, exit, seat and owner, so no member, signing or not, loses stake or a seat.
    /// @param _before Each bond's record before the call, by bond id.
    function _checkBlockStart(IEtnaStaking.Bond[] memory _before) internal {
        for (uint256 bondId; bondId < _before.length; ++bondId) {
            IEtnaStaking.Bond memory bond = staking.bondAt(bondId);
            if (keccak256(abi.encode(bond)) != keccak256(abi.encode(_before[bondId]))) {
                _violate("blockStart: a bond record changed");
            }
            if (bond.holdsSeat) _checkSeat(bondId, true, bond.seat, "blockStart");
        }
    }

    /// @dev Captures the snapshot words the block-start call just wrote and those implied by the
    /// seat table it left: record s holds the key and power of the bond in seat s, or zero; the
    /// total is the seated bonds' effStake; the height is this block.
    function _capture() internal {
        bytes32[] memory expected = new bytes32[](SNAPSHOT_WORDS);
        expected[0] = bytes32(block.number);
        uint256 total;
        for (uint256 seat; seat < nMax; ++seat) {
            (bool occupied, uint256 bondId) = staking.bondInSeat(uint8(seat));
            if (!occupied) continue;
            uint256 effStake = staking.bondAt(bondId).effStake;
            (uint8 ckPrefix, bytes32 ckX) = EtnaTestKeys.fallbackKey(_keyOfBond[bondId]);
            total += effStake;
            expected[2 + 2 * seat] = ckX;
            expected[3 + 2 * seat] = bytes32(uint256(ckPrefix) | (effStake / vpUnit) << 8);
        }
        expected[1] = bytes32(total);

        delete _capturedWords;
        delete _expectedWords;
        for (uint256 i; i < SNAPSHOT_WORDS; ++i) {
            _capturedWords.push(vm.load(address(staking), snapshotSlot(i)));
            _expectedWords.push(expected[i]);
        }
        captured = true;
    }

    /// @dev Records each bond's exit height and forfeiture flag, as a violation if the exit moved
    /// later or the flag was cleared.
    function _afterAction() internal {
        for (uint256 bondId; bondId < _keyOfBond.length; ++bondId) {
            uint48 exitHeight = staking.bondAt(bondId).exitHeight;
            if (exitHeight > seenExitHeight[bondId]) _violate("an exit height moved later");
            seenExitHeight[bondId] = exitHeight;
            if (ghostForfeited[bondId] && !staking.forfeited(bondId)) {
                _violate("a forfeiture flag was cleared");
            }
        }
    }

    /// @dev Records a violation if a call the model rejects succeeded.
    function _checkAccepted(string memory _action, bytes4 _expected) internal {
        if (_expected != 0) {
            _violate(string.concat(_action, ": accepted a call the model rejects"));
        }
    }

    /// @dev Records a violation unless the call reverted with exactly the predicted error.
    function _checkRejected(
        string memory _action,
        bytes4 _expected,
        bytes memory _reason
    )
        internal
    {
        ++rejected;
        if (_expected == 0) {
            _violate(string.concat(_action, ": rejected a call the model accepts"));
        } else if (_reason.length != 4 || bytes4(_reason) != _expected) {
            _violate(string.concat(_action, ": rejected with the wrong error"));
        }
    }

    /// @dev A pseudo-random word derived from `_seed` and `_index`.
    function _rand(uint256 _seed, uint256 _index) internal pure returns (uint256) {
        return uint256(keccak256(abi.encode(_seed, _index)));
    }

    /// @dev Counts a violation, keeping the first one's reason.
    function _violate(string memory _reason) internal {
        if (violations++ == 0) firstViolation = _reason;
    }
}
