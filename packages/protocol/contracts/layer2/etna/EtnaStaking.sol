// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { IEtnaStaking } from "./iface/IEtnaStaking.sol";
import { LibCometVote } from "./libs/LibCometVote.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import { LibBit } from "solady/src/utils/LibBit.sol";
import { EssentialContract } from "src/shared/common/EssentialContract.sol";
import { LibEtnaKeys } from "src/shared/etna/LibEtnaKeys.sol";

import "./EtnaStaking_Layout.sol"; // DO NOT DELETE

/// @title EtnaStaking
/// @notice The L2 staking contract of an Etna chain; see `IEtnaStaking`.
/// @dev All state lives in the ERC-7201 namespace `taiko.etna.staking` with base slot T (spec
/// appendix B). Nodes and guests read only T (`snapshotHeight`), T + 1 (`snapshotTotalStake`),
/// the live key-to-seat mapping at T + 2 and the 128 snapshot seat records at T + 3 to T + 258;
/// the bond records, the seat table, the miss counts and the forfeiture flags that follow are
/// this contract's own. Only `onBlockStart` writes the snapshot words. The key-to-seat mapping,
/// the seat table and the occupancy bitmap are live: every call that takes or releases a seat
/// updates them in that call. No entry point is affected by pause.
/// @custom:security-contact security@taiko.xyz
contract EtnaStaking is EssentialContract, IEtnaStaking {
    using SafeERC20 for IERC20;

    // ---------------------------------------------------------------
    // Structs
    // ---------------------------------------------------------------

    /// @dev A key's live seat, packed from the least-significant bit as [holdsSeat (8 bits),
    /// seat (8 bits)]. Every key whose bond holds no seat maps to the zero word.
    struct SeatRef {
        bool holdsSeat;
        uint8 seat;
    }

    /// @dev A candidate snapshot seat record: word 1 is `ckX` and word 2 packs [ckPrefix
    /// (8 bits), power (64 bits)] from the least-significant bit with the other bits zero. Both
    /// words are zero for an empty seat.
    struct SnapshotRecord {
        bytes32 ckX;
        uint8 ckPrefix;
        uint64 power;
    }

    /// @custom:storage-location erc7201:taiko.etna.staking
    struct StakingStorage {
        /// @dev Slot T: the block number of the last snapshot.
        uint256 snapshotHeight;
        /// @dev Slot T + 1: the sum of the effStake of the bonds in the snapshot records.
        uint256 snapshotTotalStake;
        /// @dev Slot T + 2: the live seat of every consensus key address.
        mapping(address ckAddr => SeatRef seatRef) keySeat;
        /// @dev Slots T + 3 to T + 258: the snapshot seat records, record s at T + 3 + 2s.
        SnapshotRecord[128] records;
        /// @dev Slot T + 259: bond id + 1 of every consensus key address ever registered.
        mapping(address ckAddr => uint256 bondIdPlusOne) keyBond;
        /// @dev Slot T + 260: the bond records, three words each.
        mapping(uint256 bondId => Bond bond) bonds;
        /// @dev Slot T + 261: the number of bonds issued, the next bond id.
        uint256 bondCount;
        /// @dev Slots T + 262 to T + 389: bond id + 1 of the bond in each seat; 0 if empty.
        uint256[128] seatBond;
        /// @dev Slots T + 390 to T + 397: each seat's count of consecutive missed signatures.
        uint16[128] missCounts;
        /// @dev Slot T + 398, bits 0-127: bit s is set while a bond holds seat s.
        uint128 occupied;
        /// @dev Slot T + 398, bits 128-175: the generation `onBlockStart` last stored.
        uint48 lastGeneration;
        /// @dev Slot T + 399: the lifetime forfeiture flag of every bond id.
        mapping(uint256 bondId => bool forfeited) forfeited;
    }

    // ---------------------------------------------------------------
    // Constants
    // ---------------------------------------------------------------

    /// @notice The `exitHeight` of a bond with no exit set.
    uint48 public constant NO_EXIT = type(uint48).max;

    /// @notice The only caller of `onBlockStart`.
    address public constant SYSTEM_CALLER = 0xffffFFFfFFffffffffffffffFfFFFfffFFFfFFfE;

    /// @notice The number of snapshot seat records, and the largest `nMax`.
    uint256 public constant MAX_SEATS = 128;

    /// @dev `erc7201("taiko.etna.staking")`: the base slot T of `StakingStorage`.
    bytes32 private constant _STORAGE_SLOT =
        0x5cfa9ae4fa3ccb6db5189dbaff84335bb566ebd2f7442638272a1d81ccb19e00;

    /// @dev TAIKO's fixed total supply in base units; `minStake * nMax` must reach it.
    uint256 private constant _TAIKO_SUPPLY = 10 ** 27;

    /// @dev The least `vpUnit`: ceil(10^27 / floor((2^63 - 1) / 8)), so that the power of all
    /// seated bonds together stays within CometBFT's total voting power limit.
    uint256 private constant _MIN_VP_UNIT = 867_361_738;

    /// @dev The basis points of a whole stake.
    uint256 private constant _BPS = 10_000;

    /// @dev `withdrawalDelay` counts L2 blocks and must be below this bound, the range of the
    /// 48-bit block numbers that `exitHeight` holds.
    uint256 private constant _DELAY_BOUND = 2 ** 48;

    /// @dev The EIP-712 domain type hash.
    bytes32 private constant _DOMAIN_TYPEHASH = keccak256(
        "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
    );

    /// @dev The hash of the EIP-712 domain name "EtnaStaking".
    bytes32 private constant _NAME_HASH = keccak256("EtnaStaking");

    /// @dev The hash of the EIP-712 domain version "1".
    bytes32 private constant _VERSION_HASH = keccak256("1");

    /// @dev The EIP-712 type hash of `Register(address owner)`.
    bytes32 private constant _REGISTER_TYPEHASH = keccak256("Register(address owner)");

    // ---------------------------------------------------------------
    // Immutable Variables
    // ---------------------------------------------------------------

    /// @inheritdoc IEtnaStaking
    address public immutable override token;

    /// @inheritdoc IEtnaStaking
    uint256 public immutable override l1ChainId;

    /// @inheritdoc IEtnaStaking
    address public immutable override inbox;

    /// @inheritdoc IEtnaStaking
    uint256 public immutable override minStake;

    /// @inheritdoc IEtnaStaking
    uint256 public immutable override vpUnit;

    /// @inheritdoc IEtnaStaking
    uint256 public immutable override nMax;

    /// @inheritdoc IEtnaStaking
    uint256 public immutable override missLimit;

    /// @inheritdoc IEtnaStaking
    uint256 public immutable override missSlashBps;

    /// @inheritdoc IEtnaStaking
    uint256 public immutable override missReleaseLimit;

    /// @inheritdoc IEtnaStaking
    uint256 public immutable override withdrawalDelay;

    /// @inheritdoc IEtnaStaking
    uint256 public immutable override slashBountyBps;

    /// @inheritdoc IEtnaStaking
    address public immutable override slashSink;

    /// @inheritdoc IEtnaStaking
    uint256 public immutable override forfeitBps;

    // ---------------------------------------------------------------
    // Constructor
    // ---------------------------------------------------------------

    /// @notice Sets the staking contract's immutable parameters.
    /// @param _config The configuration: nonzero token, inbox, slash sink and L1 chain id;
    /// a slash sink other than the token; 1 <= nMax <= 128; vpUnit >= 867,361,738;
    /// minStake >= vpUnit and minStake * nMax >= 10^27; 1 <= missLimit <= missReleaseLimit <=
    /// 65,535; 0 < missSlashBps <= 10,000; slashBountyBps < 10,000; 0 < forfeitBps <= 10,000;
    /// and 0 < withdrawalDelay < 2^48.
    constructor(Config memory _config) {
        require(
            _config.token != address(0) && _config.inbox != address(0)
                && _config.slashSink != address(0) && _config.l1ChainId != 0,
            InvalidConfig()
        );
        require(_config.slashSink != _config.token, SlashSinkIsToken());
        require(_config.nMax != 0 && _config.nMax <= MAX_SEATS, InvalidConfig());
        require(_config.vpUnit >= _MIN_VP_UNIT, InvalidConfig());
        require(_config.minStake >= _config.vpUnit, InvalidConfig());
        // minStake * nMax >= 10^27, written as minStake >= ceil(10^27 / nMax) to avoid overflow.
        require(
            _config.minStake >= (_TAIKO_SUPPLY + _config.nMax - 1) / _config.nMax, InvalidConfig()
        );
        require(
            _config.missLimit != 0 && _config.missLimit <= _config.missReleaseLimit
                && _config.missReleaseLimit <= type(uint16).max,
            InvalidConfig()
        );
        require(_config.missSlashBps != 0 && _config.missSlashBps <= _BPS, InvalidConfig());
        require(_config.slashBountyBps < _BPS, InvalidConfig());
        require(_config.forfeitBps != 0 && _config.forfeitBps <= _BPS, InvalidConfig());
        require(
            _config.withdrawalDelay != 0 && _config.withdrawalDelay < _DELAY_BOUND, InvalidConfig()
        );

        token = _config.token;
        l1ChainId = _config.l1ChainId;
        inbox = _config.inbox;
        minStake = _config.minStake;
        vpUnit = _config.vpUnit;
        nMax = _config.nMax;
        missLimit = _config.missLimit;
        missSlashBps = _config.missSlashBps;
        missReleaseLimit = _config.missReleaseLimit;
        withdrawalDelay = _config.withdrawalDelay;
        slashBountyBps = _config.slashBountyBps;
        slashSink = _config.slashSink;
        forfeitBps = _config.forfeitBps;
    }

    // ---------------------------------------------------------------
    // External & Public Functions
    // ---------------------------------------------------------------

    /// @notice Initializes the owner, the DAO's execution address on L2.
    /// @param _owner The owner; `msg.sender` if zero.
    function init(address _owner) external initializer {
        __Essential_init(_owner);
    }

    /// @inheritdoc IEtnaStaking
    /// @dev Checks in order: the stake, the key, the proof of possession, the key's first use and
    /// an empty seat. The stake is pulled last.
    function register(
        bytes calldata _publicKey,
        uint256 _amount,
        bytes calldata _popSig
    )
        external
        nonReentrant
        returns (uint256 bondId_)
    {
        require(_amount >= minStake, StakeTooLow());
        (uint8 prefix, bytes32 x, bytes32 y) = LibEtnaKeys.parsePublicKey(_publicKey);
        address ckAddr = LibEtnaKeys.ckAddr(x, y);
        // The digest names the caller, so a copied transaction cannot change the owner.
        require(
            LibEtnaKeys.recoverSigner(registerDigest(msg.sender), _popSig) == ckAddr,
            LibEtnaKeys.InvalidSignature()
        );

        bondId_ = _issueBond(prefix, x, ckAddr, _amount);
        IERC20(token).safeTransferFrom(msg.sender, address(this), _amount);
    }

    /// @inheritdoc IEtnaStaking
    /// @dev Checks in order: issuance, withdrawal, the owner, the exit and the amount. The stake
    /// is pulled last.
    function topUp(uint256 _bondId, uint256 _amount) external nonReentrant {
        StakingStorage storage $ = _stakingStorage();
        Bond storage bond = _ownedBond($, _bondId);
        require(bond.exitHeight == NO_EXIT, ExitAlreadySet());
        require(_amount != 0, ZeroAmount());

        uint256 effStake = bond.effStake + _amount;
        bond.effStake = effStake;
        emit TopUpDeposited(_bondId, _amount);
        if (!bond.holdsSeat && effStake >= minStake) {
            emit SeatTaken(_bondId, _takeSeat($, _bondId, bond, _ckAddrOf(bond)));
        }
        IERC20(token).safeTransferFrom(msg.sender, address(this), _amount);
    }

    /// @inheritdoc IEtnaStaking
    /// @dev Checks in order: issuance, withdrawal, the owner, the exit and the block number.
    function requestExit(uint256 _bondId) external nonReentrant {
        StakingStorage storage $ = _stakingStorage();
        Bond storage bond = _ownedBond($, _bondId);
        require(bond.exitHeight == NO_EXIT, ExitAlreadySet());
        require(block.number < NO_EXIT, InvalidExitHeight());

        bond.exitHeight = uint48(block.number);
        emit ExitRequested(_bondId, block.number);
        if (bond.holdsSeat) emit SeatReleased(_bondId, _releaseSeat($, bond, _ckAddrOf(bond)));
    }

    /// @inheritdoc IEtnaStaking
    /// @dev Checks in order: issuance, withdrawal, the exit and the delay, then, only for a
    /// positive balance, the owner and the recipient. A bond with an exit set holds no seat, so
    /// withdrawal releases none. With a zero balance nothing is paid and `Withdrawn` names the
    /// zero address, not a recipient the caller picked. The stake is paid last.
    function withdraw(uint256 _bondId, address _to) external nonReentrant {
        Bond storage bond = _unwithdrawnBond(_stakingStorage(), _bondId);
        uint256 exitHeight = bond.exitHeight;
        require(exitHeight != NO_EXIT, ExitNotSet());
        require(block.number >= exitHeight + withdrawalDelay, WithdrawalNotReady());
        uint256 amount = bond.effStake;
        if (amount != 0) {
            require(bond.owner == msg.sender, NotBondOwner());
            require(_to != address(0), InvalidRecipient());
        }

        bond.owner = address(0);
        bond.withdrawn = true;
        bond.effStake = 0;
        if (amount == 0) {
            emit Withdrawn(_bondId, address(0), 0);
        } else {
            emit Withdrawn(_bondId, _to, amount);
            IERC20(token).safeTransfer(_to, amount);
        }
    }

    /// @inheritdoc IEtnaStaking
    /// @dev Checks in order: both votes' ranges, the double sign, the generation, issuance,
    /// withdrawal, the stake and the signatures. Reads no Inbox state and takes no Inbox lock:
    /// the Inbox enters only as the immutable the chain domain binds, so votes signed before the
    /// Inbox was initialized are evidence too. The bounty and the rest are paid last, and a zero
    /// bounty makes no transfer.
    function slashDoubleSign(
        uint256 _bondId,
        Vote calldata _voteA,
        Vote calldata _voteB
    )
        external
        nonReentrant
    {
        Vote memory a = _voteA;
        Vote memory b = _voteB;
        LibCometVote.checkRanges(a);
        LibCometVote.checkRanges(b);
        require(
            a.voteType == b.voteType && a.height == b.height && a.round == b.round
                && a.generation == b.generation && !LibCometVote.sameBlockId(a, b),
            NotDoubleSign()
        );
        StakingStorage storage $ = _stakingStorage();
        require(a.generation <= $.lastGeneration, FutureGeneration());
        Bond storage bond = _unwithdrawnBond($, _bondId);
        uint256 slashed = bond.effStake;
        require(slashed != 0, NothingToSlash());

        // The L1 chain id comes first and the L2 chain id, this chain's, second.
        bytes memory cometChainId = LibCometVote.chainId(
            LibCometVote.chainDomain(l1ChainId, block.chainid, inbox, a.generation)
        );
        address signer = _voteSigner(a, cometChainId);
        require(
            _voteSigner(b, cometChainId) == signer && $.keyBond[signer] == _bondId + 1,
            LibEtnaKeys.InvalidSignature()
        );

        bond.effStake = 0;
        _forceExit(bond);
        uint256 bounty = Math.mulDiv(slashed, slashBountyBps, _BPS);
        emit DoubleSignSlashed(
            _bondId, msg.sender, slashed, bounty, a.generation, a.height, a.round, a.voteType
        );
        // Registration mapped the signer, the bond's key address, to this bond, so the seat is
        // released without decompressing the stored key.
        if (bond.holdsSeat) emit SeatReleased(_bondId, _releaseSeat($, bond, signer));

        if (bounty != 0) IERC20(token).safeTransfer(msg.sender, bounty);
        IERC20(token).safeTransfer(slashSink, slashed - bounty);
    }

    /// @inheritdoc IEtnaStaking
    /// @dev Checks in order: issuance, withdrawal, the flag, the deadline and the stake. The
    /// balance, the flag, the exit and the seat change before the penalty is paid.
    function forfeit(
        uint256 _bondId,
        bytes32 _incidentId,
        uint256 _validUntil
    )
        external
        onlyOwner
        nonReentrant
    {
        StakingStorage storage $ = _stakingStorage();
        Bond storage bond = _unwithdrawnBond($, _bondId);
        require(!$.forfeited[_bondId], AlreadyForfeited());
        require(block.timestamp <= _validUntil, AuthorizationExpired());
        uint256 balance = bond.effStake;
        require(balance != 0, NothingToForfeit());

        // forfeitBps <= 10,000, so the penalty never exceeds the balance.
        uint256 penalty = Math.mulDiv(balance, forfeitBps, _BPS, Math.Rounding.Up);
        bond.effStake = balance - penalty;
        $.forfeited[_bondId] = true;
        _forceExit(bond);
        emit Forfeited(_bondId, _incidentId, balance, penalty);
        if (bond.holdsSeat) emit SeatReleased(_bondId, _releaseSeat($, bond, _ckAddrOf(bond)));

        IERC20(token).safeTransfer(slashSink, penalty);
    }

    /// @inheritdoc IEtnaStaking
    /// @dev Three passes over the seats, in the interface's order: the miss counts, the penalties
    /// with the releases, and the snapshot. The penalties of the call reach slashSink in one
    /// transfer, made last.
    function onBlockStart(uint48 _generation, uint128 _missBitmap) external nonReentrant {
        require(msg.sender == SYSTEM_CALLER, NotSystemCaller());
        StakingStorage storage $ = _stakingStorage();
        $.lastGeneration = _generation;

        _countMisses($, _missBitmap);
        uint256 penalties = _penalizeAndRelease($);
        _writeSnapshot($);
        if (penalties != 0) IERC20(token).safeTransfer(slashSink, penalties);
    }

    /// @inheritdoc IEtnaStaking
    function bondForKey(address _ckAddr) external view returns (bool registered_, uint256 bondId_) {
        return _lookup(_stakingStorage().keyBond[_ckAddr]);
    }

    /// @inheritdoc IEtnaStaking
    function seatOfBond(uint256 _bondId) external view returns (bool holdsSeat_, uint8 seat_) {
        // An unissued id's record is never written, so it holds no seat.
        Bond storage bond = _stakingStorage().bonds[_bondId];
        if (bond.holdsSeat) return (true, bond.seat);
    }

    /// @inheritdoc IEtnaStaking
    function bondInSeat(uint8 _seat) external view returns (bool occupied_, uint256 bondId_) {
        if (_seat < nMax) return _lookup(_stakingStorage().seatBond[_seat]);
    }

    /// @inheritdoc IEtnaStaking
    function snapshot()
        external
        view
        returns (uint256 height_, uint256 totalStake_, SeatMember[] memory members_)
    {
        StakingStorage storage $ = _stakingStorage();
        height_ = $.snapshotHeight;
        totalStake_ = $.snapshotTotalStake;
        members_ = new SeatMember[](MAX_SEATS);
        uint256 count;
        for (uint256 seat; seat < MAX_SEATS; ++seat) {
            SnapshotRecord memory record = $.records[seat];
            if (record.ckX == 0 && record.ckPrefix == 0 && record.power == 0) continue;
            members_[count++] = SeatMember({
                seat: uint8(seat), ckPrefix: record.ckPrefix, ckX: record.ckX, power: record.power
            });
        }
        // Shrinks the array to the occupied records.
        assembly ("memory-safe") {
            mstore(members_, count)
        }
    }

    /// @inheritdoc IEtnaStaking
    function bondCount() external view returns (uint256) {
        return _stakingStorage().bondCount;
    }

    /// @inheritdoc IEtnaStaking
    function bondAt(uint256 _bondId) external view returns (Bond memory) {
        // An unissued id's record is never written, so it reads as the zero bond.
        return _stakingStorage().bonds[_bondId];
    }

    /// @inheritdoc IEtnaStaking
    function forfeited(uint256 _bondId) external view returns (bool) {
        return _stakingStorage().forfeited[_bondId];
    }

    /// @inheritdoc IEtnaStaking
    function missCount(uint8 _seat) external view returns (uint16) {
        return _seat < MAX_SEATS ? _stakingStorage().missCounts[_seat] : 0;
    }

    /// @inheritdoc IEtnaStaking
    function lastGeneration() external view returns (uint48) {
        return _stakingStorage().lastGeneration;
    }

    /// @inheritdoc IEtnaStaking
    function registerDigest(address _owner) public view returns (bytes32) {
        bytes32 domainSeparator = keccak256(
            abi.encode(_DOMAIN_TYPEHASH, _NAME_HASH, _VERSION_HASH, block.chainid, address(this))
        );
        bytes32 structHash = keccak256(abi.encode(_REGISTER_TYPEHASH, _owner));
        return keccak256(abi.encodePacked(hex"1901", domainSeparator, structHash));
    }

    // ---------------------------------------------------------------
    // Private Functions
    // ---------------------------------------------------------------

    /// @dev Returns the staking storage at T.
    /// @return $ The staking storage.
    function _stakingStorage() private pure returns (StakingStorage storage $) {
        assembly {
            $.slot := _STORAGE_SLOT
        }
    }

    /// @dev Returns an issued bond that was not withdrawn. Reverts with `UnknownBond` for an
    /// unissued id before reading the bond, and with `BondWithdrawn` for a withdrawn bond.
    /// @param $ The staking storage.
    /// @param _bondId The bond id.
    /// @return bond_ The bond.
    function _unwithdrawnBond(
        StakingStorage storage $,
        uint256 _bondId
    )
        private
        view
        returns (Bond storage bond_)
    {
        require(_bondId < $.bondCount, UnknownBond());
        bond_ = $.bonds[_bondId];
        require(!bond_.withdrawn, BondWithdrawn());
    }

    /// @dev Returns an issued, unwithdrawn bond that the caller owns; reverts as
    /// `_unwithdrawnBond` does, then with `NotBondOwner`.
    /// @param $ The staking storage.
    /// @param _bondId The bond id.
    /// @return bond_ The bond.
    function _ownedBond(
        StakingStorage storage $,
        uint256 _bondId
    )
        private
        view
        returns (Bond storage bond_)
    {
        bond_ = _unwithdrawnBond($, _bondId);
        require(bond_.owner == msg.sender, NotBondOwner());
    }

    /// @dev Issues the next bond id to a key never registered before, reverting with
    /// `KeyAlreadyUsed` otherwise, records the bond with the caller as its owner, no exit and
    /// effStake `_amount`, seats it and emits `Registered`.
    /// @param _ckPrefix The key's SEC1 prefix.
    /// @param _ckX The key's X coordinate.
    /// @param _ckAddr The key's address.
    /// @param _amount The stake, at least minStake.
    /// @return bondId_ The new bond id.
    function _issueBond(
        uint8 _ckPrefix,
        bytes32 _ckX,
        address _ckAddr,
        uint256 _amount
    )
        private
        returns (uint256 bondId_)
    {
        StakingStorage storage $ = _stakingStorage();
        require($.keyBond[_ckAddr] == 0, KeyAlreadyUsed());
        bondId_ = $.bondCount++;
        $.keyBond[_ckAddr] = bondId_ + 1;
        Bond storage bond = $.bonds[bondId_];
        bond.owner = msg.sender;
        bond.ckPrefix = _ckPrefix;
        bond.exitHeight = NO_EXIT;
        bond.ckX = _ckX;
        bond.effStake = _amount;
        uint8 seat = _takeSeat($, bondId_, bond, _ckAddr);
        emit Registered(bondId_, msg.sender, _ckAddr, _ckPrefix, _ckX, _amount, seat);
    }

    /// @dev Gives a seatless bond the lowest empty seat and resets the seat's miss count; reverts
    /// with `NoEmptySeat` if every seat is held. Moves no other bond.
    /// @param $ The staking storage.
    /// @param _bondId The bond id.
    /// @param _bond The bond, which holds no seat.
    /// @param _ckAddr The bond's consensus key address.
    /// @return seat_ The seat taken.
    function _takeSeat(
        StakingStorage storage $,
        uint256 _bondId,
        Bond storage _bond,
        address _ckAddr
    )
        private
        returns (uint8 seat_)
    {
        uint256 occupied = $.occupied;
        // nMax <= 128, so the mask of the seats fits in 256 bits.
        uint256 empty = ~occupied & ((uint256(1) << nMax) - 1);
        require(empty != 0, NoEmptySeat());
        seat_ = uint8(LibBit.ffs(empty));

        $.occupied = uint128(occupied | uint256(1) << seat_);
        $.seatBond[seat_] = _bondId + 1;
        $.keySeat[_ckAddr] = SeatRef({ holdsSeat: true, seat: seat_ });
        $.missCounts[seat_] = 0;
        _bond.holdsSeat = true;
        _bond.seat = seat_;
    }

    /// @dev Releases a bond's seat: clears the seat table entry, the occupancy bit, the key's
    /// key-to-seat word (to zero) and the seat's miss count. Emits nothing.
    /// @param $ The staking storage.
    /// @param _bond The bond, which holds a seat.
    /// @param _ckAddr The bond's consensus key address.
    /// @return seat_ The seat released.
    function _releaseSeat(
        StakingStorage storage $,
        Bond storage _bond,
        address _ckAddr
    )
        private
        returns (uint8 seat_)
    {
        seat_ = _bond.seat;
        $.occupied &= ~uint128(uint256(1) << seat_);
        delete $.seatBond[seat_];
        delete $.keySeat[_ckAddr];
        delete $.missCounts[seat_];
        _bond.holdsSeat = false;
        _bond.seat = 0;
    }

    /// @dev Counts misses: raises the miss count of each occupied seat whose bit in `_missBitmap`
    /// is set by one and resets the count of every other occupied seat to zero. Only occupied
    /// seats, all below nMax, are visited, so the other bits change nothing.
    /// @param $ The staking storage.
    /// @param _missBitmap The block's missed-signature bitmap; bit s is seat s.
    function _countMisses(StakingStorage storage $, uint128 _missBitmap) private {
        for (uint256 seats = $.occupied; seats != 0; seats &= seats - 1) {
            uint256 seat = LibBit.ffs(seats);
            // A seat whose count reaches missReleaseLimit is released in the same call, so between
            // calls every occupied seat's count is at most missReleaseLimit - 1 <= 65,534 and the
            // increment fits in 16 bits.
            $.missCounts[seat] = ((_missBitmap >> seat) & 1) == 1 ? $.missCounts[seat] + 1 : 0;
        }
    }

    /// @dev Penalizes each seated bond whose seat's miss count is a positive multiple of
    /// missLimit, deducting ceil(effStake * missSlashBps / 10,000) from its effStake and leaving
    /// the count as it is. Then a bond releases its seat if the penalty left it below minStake or
    /// if its seat's count reached missReleaseLimit, with no exit set, nothing more deducted and
    /// no event; the release discards the count. Visits a copy of the occupancy bits, so the
    /// releases do not disturb the loop.
    /// @param $ The staking storage.
    /// @return total_ The sum of the penalties, owed to slashSink.
    function _penalizeAndRelease(StakingStorage storage $) private returns (uint256 total_) {
        for (uint256 seats = $.occupied; seats != 0; seats &= seats - 1) {
            uint256 seat = LibBit.ffs(seats);
            uint256 count = $.missCounts[seat];
            // missLimit <= missReleaseLimit, so a smaller count neither penalizes nor releases.
            if (count < missLimit) continue;
            Bond storage bond = $.bonds[$.seatBond[seat] - 1];
            uint256 effStake = bond.effStake;
            if (count % missLimit == 0) {
                // missSlashBps <= 10,000, so the penalty never exceeds effStake.
                uint256 penalty = Math.mulDiv(effStake, missSlashBps, _BPS, Math.Rounding.Up);
                effStake -= penalty;
                bond.effStake = effStake;
                total_ += penalty;
            }
            // A seated bond holds at least minStake, so only this call's penalty leaves it below.
            if (effStake < minStake || count >= missReleaseLimit) {
                _releaseSeat($, bond, _ckAddrOf(bond));
            }
        }
    }

    /// @dev Writes the candidate snapshot from the seat table: record s, for each s below nMax,
    /// holds the key and power floor(effStake / vpUnit) of the bond in seat s, or zero for an
    /// empty seat. Records at or above nMax are never written, so they stay zero. Then writes the
    /// seated bonds' effStake total and the height. Reverts, failing the whole call, if a power
    /// does not fit in 64 bits.
    /// @param $ The staking storage.
    function _writeSnapshot(StakingStorage storage $) private {
        uint256 occupied = $.occupied;
        uint256 totalStake;
        for (uint256 seat; seat < nMax; ++seat) {
            if (((occupied >> seat) & 1) == 0) {
                delete $.records[seat];
                continue;
            }
            Bond storage bond = $.bonds[$.seatBond[seat] - 1];
            uint256 effStake = bond.effStake;
            totalStake += effStake;
            $.records[seat] = SnapshotRecord({
                ckX: bond.ckX, ckPrefix: bond.ckPrefix, power: SafeCast.toUint64(effStake / vpUnit)
            });
        }
        $.snapshotTotalStake = totalStake;
        $.snapshotHeight = block.number;
    }

    /// @dev Sets a bond's exit height to min(exitHeight, block.number): an exit at the current
    /// block if none is set, and an earlier exit kept.
    /// @param _bond The bond.
    function _forceExit(Bond storage _bond) private {
        // exitHeight <= 2^48 - 1, so a block number below it fits in 48 bits.
        if (block.number < _bond.exitHeight) _bond.exitHeight = uint48(block.number);
    }

    /// @dev Returns the address that signed a vote: the signer of keccak256 of its sign bytes
    /// under `_cometChainId`. Reverts with `LibEtnaKeys.InvalidSignature` as
    /// `LibEtnaKeys.recoverSigner` does.
    /// @param _vote The vote.
    /// @param _cometChainId The CometBFT chain id the vote must be signed under.
    /// @return The signer, never zero.
    function _voteSigner(
        Vote memory _vote,
        bytes memory _cometChainId
    )
        private
        pure
        returns (address)
    {
        return LibEtnaKeys.recoverSigner(
            keccak256(LibCometVote.signBytes(_vote, _cometChainId)), _vote.signature
        );
    }

    /// @dev Returns a bond's consensus key address, decompressing its stored key. Registration
    /// validated the key, so this reverts only for lack of gas, such as a modexp precompile call
    /// that runs out of it, never for the key itself.
    /// @param _bond The bond.
    /// @return The key address.
    function _ckAddrOf(Bond storage _bond) private view returns (address) {
        bytes32 x = _bond.ckX;
        return LibEtnaKeys.ckAddr(x, LibEtnaKeys.decompress(_bond.ckPrefix, x));
    }

    /// @dev Decodes a stored bond id + 1.
    /// @param _bondIdPlusOne The stored value; 0 if none.
    /// @return found_ Whether it names a bond.
    /// @return bondId_ The bond id; 0 if none.
    function _lookup(uint256 _bondIdPlusOne) private pure returns (bool found_, uint256 bondId_) {
        if (_bondIdPlusOne != 0) return (true, _bondIdPlusOne - 1);
    }
}
