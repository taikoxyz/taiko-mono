// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import { IProposerAuction } from "../iface/IProposerAuction.sol";
import { LibPreconfConstants } from "../libs/LibPreconfConstants.sol";
import { LibPreconfUtils } from "../libs/LibPreconfUtils.sol";
import { IInbox } from "src/layer1/core/iface/IInbox.sol";
import { IProposerChecker } from "src/layer1/core/iface/IProposerChecker.sol";
import { LibHashOptimized } from "src/layer1/core/libs/LibHashOptimized.sol";
import { EssentialContract } from "src/shared/common/EssentialContract.sol";
import { LibMath } from "src/shared/libs/LibMath.sol";

import "./ProposerAuction_Layout.sol"; // DO NOT DELETE

/// @title ProposerAuction
/// @notice Perpetual standing-bid auction for Taiko's preconfer/proposer rights.
/// @dev Implements the design in packages/protocol/docs/auction_based_permissionless_preconf.md:
///      - A bonded ranked list of standing ETH bids (per-epoch rate); the top bid is the winner
///        and the second is the designated backup.
///      - Every transition takes effect TRANSITION_LEAD_EPOCHS epochs after placement, so the
///        current and next epoch's assignments are always final.
///      - The winner is charged one bid amount (ETH) per epoch served, lazily from their prepaid
///        ETH balance when the epoch assignment is computed — no keeper transactions.
///      - checkProposer implements the fallback ladder: winner → backup → any bonded operator →
///        anyone; a stall escrows the winner's liveness bond for a refute window during which the
///        winner can only refute by disproving the recorded proposal gap.
///      - S1 faults (signed invalid blocks, equivocation) are slashable with EIP-712 evidence.
/// @custom:security-contact security@taiko.xyz
contract ProposerAuction is EssentialContract, IProposerAuction {
    using SafeERC20 for IERC20;

    // ---------------------------------------------------------------
    // Constants
    // ---------------------------------------------------------------

    /// @notice Maximum number of standing bids.
    uint8 public constant MAX_LIST_SIZE = 16;

    /// @notice Minimum increment (basis points) required to displace the current top bid.
    uint16 public constant MIN_INCREMENT_BPS = 500;

    /// @notice Epochs between a transition being placed and taking effect.
    uint32 public constant TRANSITION_LEAD_EPOCHS = 2;

    /// @notice Maximum number of epochs backfilled by snapshot().
    uint32 public constant MAX_BACKFILL_EPOCHS = 32;

    /// @notice Fault type: stall (liveness fault).
    uint8 internal constant _FAULT_STALL = 1;

    /// @notice Fault type: signed invalid block (safety fault).
    uint8 internal constant _FAULT_INVALID_BLOCK = 2;

    /// @notice Fault type: equivocation (safety fault).
    uint8 internal constant _FAULT_EQUIVOCATION = 3;

    /// @dev EIP-712 type hash for SignedBlock data.
    bytes32 internal constant _BLOCK_TYPEHASH = keccak256(
        "SignedBlockData(uint32 epoch,uint64 seqNo,uint64 blockNumber,bytes32 parentHash,uint48 timestamp,"
        "address coinbase,uint48 gasLimit,bytes32 txRoot)"
    );

    // ---------------------------------------------------------------
    // Immutable Variables
    // ---------------------------------------------------------------

    /// @notice The Inbox address; the only caller of checkProposer.
    address public immutable inbox;

    /// @notice The TAIKO token used for bonds.
    IERC20 public immutable bondToken;

    /// @dev Slash amount per liveness/safety fault, in gwei.
    uint96 private immutable _livenessBond;

    /// @dev Multiplier for livenessBond to derive bond thresholds.
    uint16 private immutable _bondMultiplier;

    /// @dev Pre-computed required bond amount (livenessBond * bondMultiplier * 2).
    uint128 private immutable _requiredBond;

    /// @dev Pre-computed ejection threshold (livenessBond * bondMultiplier).
    uint128 private immutable _ejectionThreshold;

    /// @dev Challenger reward share in basis points.
    uint16 private immutable _rewardBps;

    /// @dev Settle-caller bounty share of the locked remainder, in basis points.
    uint16 private immutable _settleBountyBps;

    /// @dev Delay before a bond withdrawal becomes possible.
    uint48 private immutable _bondWithdrawalDelay;

    /// @dev Maximum tenure of a standing bid, in epochs (extendable via renew()).
    uint32 private immutable _tenureMaxEpochs;

    /// @dev Initial reserve floor, in gwei.
    uint128 private immutable _initialFloorInGwei;

    /// @dev Multiplier applied to the moving average bid to derive the reserve floor.
    uint8 private immutable _movingAverageMultiplier;

    /// @dev Time window for the moving average.
    uint48 private immutable _movingAverageWindow;

    /// @dev Basis points of the reserve EMA retained per unassigned epoch (floor decay).
    uint16 private immutable _floorDecayBps;

    /// @dev Silence tolerated before the fallback ladder opens, in seconds.
    uint48 private immutable _stallGrace;

    /// @dev Winner absence tolerated before a stall slash is escrowed, in seconds.
    /// @dev Decoupled from the ladder-open threshold so that transient accidents (L1 inclusion
    ///      delays, shallow reorgs) let backups serve without slashing an honest winner.
    uint48 private immutable _escrowGrace;

    /// @dev Extra silence tolerated for the designated backup rung, in seconds.
    uint48 private immutable _backupGrace;

    /// @dev Extra silence tolerated for the bonded-operator rung, in seconds.
    uint48 private immutable _fallbackGrace;

    /// @dev Refute window before a stall slash settles, in seconds.
    uint48 private immutable _refuteWindow;

    /// @dev Timestamp margin before epoch start during which the incoming operator's handover
    ///      blocks are legal S1 evidence (matches the client's handoverSkipSlots).
    uint48 private immutable _handoverMargin;

    /// @dev EIP-712 domain typehash for SignedBlock data.
    /// @dev The domain separator is computed dynamically in the verify path so that proxied
    ///      deployments sign over the proxy address, not the implementation address.
    bytes32 internal constant _DOMAIN_TYPEHASH = keccak256(
        "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
    );

    /// @dev EIP-712 domain name hash for SignedBlock data.
    bytes32 internal constant _DOMAIN_NAME_HASH = keccak256("TAIKO_PRECONF_BLOCK");

    /// @dev EIP-712 domain version hash for SignedBlock data.
    bytes32 internal constant _DOMAIN_VERSION_HASH = keccak256("1");

    // ---------------------------------------------------------------
    // State Variables
    // ---------------------------------------------------------------

    /// @dev Unordered list of listed bidders (ranking is computed at assignment time; N <= 16).
    address[] internal _ranked;

    /// @dev Bid info per bidder.
    mapping(address bidder => IProposerAuction.BidInfo info) internal _bids;

    /// @dev Pending changes (re-bids, renewals, signer rotations) applied with the
    ///      TRANSITION_LEAD_EPOCHS delay, so finalized assignments cannot be altered.
    mapping(address bidder => IProposerAuction.PendingUpdate update) internal _pendingUpdates;

    /// @dev Registered block signer per bidder (persists after lapse for historical disputes).
    mapping(address bidder => address signer) internal _signers;

    /// @dev Bond ledger per account.
    mapping(address account => IProposerAuction.BondInfo info) internal _bonds;

    /// @dev Prepaid ETH balances for per-epoch fee payments.
    mapping(address account => uint256 balance) internal _ethBalances;

    /// @dev Pending stall slashes per epoch.
    mapping(uint32 epoch => IProposerAuction.StallEscrow escrow) internal _stallEscrows;

    /// @dev Winner recorded per assigned epoch (used by S1 disputes).
    mapping(uint32 epoch => address winner) internal _epochWinners;

    /// @dev Winner's registered signer per assigned epoch (used by S1 disputes).
    mapping(uint32 epoch => address signer) internal _epochSigners;

    /// @dev One-shot guard per fault digest.
    mapping(bytes32 digest => bool used) internal _slashedBefore;

    /// @dev Epoch for which the assignment cache is valid.
    uint32 internal _assignedEpoch;

    /// @dev Cached current-epoch assignment (final).
    address internal _currentWinner;

    /// @dev Cached current-epoch backup (final).
    address internal _currentBackup;

    /// @dev Cached next-epoch assignment (final modulo payment at the boundary).
    address internal _nextWinner;

    /// @dev Cached next-epoch backup (final modulo payment at the boundary).
    address internal _nextBackup;

    /// @dev Timestamp of the last accepted proposal (tx-atomic with the propose call).
    uint48 internal _lastProposalAt;

    /// @dev Timestamp of the last accepted winner proposal.
    uint48 internal _lastWinnerProposalAt;

    /// @dev Monotonic bid placement sequence, for deterministic tie-breaking.
    uint48 internal _bidSeq;

    /// @dev Total TAIKO locked from slashes, in gwei.
    uint128 internal _totalSlashedAmount;

    /// @dev Accumulated ETH auction proceeds.
    uint256 internal _proceeds;

    /// @dev Moving average of charged bid amounts, in gwei.
    uint128 internal _movingAverageBid;

    /// @dev Timestamp of the last moving-average update.
    uint48 internal _lastAvgUpdate;

    /// @dev Contract creation time, for the moving-average seed.
    uint48 internal _contractCreationTime;

    /// @dev Last epoch for which the unassigned-mode fee was charged (once per unassigned epoch).
    uint32 internal _lastUnassignedFeeEpoch;

    /// @dev Whether an account has ever held a standing bid (gates the delay-free bond exit).
    mapping(address account => bool everListed) internal _everListed;

    uint256[29] private __gap;

    // ---------------------------------------------------------------
    // Constructor
    // ---------------------------------------------------------------

    /// @notice Initializes immutable configuration from a packed Config struct.
    /// @dev Bundled into a struct to keep the constructor's stack footprint small (avoids the
    ///      legacy non-via-IR "stack too deep" codegen failure in solc 0.8.30).
    /// @param _config The auction configuration.
    constructor(Config memory _config) {
        require(_config.inbox != address(0), ZeroAddress());
        require(_config.bondToken != address(0), ZeroAddress());
        require(_config.livenessBondAmount > 0, ZeroValue());
        require(
            _config.bondMultiplier > 0 && _config.bondMultiplier <= 100, InvalidBondMultiplier()
        );
        require(_config.rewardBps <= 5000, InvalidBps()); // <= 50%: a self-slash must never be free
        require(_config.settleBountyBps <= 5000, InvalidBps());
        require(_config.bondWithdrawalDelay > 0, ZeroValue());
        require(_config.tenureMaxEpochs > 0, ZeroValue());
        require(_config.initialFloorInGwei > 0, ZeroValue());
        require(_config.movingAverageMultiplier > 0, ZeroValue());
        require(_config.movingAverageWindow > 0, ZeroValue());
        require(
            _config.stallGrace > 0 && _config.backupGrace > 0 && _config.fallbackGrace > 0,
            ZeroValue()
        );
        require(_config.escrowGrace >= _config.stallGrace, InvalidEscrowGrace());
        require(_config.refuteWindow > 0, ZeroValue());
        require(
            _config.handoverMargin <= LibPreconfConstants.SECONDS_IN_EPOCH, InvalidHandoverMargin()
        );
        require(_config.floorDecayBps <= 10_000, InvalidBps());

        inbox = _config.inbox;
        bondToken = IERC20(_config.bondToken);
        _livenessBond = _config.livenessBondAmount;
        _bondMultiplier = _config.bondMultiplier;
        _rewardBps = _config.rewardBps;
        _settleBountyBps = _config.settleBountyBps;
        _bondWithdrawalDelay = _config.bondWithdrawalDelay;
        _tenureMaxEpochs = _config.tenureMaxEpochs;
        _initialFloorInGwei = _config.initialFloorInGwei;
        _movingAverageMultiplier = _config.movingAverageMultiplier;
        _movingAverageWindow = _config.movingAverageWindow;
        _floorDecayBps = _config.floorDecayBps;
        _stallGrace = _config.stallGrace;
        _escrowGrace = _config.escrowGrace;
        _backupGrace = _config.backupGrace;
        _fallbackGrace = _config.fallbackGrace;
        _refuteWindow = _config.refuteWindow;
        _handoverMargin = _config.handoverMargin;

        unchecked {
            uint128 ejectionThreshold = uint128(_config.livenessBondAmount) * _config.bondMultiplier;
            _ejectionThreshold = ejectionThreshold;
            _requiredBond = ejectionThreshold * 2;
        }
    }

    // ---------------------------------------------------------------
    // Initializer Functions
    // ---------------------------------------------------------------

    /// @notice Initializes the owner of this contract.
    /// @param _owner The owner of this contract.
    function init(address _owner) external initializer {
        __Essential_init(_owner);
        _contractCreationTime = uint48(block.timestamp);
        // Sentinel so the first real unassigned epoch still charges the unassigned-mode fee.
        _lastUnassignedFeeEpoch = type(uint32).max;
    }

    // ---------------------------------------------------------------
    // Auction Lifecycle
    // ---------------------------------------------------------------

    /// @inheritdoc IProposerAuction
    function bid(uint128 _amountInGwei, address _signer) external nonReentrant {
        require(_signer != address(0), InvalidSigner());

        IProposerAuction.BondInfo storage bond = _bonds[msg.sender];
        require(bond.balance >= _requiredBond, InsufficientBond());
        if (bond.withdrawableAt != 0) bond.withdrawableAt = 0;

        uint32 currentEpoch = _currentEpochIndex();
        (uint128 topAmount, address topHolder) = _activeTop(currentEpoch);

        // Self re-bids (same holder) are exempt from the reserve floor: an incumbent must be
        // able to re-bid or rotate signer at their own rate without the floor ratcheting rent.
        if (topHolder != msg.sender) {
            require(_amountInGwei >= getReserveFloor(), BidBelowReserve());
        }
        if (topHolder != address(0) && topHolder != msg.sender && _amountInGwei > topAmount) {
            require(
                _amountInGwei
                    >= uint128(uint256(topAmount) * (10_000 + MIN_INCREMENT_BPS) / 10_000),
                IncrementTooSmall()
            );
        }

        IProposerAuction.BidInfo storage info = _bids[msg.sender];
        if (info.amountInGwei == 0) {
            // New entry: its live fields already take effect TRANSITION_LEAD_EPOCHS later.
            _purgeInactiveInternal();
            if (_ranked.length >= MAX_LIST_SIZE) {
                // A full list is not closed: evict the lowest-ranked entry when the new bid
                // clears it by the increment (the evictee is rank 16, never winner/backup, so
                // the current/next assignment finality invariant is untouched).
                address evictee = _lowestBidder();
                require(evictee != address(0), ListFull());
                require(
                    _amountInGwei
                        >= uint128(
                            uint256(_bids[evictee].amountInGwei) * (10_000 + MIN_INCREMENT_BPS)
                                / 10_000
                        ),
                    IncrementTooSmall()
                );
                _lapseBid(evictee);
            }
            _ranked.push(msg.sender);
            info = _bids[msg.sender];
            _everListed[msg.sender] = true;

            unchecked {
                // Safe: _tenureMaxEpochs <= type(uint32).max - TRANSITION_LEAD_EPOCHS.
                info.effectiveEpoch = currentEpoch + TRANSITION_LEAD_EPOCHS;
                info.expiresAtEpoch = info.effectiveEpoch + _tenureMaxEpochs;
            }
            info.amountInGwei = _amountInGwei;
            info.placedEpoch = currentEpoch;
            info.joinedAt = uint48(block.timestamp);
            unchecked {
                info.placedSeq = ++_bidSeq;
            }
            _signers[msg.sender] = _signer;
        } else {
            // Existing entry: record a pending change so that already-finalized assignments
            // (current and next epoch) are never altered by re-bids or signer rotations.
            unchecked {
                uint32 effectiveEpoch = currentEpoch + TRANSITION_LEAD_EPOCHS;
                _pendingUpdates[msg.sender] = IProposerAuction.PendingUpdate({
                    amountInGwei: _amountInGwei,
                    signer: _signer,
                    effectiveEpoch: effectiveEpoch,
                    expiresAtEpoch: effectiveEpoch + _tenureMaxEpochs
                });
            }
        }

        emit BidPlaced(msg.sender, _amountInGwei, _signer);
    }

    /// @inheritdoc IProposerAuction
    function renew() external nonReentrant {
        IProposerAuction.BidInfo storage info = _bids[msg.sender];
        require(info.amountInGwei != 0, NotListed());
        require(info.withdrawEffectiveEpoch == 0, AlreadyQuitting());
        // A listed operator whose bond has been slashed below the ejection threshold cannot
        // keep renewing their tenure (Q7): the seat must not persist as an unbonded franchise.
        require(_bonds[msg.sender].balance >= _ejectionThreshold, InsufficientBond());

        // Renewals are pending too: they must never resurrect an expiring entry into the
        // already-finalized next epoch. The new expiry applies from the pending effective epoch.
        IProposerAuction.PendingUpdate storage pending = _pendingUpdates[msg.sender];
        unchecked {
            uint32 effectiveEpoch = _currentEpochIndex() + TRANSITION_LEAD_EPOCHS;
            pending.effectiveEpoch = effectiveEpoch;
            pending.expiresAtEpoch = effectiveEpoch + _tenureMaxEpochs;
        }
        // If a pending re-bid exists, its amount/signer are kept; otherwise this stays an
        // expiry-only renewal (amountInGwei remains 0).

        emit BidRenewed(msg.sender, pending.expiresAtEpoch);
    }

    /// @inheritdoc IProposerAuction
    function quit() external nonReentrant {
        IProposerAuction.BidInfo storage info = _bids[msg.sender];
        require(info.amountInGwei != 0, NotListed());
        require(info.withdrawEffectiveEpoch == 0, AlreadyQuitting());

        unchecked {
            info.withdrawEffectiveEpoch = _currentEpochIndex() + TRANSITION_LEAD_EPOCHS;
        }

        // Quitting wins over any pending re-bid/renewal.
        delete _pendingUpdates[msg.sender];

        IProposerAuction.BondInfo storage bond = _bonds[msg.sender];
        if (bond.withdrawableAt == 0) {
            bond.withdrawableAt = uint48(block.timestamp) + _bondWithdrawalDelay;
        }

        emit BidWithdrawn(msg.sender, info.withdrawEffectiveEpoch);
    }

    /// @inheritdoc IProposerAuction
    function purgeInactive() external returns (uint256 removed_) {
        removed_ = _catchUpSnapshots(MAX_BACKFILL_EPOCHS);
    }

    /// @inheritdoc IProposerAuction
    function snapshot() external nonReentrant {
        _catchUpSnapshots(MAX_BACKFILL_EPOCHS);
    }

    // ---------------------------------------------------------------
    // Bonds (TAIKO)
    // ---------------------------------------------------------------

    /// @inheritdoc IProposerAuction
    function depositBond(uint128 _amount) external nonReentrant {
        bondToken.safeTransferFrom(msg.sender, address(this), uint256(_amount) * 1 gwei);
        _bonds[msg.sender].balance += _amount;
        emit BondDeposited(msg.sender, _amount);
    }

    /// @inheritdoc IProposerAuction
    function withdrawBond(uint128 _amount) external nonReentrant {
        IProposerAuction.BondInfo storage info = _bonds[msg.sender];
        if (info.withdrawableAt == 0) {
            // Active bidders must quit first; formerly-listed accounts must have started their
            // withdrawal clock via quit()/lapse/purge — expiry alone is not a delay-free exit
            // (Q6). Never-listed accounts (transient rung-2 bonders) may withdraw instantly.
            require(!_hasActiveBid(msg.sender), ActiveBidderMustQuitFirst());
            require(!_everListed[msg.sender], WithdrawalDelayNotPassed());
        } else {
            require(block.timestamp >= info.withdrawableAt, WithdrawalDelayNotPassed());
        }
        require(info.balance >= _amount, InsufficientBond());

        info.balance -= _amount;
        bondToken.safeTransfer(msg.sender, uint256(_amount) * 1 gwei);

        emit BondWithdrawn(msg.sender, _amount);
    }

    // ---------------------------------------------------------------
    // ETH Prepay and Proceeds
    // ---------------------------------------------------------------

    /// @inheritdoc IProposerAuction
    function depositEth() external payable {
        _ethBalances[msg.sender] += msg.value;
        emit EthDeposited(msg.sender, msg.value);
    }

    /// @inheritdoc IProposerAuction
    function withdrawEth(uint256 _amount) external nonReentrant {
        // Q11: bring the assignment cache current first — the next-winner reservation below is
        // only active when _assignedEpoch == currentEpoch, and lazy snapshots leave a stale-cache
        // window at every epoch start that a fixed next winner could otherwise drain through.
        _catchUpSnapshots(MAX_BACKFILL_EPOCHS);

        uint256 available = _ethBalances[msg.sender];
        // The fixed next-epoch winner must keep enough ETH to pay the epoch they already won;
        // otherwise draining prepaid ETH would be a fast exit that bypasses the quit notice.
        if (_assignedEpoch == _currentEpochIndex() && _nextWinner == msg.sender) {
            uint256 reserved = uint256(_bids[msg.sender].amountInGwei) * 1 gwei;
            available = available > reserved ? available - reserved : 0;
        }
        require(available >= _amount, InsufficientEth());

        _ethBalances[msg.sender] -= _amount;
        (bool success,) = msg.sender.call{ value: _amount }("");
        require(success, EthTransferFailed());

        emit EthWithdrawn(msg.sender, _amount);
    }

    /// @inheritdoc IProposerAuction
    function withdrawProceeds(address _to, uint256 _amount) external onlyOwner nonReentrant {
        require(_to != address(0), ZeroAddress());
        require(_proceeds >= _amount, InsufficientProceeds());

        _proceeds -= _amount;
        (bool success,) = _to.call{ value: _amount }("");
        require(success, EthTransferFailed());

        emit ProceedsWithdrawn(_to, _amount);
    }

    // ---------------------------------------------------------------
    // IProposerChecker
    // ---------------------------------------------------------------

    /// @inheritdoc IProposerChecker
    /// @dev Implements the fallback ladder. Writes lastProposalAt atomically with the proposal
    ///      transaction (a revert rolls the write back together with the proposal).
    function checkProposer(
        address _proposer,
        bytes calldata /*_lookaheadData*/
    )
        external
        override(IProposerChecker)
        returns (uint48 endOfSubmissionWindowTimestamp_)
    {
        require(msg.sender == inbox, NotInbox());

        uint32 currentEpoch = _currentEpochIndex();
        // Q4: bounded resumable catch-up instead of a single-epoch snapshot, so a quiet epoch
        // is never sealed (and its S1 evidence voided) by its first successor proposal.
        _catchUpSnapshots(MAX_BACKFILL_EPOCHS);

        uint48 epochStart = LibPreconfUtils.getEpochTimestamp();
        uint48 epochEnd = uint48(uint256(epochStart) + LibPreconfConstants.SECONDS_IN_EPOCH);

        // Q2: when the winner carried their clock across a boundary, _lastWinnerProposalAt is
        // their actual last proposal (possibly in a previous epoch); only a winner with no
        // proposal history (freshly assigned) measures absence from epochStart.
        uint48 absenceBase = _lastWinnerProposalAt == 0 ? epochStart : _lastWinnerProposalAt;
        uint48 absence = uint48(block.timestamp) - absenceBase;

        address winner = _currentWinner;

        // Rung 0: the winner may always propose during their epoch.
        if (winner != address(0) && _proposer == winner) {
            _lastProposalAt = uint48(block.timestamp);
            _lastWinnerProposalAt = uint48(block.timestamp);
            return epochEnd;
        }

        bool allowed;
        if (winner == address(0)) {
            // Unassigned: any bonded operator may propose first-come; anyone after the grace.
            bool bonded = _hasBondAtLeast(_proposer, _ejectionThreshold);
            allowed = absence > _stallGrace || bonded;
            if (allowed && bonded && absence <= _stallGrace) {
                // Q19: price the free-rider option — the first bonded operator to use the
                // instant unassigned rung pays the (decaying) reserve floor, once per epoch.
                _chargeUnassignedFee(currentEpoch, _proposer);
                // Q15: passing the rung via the bond defers that bond's withdrawal, so the
                // "bonded operator" gate is standing collateral, not a same-block round-trip.
                _deferBondWithdrawal(_proposer);
            }
        } else if (absence > _stallGrace) {
            uint48 graceSum1 = _stallGrace + _backupGrace;
            uint48 graceSum2 = graceSum1 + _fallbackGrace;
            if (absence <= graceSum1) {
                // Rung 1: the designated backup only.
                allowed = _proposer == _currentBackup;
            } else if (absence <= graceSum2) {
                // Rung 2: the backup or any bonded operator.
                allowed = (_currentBackup != address(0) && _proposer == _currentBackup)
                    || _hasBondAtLeast(_proposer, _ejectionThreshold);
                if (allowed && _proposer != _currentBackup) {
                    // Q15: a non-backup operator passing via the bond defers that bond.
                    _deferBondWithdrawal(_proposer);
                }
            } else {
                // Rung 3: anyone.
                allowed = true;
            }
        }
        if (!allowed) revert InvalidProposer();

        // Slash escrow fires only after the (larger) escrow grace, so transient accidents let
        // backups serve without slashing an honest winner.
        if (winner != address(0) && absence > _escrowGrace) {
            _escrowStallSlash(currentEpoch, winner, absenceBase, _proposer);
        }
        _lastProposalAt = uint48(block.timestamp);
        return epochEnd;
    }

    // ---------------------------------------------------------------
    // Slashing
    // ---------------------------------------------------------------

    /// @inheritdoc IProposerAuction
    function settleStallSlash(uint32 _epoch) external nonReentrant {
        IProposerAuction.StallEscrow storage escrow = _stallEscrows[_epoch];
        require(escrow.escrowedAt != 0 && !escrow.settled, NoPendingStallSlash());
        require(
            uint48(block.timestamp) >= escrow.escrowedAt + _refuteWindow, RefuteWindowNotPassed()
        );

        escrow.settled = true;
        _slashedBefore[keccak256(abi.encode(_epoch, _FAULT_STALL, escrow.winner))] = true;

        // Challenger reward (Q9): the designated backup's reward is burned — the direct
        // beneficiary of a stall must not also collect the slash.
        uint128 reward = uint128(uint256(escrow.amount) * _rewardBps / 10_000);
        if (reward > 0 && !escrow.challengerIsBackup) {
            _bonds[escrow.challenger].balance += reward;
        } else {
            reward = 0;
        }
        // Settle bounty (Q8): pay the caller out of the locked remainder so settlement is
        // self-incentivized.
        uint128 bounty = uint128(uint256(escrow.amount - reward) * _settleBountyBps / 10_000);
        if (bounty > 0) _bonds[msg.sender].balance += bounty;
        _totalSlashedAmount += escrow.amount - reward - bounty;

        _maybeEject(escrow.winner);

        emit StallSettled(_epoch, escrow.winner, escrow.amount, escrow.challenger, reward);
    }

    /// @inheritdoc IProposerAuction
    function refuteStall(uint32 _epoch, IInbox.Proposal calldata _proposal) external nonReentrant {
        IProposerAuction.StallEscrow storage escrow = _stallEscrows[_epoch];
        require(escrow.escrowedAt != 0 && !escrow.settled, NoPendingStallSlash());
        require(msg.sender == escrow.winner, NotWinner());

        require(
            LibHashOptimized.hashProposal(_proposal) == IInbox(inbox).getProposalHash(_proposal.id),
            InvalidRefutation()
        );
        require(_proposal.proposer == escrow.winner, InvalidRefutation());
        require(
            _proposal.timestamp > escrow.gapStart && _proposal.timestamp <= escrow.escrowedAt,
            InvalidRefutation()
        );

        _bonds[escrow.winner].balance += escrow.amount;
        escrow.settled = true;

        emit StallRefuted(_epoch, escrow.winner);
    }

    /// @inheritdoc IProposerAuction
    /// @dev Evidence window: the per-epoch winner/signer records persist forever, but slashing
    ///      is economically effective only while the winner's bond remains (bond withdrawal is
    ///      only possible after quit + the withdrawal delay).
    function slashInvalidBlock(uint32 _epoch, SignedBlock calldata _block) external nonReentrant {
        address winner = _epochWinners[_epoch];
        require(winner != address(0), NoWinnerForEpoch());
        require(_block.epoch == _epoch, InvalidSignature());
        require(_recoverBlockSigner(_block) == _epochSigners[_epoch], InvalidSignature());

        uint256 epochStart = _epochStartTimestamp(_epoch);
        // Q3: the incoming operator legally produces handover blocks in the last
        // HANDOVER_MARGIN seconds of the outgoing epoch (the client's handoverSkipSlots
        // convention). Blocks tagged epoch E are legal from epochStart(E) - handoverMargin.
        uint256 legalStart = epochStart - uint256(_handoverMargin);
        require(
            uint256(_block.timestamp) < legalStart
                || uint256(_block.timestamp) >= epochStart + LibPreconfConstants.SECONDS_IN_EPOCH,
            NoViolation()
        );

        bytes32 evidence = keccak256(
            abi.encode(
                _block.epoch,
                _block.blockNumber,
                _block.parentHash,
                _block.timestamp,
                _block.coinbase,
                _block.gasLimit,
                _block.txRoot
            )
        );
        _slashForFault(_epoch, _FAULT_INVALID_BLOCK, winner, msg.sender, evidence);
    }

    /// @inheritdoc IProposerAuction
    /// @dev Evidence window: see slashInvalidBlock.
    function slashEquivocation(
        uint32 _epoch,
        SignedBlock calldata _a,
        SignedBlock calldata _b
    )
        external
        nonReentrant
    {
        address winner = _epochWinners[_epoch];
        require(winner != address(0), NoWinnerForEpoch());
        require(_a.epoch == _epoch && _b.epoch == _epoch, InvalidSignature());
        // Q10: equivocation is two signatures sharing (epoch, seqNo) but differing in content —
        // the winner signs at most one block per slot, so a fabricated-parentHash double-spend is
        // a second signature for the same seqNo once the canonical block is produced.
        require(_a.seqNo == _b.seqNo, NoViolation());
        require(
            _a.blockNumber != _b.blockNumber || _a.parentHash != _b.parentHash
                || _a.timestamp != _b.timestamp || _a.coinbase != _b.coinbase
                || _a.gasLimit != _b.gasLimit || _a.txRoot != _b.txRoot,
            NoViolation()
        );
        require(
            _recoverBlockSigner(_a) == _epochSigners[_epoch]
                && _recoverBlockSigner(_b) == _epochSigners[_epoch],
            InvalidSignature()
        );

        bytes32 evidence = keccak256(abi.encode(_hashBlockData(_a), _hashBlockData(_b)));
        _slashForFault(_epoch, _FAULT_EQUIVOCATION, winner, msg.sender, evidence);
    }

    // ---------------------------------------------------------------
    // External View Functions
    // ---------------------------------------------------------------

    /// @inheritdoc IProposerAuction
    function getAssignmentForCurrentEpoch()
        external
        view
        returns (IProposerAuction.Assignment memory assignment_)
    {
        uint32 currentEpoch = _currentEpochIndex();
        if (_assignedEpoch == currentEpoch) {
            return IProposerAuction.Assignment(_currentWinner, _currentBackup);
        }
        (address winner_, address backup_,) = _viewAssignment(currentEpoch);
        return IProposerAuction.Assignment(winner_, backup_);
    }

    /// @inheritdoc IProposerAuction
    function getAssignmentForNextEpoch()
        external
        view
        returns (IProposerAuction.Assignment memory assignment_)
    {
        uint32 currentEpoch = _currentEpochIndex();
        if (_assignedEpoch == currentEpoch) {
            return IProposerAuction.Assignment(_nextWinner, _nextBackup);
        }
        (address winner_, address backup_,) = _viewAssignment(currentEpoch + 1);
        return IProposerAuction.Assignment(winner_, backup_);
    }

    /// @inheritdoc IProposerAuction
    function getProvisionalWinner() external view returns (address winner_, bool isFinal_) {
        uint32 currentEpoch = _currentEpochIndex();
        uint128 topAmount;
        uint48 topPlacedSeq;
        for (uint256 i; i < _ranked.length; ++i) {
            address bidder = _ranked[i];
            IProposerAuction.BidInfo memory info = _bids[bidder];
            if (info.amountInGwei == 0) continue;
            if (
                winner_ == address(0) || info.amountInGwei > topAmount
                    || (info.amountInGwei == topAmount && info.placedSeq < topPlacedSeq)
            ) {
                winner_ = bidder;
                topAmount = info.amountInGwei;
                topPlacedSeq = info.placedSeq;
            }
        }
        if (winner_ != address(0)) {
            IProposerAuction.BidInfo memory info = _bids[winner_];
            isFinal_ = info.effectiveEpoch <= currentEpoch + 1
                && info.expiresAtEpoch > currentEpoch + 1
                && (info.withdrawEffectiveEpoch == 0
                    || info.withdrawEffectiveEpoch > currentEpoch + 1);
        }
    }

    /// @inheritdoc IProposerAuction
    function getBidderInfo(address _bidder)
        external
        view
        returns (IProposerAuction.BidInfo memory info_, address signer_)
    {
        return (_bids[_bidder], _signers[_bidder]);
    }

    /// @inheritdoc IProposerAuction
    function getPendingUpdate(address _bidder)
        external
        view
        returns (IProposerAuction.PendingUpdate memory update_)
    {
        return _pendingUpdates[_bidder];
    }

    /// @inheritdoc IProposerAuction
    function getBondInfo(address _account)
        external
        view
        returns (IProposerAuction.BondInfo memory info_)
    {
        return _bonds[_account];
    }

    /// @inheritdoc IProposerAuction
    function getEthBalance(address _account) external view returns (uint256 balance_) {
        return _ethBalances[_account];
    }

    /// @inheritdoc IProposerAuction
    function getReserveFloor() public view returns (uint128 floorInGwei_) {
        uint256 scaled = uint256(_movingAverageBid) * _movingAverageMultiplier;
        uint256 floor = LibMath.max(uint256(_initialFloorInGwei), scaled);
        // Q1: when an incumbent exists, the 5% increment rule is the true entry bar; the EMA
        // floor must not price entrants above it (otherwise the floor, not the increment, closes
        // the auction at ~2x the incumbent's rate).
        (uint128 topAmount,) = _activeTop(_currentEpochIndex());
        if (topAmount != 0) {
            uint256 incrementBar = uint256(topAmount) * (10_000 + MIN_INCREMENT_BPS) / 10_000;
            floor = LibMath.min(floor, incrementBar);
        }
        floorInGwei_ = uint128(LibMath.min(floor, uint256(type(uint128).max)));
    }

    /// @inheritdoc IProposerAuction
    function getHandoverMargin() external view returns (uint48 handoverMargin_) {
        return _handoverMargin;
    }

    /// @inheritdoc IProposerAuction
    function getSettleBountyBps() external view returns (uint16 settleBountyBps_) {
        return _settleBountyBps;
    }

    /// @inheritdoc IProposerAuction
    function getFloorDecayBps() external view returns (uint16 floorDecayBps_) {
        return _floorDecayBps;
    }

    /// @inheritdoc IProposerAuction
    function getPendingStallSlash(uint32 _epoch)
        external
        view
        returns (IProposerAuction.StallEscrow memory escrow_)
    {
        return _stallEscrows[_epoch];
    }

    /// @inheritdoc IProposerAuction
    function getRequiredBond() external view returns (uint128 requiredBond_) {
        return _requiredBond;
    }

    /// @inheritdoc IProposerAuction
    function getEjectionThreshold() external view returns (uint128 threshold_) {
        return _ejectionThreshold;
    }

    /// @inheritdoc IProposerAuction
    function getLivenessBond() external view returns (uint96 livenessBond_) {
        return _livenessBond;
    }

    /// @inheritdoc IProposerAuction
    function getTotalSlashedAmount() external view returns (uint128 total_) {
        return _totalSlashedAmount;
    }

    /// @inheritdoc IProposerAuction
    function getProceeds() external view returns (uint256 proceeds_) {
        return _proceeds;
    }

    /// @inheritdoc IProposerAuction
    function getBidderCount() external view returns (uint256 count_) {
        return _ranked.length;
    }

    /// @inheritdoc IProposerAuction
    function getBidderAt(uint256 _index) external view returns (address bidder_) {
        return _ranked[_index];
    }

    // ---------------------------------------------------------------
    // Internal Functions
    // ---------------------------------------------------------------

    /// @dev Computes and caches the current and next epoch assignments. The current epoch is
    ///      PROMOTED from the cached next assignment whenever the previous snapshot ran, so
    ///      finalized assignments can never be recomputed away by later transitions; the next
    ///      epoch is computed once here and stays final for the whole epoch. The winner's
    ///      per-epoch fee is charged lazily at promotion — no keeper transactions.
    /// @param _epoch The epoch to assign.
    function _snapshot(uint32 _epoch) internal {
        address prevWinner = _currentWinner;
        bool contiguous = _assignedEpoch == _epoch - 1;

        address winner_ = _nextWinner;
        address backup_ = _nextBackup;
        uint128 chargedInGwei;
        bool promoted = false;

        if (_assignedEpoch == _epoch - 1) {
            // Normal path: promote the assignment fixed at the previous snapshot.
            if (winner_ == address(0)) {
                promoted = true;
            } else if (
                // Q7: the winner must also still be bonded at the ejection threshold; a
                // self-drained winner is lapsed at the boundary, never re-promoted.
                _bids[winner_].amountInGwei != 0 && _bonds[winner_].balance >= _ejectionThreshold
                    && _tryCharge(winner_)
            ) {
                chargedInGwei = _bids[winner_].amountInGwei;
                promoted = true;
            } else {
                // Ejected since the prediction or unable to pay (ETH or bond): fall through to a
                // fresh compute so the backup inherits immediately.
                if (_bids[winner_].amountInGwei != 0) _lapseBid(winner_);
            }
            if (promoted) {
                _currentWinner = winner_;
                _currentBackup = backup_;
            }
        }

        if (!promoted) {
            // Boot/catch-up path: state relevant to _epoch is immutable (transitions placed now
            // take effect >= _epoch + 2), so computing fresh is equivalent to the fixed value.
            _materializePending(_epoch);
            (_currentWinner, _currentBackup, chargedInGwei) = _computeAssignment(_epoch, true);
        }

        _assignedEpoch = _epoch;

        // Q2/Q12 — the winner-absence clock. A winner unchanged across the boundary carries
        // their clock (the ladder does not re-close); a genuinely new (scheduled) winner gets
        // the full grace from epochStart (reset to 0); a fresh-computed winner on a *contiguous*
        // boundary is a surprise inheritance and its clock starts at assignment, so an escrow can
        // never fire in the transaction that created the assignment; a boot/catch-up-gap snapshot
        // is not a surprise and gets the full grace from epochStart.
        if (promoted) {
            if (_currentWinner != prevWinner) _lastWinnerProposalAt = 0;
        } else if (contiguous) {
            _lastWinnerProposalAt = uint48(block.timestamp);
        } else {
            _lastWinnerProposalAt = 0;
        }

        // Record the epoch's winner/signer BEFORE materializing pending changes that affect the
        // NEXT epoch: the signer slashable for this epoch is the one that was live when the
        // assignment was fixed, never a rotation that materializes later.
        if (_currentWinner != address(0)) {
            _epochWinners[_epoch] = _currentWinner;
            _epochSigners[_epoch] = _signers[_currentWinner];
            _updateMovingAverage(_bids[_currentWinner].amountInGwei);
        } else {
            // Q1: decay the reserve floor while the list is unassigned, so vacancy is not an
            // absorbing state (the floor relaxes toward initialFloor and the auction re-opens).
            _decayMovingAverage();
        }

        // Materialize changes that may affect the next epoch, then compute it (final for the
        // rest of the current epoch).
        _materializePending(_epoch + 1);
        (_nextWinner, _nextBackup,) = _computeAssignment(_epoch + 1, false);

        emit EpochAssigned(_epoch, _currentWinner, _currentBackup, chargedInGwei);
    }

    /// @dev Charges the winner's per-epoch fee if payable.
    /// @param _winner The winner to charge.
    /// @return charged_ True if the fee was charged.
    function _tryCharge(address _winner) internal returns (bool charged_) {
        uint256 feeWei = uint256(_bids[_winner].amountInGwei) * 1 gwei;
        if (_ethBalances[_winner] < feeWei) return false;
        _ethBalances[_winner] -= feeWei;
        _proceeds += feeWei;
        return true;
    }

    /// @dev Applies pending changes (re-bids, renewals, signer rotations) that take effect by
    ///      _throughEpoch. Entries removed meanwhile drop their pending changes.
    /// @param _throughEpoch The latest effective epoch to materialize.
    function _materializePending(uint32 _throughEpoch) internal {
        for (uint256 i; i < _ranked.length; ++i) {
            address bidder = _ranked[i];
            IProposerAuction.PendingUpdate memory pending = _pendingUpdates[bidder];
            if (pending.effectiveEpoch == 0 || pending.effectiveEpoch > _throughEpoch) continue;
            delete _pendingUpdates[bidder];

            IProposerAuction.BidInfo storage info = _bids[bidder];
            if (info.amountInGwei == 0) continue; // purged or ejected meanwhile

            if (pending.amountInGwei != 0) {
                info.amountInGwei = pending.amountInGwei;
                info.effectiveEpoch = pending.effectiveEpoch;
                info.expiresAtEpoch = pending.expiresAtEpoch;
                info.withdrawEffectiveEpoch = 0; // a re-bid revokes a quit
                info.joinedAt = uint48(block.timestamp);
                unchecked {
                    info.placedSeq = ++_bidSeq;
                }
                _signers[bidder] = pending.signer;
            } else {
                info.expiresAtEpoch = pending.expiresAtEpoch;
            }
        }
    }

    /// @dev Catches up missed snapshots up to _maxSteps epochs back, so epoch records and fee
    ///      charges exist even for epochs in which nobody proposed.
    /// @param _maxSteps The maximum number of epochs to backfill.
    function _catchUpSnapshots(uint32 _maxSteps) internal returns (uint256 purged_) {
        uint32 currentEpoch = _currentEpochIndex();
        if (_assignedEpoch >= currentEpoch) return 0;
        uint32 start;
        if (_assignedEpoch == 0) {
            // Bootstrap: the contract has never snapshotted. Epochs before now predate any bid
            // (bids take effect two epochs after placement), so fast-forward to the current
            // epoch instead of backfilling the pre-deployment gap.
            start = currentEpoch;
        } else {
            // Q17: resumable — process up to _maxSteps epochs starting from _assignedEpoch + 1,
            // never skipping, so repeated permissionless pokes eventually record every epoch
            // (bounded gas per call, no permanently lost epochs).
            start = _assignedEpoch + 1;
        }
        uint32 end = start + _maxSteps - 1;
        if (end > currentEpoch) end = currentEpoch;
        for (uint32 e = start; e <= end; ++e) {
            _snapshot(e);
        }
        // Q5: purge once, after the catch-up loop, at the (now-current) _assignedEpoch reference.
        purged_ = _purgeInactiveInternal();
    }

    /// @dev Ranks active entries for an epoch and optionally charges the winner's per-epoch fee.
    /// @param _epoch The epoch to compute the assignment for.
    /// @param _charge Whether to charge the winner (true only when the epoch becomes current).
    /// @return winner_ The top active bidder, or address(0).
    /// @return backup_ The second active bidder, or address(0).
    /// @return chargedInGwei_ The amount charged, if any.
    function _computeAssignment(
        uint32 _epoch,
        bool _charge
    )
        internal
        returns (address winner_, address backup_, uint128 chargedInGwei_)
    {
        // Q12: only the eventual winner is charged (and lapsed on non-payment); underfunded
        // non-winners are skipped, never mass-lapsed. The loop re-runs at most once per lapsed
        // winner (each lapse removes an entry from the <=16 list), so it is strictly bounded.
        while (true) {
            address[] memory candidates = new address[](_ranked.length);
            uint256 count;

            // Iterate backwards so that lapses (which swap-pop) are safe.
            for (uint256 i = _ranked.length; i > 0; --i) {
                address bidder = _ranked[i - 1];
                IProposerAuction.BidInfo memory info = _bids[bidder];
                if (info.amountInGwei == 0) continue;
                if (info.effectiveEpoch > _epoch) continue;
                if (info.expiresAtEpoch <= _epoch) continue;
                if (info.withdrawEffectiveEpoch != 0 && info.withdrawEffectiveEpoch <= _epoch) {
                    continue;
                }
                candidates[count++] = bidder;
            }

            for (uint256 i; i < count; ++i) {
                address candidate = candidates[i];
                IProposerAuction.BidInfo memory info = _bids[candidate];
                if (winner_ == address(0) || _outranks(info, _bids[winner_])) {
                    backup_ = winner_;
                    winner_ = candidate;
                } else if (backup_ == address(0) || _outranks(info, _bids[backup_])) {
                    backup_ = candidate;
                }
            }

            if (!_charge || winner_ == address(0)) break;

            uint256 feeWei = uint256(_bids[winner_].amountInGwei) * 1 gwei;
            if (_ethBalances[winner_] >= feeWei) {
                chargedInGwei_ = _bids[winner_].amountInGwei;
                _ethBalances[winner_] -= feeWei;
                _proceeds += feeWei;
                break;
            }

            // Winner cannot pay: lapse only the winner and re-rank.
            _lapseBid(winner_);
            winner_ = address(0);
            backup_ = address(0);
        }
    }

    /// @dev View variant of _computeAssignment: no charging, no lapses.
    function _viewAssignment(uint32 _epoch)
        internal
        view
        returns (address winner_, address backup_, uint128 chargedInGwei_)
    {
        address[] memory candidates = new address[](_ranked.length);
        uint256 count;
        for (uint256 i; i < _ranked.length; ++i) {
            address bidder = _ranked[i];
            IProposerAuction.BidInfo memory info = _bids[bidder];
            if (info.amountInGwei == 0) continue;
            if (info.effectiveEpoch > _epoch) continue;
            if (info.expiresAtEpoch <= _epoch) continue;
            if (info.withdrawEffectiveEpoch != 0 && info.withdrawEffectiveEpoch <= _epoch) {
                continue;
            }
            candidates[count++] = bidder;
        }
        for (uint256 i; i < count; ++i) {
            address candidate = candidates[i];
            IProposerAuction.BidInfo memory info = _bids[candidate];
            if (winner_ == address(0) || _outranks(info, _bids[winner_])) {
                backup_ = winner_;
                winner_ = candidate;
            } else if (backup_ == address(0) || _outranks(info, _bids[backup_])) {
                backup_ = candidate;
            }
        }
        chargedInGwei_ = winner_ == address(0) ? 0 : _bids[winner_].amountInGwei;
    }

    /// @dev Returns the highest active bid for an epoch (used for the outbid increment rule).
    function _activeTop(uint32 _epoch)
        internal
        view
        returns (uint128 topAmount_, address topHolder_)
    {
        for (uint256 i; i < _ranked.length; ++i) {
            address bidder = _ranked[i];
            IProposerAuction.BidInfo memory info = _bids[bidder];
            if (info.amountInGwei == 0) continue;
            if (info.effectiveEpoch > _epoch) continue;
            if (info.expiresAtEpoch <= _epoch) continue;
            if (info.withdrawEffectiveEpoch != 0 && info.withdrawEffectiveEpoch <= _epoch) {
                continue;
            }
            if (
                topHolder_ == address(0) || info.amountInGwei > topAmount_
                    || (info.amountInGwei == topAmount_
                        && info.placedSeq < _bids[topHolder_].placedSeq)
            ) {
                topAmount_ = info.amountInGwei;
                topHolder_ = bidder;
            }
        }
    }

    /// @dev Escrows the winner's liveness bond when a fallback proposer fires the ladder.
    /// @param _epoch The fault epoch.
    /// @param _winner The stalled winner.
    /// @param _gapStart The start of the recorded proposal gap.
    /// @param _challenger The fallback proposer.
    function _escrowStallSlash(
        uint32 _epoch,
        address _winner,
        uint48 _gapStart,
        address _challenger
    )
        internal
    {
        IProposerAuction.StallEscrow storage escrow = _stallEscrows[_epoch];
        if (escrow.escrowedAt != 0) return; // One escrow per epoch.

        uint128 amount =
            uint128(LibMath.min(uint256(_livenessBond), uint256(_bonds[_winner].balance)));
        if (amount == 0) return;

        _bonds[_winner].balance -= amount;
        escrow.winner = _winner;
        escrow.amount = amount;
        escrow.gapStart = _gapStart;
        escrow.escrowedAt = uint48(block.timestamp);
        escrow.challenger = _challenger;
        // Q9: record whether the challenger was the designated backup, so settlement can burn
        // the reward of the stall's direct beneficiary.
        escrow.challengerIsBackup = _challenger == _currentBackup;

        emit StallEscrowed(_epoch, _winner, amount, _gapStart, _challenger);
    }

    /// @dev Applies a one-shot slash for an S1 fault.
    /// @param _epoch The fault epoch.
    /// @param _faultType The fault type.
    /// @param _winner The slashed winner.
    /// @param _challenger The challenger receiving the reward.
    /// @param _evidence Fault-specific evidence.
    function _slashForFault(
        uint32 _epoch,
        uint8 _faultType,
        address _winner,
        address _challenger,
        bytes32 _evidence
    )
        internal
    {
        uint128 amount =
            uint128(LibMath.min(uint256(_livenessBond), uint256(_bonds[_winner].balance)));
        // Never burn the one-shot digest on an unbonded (already-exited) winner.
        require(amount > 0, NoBondToSlash());

        bytes32 digest = keccak256(abi.encode(_epoch, _faultType, _winner, _evidence));
        require(!_slashedBefore[digest], AlreadySlashed());
        _slashedBefore[digest] = true;

        uint128 reward = uint128(uint256(amount) * _rewardBps / 10_000);

        _bonds[_winner].balance -= amount;
        if (reward > 0) _bonds[_challenger].balance += reward;
        _totalSlashedAmount += amount - reward;

        _maybeEject(_winner);

        emit ProposerSlashed(_winner, _faultType, amount, _challenger, reward);
    }

    /// @dev Ejects a bidder whose bond is below the ejection threshold.
    /// @param _bidder The bidder to check.
    function _maybeEject(address _bidder) internal {
        if (_bonds[_bidder].balance >= _ejectionThreshold) return;
        if (_bids[_bidder].amountInGwei == 0) return;

        _removeBidder(_bidder);
        IProposerAuction.BondInfo storage bond = _bonds[_bidder];
        if (bond.withdrawableAt == 0) {
            bond.withdrawableAt = uint48(block.timestamp) + _bondWithdrawalDelay;
        }

        emit ProposerEjected(_bidder);
    }

    /// @dev Lapses a bid (removes it and starts the bond withdrawal delay).
    /// @param _bidder The bidder to lapse.
    function _lapseBid(address _bidder) internal {
        _removeBidder(_bidder);
        IProposerAuction.BondInfo storage bond = _bonds[_bidder];
        if (bond.withdrawableAt == 0) {
            bond.withdrawableAt = uint48(block.timestamp) + _bondWithdrawalDelay;
        }
        emit BidLapsed(_bidder);
    }

    /// @dev Removes a bidder from the list (swap-pop) and clears their bid entry.
    /// @param _bidder The bidder to remove.
    function _removeBidder(address _bidder) internal {
        if (_bids[_bidder].amountInGwei == 0) return;

        uint256 last = _ranked.length - 1;
        for (uint256 i; i <= last; ++i) {
            if (_ranked[i] == _bidder) {
                _ranked[i] = _ranked[last];
                _ranked.pop();
                delete _bids[_bidder];
                return;
            }
        }
    }

    /// @dev Removes all lapsed entries (expired, withdrawn-and-effective, or zero amount).
    /// @return removed_ The number of entries removed.
    function _purgeInactiveInternal() internal returns (uint256 removed_) {
        // Q5: purge against _assignedEpoch (not the live current epoch) — an entry is only
        // removed once its last active epoch has been recorded, so backfill can never lose a
        // historical winner/signer to a purge that post-dates it.
        uint32 refEpoch = _assignedEpoch;
        for (uint256 i = _ranked.length; i > 0; --i) {
            address bidder = _ranked[i - 1];
            IProposerAuction.BidInfo memory info = _bids[bidder];
            bool inactive = info.amountInGwei == 0 || info.expiresAtEpoch <= refEpoch
                || (info.withdrawEffectiveEpoch != 0 && info.withdrawEffectiveEpoch <= refEpoch);
            // A pending change materializing by the next epoch keeps the entry alive.
            if (inactive) {
                uint32 pendingEffective = _pendingUpdates[bidder].effectiveEpoch;
                if (pendingEffective != 0 && pendingEffective <= refEpoch + 1) {
                    inactive = false;
                }
            }
            if (!inactive) continue;
            // Q6: lapses route through the withdrawal-delay clock (expiry is not a free exit).
            _lapseBid(bidder);
            ++removed_;
        }
    }

    /// @dev Returns whether an address has an active standing bid.
    /// @param _bidder The address to check.
    /// @return active_ True if the bid counts for the current epoch.
    function _hasActiveBid(address _bidder) internal view returns (bool active_) {
        IProposerAuction.BidInfo memory info = _bids[_bidder];
        if (info.amountInGwei == 0) return false;
        uint32 currentEpoch = _currentEpochIndex();
        return info.expiresAtEpoch > currentEpoch
            && (info.withdrawEffectiveEpoch == 0 || info.withdrawEffectiveEpoch > currentEpoch);
    }

    /// @dev Returns whether an account holds at least the given bond amount.
    function _hasBondAtLeast(address _account, uint128 _amount) internal view returns (bool ok_) {
        return _bonds[_account].balance >= _amount;
    }

    /// @dev Starts (or leaves running) an account's bond withdrawal clock. Called when a bond is
    ///      used to pass checkProposer, so the "bonded operator" rung is standing collateral
    ///      rather than a same-block deposit->propose->withdraw round-trip (Q15).
    function _deferBondWithdrawal(address _account) internal {
        if (_bonds[_account].withdrawableAt == 0) {
            _bonds[_account].withdrawableAt = uint48(block.timestamp) + _bondWithdrawalDelay;
        }
    }

    /// @dev Charges the unassigned-mode fee (the decaying reserve floor) to the first bonded
    ///      operator to use the instant unassigned rung in an epoch, once per epoch (Q19).
    function _chargeUnassignedFee(uint32 _epoch, address _proposer) internal {
        if (_lastUnassignedFeeEpoch == _epoch) return;
        uint256 feeWei = uint256(getReserveFloor()) * 1 gwei;
        require(_ethBalances[_proposer] >= feeWei, InsufficientEth());
        _ethBalances[_proposer] -= feeWei;
        _proceeds += feeWei;
        _lastUnassignedFeeEpoch = _epoch;
    }

    /// @dev Returns the lowest-ranked listed bidder (the entry that loses to every other). Used
    ///      to evict the worst entry when the list is full (Q14).
    function _lowestBidder() internal view returns (address lowest_) {
        for (uint256 i; i < _ranked.length; ++i) {
            address bidder = _ranked[i];
            IProposerAuction.BidInfo memory info = _bids[bidder];
            if (info.amountInGwei == 0) continue;
            if (lowest_ == address(0) || _outranks(_bids[lowest_], info)) {
                lowest_ = bidder;
            }
        }
    }

    /// @dev Rank comparison: higher amount wins; ties break by earlier placement (placedSeq).
    function _outranks(
        IProposerAuction.BidInfo memory _a,
        IProposerAuction.BidInfo memory _b
    )
        internal
        pure
        returns (bool outranks_)
    {
        return _a.amountInGwei > _b.amountInGwei
            || (_a.amountInGwei == _b.amountInGwei && _a.placedSeq < _b.placedSeq);
    }

    /// @dev Recovers the signer of a SignedBlock (EIP-712).
    /// @dev The domain separator binds block.chainid and address(this) and is computed at verify
    ///      time so that proxied deployments sign over the proxy address, not the implementation.
    function _recoverBlockSigner(SignedBlock calldata _block)
        internal
        view
        returns (address signer_)
    {
        bytes32 domainSeparator = keccak256(
            abi.encode(
                _DOMAIN_TYPEHASH,
                _DOMAIN_NAME_HASH,
                _DOMAIN_VERSION_HASH,
                block.chainid,
                address(this)
            )
        );
        bytes32 structHash = _hashBlockData(_block);
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));
        signer_ = ecrecover(digest, _block.v, _block.r, _block.s);
        require(signer_ != address(0), InvalidSignature());
    }

    /// @dev Computes the EIP-712 struct hash of a SignedBlock's data.
    function _hashBlockData(SignedBlock calldata _block) internal pure returns (bytes32 hash_) {
        hash_ = keccak256(
            abi.encode(
                _BLOCK_TYPEHASH,
                _block.epoch,
                _block.seqNo,
                _block.blockNumber,
                _block.parentHash,
                _block.timestamp,
                _block.coinbase,
                _block.gasLimit,
                _block.txRoot
            )
        );
    }

    /// @dev Returns the start timestamp of an epoch.
    /// @param _epoch The epoch index.
    function _epochStartTimestamp(uint32 _epoch) internal view returns (uint256 ts_) {
        ts_ = uint256(LibPreconfConstants.getGenesisTimestamp(block.chainid)) + uint256(_epoch)
            * LibPreconfConstants.SECONDS_IN_EPOCH;
    }

    /// @dev Returns the current epoch index.
    function _currentEpochIndex() internal view returns (uint32 epoch_) {
        uint256 epochStart = LibPreconfUtils.getEpochTimestamp();
        uint256 genesis = LibPreconfConstants.getGenesisTimestamp(block.chainid);
        epoch_ = uint32((epochStart - genesis) / LibPreconfConstants.SECONDS_IN_EPOCH);
    }

    /// @dev Updates the time-weighted moving average of charged bids.
    /// @param _newBid The newly charged bid amount, in gwei.
    function _updateMovingAverage(uint128 _newBid) internal {
        uint48 nowTs = uint48(block.timestamp);
        uint128 currentAvg = _movingAverageBid;

        if (currentAvg == 0) {
            _movingAverageBid = _newBid;
            _lastAvgUpdate = nowTs;
            return;
        }

        uint48 lastUpdate = _lastAvgUpdate == 0 ? nowTs : _lastAvgUpdate;
        uint48 window = _movingAverageWindow;

        uint256 weightNew;
        unchecked {
            uint48 elapsed = nowTs - lastUpdate;
            weightNew = elapsed >= window ? window : elapsed;
            if (weightNew == 0) weightNew = 1;
        }

        uint256 weightedAvg =
            (uint256(currentAvg) * (window - weightNew) + uint256(_newBid) * weightNew) / window;
        _movingAverageBid = uint128(weightedAvg);
        _lastAvgUpdate = nowTs;
    }

    /// @dev Decays the moving average by _floorDecayBps (Q1): applied once per unassigned epoch,
    ///      so the reserve floor relaxes toward initialFloor when nobody is assigned (vacancy is
    ///      not an absorbing state).
    function _decayMovingAverage() internal {
        uint128 currentAvg = _movingAverageBid;
        if (currentAvg == 0) return;
        _movingAverageBid = uint128(uint256(currentAvg) * _floorDecayBps / 10_000);
        _lastAvgUpdate = uint48(block.timestamp);
    }

    // ---------------------------------------------------------------
    // Errors
    // ---------------------------------------------------------------

    error ZeroAddress();
    error ZeroValue();
    error InvalidSigner();
    error InvalidBondMultiplier();
    error InvalidBps();
    error InvalidEscrowGrace();
    error InvalidHandoverMargin();
    error NoBondToSlash();
    error InvalidSignature();
    error InvalidRefutation();
    error NoViolation();
    error NoWinnerForEpoch();
    error NoPendingStallSlash();
    error NotWinner();
    error NotListed();
    error AlreadyQuitting();
    error AlreadySlashed();
    error ListFull();
    error IncrementTooSmall();
    error BidBelowReserve();
    error InsufficientBond();
    error InsufficientEth();
    error InsufficientProceeds();
    error ActiveBidderMustQuitFirst();
    error WithdrawalDelayNotPassed();
    error RefuteWindowNotPassed();
    error EthTransferFailed();
    error NotInbox();
}
