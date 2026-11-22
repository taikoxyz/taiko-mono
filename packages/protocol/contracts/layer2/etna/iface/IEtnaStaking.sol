// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/// @title IEtnaStaking
/// @notice The L2 staking contract the Etna candidate validator set comes from (spec 4.1, 4.2).
/// @dev Section numbers refer to the Etna specification. Validators register a secp256k1
/// consensus key with a stake of the bridged TAIKO token on L2. Each registration issues a new
/// bond id, counting up from 0 and never reused. A bond holds one of `nMax` seats exactly while it
/// is issued and unwithdrawn, has no exit set and has effStake >= minStake: it takes the lowest
/// empty seat in the call that makes it meet these conditions, never moving another bond, and
/// releases the seat in the call that ends one of them. At the start of every Etna block the
/// execution layer calls `onBlockStart` from the system caller, which counts missed signatures,
/// applies their penalties and writes the candidate snapshot. Nodes and guests read the snapshot
/// and the live key-to-seat mapping from storage under the ERC-7201 namespace
/// `taiko.etna.staking` (spec appendix B), not through this interface. The interface has no
/// imports, so clients can copy it.
/// @custom:security-contact security@taiko.xyz
interface IEtnaStaking {
    // ---------------------------------------------------------------
    // Structs
    // ---------------------------------------------------------------

    /// @notice The immutable parameters of a staking implementation (spec 11).
    struct Config {
        /// @notice The staking token, the bridged TAIKO token on L2; nonzero.
        address token;
        /// @notice The L1 chain id, which the double-sign chain domain binds; nonzero.
        uint256 l1ChainId;
        /// @notice The Etna Inbox proxy on L1, which the double-sign chain domain binds; nonzero.
        address inbox;
        /// @notice The least stake of a registration and the least effStake of a seated bond, in
        /// token base units; at least `vpUnit`, and `minStake * nMax` is at least 10^27, TAIKO's
        /// fixed total supply, so a bond that comes to meet the seat conditions finds an empty
        /// seat.
        uint256 minStake;
        /// @notice The token base units per unit of voting power; at least 867,361,738, so the
        /// power of all seated bonds together stays within CometBFT's limit.
        uint256 vpUnit;
        /// @notice The number of seats, in [1, 128].
        uint256 nMax;
        /// @notice The consecutive missed signatures at which a seated bond is penalized, in
        /// [1, 65,535].
        uint256 missLimit;
        /// @notice The missed-signature penalty in basis points of effStake, in [1, 10,000].
        uint256 missSlashBps;
        /// @notice The L2 blocks from a bond's exit height until it can be withdrawn, in
        /// [1, 2^48). Deployment also requires at least U + 2 + the double-sign evidence window;
        /// U is an L1 Inbox value, so the deployment tooling checks that bound, not the
        /// constructor.
        uint256 withdrawalDelay;
        /// @notice The share of a double-sign slash paid to the reporter, in basis points; below
        /// 10,000 (zero is allowed).
        uint256 slashBountyBps;
        /// @notice The receiver of every slashed stake minus the bounty, of every missed-signature
        /// penalty and of every forfeiture penalty; nonzero.
        address slashSink;
        /// @notice The responsibility-forfeiture rate in basis points, in [1, 10,000].
        uint256 forfeitBps;
    }

    /// @notice A CometBFT vote submitted as double-sign evidence (spec 4.1, appendix A).
    struct Vote {
        /// @notice The vote type: 1 for prevote, 2 for precommit.
        uint8 voteType;
        /// @notice The L2 height, in [1, 2^63).
        uint64 height;
        /// @notice The consensus round, below 2^31.
        uint32 round;
        /// @notice The CometBFT block id hash (the vote's `hash` in spec appendix A), not an EL
        /// block hash: empty or exactly 32 bytes, including all-zero bytes.
        /// @dev A nil vote has both hashes empty and partsTotal zero. `IEtnaInbox` calls the same
        /// kind of value `cometHash` and uses `blockHash` for EL block hashes.
        bytes blockHash;
        /// @notice The part set header total.
        uint32 partsTotal;
        /// @notice The part set header hash: empty or exactly 32 bytes, including all-zero bytes.
        bytes partsHash;
        /// @notice The seconds of the vote timestamp since the Unix epoch: a signed int64 carried
        /// as its 64-bit two's-complement pattern (e.g. -1 is 2^64 - 1). Every value is accepted,
        /// including seconds outside CometBFT's Timestamp range (0001-01-01T00:00:00Z up to
        /// 10000-01-01T00:00:00Z), which stock CometBFT would not sign.
        uint64 timestampSeconds;
        /// @notice The nanoseconds of the vote timestamp: a signed int32 carried as its 32-bit
        /// two's-complement pattern (e.g. -1 is 2^32 - 1). Every value is accepted, including
        /// negative nanos and nanos of 10^9 or more, which stock CometBFT would not sign.
        uint32 timestampNanos;
        /// @notice The recovery generation of the chain id the vote is signed under.
        uint48 generation;
        /// @notice The 65-byte signature R ‖ S ‖ V, with V in {0, 1} and S at most n / 2.
        bytes signature;
    }

    /// @notice An occupied record of the candidate snapshot, as `snapshot()` returns it
    /// (appendix A).
    struct SeatMember {
        /// @notice The seat number, below 128.
        uint8 seat;
        /// @notice The SEC1 prefix of the member's consensus key, 0x02 or 0x03.
        uint8 ckPrefix;
        /// @notice The X coordinate of the member's consensus key.
        bytes32 ckX;
        /// @notice The member's voting power, floor(effStake / vpUnit) when the record was
        /// written.
        uint64 power;
    }

    /// @notice A bond's record, kept from registration on, whether or not it holds a seat.
    struct Bond {
        /// @notice The bond owner, the registration's caller; zero once withdrawn.
        address owner;
        /// @notice The SEC1 prefix of the consensus key, 0x02 or 0x03.
        uint8 ckPrefix;
        /// @notice Whether the bond was withdrawn.
        bool withdrawn;
        /// @notice Whether the bond holds `seat`.
        bool holdsSeat;
        /// @notice The seat the bond holds; meaningful only while `holdsSeat` is set.
        uint8 seat;
        /// @notice The L2 block of the exit, set by `requestExit` and moved to at most the current
        /// block by a slash or a forfeiture; 2^48 - 1 while no exit is set.
        uint48 exitHeight;
        /// @notice The X coordinate of the consensus key.
        bytes32 ckX;
        /// @notice The effective stake in token base units, the bond's whole principal; zero once
        /// slashed or withdrawn.
        uint256 effStake;
    }

    // ---------------------------------------------------------------
    // Events
    // ---------------------------------------------------------------

    /// @notice Emitted when a validator registers; the new bond takes `seat` in the same call.
    /// @param bondId The new bond id.
    /// @param owner The bond owner, the caller.
    /// @param ckAddr The consensus key's address, keccak256(ckX ‖ ckY)[12:].
    /// @param ckPrefix The SEC1 prefix of the consensus key.
    /// @param ckX The X coordinate of the consensus key.
    /// @param amount The stake pulled from the owner.
    /// @param seat The seat the bond takes.
    event Registered(
        uint256 indexed bondId,
        address indexed owner,
        address indexed ckAddr,
        uint8 ckPrefix,
        bytes32 ckX,
        uint256 amount,
        uint8 seat
    );

    /// @notice Emitted when an owner adds stake to a bond (spec 4.1).
    /// @param bondId The bond id.
    /// @param amount The added TAIKO base units, part of effStake at once.
    event TopUpDeposited(uint256 indexed bondId, uint256 amount);

    /// @notice Emitted when the bond owner sets an exit.
    /// @param bondId The bond id.
    /// @param exitHeight The exit height, the current L2 block number.
    event ExitRequested(uint256 indexed bondId, uint256 exitHeight);

    /// @notice Emitted when a bond is withdrawn.
    /// @param bondId The bond id.
    /// @param to The recipient of the stake.
    /// @param amount The stake paid out; zero for a bond without balance.
    event Withdrawn(uint256 indexed bondId, address indexed to, uint256 amount);

    /// @notice Emitted when a top-up gives a seatless bond a seat. A registration reports its
    /// seat in `Registered` instead.
    /// @param bondId The bond id.
    /// @param seat The seat the bond takes.
    event SeatTaken(uint256 indexed bondId, uint8 seat);

    /// @notice Emitted when `requestExit`, `slashDoubleSign` or `forfeit` releases a bond's seat.
    /// `onBlockStart` emits no events, so a seat that a missed-signature penalty releases is not
    /// reported.
    /// @param bondId The bond id.
    /// @param seat The seat the bond releases.
    event SeatReleased(uint256 indexed bondId, uint8 seat);

    /// @notice Emitted when double-sign evidence slashes a bond.
    /// @param bondId The bond id.
    /// @param reporter The caller, who receives the bounty.
    /// @param slashed The slashed stake, the bond's whole effStake.
    /// @param bounty The part of `slashed` paid to the reporter.
    /// @param generation The votes' recovery generation.
    /// @param height The votes' height.
    /// @param round The votes' round.
    /// @param voteType The votes' type.
    event DoubleSignSlashed(
        uint256 indexed bondId,
        address indexed reporter,
        uint256 slashed,
        uint256 bounty,
        uint48 generation,
        uint64 height,
        uint32 round,
        uint8 voteType
    );

    /// @notice Emitted when the DAO deducts principal and forces an exit (spec 4.4).
    /// @param bondId The bond id.
    /// @param incidentId The DAO's published attribution identifier; not globally unique.
    /// @param balanceBefore The bond's effStake at execution.
    /// @param penalty The amount sent to slashSink.
    event Forfeited(
        uint256 indexed bondId, bytes32 incidentId, uint256 balanceBefore, uint256 penalty
    );

    // ---------------------------------------------------------------
    // External Functions
    // ---------------------------------------------------------------

    /// @notice Registers a consensus key with a stake pulled from the caller, who becomes the bond
    /// owner; the new bond takes a seat in the same call (spec 4.1).
    /// @dev `_publicKey` is exactly 33 bytes of canonical SEC1 compressed secp256k1 encoding,
    /// prefix 0x02 or 0x03 followed by the 32-byte big-endian X; the contract decompresses it
    /// (appendix A) and rejects any other encoding with `LibEtnaKeys.InvalidPublicKey`. `_popSig`
    /// is exactly 65 bytes R ‖ S ‖ V with V in {0, 1}, 0 < R < n and 0 < S <= n / 2 and must
    /// recover, over `registerDigest(msg.sender)`, to the key's address; any other signature
    /// reverts with `LibEtnaKeys.InvalidSignature`. Requires `_amount >= minStake` (`StakeTooLow`)
    /// and a key address never registered before (`KeyAlreadyUsed`). The bond stores only
    /// `ckPrefix` and `ckX`, has effStake = `_amount` and no exit, and takes the lowest empty
    /// seat, reverting `NoEmptySeat` if every seat is held. A rejected registration issues no bond
    /// id and leaves the key unused.
    /// @param _publicKey The 33-byte compressed consensus key.
    /// @param _amount The stake; the caller must have approved it.
    /// @param _popSig The proof of possession.
    /// @return bondId_ The new bond id.
    function register(
        bytes calldata _publicKey,
        uint256 _amount,
        bytes calldata _popSig
    )
        external
        returns (uint256 bondId_);

    /// @notice Adds stake to a bond's effStake at once (spec 4.1).
    /// @dev Only the bond owner (`NotBondOwner`), for an issued (`UnknownBond`) and unwithdrawn
    /// (`BondWithdrawn`) bond with no exit set (`ExitAlreadySet`), and only a positive `_amount`
    /// (`ZeroAmount`). Transfers `_amount` TAIKO in, rejecting overflow of effStake, and changes
    /// neither owner nor key. A seatless bond that it brings to minStake or more takes the lowest
    /// empty seat in the same call, reverting `NoEmptySeat` if every seat is held. A top-up
    /// cannot be withdrawn separately; it leaves with the rest of the principal, through
    /// `withdraw`.
    /// @param _bondId The bond id.
    /// @param _amount The positive TAIKO base units approved to this contract.
    function topUp(uint256 _bondId, uint256 _amount) external;

    /// @notice Sets a bond's exit at the current L2 block; the bond releases its seat in the same
    /// call (spec 4.1).
    /// @dev Only the bond owner, for an issued, unwithdrawn bond with no exit set
    /// (`ExitAlreadySet`). Reverts `InvalidExitHeight` unless block.number is below 2^48 - 1, the
    /// no-exit value. Once set, the exit height only moves earlier, through a double-sign slash or
    /// a forfeiture.
    /// @param _bondId The bond id.
    function requestExit(uint256 _bondId) external;

    /// @notice Withdraws a bond once the withdrawal delay has passed since its exit (spec 4.1).
    /// @dev Requires an issued, unwithdrawn bond with an exit set (`ExitNotSet`) and
    /// block.number >= exitHeight + withdrawalDelay (`WithdrawalNotReady`). With a positive
    /// effStake only the owner may call it, and all of it is paid to a nonzero `_to`
    /// (`InvalidRecipient`); with zero effStake anyone may call it and nothing is paid. Zeros
    /// effStake, clears the owner and marks the bond withdrawn, keeping its id, key, lifetime key
    /// registration, exit height and forfeiture flag.
    /// @param _bondId The bond id.
    /// @param _to The recipient of the stake.
    function withdraw(uint256 _bondId, address _to) external;

    /// @notice Slashes a bond's whole stake for a same-round double sign (spec 4.1).
    /// @dev Callable by anyone. Both votes are in range (`InvalidVote`) and have the same type,
    /// height, round and generation and different block ids (`NotDoubleSign`), and the generation
    /// is at most `lastGeneration()`, the one `onBlockStart` last stored (`FutureGeneration`).
    /// Both signatures recover, over keccak256 of each vote's sign bytes under the chain id of
    /// `chainDomain(l1ChainId, block.chainid, inbox, generation)` (appendix A), to the same
    /// nonzero address, whose lifetime key lookup `bondForKey` must return exactly
    /// `(true, _bondId)`; anything else reverts with `LibEtnaKeys.InvalidSignature`. No key is
    /// decompressed here. The bond must be issued and unwithdrawn with a positive effStake
    /// (`NothingToSlash`), whether or not it holds a seat. Zeros effStake, sets exitHeight to
    /// min(existing, block.number) and releases the seat, then pays
    /// floor(slashed * slashBountyBps / 10000) to the caller and the rest to slashSink. The owner
    /// or signer may self-report and receives the same bounty.
    /// @param _bondId The bond id.
    /// @param _voteA One vote.
    /// @param _voteB The conflicting vote.
    function slashDoubleSign(
        uint256 _bondId,
        Vote calldata _voteA,
        Vote calldata _voteB
    )
        external;

    /// @notice Deducts a fixed fraction of a bond's principal and forces its exit (spec 4.4).
    /// @dev Only the owner of this contract, the DAO's execution address on L2. Requires an
    /// issued, unwithdrawn bond, `forfeited(_bondId) == false` (`AlreadyForfeited`),
    /// block.timestamp <= `_validUntil` (`AuthorizationExpired`) and a positive effStake
    /// (`NothingToForfeit`), whether or not the bond holds a seat or has an exit set. Deducts
    /// ceil(effStake * forfeitBps / 10000) and sends it to slashSink with no bounty, sets the
    /// lifetime flag and exitHeight = min(existing, block.number), and releases the seat. There is
    /// no nonce, revocation or delay: an unexecuted authorization stays executable until
    /// `_validUntil`.
    /// @param _bondId The bond id, including one with an exit set.
    /// @param _incidentId The published attribution identifier.
    /// @param _validUntil The inclusive deadline, an L2 Unix timestamp in seconds.
    function forfeit(uint256 _bondId, bytes32 _incidentId, uint256 _validUntil) external;

    /// @notice The block-start call: counts missed signatures, applies their penalties and writes
    /// the candidate snapshot (spec 4.2).
    /// @dev Only the system caller 0xfffffffffffffffffffffffffffffffffffffffe
    /// (`NotSystemCaller`), from which the execution layer makes this call at the start of every
    /// Etna block with both arguments taken from the block's extraData. Stores `_generation` as
    /// `lastGeneration()`, then, in order: counts misses, raising the count of each occupied seat
    /// s by one if bit s of `_missBitmap` is set and resetting it to zero otherwise (bits of empty
    /// seats and at or above nMax change nothing); penalizes each seat whose count reached
    /// missLimit: deducts ceil(effStake * missSlashBps / 10000) from the seated bond for
    /// slashSink with no bounty and resets the count to zero, and a bond that this leaves below
    /// minStake also releases its seat, without an exit being set; and writes the 128 snapshot
    /// seat records, `snapshotTotalStake` and `snapshotHeight` = block.number, so the snapshot
    /// already reflects this call's penalties. Only this call writes the snapshot, and it emits
    /// no events. If it reverts, nothing changes and the block stays valid.
    /// @param _generation The block's recovery generation.
    /// @param _missBitmap The block's missed-signature bitmap; bit s is seat s.
    function onBlockStart(uint48 _generation, uint128 _missBitmap) external;

    /// @notice Returns the bond a consensus key address was registered with (appendix A).
    /// @param _ckAddr The consensus key's address.
    /// @return registered_ Whether the key was ever registered; never cleared, not even by
    /// withdrawal.
    /// @return bondId_ The bond id; 0 for an unused key.
    function bondForKey(address _ckAddr) external view returns (bool registered_, uint256 bondId_);

    /// @notice Returns the seat a bond holds (appendix A).
    /// @param _bondId The bond id.
    /// @return holdsSeat_ Whether the bond holds a seat; false for every other id, issued or not.
    /// @return seat_ The seat; 0 if none.
    function seatOfBond(uint256 _bondId) external view returns (bool holdsSeat_, uint8 seat_);

    /// @notice Returns the bond holding a seat (appendix A).
    /// @param _seat The seat.
    /// @return occupied_ Whether a bond holds the seat; false for an empty seat and for a seat
    /// number at or above nMax.
    /// @return bondId_ The bond id; 0 if none.
    function bondInSeat(uint8 _seat) external view returns (bool occupied_, uint256 bondId_);

    /// @notice Returns the candidate snapshot that `onBlockStart` last wrote (spec 4.2).
    /// @dev A convenience view: nodes and guests read the snapshot words from storage
    /// (appendix B).
    /// @return height_ `snapshotHeight`, the whole storage word at the namespace's base slot.
    /// @return totalStake_ `snapshotTotalStake`, the sum of the effStake of the bonds in the
    /// records.
    /// @return members_ The occupied snapshot seat records, in ascending seat order.
    function snapshot()
        external
        view
        returns (uint256 height_, uint256 totalStake_, SeatMember[] memory members_);

    /// @notice Returns the EIP-712 digest a registration's proof of possession signs
    /// (appendix A).
    /// @dev keccak256(0x1901 ‖ domainSeparator ‖ keccak256(abi.encode(keccak256("Register(address
    /// owner)"), _owner))), the domain being name "EtnaStaking", version "1", chainId = the L2
    /// chain id (block.chainid) and verifyingContract = this contract.
    /// @param _owner The bond owner.
    /// @return The digest.
    function registerDigest(address _owner) external view returns (bytes32);

    /// @notice Returns the number of bonds issued, which is the next bond id.
    /// @return The bond count.
    function bondCount() external view returns (uint256);

    /// @notice Returns a bond's record.
    /// @param _bondId The bond id.
    /// @return The bond; all zero for an id never issued.
    function bondAt(uint256 _bondId) external view returns (Bond memory);

    /// @notice Returns a bond id's lifetime forfeiture flag, never reset by withdrawal (spec 4.4).
    /// @param _bondId The bond id.
    /// @return Whether responsibility forfeiture already executed for this bond.
    function forfeited(uint256 _bondId) external view returns (bool);

    /// @notice Returns a seat's count of consecutive missed signatures (spec 4.2).
    /// @param _seat The seat.
    /// @return The miss count; taking a seat resets it to zero.
    function missCount(uint8 _seat) external view returns (uint16);

    /// @notice Returns the generation `onBlockStart` last stored, the upper bound for the
    /// generation of double-sign evidence.
    /// @return The generation; zero before the first call.
    function lastGeneration() external view returns (uint48);

    /// @notice Returns the staking token, the bridged TAIKO token on L2.
    /// @return The token address.
    function token() external view returns (address);

    /// @notice Returns the L1 chain id that the double-sign chain domain binds.
    /// @return The L1 chain id.
    function l1ChainId() external view returns (uint256);

    /// @notice Returns the Etna Inbox proxy on L1 that the double-sign chain domain binds.
    /// @return The Inbox address.
    function inbox() external view returns (address);

    /// @notice Returns the least stake of a registration and the least effStake of a seated bond.
    /// @return The minimum stake in token base units.
    function minStake() external view returns (uint256);

    /// @notice Returns the token base units per unit of voting power.
    /// @return The voting power unit.
    function vpUnit() external view returns (uint256);

    /// @notice Returns the number of seats.
    /// @return The seat count, in [1, 128].
    function nMax() external view returns (uint256);

    /// @notice Returns the consecutive missed signatures at which a seated bond is penalized.
    /// @return The miss limit.
    function missLimit() external view returns (uint256);

    /// @notice Returns the missed-signature penalty in basis points of effStake.
    /// @return The penalty rate.
    function missSlashBps() external view returns (uint256);

    /// @notice Returns the L2 blocks from a bond's exit height until it can be withdrawn.
    /// @return The withdrawal delay.
    function withdrawalDelay() external view returns (uint256);

    /// @notice Returns the reporter's share of a double-sign slash in basis points.
    /// @return The bounty rate.
    function slashBountyBps() external view returns (uint256);

    /// @notice Returns the receiver of slashed stake, penalties and forfeitures.
    /// @return The slash sink.
    function slashSink() external view returns (address);

    /// @notice Returns the responsibility-forfeiture rate in basis points.
    /// @return The forfeiture rate.
    function forfeitBps() external view returns (uint256);

    // ---------------------------------------------------------------
    // Errors
    // ---------------------------------------------------------------

    /// @notice A constructor parameter is zero or out of bounds.
    error InvalidConfig();
    /// @notice The stake is below `minStake`.
    error StakeTooLow();
    /// @notice The consensus key was registered before.
    error KeyAlreadyUsed();
    /// @notice Every seat is held, so a bond that would take one finds none.
    error NoEmptySeat();
    /// @notice The bond id was never issued.
    error UnknownBond();
    /// @notice The caller is not the bond owner.
    error NotBondOwner();
    /// @notice The bond was withdrawn.
    error BondWithdrawn();
    /// @notice The bond already has an exit set.
    error ExitAlreadySet();
    /// @notice The bond has no exit set.
    error ExitNotSet();
    /// @notice The current block number is not below 2^48 - 1, the no-exit value.
    error InvalidExitHeight();
    /// @notice The withdrawal delay has not passed.
    error WithdrawalNotReady();
    /// @notice The top-up amount is zero.
    error ZeroAmount();
    /// @notice The recipient of a positive stake is the zero address.
    error InvalidRecipient();
    /// @notice A vote field is out of range.
    error InvalidVote();
    /// @notice The votes are not a same-round double sign.
    error NotDoubleSign();
    /// @notice The votes' generation is above the one `onBlockStart` last stored.
    error FutureGeneration();
    /// @notice The bond has no stake to slash.
    error NothingToSlash();
    /// @notice The bond has no principal to forfeit.
    error NothingToForfeit();
    /// @notice The bond was already forfeited.
    error AlreadyForfeited();
    /// @notice The authorization's `validUntil` deadline has passed.
    error AuthorizationExpired();
    /// @notice The caller of `onBlockStart` is not the system caller.
    error NotSystemCaller();
}
