// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { IInbox } from "../iface/IInbox.sol";
import { IProverMarket } from "../iface/IProverMarket.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { EssentialContract } from "src/shared/common/EssentialContract.sol";
import { LibAddress } from "src/shared/libs/LibAddress.sol";

/// @title ProverMarket
/// @notice Perpetual reverse-auction prover market. Provers bid to win exclusive proving rights
/// for terms of proposals. Lower fee bids displace the current winner. The market handles
/// authorization, fee accounting, and bond management for proving obligations.
/// @custom:security-contact security@taiko.xyz
contract ProverMarket is EssentialContract, IProverMarket {
    using SafeERC20 for IERC20;
    using LibAddress for address;

    // ---------------------------------------------------------------
    // Structs
    // ---------------------------------------------------------------

    /// @notice Term identity and proposal range (2 slots).
    struct Term {
        // Slot 0 (32 bytes) — hot path: proof settlement
        address prover;
        uint48 startProposalId;
        uint48 endProposalId;
        // Slot 1 (14 bytes used) — chain + fee
        uint64 feeInGwei;
        uint48 prevTermId;
    }

    /// @notice Top-level market state shared across terms (1 slot, 32 bytes).
    struct MarketState {
        uint48 activeTermId;
        uint48 pendingTermId;
        uint48 nextTermId;
        uint8 permissionlessReason;
        bool activeTermExiting;
        uint48 feeEwmaInGwei;
        uint48 lastRetiredTermId;
    }

    /// @notice Tracks cap-exceeded permissionless state (1 slot).
    struct CapState {
        uint48 capFeeSnapshotGwei;
        uint48 capStartProposalId;
        uint48 capProposalCount;
        uint48 lastProvenProposalId;
        uint8 unprovenTermCount;
    }

    /// @notice Consolidated prover financial state packed into a single storage slot.
    struct ProverAccount {
        uint64 bondBalance;
        uint64 reservedBond;
    }

    // ---------------------------------------------------------------
    // Constants
    // ---------------------------------------------------------------

    /// @notice Gas stipend for ETH fee transfers to provers. Matches the Bridge constant.
    /// Enough for proxy dispatch + event log, low enough to prevent callback abuse.
    uint256 private constant _SEND_ETHER_GAS_LIMIT = 35_000;

    // ---------------------------------------------------------------
    // Immutable Variables
    // ---------------------------------------------------------------

    /// @dev Inbox that owns proposal acceptance and proof finalization.
    IInbox internal immutable _inbox;

    /// @dev Bond token that backs prover obligations.
    IERC20 internal immutable _bondToken;

    /// @dev Minimum bond in gwei required to place a bid.
    uint64 internal immutable _minBondGwei;

    /// @dev Exclusive proving window in seconds. Within this window only the assigned prover may
    /// prove; after it anyone may prove and the assigned prover is slashed.
    uint48 internal immutable _provingWindow;

    /// @dev Minimum fee discount in basis points a new bid must undercut by (e.g. 1000 = 10%).
    uint16 internal immutable _bidDiscountBps;

    /// @dev Bond in gwei reserved per assigned proposal. Released when proven.
    uint64 internal immutable _bondPerProposalGwei;

    /// @dev Fixed slash amount in gwei per late proof submission.
    uint64 internal immutable _slashPerProofGwei;

    /// @dev Maximum multiplier applied to the fee EWMA when no active or pending bid exists.
    uint8 internal immutable _maxBidEwmaMultiplier;

    // ---------------------------------------------------------------
    // State Variables
    // ---------------------------------------------------------------

    /// @notice Shared market state.
    MarketState public marketState;

    /// @notice All terms indexed by term id.
    mapping(uint48 termId => Term) public terms;

    /// @notice Consolidated prover account: bond balance and reserved bond.
    mapping(address account => ProverAccount) public proverAccounts;

    /// @notice Cap-exceeded permissionless state.
    CapState public capState;

    uint256[46] private __gap;

    // ---------------------------------------------------------------
    // Events
    // ---------------------------------------------------------------

    /// @notice Emitted when a bid is placed or updated.
    event BidPlaced(uint48 indexed termId, address indexed prover, uint64 feeInGwei);

    /// @notice Emitted when a pending term becomes active.
    event TermActivated(uint48 indexed termId, uint48 firstProposalId, uint48 activatedAt);

    /// @notice Emitted when a prover exits their position.
    event TermExited(uint48 indexed termId);

    /// @notice Emitted when bond is deposited.
    event BondDeposited(address indexed account, uint64 amount);

    /// @notice Emitted when bond is withdrawn.
    event BondWithdrawn(address indexed account, uint64 amount);

    /// @notice Emitted when a prover fee is charged from proposer ETH.
    event FeeCharged(uint48 indexed proposalId, address indexed proposer, uint64 feeInGwei);

    /// @notice Emitted when emergency permissionless mode changes.
    event PermissionlessModeUpdated(bool enabled);

    /// @notice Emitted when unproven term count reaches the cap threshold.
    event CapExceeded(uint48 proposalId);

    /// @notice Emitted when proofs catch up and cap-exceeded mode clears.
    event CapRecovered(uint48 proposalId);

    /// @notice Emitted when a prover is slashed for missing the proving window.
    event ProverSlashed(
        address indexed prover, address indexed proofSubmitter, uint64 slashedAmount
    );

    // ---------------------------------------------------------------
    // Constructor
    // ---------------------------------------------------------------

    /// @notice Initializes immutable contract dependencies.
    /// @param _inboxAddr The inbox address.
    /// @param _bondTokenAddr The bond token address.
    /// @param _minBond The minimum bond in gwei required to bid.
    /// @param _provingWindowSeconds The exclusive proving window in seconds.
    /// @param _bidDiscountBasisPoints Minimum fee discount in basis points for new bids (e.g. 1000
    /// = 10%).
    /// @param _bondPerProposal Bond in gwei reserved per assigned proposal.
    /// @param _slashPerProof Fixed slash amount in gwei per late proof submission.
    /// @param _maxBidMultiplier Maximum multiplier on EWMA for bids when no active/pending term
    /// exists (e.g. 10 means cap at 10x the EWMA).
    constructor(
        address _inboxAddr,
        address _bondTokenAddr,
        uint64 _minBond,
        uint48 _provingWindowSeconds,
        uint16 _bidDiscountBasisPoints,
        uint64 _bondPerProposal,
        uint64 _slashPerProof,
        uint8 _maxBidMultiplier
    )
        nonZeroAddr(_inboxAddr)
        nonZeroAddr(_bondTokenAddr)
        nonZeroValue(_minBond)
        nonZeroValue(_provingWindowSeconds)
        nonZeroValue(_bidDiscountBasisPoints)
        nonZeroValue(_bondPerProposal)
        nonZeroValue(_slashPerProof)
        nonZeroValue(_maxBidMultiplier)
    {
        _inbox = IInbox(_inboxAddr);
        _bondToken = IERC20(_bondTokenAddr);
        _minBondGwei = _minBond;
        _provingWindow = _provingWindowSeconds;
        _bidDiscountBps = _bidDiscountBasisPoints;
        _bondPerProposalGwei = _bondPerProposal;
        _slashPerProofGwei = _slashPerProof;
        _maxBidEwmaMultiplier = _maxBidMultiplier;
    }

    // ---------------------------------------------------------------
    // External Functions
    // ---------------------------------------------------------------

    /// @notice Initializes the contract owner.
    /// @param _owner The owner of this contract.
    function init(address _owner) external initializer {
        __Essential_init(_owner);
    }

    /// @notice Deposits bond used to back proving obligations.
    /// @param _amount The bond amount in gwei.
    function depositBond(uint64 _amount) external nonReentrant nonZeroValue(_amount) {
        _bondToken.safeTransferFrom(msg.sender, address(this), uint256(_amount) * 1 gwei);
        proverAccounts[msg.sender].bondBalance += _amount;
        emit BondDeposited(msg.sender, _amount);
    }

    /// @notice Withdraws previously deposited bond.
    /// @param _amount The bond amount in gwei.
    function withdrawBond(uint64 _amount) external nonReentrant nonZeroValue(_amount) {
        ProverAccount memory acct = proverAccounts[msg.sender];
        require(acct.bondBalance - acct.reservedBond >= _amount, InsufficientBond());
        acct.bondBalance -= _amount;
        proverAccounts[msg.sender] = acct;
        _bondToken.safeTransfer(msg.sender, uint256(_amount) * 1 gwei);
        emit BondWithdrawn(msg.sender, _amount);
    }

    /// @notice Places or updates a bid for a future proving term.
    /// @param _feeInGwei The fee quote in gwei for each assigned proposal.
    function bid(uint64 _feeInGwei) external nonReentrant whenNotPaused {
        require(proverAccounts[msg.sender].bondBalance >= _minBondGwei, InsufficientBond());

        MarketState memory state = marketState;

        if (state.activeTermId != 0) {
            require(
                _feeInGwei * 10_000
                    <= uint256(terms[state.activeTermId].feeInGwei) * (10_000 - _bidDiscountBps),
                BidFeeTooHigh()
            );
        }

        if (state.pendingTermId != 0 && terms[state.pendingTermId].prover != msg.sender) {
            require(
                _feeInGwei * 10_000
                    <= uint256(terms[state.pendingTermId].feeInGwei) * (10_000 - _bidDiscountBps),
                BidFeeTooHigh()
            );
        }

        if (state.activeTermId == 0 && state.pendingTermId == 0 && state.feeEwmaInGwei != 0) {
            require(
                _feeInGwei <= uint256(_maxBidEwmaMultiplier) * state.feeEwmaInGwei, BidFeeTooHigh()
            );
        }

        uint48 newTermId = ++state.nextTermId;

        terms[newTermId] = Term({
            prover: msg.sender,
            startProposalId: 0,
            endProposalId: 0,
            feeInGwei: _feeInGwei,
            prevTermId: 0
        });

        state.pendingTermId = newTermId;
        marketState = state;

        emit BidPlaced(newTermId, msg.sender, _feeInGwei);
    }

    /// @notice Requests exit from the market for the caller's active or pending position.
    function exit() external {
        MarketState memory state = marketState;

        if (state.pendingTermId != 0 && terms[state.pendingTermId].prover == msg.sender) {
            uint48 exitedId = state.pendingTermId;
            state.pendingTermId = 0;
            marketState = state;
            emit TermExited(exitedId);
            return;
        }

        if (state.activeTermId != 0 && terms[state.activeTermId].prover == msg.sender) {
            require(!state.activeTermExiting, NoBidToExit());
            state.activeTermExiting = true;
            marketState = state;
            emit TermExited(state.activeTermId);
            return;
        }

        revert NoBidToExit();
    }

    /// @inheritdoc IProverMarket
    function onProposalAccepted(
        uint48 _proposalId,
        address _proposer,
        uint48 _proposalTimestamp
    )
        external
        payable
        onlyFrom(address(_inbox))
    {
        MarketState memory state = marketState;
        uint256 feeConsumed;
        bool stateChanged;

        if (state.permissionlessReason == 0) {
            if (state.activeTermId != 0) {
                bool shouldRetire = state.activeTermExiting || state.pendingTermId != 0;
                if (!shouldRetire) {
                    Term memory term = terms[state.activeTermId];
                    ProverAccount memory acct = proverAccounts[term.prover];
                    shouldRetire = acct.bondBalance < acct.reservedBond + _bondPerProposalGwei;
                }
                if (shouldRetire) {
                    terms[state.activeTermId].endProposalId = _proposalId - 1;
                    _updateFeeEwma(
                        state,
                        terms[state.activeTermId].feeInGwei,
                        _proposalId - terms[state.activeTermId].startProposalId
                    );
                    state.lastRetiredTermId = state.activeTermId;
                    state.activeTermId = 0;
                    state.activeTermExiting = false;
                    stateChanged = true;

                    CapState memory cap = capState;
                    cap.unprovenTermCount++;
                    if (cap.unprovenTermCount >= 3 && state.permissionlessReason == 0) {
                        state.permissionlessReason = 2;
                        cap.capFeeSnapshotGwei = state.feeEwmaInGwei;
                        cap.capStartProposalId = _proposalId;
                        cap.capProposalCount = 0;
                        emit CapExceeded(_proposalId);
                    }
                    capState = cap;
                }
            }

            if (state.activeTermId == 0 && state.pendingTermId != 0) {
                _activatePendingTerm(state, _proposalId, _proposalTimestamp);
                stateChanged = true;
            }

            uint48 activeId = state.activeTermId;
            if (activeId != 0) {
                Term memory term = terms[activeId];
                address prv = term.prover;
                ProverAccount memory acct = proverAccounts[prv];

                acct.reservedBond += _bondPerProposalGwei;

                uint256 feeWei = uint256(term.feeInGwei) * 1 gwei;
                if (feeWei > 0) {
                    require(msg.value >= feeWei, InsufficientFee());
                    feeConsumed = feeWei;
                }

                proverAccounts[prv] = acct;

                if (feeConsumed > 0) {
                    prv.sendEtherAndVerify(feeConsumed, _SEND_ETHER_GAS_LIMIT);
                    emit FeeCharged(_proposalId, _proposer, term.feeInGwei);
                }
            } else if (state.permissionlessReason == 2) {
                CapState memory cap = capState;
                uint256 feeWei = uint256(cap.capFeeSnapshotGwei) * 2 * 1 gwei;
                if (feeWei > 0) {
                    require(msg.value >= feeWei, InsufficientFee());
                    feeConsumed = feeWei;
                }
                cap.capProposalCount++;
                capState = cap;
            }
        } else if (state.permissionlessReason == 2) {
            CapState memory cap = capState;
            uint256 feeWei = uint256(cap.capFeeSnapshotGwei) * 2 * 1 gwei;
            if (feeWei > 0) {
                require(msg.value >= feeWei, InsufficientFee());
                feeConsumed = feeWei;
            }
            cap.capProposalCount++;
            capState = cap;
        }

        if (stateChanged) marketState = state;

        uint256 excess = msg.value - feeConsumed;
        if (excess > 0) {
            _proposer.sendEtherAndVerify(excess);
        }
    }

    /// @notice Checks whether a caller is authorized to submit a proof for a given proposal.
    /// @param _caller The account that would submit the proof.
    /// @param _firstNewProposalId The first proposal id that would be newly finalized.
    /// @param _proposalAge The age in seconds of the first newly finalized proposal.
    /// @return True if the caller is authorized to prove.
    function canSubmitProof(
        address _caller,
        uint48 _firstNewProposalId,
        uint256 _proposalAge
    )
        public
        view
        returns (bool)
    {
        MarketState memory state = marketState;
        if (state.permissionlessReason != 0) return true;

        if (_proposalAge >= uint256(_provingWindow)) return true;

        uint48 hint = state.activeTermId != 0 ? state.activeTermId : state.lastRetiredTermId;
        uint48 termId = _findTermForProposal(_firstNewProposalId, hint);

        if (termId == 0) return true;

        return _caller == terms[termId].prover;
    }

    /// @inheritdoc IProverMarket
    function onProofAccepted(
        address _caller,
        uint48 _firstNewProposalId,
        uint48 _lastProposalId,
        uint256 _proposalAge
    )
        external
        onlyFrom(address(_inbox))
    {
        MarketState memory state = marketState;
        bool stateChanged;

        if (state.permissionlessReason != 1) {
            stateChanged =
                _settleProof(state, _caller, _firstNewProposalId, _lastProposalId, _proposalAge);

            CapState memory cap = capState;
            if (cap.unprovenTermCount > 0) {
                uint8 provenCount =
                    _countFullyProvenTerms(state, cap.lastProvenProposalId, _lastProposalId);
                if (provenCount >= cap.unprovenTermCount) {
                    cap.unprovenTermCount = 0;
                } else {
                    cap.unprovenTermCount -= provenCount;
                }
                cap.lastProvenProposalId = _lastProposalId;
                if (cap.unprovenTermCount < 3 && state.permissionlessReason == 2) {
                    state.permissionlessReason = 0;
                    stateChanged = true;
                    emit CapRecovered(_lastProposalId);
                }
                capState = cap;
            }

            if (cap.capProposalCount > 0 && cap.capFeeSnapshotGwei > 0) {
                _releasePermissionlessEscrow(
                    _caller, _firstNewProposalId, _lastProposalId
                );
            }
        }

        if (stateChanged) marketState = state;
    }

    /// @notice Enables or disables emergency permissionless proving mode.
    /// @param _enabled True to force permissionless proving, false to restore market enforcement.
    function forcePermissionlessMode(bool _enabled) external onlyOwner {
        marketState.permissionlessReason = _enabled ? 1 : 0;
        if (!_enabled) {
            CapState memory cap = capState;
            uint256 remaining;
            if (cap.capProposalCount > 0 && cap.capFeeSnapshotGwei > 0) {
                remaining = uint256(cap.capFeeSnapshotGwei) * 2 * 1 gwei * cap.capProposalCount;
            }
            delete capState;
            if (remaining > 0) {
                msg.sender.sendEtherAndVerify(remaining, _SEND_ETHER_GAS_LIMIT);
            }
        }
        emit PermissionlessModeUpdated(_enabled);
    }

    /// @inheritdoc IProverMarket
    function bondToken() external view returns (address) {
        return address(_bondToken);
    }

    /// @notice Returns the exclusive proving window in seconds.
    function provingWindow() external view returns (uint48) {
        return _provingWindow;
    }

    /// @notice Returns the fee in gwei that the next proposal will be charged.
    function activeFeeInGwei() external view returns (uint64) {
        MarketState memory state = marketState;
        if (state.permissionlessReason == 1) return 0;
        if (state.permissionlessReason == 2) return uint64(state.feeEwmaInGwei) * 2;

        if (state.activeTermId != 0) {
            bool wouldRetire = state.activeTermExiting || state.pendingTermId != 0;
            if (!wouldRetire) {
                ProverAccount memory acct = proverAccounts[terms[state.activeTermId].prover];
                wouldRetire = acct.bondBalance < acct.reservedBond + _bondPerProposalGwei;
            }
            if (wouldRetire) {
                if (state.pendingTermId != 0) return terms[state.pendingTermId].feeInGwei;
                return 0;
            }
            return terms[state.activeTermId].feeInGwei;
        }
        if (state.pendingTermId != 0) {
            return terms[state.pendingTermId].feeInGwei;
        }
        return 0;
    }

    /// @notice Returns the minimum bond in gwei required to place a bid.
    function minBond() external view returns (uint64) {
        return _minBondGwei;
    }

    /// @notice Returns the minimum bid discount in basis points (e.g. 1000 = 10%).
    function bidDiscountBps() external view returns (uint16) {
        return _bidDiscountBps;
    }

    /// @notice Returns the bond in gwei reserved per assigned proposal.
    function bondPerProposal() external view returns (uint64) {
        return _bondPerProposalGwei;
    }

    /// @notice Returns the slash amount in gwei per late proof.
    function slashPerProof() external view returns (uint64) {
        return _slashPerProofGwei;
    }

    /// @notice Returns the max bid multiplier applied to the EWMA.
    function maxBidEwmaMultiplier() external view returns (uint8) {
        return _maxBidEwmaMultiplier;
    }

    /// @notice Returns the exponentially weighted moving average of activated term fees.
    function feeEwma() external view returns (uint48) {
        return marketState.feeEwmaInGwei;
    }

    /// @inheritdoc IProverMarket
    function creditMigratedBond(
        address _account,
        uint64 _amount
    )
        external
        onlyFrom(address(_inbox))
    {
        proverAccounts[_account].bondBalance += _amount;
        emit BondDeposited(_account, _amount);
    }

    // ---------------------------------------------------------------
    // Private Functions
    // ---------------------------------------------------------------

    /// @dev Activates the current pending term for new assignments. Skips activation if the
    ///      pending prover lacks sufficient bond.
    function _activatePendingTerm(
        MarketState memory _state,
        uint48 _proposalId,
        uint48 _proposalTimestamp
    )
        private
    {
        uint48 pendingId = _state.pendingTermId;
        address prv = terms[pendingId].prover;
        ProverAccount memory acct = proverAccounts[prv];

        if (acct.bondBalance < acct.reservedBond + _bondPerProposalGwei) {
            _state.pendingTermId = 0;
            return;
        }

        terms[pendingId].startProposalId = _proposalId;
        terms[pendingId].prevTermId = _state.lastRetiredTermId;

        _state.activeTermId = pendingId;
        _state.pendingTermId = 0;
        _state.activeTermExiting = false;

        emit TermActivated(pendingId, _proposalId, _proposalTimestamp);
    }

    /// @dev Updates the fee EWMA using proposal-weighted blending.
    ///      Formula: newEwma = (ewma * W + fee * count) / (W + count), where W = 1024.
    ///      A term that served more proposals has proportionally more influence on the average.
    function _updateFeeEwma(
        MarketState memory _state,
        uint64 _fee,
        uint256 _proposalCount
    )
        private
        pure
    {
        if (_proposalCount == 0) return;
        uint48 ewma = _state.feeEwmaInGwei;
        if (ewma == 0) {
            _state.feeEwmaInGwei = uint48(_fee);
        } else {
            uint256 w = 1024;
            _state.feeEwmaInGwei =
                uint48((uint256(ewma) * w + uint256(_fee) * _proposalCount) / (w + _proposalCount));
        }
    }

    /// @dev Handles bond release, authorization, and slashing for a finalized proof range.
    function _settleProof(
        MarketState memory _state,
        address _caller,
        uint48 _firstNewProposalId,
        uint48 _lastProposalId,
        uint256 _proposalAge
    )
        private
        returns (bool stateChanged_)
    {
        uint48 hint = _state.activeTermId != 0 ? _state.activeTermId : _state.lastRetiredTermId;
        uint48 firstTermId = _findTermForProposal(_firstNewProposalId, hint);

        _releaseReservedBond(_firstNewProposalId, _lastProposalId, hint);

        if (_proposalAge < uint256(_provingWindow)) {
            if (firstTermId != 0) {
                require(_caller == terms[firstTermId].prover, NotAuthorizedProver());
            }
            return false;
        }

        if (firstTermId == 0) return false;

        address prv = terms[firstTermId].prover;
        ProverAccount memory acct = proverAccounts[prv];

        uint64 slashAmount =
            _slashPerProofGwei < acct.bondBalance ? _slashPerProofGwei : acct.bondBalance;

        if (slashAmount > 0) {
            acct.bondBalance -= slashAmount;
            proverAccounts[prv] = acct;

            if (_caller != prv) {
                proverAccounts[_caller].bondBalance += slashAmount;
            }
            emit ProverSlashed(prv, _caller, slashAmount);
        }

        if (acct.bondBalance < acct.reservedBond) {
            if (_state.activeTermId == firstTermId) {
                terms[firstTermId].endProposalId = _firstNewProposalId - 1;
                if (_state.permissionlessReason == 0) {
                    _updateFeeEwma(
                        _state,
                        terms[firstTermId].feeInGwei,
                        _firstNewProposalId - terms[firstTermId].startProposalId
                    );
                }
                _state.lastRetiredTermId = firstTermId;
                _state.activeTermId = 0;
                _state.activeTermExiting = false;
                stateChanged_ = true;
            }
        }
    }

    /// @dev Finds the term that owns a proposal by walking backward from a hint.
    ///      Max 3 iterations (bounded by cap). Returns 0 if permissionless.
    function _findTermForProposal(
        uint48 _proposalId,
        uint48 _hintTermId
    )
        private
        view
        returns (uint48 termId_)
    {
        uint48 tid = _hintTermId;
        for (uint8 i; i < 3 && tid != 0; ++i) {
            uint48 tStart = terms[tid].startProposalId;
            uint48 tEnd = terms[tid].endProposalId;
            if (tEnd == 0) tEnd = type(uint48).max;
            if (_proposalId >= tStart && _proposalId <= tEnd) return tid;
            tid = terms[tid].prevTermId;
        }
    }

    /// @dev Releases reserved bond using term range arithmetic. O(T) where T <= 3.
    function _releaseReservedBond(
        uint48 _firstProposalId,
        uint48 _lastProposalId,
        uint48 _hintTermId
    )
        private
    {
        uint48[3] memory tids;
        uint8 count;
        uint48 tid = _hintTermId;

        for (uint8 i; i < 3 && tid != 0; ++i) {
            uint48 tStart = terms[tid].startProposalId;
            uint48 tEnd = terms[tid].endProposalId;
            if (tEnd == 0) tEnd = type(uint48).max;

            if (tEnd < _firstProposalId) break;
            if (tStart <= _lastProposalId) {
                tids[count++] = tid;
            }
            tid = terms[tid].prevTermId;
        }

        for (uint8 i = count; i > 0;) {
            --i;
            tid = tids[i];
            uint48 tStart = terms[tid].startProposalId;
            uint48 tEnd = terms[tid].endProposalId;
            if (tEnd == 0) tEnd = _lastProposalId;

            uint48 overlapStart = tStart > _firstProposalId ? tStart : _firstProposalId;
            uint48 overlapEnd = tEnd < _lastProposalId ? tEnd : _lastProposalId;

            uint64 releaseAmount = uint64(overlapEnd - overlapStart + 1) * _bondPerProposalGwei;
            address prv = terms[tid].prover;
            ProverAccount memory acct = proverAccounts[prv];
            if (releaseAmount > acct.reservedBond) releaseAmount = acct.reservedBond;
            acct.reservedBond -= releaseAmount;
            proverAccounts[prv] = acct;
        }
    }

    /// @dev Counts how many terms became fully proven since the last watermark.
    function _countFullyProvenTerms(
        MarketState memory _state,
        uint48 _prevProvenProposalId,
        uint48 _lastProposalId
    )
        private
        view
        returns (uint8 count_)
    {
        uint48 tid = _state.lastRetiredTermId;
        for (uint8 i; i < 3 && tid != 0; ++i) {
            uint48 tEnd = terms[tid].endProposalId;
            if (tEnd != 0 && tEnd <= _lastProposalId && tEnd > _prevProvenProposalId) {
                count_++;
            }
            tid = terms[tid].prevTermId;
        }
    }

    /// @dev Releases escrowed permissionless fees to the proof submitter.
    ///      Advances capStartProposalId past the released range to prevent replay.
    function _releasePermissionlessEscrow(
        address _caller,
        uint48 _firstNewProposalId,
        uint48 _lastProposalId
    )
        private
    {
        CapState memory cap = capState;
        uint48 capEnd = cap.capStartProposalId + cap.capProposalCount - 1;
        if (_lastProposalId < cap.capStartProposalId || _firstNewProposalId > capEnd) return;

        uint48 overlapStart =
            _firstNewProposalId > cap.capStartProposalId
                ? _firstNewProposalId
                : cap.capStartProposalId;
        uint48 overlapEnd = _lastProposalId < capEnd ? _lastProposalId : capEnd;

        uint48 newCapStart = overlapEnd + 1;
        cap.capProposalCount = capEnd >= newCapStart ? capEnd - newCapStart + 1 : 0;
        cap.capStartProposalId = newCapStart;
        capState = cap;

        uint256 payout =
            uint256(overlapEnd - overlapStart + 1) * uint256(cap.capFeeSnapshotGwei) * 2 * 1 gwei;
        if (payout > 0) {
            _caller.sendEtherAndVerify(payout, _SEND_ETHER_GAS_LIMIT);
        }
    }

    // ---------------------------------------------------------------
    // Errors
    // ---------------------------------------------------------------

    error InsufficientBond();
    error InsufficientFee();
    error NoBidToExit();
    error BidFeeTooHigh();
    error NotAuthorizedProver();
}
