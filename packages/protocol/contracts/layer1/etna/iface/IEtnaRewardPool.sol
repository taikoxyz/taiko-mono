// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { IEtnaInbox } from "./IEtnaInbox.sol";

/// @title IEtnaRewardPool
/// @notice The L1 pool of the Etna chain's fee revenue. L2 fees arrive through the L1 Bridge from
/// the L2 fee vault; each epoch's validator and proving shares are fixed and paid out in the
/// landing that carries the epoch's last commit.
/// @dev The Inbox reports each landing's validator participation through `recordLanding`. When an
/// epoch completes, the pool freezes it: it allocates fixed shares of the free balance (the
/// balance minus the credits not yet withdrawn), credits the validator share to the owners of
/// the committee's registrations, the base part by effective stake times signed heights and the
/// proposer bonus part by proposer score, each out of what the whole committee could have earned,
/// and sends the proving share to the Inbox. Credits are
/// reserved until their owners withdraw them, so no Ether is committed to two epochs and the
/// balance always covers the reservations.
/// @custom:security-contact security@taiko.xyz
interface IEtnaRewardPool {
    // ---------------------------------------------------------------
    // Structs
    // ---------------------------------------------------------------

    /// @notice The settlement of one epoch.
    /// @dev Five storage words, in field order.
    struct EpochRecord {
        /// @notice The epoch's committee hash, written by the first landing that reports the
        /// epoch; every later report and the settlement committee must match it.
        bytes32 committeeHash;
        /// @notice The validator share fixed at the freeze, in wei.
        uint256 alloc;
        /// @notice The part of `alloc` credited to registration owners, in wei. The rest (rounding
        /// remainders, shares without an owner and unearned proposer bonus) stays in the free
        /// balance.
        uint256 paid;
        /// @notice The proving share sent to the Inbox at the freeze, in wei.
        uint256 provingShare;
        /// @notice The L1 block of the freeze; 0 while the epoch is open. A frozen epoch is
        /// settled.
        uint64 frozenAtL1;
    }

    // ---------------------------------------------------------------
    // Events
    // ---------------------------------------------------------------

    /// @notice Emitted when a fee sweep from the L2 fee vault arrives through the L1 Bridge.
    /// @param msgHash The hash of the Bridge message.
    /// @param sweepNonce The vault's sweep nonce carried by the message.
    /// @param amount The amount received, in wei.
    event FeesArrived(bytes32 indexed msgHash, uint64 indexed sweepNonce, uint256 amount);

    /// @notice Emitted when the pool receives Ether outside a sweep, such as a donation or a
    /// Bridge fee refund.
    /// @param from The sender.
    /// @param amount The amount received, in wei.
    event Donation(address indexed from, uint256 amount);

    /// @notice Emitted when an epoch is frozen and settled.
    /// @param epoch The epoch.
    /// @param alloc The validator share, in wei.
    /// @param paid The part of `alloc` credited to registration owners, in wei.
    /// @param provingShare The proving share sent to the Inbox, in wei.
    event EpochFrozen(uint64 indexed epoch, uint256 alloc, uint256 paid, uint256 provingShare);

    /// @notice Emitted for each committee member whose registration owner is credited at a
    /// settlement.
    /// @param epoch The epoch.
    /// @param index The member's index in the committee, in set-key order.
    /// @param bondId The member's bond id.
    /// @param owner The owner of the member's registration, who is credited.
    /// @param amount The credited amount, in wei: the member's base part plus its proposer bonus.
    event ValidatorRewarded(
        uint64 indexed epoch, uint256 index, uint32 bondId, address indexed owner, uint256 amount
    );

    /// @notice Emitted when an owner withdraws its credits.
    /// @param owner The owner whose credits are withdrawn.
    /// @param to The recipient.
    /// @param amount The withdrawn amount, in wei.
    event RewardsWithdrawn(address indexed owner, address indexed to, uint256 amount);

    // ---------------------------------------------------------------
    // External Functions
    // ---------------------------------------------------------------

    /// @notice Records one landing's validator participation and freezes and settles every epoch
    /// the landing completes.
    /// @dev Only the Inbox may call, after the landing's proof is verified. Not pausable. For each
    /// part: the committee hash must be non-zero, the epoch must not be frozen, and the hash is
    /// stored on the first report and must match on every later one; the signed counts and the
    /// proposer scores are added to the epoch's totals with checked uint32 arithmetic. The Inbox
    /// bounds each part's scores to 10_000 per commit height, so an epoch's scores sum to at most
    /// `10_000 * _epochLenL2`, and the epoch length to 429,496, so that total fits a uint32.
    /// Epoch `e` is complete when the batch carries the commit of its last height
    /// `(e + 1) * _epochLenL2`, i.e. when
    /// `_lastHeight - 1 >= (e + 1) * _epochLenL2`. Each complete part, in part order, is frozen
    /// and settled with the next entry of `_settlements`, whose hash must equal the stored
    /// committee hash; the number of complete parts must equal `_settlements.length`.
    ///
    /// Freezing allocates `free * allocValidatorPpm / 1e6` to validators and
    /// `free * allocProverPpm / 1e6` to proving, where `free` is the free balance just before
    /// this epoch's freeze, so an earlier epoch frozen in the same call lowers a later one's. The
    /// validator share splits into `bonusAlloc = alloc * proposerBonusPpm / 1e6` and
    /// `baseAlloc = alloc - bonusAlloc`. Each member (indices below the committee length only)
    /// earns the base part `mulDiv(baseAlloc, weight, max(fullWeight, totalWeight))` of its
    /// weight `effStake * count`, or nothing when the total weight is zero, plus the bonus part
    /// `mulDiv(bonusAlloc, score, max(10_000 * _epochLenL2, totalScore))` of its proposer score,
    /// both rounded down, where `fullWeight` sums `effStake * _epochLenL2` over the committee,
    /// `totalWeight` sums the members' weights and `totalScore` their scores. With the Inbox's
    /// bounds the denominators are `fullWeight` and `10_000 * _epochLenL2`, what the whole
    /// committee could have earned, so omitting a member's signature never raises another
    /// member's part of that epoch; the maxima keep the parts within `baseAlloc` and `bonusAlloc`, and the pool
    /// solvent, for any recorded counts and scores. A member whose sum is non-zero is credited it
    /// unless its registration has no owner; credited amounts are reserved, and the base no member
    /// signed for and the bonus no proposer earned stay free. The proving share is sent to the
    /// Inbox; a failed transfer reverts the call.
    /// @param _lastHeight The height of the landing's last block.
    /// @param _epochLenL2 The epoch length in L2 blocks.
    /// @param _parts The participation per epoch of the batch's commit range, in ascending epoch
    /// order.
    /// @param _settlements The committee of each epoch the landing completes, in part order.
    function recordLanding(
        uint64 _lastHeight,
        uint64 _epochLenL2,
        IEtnaInbox.EpochParticipation[] calldata _parts,
        IEtnaInbox.CommitteeMember[][] calldata _settlements
    )
        external;

    /// @notice Withdraws all of the caller's credits.
    /// @dev Releases the reservation and sends the credits to `_to`; a failed transfer reverts.
    /// Returns zero without a transfer or an event when the caller has no credits.
    /// @param _to The recipient; must be non-zero.
    /// @return amount_ The withdrawn amount, in wei.
    function withdrawRewards(address _to) external returns (uint256 amount_);

    /// @notice Returns the balance not reserved for credits: the base of the next freeze.
    /// @return The pool balance minus `reservedTotal`, in wei.
    function freeBalance() external view returns (uint256);

    /// @notice Returns the credits not yet withdrawn.
    /// @return The total reserved credits, in wei.
    function reservedTotal() external view returns (uint256);

    /// @notice Returns the total amount of fee sweeps received through the L1 Bridge.
    /// @dev Bookkeeping only; donations and refunds are not included.
    /// @return The received sweeps, in wei.
    function arrivedTotal() external view returns (uint256);

    /// @notice Returns the settlement record of an epoch.
    /// @param _epoch The epoch.
    /// @return The epoch's record; zero if no landing reported it.
    function epochRecord(uint64 _epoch) external view returns (EpochRecord memory);

    /// @notice Returns the number of signed heights recorded for a committee member.
    /// @param _epoch The epoch.
    /// @param _index The member's index in the committee, in set-key order.
    /// @return The recorded count.
    function signedCountOf(uint64 _epoch, uint256 _index) external view returns (uint32);

    /// @notice Returns the proposer score recorded for a committee member.
    /// @param _epoch The epoch.
    /// @param _index The member's index in the committee, in set-key order.
    /// @return The recorded score, 10_000 per block whose last commit carried the whole committee.
    function proposerScoreOf(uint64 _epoch, uint256 _index) external view returns (uint32);

    /// @notice Returns an owner's credits.
    /// @param _account The owner.
    /// @return The credits not yet withdrawn, in wei.
    function creditsOf(address _account) external view returns (uint256);

    /// @notice Returns whether the balance covers the reservations.
    /// @return Whether the pool balance is at least `reservedTotal`.
    function checkInvariants() external view returns (bool);

    /// @notice Returns the Etna Inbox, the only caller of `recordLanding` and the receiver of the
    /// proving shares.
    /// @return The Inbox proxy.
    function inbox() external view returns (address);

    /// @notice Returns the Etna staking registry that names each registration's owner.
    /// @return The registry proxy.
    function stakingRegistry() external view returns (address);

    /// @notice Returns the L1 Bridge that delivers the fee sweeps.
    /// @return The L1 Bridge.
    function l1Bridge() external view returns (address);

    /// @notice Returns the L2 fee vault, the only accepted sweep sender.
    /// @return The vault address on L2.
    function l2FeeVault() external view returns (address);

    /// @notice Returns the chain id of the Etna L2, the only accepted sweep source.
    /// @return The L2 chain id.
    function l2ChainId() external view returns (uint64);

    /// @notice Returns the validator share of the free balance at each freeze.
    /// @return The share in parts per million.
    function allocValidatorPpm() external view returns (uint32);

    /// @notice Returns the proving share of the free balance at each freeze.
    /// @return The share in parts per million.
    function allocProverPpm() external view returns (uint32);

    /// @notice Returns the part of each frozen epoch's validator share paid as proposer bonus.
    /// @return The part in parts per million of the validator share.
    function proposerBonusPpm() external view returns (uint32);
}
