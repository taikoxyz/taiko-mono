// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { IInbox } from "src/layer1/core/iface/IInbox.sol";
import { IProposerChecker } from "src/layer1/core/iface/IProposerChecker.sol";

/// @title IProposerAuction
/// @notice Perpetual standing-bid auction for Taiko's preconfer/proposer rights.
/// @dev See packages/protocol/docs/auction_based_permissionless_preconf.md for the full design.
///      - Standing bids (ETH, in gwei) form a ranked list; the top bid is the winner and the
///        second is the designated backup.
///      - Every transition (bid, quit, expiry) takes effect TRANSITION_LEAD_EPOCHS (2) epochs
///        after placement, so the current and next epoch's assignments are always final.
///      - The winner pays their bid amount (in ETH) per epoch served, charged lazily from a
///        prepaid ETH balance when the epoch assignment is computed.
///      - Listed operators must hold a TAIKO liveness bond; stall, equivocation, and
///        invalid-block faults are slashable.
/// @custom:security-contact security@taiko.xyz
interface IProposerAuction is IProposerChecker {
    // ---------------------------------------------------------------
    // Events
    // ---------------------------------------------------------------

    /// @notice Emitted when a bid is placed or updated.
    /// @param bidder The bidder.
    /// @param amountInGwei The per-epoch bid amount in gwei.
    /// @param signer The registered block-signing address for S1 disputes.
    event BidPlaced(address indexed bidder, uint128 amountInGwei, address indexed signer);

    /// @notice Emitted when a standing bid's expiry is extended.
    /// @param bidder The bidder.
    /// @param expiresAtEpoch The new expiry epoch.
    event BidRenewed(address indexed bidder, uint32 expiresAtEpoch);

    /// @notice Emitted when a bidder quits.
    /// @param bidder The bidder.
    /// @param withdrawEffectiveEpoch The epoch from which the bid no longer counts.
    event BidWithdrawn(address indexed bidder, uint32 withdrawEffectiveEpoch);

    /// @notice Emitted when a standing bid lapses (expiry, non-payment, or ejection).
    /// @param bidder The bidder.
    event BidLapsed(address indexed bidder);

    /// @notice Emitted when the assignment for an epoch is computed.
    /// @param epoch The assigned epoch.
    /// @param winner The winner (address(0) if unassigned).
    /// @param backup The designated backup (address(0) if none).
    /// @param chargedInGwei The per-epoch fee charged to the winner, in gwei.
    event EpochAssigned(
        uint32 indexed epoch, address indexed winner, address indexed backup, uint128 chargedInGwei
    );

    /// @notice Emitted when a backlog deeper than the backfill window forces the catch-up to skip
    /// epochs, so the skipped range is observable rather than silently dropped.
    /// @param fromEpoch The first skipped epoch (inclusive).
    /// @param toEpoch The last skipped epoch (inclusive).
    event SnapshotsSkipped(uint32 indexed fromEpoch, uint32 indexed toEpoch);

    /// @notice Emitted when TAIKO bonds are deposited.
    event BondDeposited(address indexed account, uint128 amount);

    /// @notice Emitted when TAIKO bonds are withdrawn.
    event BondWithdrawn(address indexed account, uint128 amount);

    /// @notice Emitted when ETH is deposited for per-epoch fee payments.
    event EthDeposited(address indexed account, uint256 amount);

    /// @notice Emitted when ETH is withdrawn.
    event EthWithdrawn(address indexed account, uint256 amount);

    /// @notice Emitted when auction proceeds are withdrawn by the owner.
    event ProceedsWithdrawn(address indexed to, uint256 amount);

    /// @notice Emitted when a stall slash is escrowed.
    /// @param epoch The epoch of the fault.
    /// @param winner The slashed winner.
    /// @param amount The escrowed amount.
    /// @param gapStart The start of the recorded proposal gap.
    /// @param challenger The fallback proposer who triggered the escrow.
    event StallEscrowed(
        uint32 indexed epoch,
        address indexed winner,
        uint128 amount,
        uint48 gapStart,
        address indexed challenger
    );

    /// @notice Emitted when a stall slash settles.
    event StallSettled(
        uint32 indexed epoch,
        address indexed winner,
        uint128 slashed,
        address indexed challenger,
        uint128 rewarded
    );

    /// @notice Emitted when a stall slash is refuted and released.
    event StallRefuted(uint32 indexed epoch, address indexed winner);

    /// @notice Emitted when an S1 fault (invalid block / equivocation) is slashed.
    event ProposerSlashed(
        address indexed winner,
        uint8 faultType,
        uint128 slashed,
        address indexed challenger,
        uint128 rewarded
    );

    /// @notice Emitted when a bidder is ejected for a bond below the ejection threshold.
    event ProposerEjected(address indexed bidder);

    // ---------------------------------------------------------------
    // Structs
    // ---------------------------------------------------------------

    /// @notice A standing bid.
    /// @param amountInGwei Per-epoch bid amount in gwei.
    /// @param placedEpoch Epoch in which the bid was placed.
    /// @param effectiveEpoch Epoch from which the bid counts (placedEpoch + TRANSITION_LEAD_EPOCHS).
    /// @param expiresAtEpoch Epoch after which the bid lapses (exclusive).
    /// @param withdrawEffectiveEpoch Epoch from which a quitting bid stops counting (0 = not quitting).
    /// @param joinedAt Timestamp of the most recent bid.
    /// @param placedSeq Monotonic placement sequence, for deterministic tie-breaking
    ///        (earlier placement wins ties).
    struct BidInfo {
        uint128 amountInGwei;
        uint32 placedEpoch;
        uint32 effectiveEpoch;
        uint32 expiresAtEpoch;
        uint32 withdrawEffectiveEpoch;
        uint48 joinedAt;
        uint48 placedSeq;
    }

    /// @notice A pending change to an existing standing bid.
    /// @dev Pending changes take effect TRANSITION_LEAD_EPOCHS epochs after placement, so they
    ///      can never alter already-finalized current/next epoch assignments. amountInGwei == 0
    ///      marks an expiry-only renewal (signer is unused).
    /// @param amountInGwei New per-epoch bid amount in gwei (0 = expiry-only renewal).
    /// @param signer New block-signing address (unused for renewals).
    /// @param effectiveEpoch Epoch from which the change applies.
    /// @param expiresAtEpoch New expiry epoch (exclusive).
    struct PendingUpdate {
        uint128 amountInGwei;
        address signer;
        uint32 effectiveEpoch;
        uint32 expiresAtEpoch;
    }

    /// @notice A bond account.
    /// @param balance TAIKO balance in gwei.
    /// @param withdrawableAt Timestamp after which the bond may be withdrawn (0 = not requested).
    struct BondInfo {
        uint128 balance;
        uint48 withdrawableAt;
    }

    /// @notice An epoch assignment.
    /// @param winner The winner (address(0) if unassigned).
    /// @param backup The designated backup (address(0) if none).
    struct Assignment {
        address winner;
        address backup;
    }

    /// @notice A pending stall slash.
    /// @param winner The slashed winner.
    /// @param amount The escrowed TAIKO amount in gwei.
    /// @param gapStart Start of the recorded proposal gap.
    /// @param escrowedAt Timestamp when the escrow was created.
    /// @param challenger The fallback proposer who triggered the escrow.
    /// @param challengerIsBackup Whether the challenger was the designated backup at escrow time
    ///        (the backup's reward is burned to avoid paying the stall's direct beneficiary).
    /// @param settled Whether the escrow is settled or refuted.
    struct StallEscrow {
        address winner;
        uint128 amount;
        uint48 gapStart;
        uint48 escrowedAt;
        address challenger;
        bool challengerIsBackup;
        bool settled;
    }

    /// @notice A winner-signed L2 block header, used as S1 dispute evidence.
    /// @dev The signature is EIP-712 over (epoch, seqNo, blockNumber, parentHash, timestamp,
    ///      coinbase, gasLimit, txRoot) with the domain of this contract. `seqNo` is the
    ///      per-epoch monotonic slot/block index: the winner signs at most one block per
    ///      (epoch, seqNo), which is what makes equivocation provable without consensus state.
    struct SignedBlock {
        uint32 epoch;
        uint64 seqNo;
        uint64 blockNumber;
        bytes32 parentHash;
        uint48 timestamp;
        address coinbase;
        uint48 gasLimit;
        bytes32 txRoot;
        uint8 v;
        bytes32 r;
        bytes32 s;
    }

    /// @notice Immutable auction configuration, bundled into a struct to keep the constructor
    ///         stack footprint small (the contract is deployed via a proxy, so the config is
    ///         passed once and copied to immutables).
    /// @param inbox The Inbox address (only caller of checkProposer).
    /// @param bondToken The TAIKO token used for bonds.
    /// @param livenessBondAmount Slash amount per fault, in gwei.
    /// @param bondMultiplier Multiplier for livenessBond to derive bond thresholds.
    /// @param rewardBps Challenger reward share in basis points (<= 5000).
    /// @param settleBountyBps Settle-caller bounty share of the locked remainder (<= 5000).
    /// @param bondWithdrawalDelay Delay before a bond withdrawal becomes possible, in seconds.
    /// @param tenureMaxEpochs Maximum tenure of a standing bid, in epochs.
    /// @param initialFloorInGwei Initial reserve floor, in gwei.
    /// @param movingAverageMultiplier Multiplier for the moving average to derive the floor.
    /// @param movingAverageWindow Moving-average window, in seconds.
    /// @param stallGrace Silence tolerated before the ladder opens, in seconds.
    /// @param escrowGrace Winner absence tolerated before a stall slash is escrowed, in seconds.
    /// @param backupGrace Backup rung extra grace, in seconds.
    /// @param fallbackGrace Bonded-operator rung extra grace, in seconds.
    /// @param refuteWindow Refute window before a stall slash settles, in seconds.
    /// @param handoverMargin Timestamp margin before epoch start during which the incoming
    ///        operator's handover blocks are legal (matches the client's handoverSkipSlots).
    /// @param floorDecayBps Basis points of the reserve EMA retained per unassigned epoch
    ///        (decays the floor toward initialFloor when the list is empty).
    struct Config {
        address inbox;
        address bondToken;
        uint96 livenessBondAmount;
        uint16 bondMultiplier;
        uint16 rewardBps;
        uint16 settleBountyBps;
        uint48 bondWithdrawalDelay;
        uint32 tenureMaxEpochs;
        uint128 initialFloorInGwei;
        uint8 movingAverageMultiplier;
        uint48 movingAverageWindow;
        uint48 stallGrace;
        uint48 escrowGrace;
        uint48 backupGrace;
        uint48 fallbackGrace;
        uint48 refuteWindow;
        uint48 handoverMargin;
        uint16 floorDecayBps;
    }

    // ---------------------------------------------------------------
    // Auction lifecycle
    // ---------------------------------------------------------------

    /// @notice Places or updates a standing bid.
    /// @dev The bid takes effect TRANSITION_LEAD_EPOCHS epochs after placement. To displace the
    ///      current top bid, the amount must exceed it by at least MIN_INCREMENT_BPS. The caller
    ///      must hold at least getRequiredBond() TAIKO.
    /// @param _amountInGwei The per-epoch bid amount in gwei.
    /// @param _signer The block-signing address used for S1 disputes.
    function bid(uint128 _amountInGwei, address _signer) external;

    /// @notice Extends the expiry of the caller's standing bid by tenureMaxEpochs.
    /// @dev Cheap renewal: no increment and no re-ranking.
    function renew() external;

    /// @notice Withdraws the caller's standing bid.
    /// @dev Takes effect TRANSITION_LEAD_EPOCHS epochs later; the caller must keep serving until
    ///      then (going dark before handover is a slashable stall). Also starts the bond
    ///      withdrawal delay.
    function quit() external;

    /// @notice Removes lapsed (expired, withdrawn, or ejected) entries from the list.
    /// @return removed_ The number of entries removed.
    function purgeInactive() external returns (uint256 removed_);

    /// @notice Catches up missed epoch snapshots (bounded backfill) and records the epoch
    ///         assignments, winners' signers, and per-epoch fee charges.
    /// @dev Permissionless: anyone can call this so that S1 dispute records exist even for
    ///      epochs in which nobody proposed. Backfill is capped at MAX_BACKFILL_EPOCHS.
    function snapshot() external;

    /// @notice Returns the pending update for a bidder, if any.
    /// @return update_ The pending update (effectiveEpoch == 0 if none).
    function getPendingUpdate(address _bidder) external view returns (PendingUpdate memory update_);

    // ---------------------------------------------------------------
    // Bonds (TAIKO)
    // ---------------------------------------------------------------

    /// @notice Deposits TAIKO into the caller's bond account.
    /// @param _amount The amount in gwei.
    function depositBond(uint128 _amount) external;

    /// @notice Withdraws TAIKO from the caller's bond account.
    /// @dev Active bidders must quit() first and wait for the withdrawal delay.
    /// @param _amount The amount in gwei.
    function withdrawBond(uint128 _amount) external;

    // ---------------------------------------------------------------
    // ETH prepay and proceeds
    // ---------------------------------------------------------------

    /// @notice Deposits ETH for the caller's per-epoch fee payments.
    function depositEth() external payable;

    /// @notice Withdraws the caller's prepaid ETH.
    /// @param _amount The amount in wei.
    function withdrawEth(uint256 _amount) external;

    /// @notice Withdraws accumulated auction proceeds.
    /// @param _to The recipient.
    /// @param _amount The amount in wei.
    function withdrawProceeds(address _to, uint256 _amount) external;

    // ---------------------------------------------------------------
    // Slashing
    // ---------------------------------------------------------------

    /// @notice Settles a pending stall slash after the refute window.
    /// @dev The escrowed amount is split: rewardBps to the challenger, the remainder locked.
    /// @param _epoch The fault epoch.
    function settleStallSlash(uint32 _epoch) external;

    /// @notice Refutes a pending stall slash by proving a canonical winner proposal inside the
    ///         recorded gap.
    /// @dev The proposal preimage must hash to the value stored in the Inbox ring buffer, have
    ///      proposer == winner, and a timestamp inside (gapStart, escrowedAt]. On success the
    ///      escrow is released to the winner.
    /// @param _epoch The fault epoch.
    /// @param _proposal The canonical proposal preimage.
    function refuteStall(uint32 _epoch, IInbox.Proposal calldata _proposal) external;

    /// @notice Slashes the epoch winner for signing a block with a timestamp outside the epoch
    ///         window.
    /// @param _epoch The epoch of the signed block.
    /// @param _block The signed block.
    function slashInvalidBlock(uint32 _epoch, SignedBlock calldata _block) external;

    /// @notice Slashes the epoch winner for signing two different blocks for the same
    ///         (blockNumber, parentHash).
    /// @param _epoch The epoch of the signed blocks.
    /// @param _a The first signed block.
    /// @param _b The second signed block.
    function slashEquivocation(
        uint32 _epoch,
        SignedBlock calldata _a,
        SignedBlock calldata _b
    )
        external;

    // ---------------------------------------------------------------
    // Getters
    // ---------------------------------------------------------------

    /// @notice Returns the assignment for the current epoch (final).
    /// @return assignment_ The winner and backup.
    function getAssignmentForCurrentEpoch() external view returns (Assignment memory assignment_);

    /// @notice Returns the assignment for the next epoch.
    /// @dev Final modulo the winner's ability to pay at the boundary (the per-epoch charge is
    ///      verified lazily; a non-paying winner is lapsed at the boundary).
    /// @return assignment_ The winner and backup.
    function getAssignmentForNextEpoch() external view returns (Assignment memory assignment_);

    /// @notice Returns the provisional top bid, ignoring effective epochs.
    /// @return winner_ The top bidder (address(0) if none).
    /// @return isFinal_ True if the bidder is also the final winner of the next epoch.
    function getProvisionalWinner() external view returns (address winner_, bool isFinal_);

    /// @notice Returns the caller's bid and registered signer.
    function getBidderInfo(address _bidder)
        external
        view
        returns (BidInfo memory info_, address signer_);

    /// @notice Returns the caller's bond info.
    function getBondInfo(address _account) external view returns (BondInfo memory info_);

    /// @notice Returns the caller's prepaid ETH balance.
    function getEthBalance(address _account) external view returns (uint256 balance_);

    /// @notice Returns the current reserve floor in gwei.
    function getReserveFloor() external view returns (uint128 floorInGwei_);

    /// @notice Returns the handover margin (seconds before epoch start during which the incoming
    ///         operator's handover blocks are legal S1 evidence).
    function getHandoverMargin() external view returns (uint48 handoverMargin_);

    /// @notice Returns the settle-caller bounty share in basis points.
    function getSettleBountyBps() external view returns (uint16 settleBountyBps_);

    /// @notice Returns the reserve-floor decay (basis points retained per unassigned epoch).
    function getFloorDecayBps() external view returns (uint16 floorDecayBps_);

    /// @notice Returns the pending stall slash for an epoch.
    function getPendingStallSlash(uint32 _epoch) external view returns (StallEscrow memory escrow_);

    /// @notice Returns the TAIKO bond required to bid.
    function getRequiredBond() external view returns (uint128 requiredBond_);

    /// @notice Returns the bond threshold that triggers ejection.
    function getEjectionThreshold() external view returns (uint128 threshold_);

    /// @notice Returns the slash amount per liveness fault.
    function getLivenessBond() external view returns (uint96 livenessBond_);

    /// @notice Returns the total TAIKO locked from slashes.
    function getTotalSlashedAmount() external view returns (uint128 total_);

    /// @notice Returns the accumulated ETH auction proceeds.
    function getProceeds() external view returns (uint256 proceeds_);

    /// @notice Returns the number of listed bidders.
    function getBidderCount() external view returns (uint256 count_);

    /// @notice Returns the bidder at an index of the internal list.
    /// @dev The list is not sorted; use getProvisionalWinner/getAssignment* for ranking.
    function getBidderAt(uint256 _index) external view returns (address bidder_);
}
