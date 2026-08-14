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
    /// @param withdrawEffectiveEpoch Epoch from which a quitted bid stops counting (0 = not quitting).
    /// @param joinedAt Timestamp of the most recent bid, for tie-breaking.
    struct BidInfo {
        uint128 amountInGwei;
        uint32 placedEpoch;
        uint32 effectiveEpoch;
        uint32 expiresAtEpoch;
        uint32 withdrawEffectiveEpoch;
        uint48 joinedAt;
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
    /// @param settled Whether the escrow is settled or refuted.
    struct StallEscrow {
        address winner;
        uint128 amount;
        uint48 gapStart;
        uint48 escrowedAt;
        address challenger;
        bool settled;
    }

    /// @notice A winner-signed L2 block header, used as S1 dispute evidence.
    /// @dev The signature is EIP-712 over (epoch, blockNumber, parentHash, timestamp, coinbase,
    ///      gasLimit, txRoot) with the domain of this contract.
    struct SignedBlock {
        uint32 epoch;
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
