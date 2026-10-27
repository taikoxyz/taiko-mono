// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/// @title IEtnaStakingRegistry
/// @notice The TAIKO staking registry the Etna committees are selected from (spec 4.1).
/// @dev Section numbers refer to the Etna specification. Validators register a secp256k1
/// consensus key with a stake; the bond id is the entry's slot, and a released slot is reused by a
/// later registration. Every L1 block that changes an entry ends with one checkpoint holding the
/// slot count and the entries root at the end of that block. Nodes read only `checkpoints` (slot R)
/// and `entries` (slot R + 1) of the ERC-7201 namespace `taiko.etna.registry` with EIP-1186
/// proofs (spec appendix B); every packed word lays its fields out in declaration order from the
/// least-significant bit. The Inbox proxy is fixed at deployment.
/// @custom:security-contact security@taiko.xyz
interface IEtnaStakingRegistry {
    // ---------------------------------------------------------------
    // Structs
    // ---------------------------------------------------------------

    /// @notice The immutable parameters of a registry implementation (spec 11).
    struct Config {
        /// @notice The staked TAIKO token.
        address token;
        /// @notice The minimum stake of a registration in token base units; non-zero.
        uint256 minStake;
        /// @notice The L1 blocks from registration until the entry is active; in [1, 2^32).
        uint256 activationDelay;
        /// @notice The L1 blocks from the exit request, or the activation if later, until the
        /// exit takes effect; in [1, 2^32).
        uint256 exitDelay;
        /// @notice The L1 blocks from the exit confirmation until the slot can be released; in
        /// [1, 2^32).
        uint256 withdrawalDelay;
        /// @notice The share of a slashed stake paid to the reporter, in basis points; at most
        /// 10,000.
        uint256 slashBountyBps;
        /// @notice The receiver of a slashed stake minus the bounty; non-zero.
        address slashSink;
        /// @notice The chain id of the Etna L2; non-zero and equal to the Inbox's.
        uint64 l2ChainId;
        /// @notice The Etna Inbox proxy; must have code.
        address inbox;
    }

    /// @notice The registry at the end of an L1 block that changed an entry (array at slot R, two
    /// words each); the first word packs `l1Block` and `count`.
    struct Checkpoint {
        /// @notice The L1 block.
        uint48 l1Block;
        /// @notice The number of slots used so far, released ones included.
        uint48 count;
        /// @notice The entries root over the first `count` entries (appendix A).
        bytes32 entriesRoot;
    }

    /// @notice An entry, indexed by bond id (array at slot R + 1, three words each); the third
    /// word packs `ckPrefix`, `activeFromL1` and `exitEffectiveL1`.
    /// @dev A released slot's entry is all zero.
    struct Entry {
        /// @notice The X coordinate of the secp256k1 consensus key.
        bytes32 ckX;
        /// @notice The effective stake in token base units; zero once slashed.
        uint256 effStake;
        /// @notice The SEC1 prefix of the consensus key, 0x02 or 0x03.
        uint8 ckPrefix;
        /// @notice The first L1 block at which the entry may be selected.
        uint48 activeFromL1;
        /// @notice The L1 block at which the exit takes effect; 2^48 - 1 if no exit is set.
        uint48 exitEffectiveL1;
    }

    /// @notice A CometBFT vote submitted as double-sign evidence (spec 4.1, appendix A).
    struct Vote {
        /// @notice The vote type: 1 for prevote, 2 for precommit.
        uint8 voteType;
        /// @notice The L2 height, in [1, 2^63).
        uint64 height;
        /// @notice The consensus round, below 2^31.
        uint32 round;
        /// @notice The block id hash; the block id is all zero for a nil vote.
        bytes32 blockHash;
        /// @notice The part set header total.
        uint32 partsTotal;
        /// @notice The part set header hash.
        bytes32 partsHash;
        /// @notice The seconds of the vote timestamp since the Unix epoch: a signed int64 carried
        /// as its 64-bit two's-complement pattern (e.g. -1 is 2^64 - 1), within CometBFT's
        /// Timestamp range [-62,135,596,800, 253,402,300,800), 0001-01-01T00:00:00Z up to
        /// 10000-01-01T00:00:00Z.
        uint64 timestampSeconds;
        /// @notice The nanoseconds of the vote timestamp, below 10^9.
        uint32 timestampNanos;
        /// @notice The recovery generation of the chain id the vote is signed under.
        uint48 generation;
        /// @notice The 65-byte signature R ‖ S ‖ V, with V in {0, 1} and S at most n / 2.
        bytes signature;
    }

    // ---------------------------------------------------------------
    // Events
    // ---------------------------------------------------------------

    /// @notice Emitted when a validator registers.
    /// @param bondId The entry's bond id (its slot).
    /// @param owner The bond owner, the caller.
    /// @param ckAddr The consensus key's address, keccak256(ckX ‖ ckY)[12:].
    /// @param ckPrefix The SEC1 prefix of the consensus key.
    /// @param ckX The X coordinate of the consensus key.
    /// @param amount The stake pulled from the owner.
    /// @param activeFromL1 The first L1 block at which the entry may be selected.
    event Registered(
        uint256 indexed bondId,
        address indexed owner,
        address indexed ckAddr,
        uint8 ckPrefix,
        bytes32 ckX,
        uint256 amount,
        uint48 activeFromL1
    );

    /// @notice Emitted when the bond owner sets an exit.
    /// @param bondId The entry's bond id.
    /// @param exitEffectiveL1 The L1 block at which the exit takes effect.
    event ExitRequested(uint256 indexed bondId, uint48 exitEffectiveL1);

    /// @notice Emitted when an exit is first confirmed.
    /// @param bondId The entry's bond id.
    /// @param exitConfirmedAtL1 The L1 block of the confirmation, where the withdrawal delay
    /// starts.
    event ExitConfirmed(uint256 indexed bondId, uint256 exitConfirmedAtL1);

    /// @notice Emitted when a withdrawal releases a slot.
    /// @param bondId The released bond id.
    /// @param to The recipient of the stake.
    /// @param amount The stake paid out; zero for a slashed entry.
    event StakeWithdrawn(uint256 indexed bondId, address indexed to, uint256 amount);

    /// @notice Emitted when double-sign evidence slashes an entry.
    /// @param bondId The entry's bond id.
    /// @param reporter The caller, who receives the bounty.
    /// @param amount The slashed stake.
    /// @param bounty The part of `amount` paid to the reporter.
    /// @param generation The votes' recovery generation.
    /// @param height The votes' height.
    /// @param round The votes' round.
    /// @param voteType The votes' type.
    event DoubleSignSlashed(
        uint256 indexed bondId,
        address indexed reporter,
        uint256 amount,
        uint256 bounty,
        uint48 generation,
        uint64 height,
        uint32 round,
        uint8 voteType
    );

    /// @notice Emitted when governance recovery moves an entry's exit earlier.
    /// @param bondId The entry's bond id.
    /// @param exitEffectiveL1 The new exit block, R.
    event ExitForced(uint256 indexed bondId, uint48 exitEffectiveL1);

    /// @notice Emitted when the current block's checkpoint is appended or overwritten.
    /// @param index The checkpoint index.
    /// @param l1Block The L1 block of the checkpoint, the current block.
    /// @param count The number of slots used so far.
    /// @param entriesRoot The entries root.
    event CheckpointWritten(
        uint256 indexed index, uint48 l1Block, uint48 count, bytes32 entriesRoot
    );

    // ---------------------------------------------------------------
    // External Functions
    // ---------------------------------------------------------------

    /// @notice Registers a consensus key with a stake pulled from the caller, who becomes the bond
    /// owner (spec 4.1).
    /// @dev `_publicKey` is exactly 33 bytes of canonical SEC1 compressed secp256k1 encoding,
    /// prefix 0x02 or 0x03 followed by the 32-byte big-endian X; the registry decompresses it
    /// (appendix A) and rejects any other encoding. `_popSig` is exactly 65 bytes R ‖ S ‖ V with
    /// V in {0, 1}, 0 < R < n and 0 < S <= n / 2, recovering over `registerDigest(msg.sender)` to
    /// the key's address. Each key address registers once, ever. Requires `_amount >= minStake`
    /// and a free slot; the most recently released slot is reused first, otherwise a new one is
    /// appended (at most 4096). The entry stores only `ckPrefix` and `ckX`, becomes active
    /// `activationDelay` blocks later and has no exit set. Writes the current block's checkpoint.
    /// @param _publicKey The 33-byte compressed consensus key.
    /// @param _amount The stake; the caller must have approved it.
    /// @param _popSig The proof of possession.
    /// @return bondId_ The entry's bond id (its slot).
    function register(
        bytes calldata _publicKey,
        uint256 _amount,
        bytes calldata _popSig
    )
        external
        returns (uint256 bondId_);

    /// @notice Sets the exit of an entry (spec 4.1).
    /// @dev Only the bond owner, and only while no exit is set. The exit takes effect at
    /// max(block.number, activeFromL1) + exitDelay, which must be below 2^48 - 1. Writes the
    /// current block's checkpoint.
    /// @param _bondId The bond id.
    function requestExit(uint256 _bondId) external;

    /// @notice Records the exit confirmation that starts the withdrawal delay (spec 4.1).
    /// @dev Callable by anyone. Reverts `InboxLocked` whenever the Inbox holds its reentrancy
    /// lock, which it does throughout `land`, `recover`, `saveForcedInclusion` (including the
    /// refund) and `sweepProtocolFees`. Requires an initialized Inbox, an unreleased entry with
    /// an exit set, and the Inbox's `activeCommitteeSnapshot() >= exitEffectiveL1`: a landed
    /// committee no longer includes the stake. The first call records block.number; later calls
    /// succeed without moving it.
    /// @param _bondId The bond id.
    function confirmExit(uint256 _bondId) external;

    /// @notice Releases an entry's slot after its confirmed exit, paying out any remaining stake
    /// (spec 4.1).
    /// @dev Reverts `InboxLocked` whenever the Inbox holds its reentrancy lock (see
    /// `confirmExit`). Requires a confirmed exit and block.number >= exitConfirmedAtL1 +
    /// withdrawalDelay. With a positive stake only the bond owner may call and the stake goes to
    /// a non-zero `_to`; a slashed entry is released by anyone without payment. Zeros the entry,
    /// clears its owner and confirmation, frees the slot and writes the current block's
    /// checkpoint; the key stays used.
    /// @param _bondId The bond id.
    /// @param _to The recipient of the stake.
    function withdraw(uint256 _bondId, address _to) external;

    /// @notice Slashes an entry's whole stake for a same-round double sign (spec 4.1).
    /// @dev Callable by anyone once the Inbox is initialized. Both votes have the same type
    /// (prevote or precommit), height, round and generation and different block ids, and the
    /// generation is at most the Inbox's recoveryGeneration. Each signature recovers, over
    /// keccak256 of the vote's sign bytes under this deployment's chain id for that generation
    /// (appendix A), to the address of the entry's stored key. The entry must be unreleased with a
    /// positive stake. Sets effStake to zero and exitEffectiveL1 to min(existing, block.number),
    /// pays slashBountyBps of the stake to the caller and the rest to slashSink, and writes the
    /// current block's checkpoint.
    /// @param _bondId The bond id.
    /// @param _voteA One vote.
    /// @param _voteB The conflicting vote.
    function slashDoubleSign(uint256 _bondId, Vote calldata _voteA, Vote calldata _voteB) external;

    /// @notice Moves an entry's exit to `_r` during governance recovery (spec 8 step 2).
    /// @dev Only the Inbox. Requires an unreleased slot whose occupant matches
    /// `_entryKey = keccak256(abi.encode(ckPrefix, ckX))`, and reverts `InvalidEventBlock` if
    /// `_r >= 2^48 - 1`, the no-exit sentinel. If `_r` is below the entry's exitEffectiveL1, sets
    /// it to `_r` without slashing, writes the current block's checkpoint and emits `ExitForced`;
    /// otherwise it keeps the existing exit and writes nothing.
    /// @param _bondId The bond id.
    /// @param _entryKey The expected occupant's key.
    /// @param _r The recovery execution block `R`.
    function forceExit(uint256 _bondId, bytes32 _entryKey, uint256 _r) external;

    /// @notice Returns the number of checkpoints.
    /// @return The number of checkpoints.
    function checkpointCount() external view returns (uint256);

    /// @notice Returns a checkpoint; reverts if it does not exist.
    /// @param _index The checkpoint index.
    /// @return The checkpoint.
    function checkpointAt(uint256 _index) external view returns (Checkpoint memory);

    /// @notice Returns the number of slots used so far, released ones included.
    /// @return The number of entries.
    function entryCount() external view returns (uint256);

    /// @notice Returns an entry; reverts if its slot was never used.
    /// @param _bondId The bond id.
    /// @return The entry; all zero for a released slot.
    function entryAt(uint256 _bondId) external view returns (Entry memory);

    /// @notice Returns the entries root over all `entryCount()` entries (appendix A).
    /// @dev Equals the latest checkpoint's root; zero with no entry.
    /// @return The entries root.
    function entriesRoot() external view returns (bytes32);

    /// @notice Returns the owner of a bond.
    /// @param _bondId The bond id.
    /// @return The owner; zero for an unused or released slot.
    function ownerOf(uint256 _bondId) external view returns (address);

    /// @notice Returns the L1 block at which a bond's exit was confirmed.
    /// @param _bondId The bond id.
    /// @return The confirmation block; zero if not confirmed.
    function exitConfirmedAtL1(uint256 _bondId) external view returns (uint256);

    /// @notice Returns whether a consensus key address was ever registered.
    /// @param _ckAddr The consensus key's address.
    /// @return Whether the key is used.
    function keyUsed(address _ckAddr) external view returns (bool);

    /// @notice Returns the number of released slots waiting for reuse.
    /// @return The number of free slots.
    function freeSlotCount() external view returns (uint256);

    /// @notice Returns the EIP-712 digest a registration's proof of possession signs
    /// (appendix A).
    /// @dev keccak256(0x1901 ‖ domainSeparator ‖ keccak256(abi.encode(keccak256("Register(address
    /// owner)"), _owner))), the domain being name "EtnaStakingRegistry", version "1",
    /// chainId = block.chainid and verifyingContract = this registry, computed on every call.
    /// @param _owner The bond owner.
    /// @return The digest.
    function registerDigest(address _owner) external view returns (bytes32);

    /// @notice Returns the Etna Inbox proxy fixed at deployment.
    /// @return The Inbox address.
    function inbox() external view returns (address);

    /// @notice Returns the chain id of the Etna L2.
    /// @return The L2 chain id.
    function l2ChainId() external view returns (uint64);

    // ---------------------------------------------------------------
    // Errors
    // ---------------------------------------------------------------

    /// @notice A constructor parameter is zero, codeless or out of bounds.
    error InvalidConfig();
    /// @notice The stake is below `minStake`.
    error StakeTooLow();
    /// @notice The public key is not a canonical 33-byte compressed secp256k1 point.
    error InvalidPublicKey();
    /// @notice The signature is malformed or does not recover to the expected key.
    error InvalidSignature();
    /// @notice The consensus key was already registered.
    error KeyAlreadyUsed();
    /// @notice Every slot holds an entry.
    error RegistryFull();
    /// @notice The bond id names no used slot.
    error UnknownBond();
    /// @notice The caller is not the bond owner.
    error NotBondOwner();
    /// @notice The slot was released.
    error SlotReleased();
    /// @notice The entry already has an exit set.
    error ExitAlreadySet();
    /// @notice The entry has no exit set.
    error ExitNotSet();
    /// @notice An activation or exit block does not fit below the no-exit sentinel.
    error InvalidEventBlock();
    /// @notice The Inbox is not initialized.
    error InboxNotInitialized();
    /// @notice The Inbox holds its reentrancy lock: it is executing `land`, `recover`,
    /// `saveForcedInclusion` or `sweepProtocolFees`.
    error InboxLocked();
    /// @notice No landed committee excludes the stake yet.
    error ExitNotCovered();
    /// @notice The exit is not confirmed.
    error ExitNotConfirmed();
    /// @notice The withdrawal delay has not elapsed.
    error WithdrawalNotReady();
    /// @notice A vote field is out of range.
    error InvalidVote();
    /// @notice The votes are not a same-round double sign.
    error NotDoubleSign();
    /// @notice The votes' generation is above the Inbox's recovery generation.
    error FutureGeneration();
    /// @notice The entry has no stake to slash.
    error NothingToSlash();
    /// @notice The slot's occupant does not match the expected entry key.
    error EntryKeyMismatch();
    /// @notice The checkpoint index does not exist.
    error UnknownCheckpoint();
    /// @notice The caller is not the Inbox.
    error NotInbox();
}
