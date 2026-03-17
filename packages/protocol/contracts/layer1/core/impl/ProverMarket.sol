// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { IProverWhitelist } from "../iface/IProverWhitelist.sol";
import { IInbox } from "../iface/IInbox.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { EssentialContract } from "src/shared/common/EssentialContract.sol";
import { LibAddress } from "src/shared/libs/LibAddress.sol";

/// @title ProverMarket
/// @notice A competitive auction market where provers bid to become the exclusive block prover.
/// The lowest-fee bidder wins the right to prove blocks, with bond requirements that escalate
/// after consecutive ejections to deter unreliable provers.
/// @custom:security-contact security@taiko.xyz
contract ProverMarket is EssentialContract, IProverWhitelist {
    using SafeERC20 for IERC20;
    using LibAddress for address;

    // ---------------------------------------------------------------
    // Structs
    // ---------------------------------------------------------------

    /// @notice Represents the current auction winner who has the exclusive right to prove blocks.
    struct Winner {
        address addr;
        uint64 feeInGwei;
        uint48 activeAt;
    }

    /// @notice Tracks market-wide state related to ejections and cooldowns.
    struct MarketState {
        uint48 lastEjectionTimestamp;
        uint48 cooldownUntil;
        uint8 consecutiveEjections;
    }

    // ---------------------------------------------------------------
    // Immutable Variables
    // ---------------------------------------------------------------

    /// @dev The inbox contract used to query proposal and finalization state.
    IInbox internal immutable _inbox;

    /// @dev The ERC20 token used for prover bonds.
    IERC20 internal immutable _bondToken;

    /// @dev The base bond amount in gwei that a prover must deposit to bid.
    uint64 internal immutable _baseBond;

    /// @dev Minimum fee reduction in basis points required when outbidding the current winner
    /// (e.g., 500 = 5%).
    uint16 internal immutable _minFeeReductionBps;

    /// @dev Duration in seconds the market is paused after an ejection before new bids are
    /// accepted.
    uint48 internal immutable _globalCooldown;

    /// @dev Delay in seconds before a new winner becomes active after placing a bid.
    uint48 internal immutable _activationDelay;

    /// @dev Percentage of the slashed bond paid to the ejector as a bounty in basis points
    /// (e.g., 5000 = 50%).
    uint16 internal immutable _slashBountyBps;

    /// @dev Maximum escalation exponent for bond requirements (e.g., 3 means 2^3 = 8x max).
    uint8 internal immutable _maxEscalation;

    /// @dev Time period in seconds over which consecutive ejection escalation decays by one step.
    uint48 internal immutable _escalationDecayPeriod;

    // ---------------------------------------------------------------
    // State Variables
    // ---------------------------------------------------------------

    /// @notice The current auction winner.
    Winner public winner; // slot 251

    /// @notice The current market state tracking ejections and cooldowns.
    MarketState public marketState; // slot 252

    /// @notice Bond balances in gwei for each prover.
    mapping(address prover => uint64 bondBalance) public bonds; // slot 253

    /// @notice ETH fee balances deposited by proposers for paying the prover.
    mapping(address prover => uint256 feeBalance) public feeBalances; // slot 254

    /// @notice The last proposal ID up to which fees have been claimed by the winner.
    uint48 public lastClaimedProposalId; // slot 255

    uint256[45] private __gap;

    // ---------------------------------------------------------------
    // Events
    // ---------------------------------------------------------------

    /// @notice Emitted when a new prover outbids the current winner.
    /// @param newWinner The address of the new winning prover.
    /// @param previousWinner The address of the outbid prover.
    /// @param feeInGwei The fee in gwei that the new winner will charge per proposal.
    event BidPlaced(address indexed newWinner, address indexed previousWinner, uint64 feeInGwei);

    /// @notice Emitted when the current winner is slashed for failing to prove within the proving
    /// window and ejected from the market.
    /// @param ejectedProver The address of the ejected prover.
    /// @param bondSlashed The total bond amount in gwei that was slashed.
    /// @param ejector The address that triggered the ejection and received the bounty.
    event WinnerSlashedAndEjected(
        address indexed ejectedProver, uint64 bondSlashed, address indexed ejector
    );

    /// @notice Emitted when the current winner voluntarily exits the market.
    /// @param prover The address of the prover that exited.
    event WinnerExited(address indexed prover);

    /// @notice Emitted when a prover deposits bond tokens.
    /// @param prover The address of the prover depositing.
    /// @param amount The amount deposited in gwei.
    event BondDeposited(address indexed prover, uint64 amount);

    /// @notice Emitted when a prover withdraws bond tokens.
    /// @param prover The address of the prover withdrawing.
    /// @param amount The amount withdrawn in gwei.
    event BondWithdrawn(address indexed prover, uint64 amount);

    /// @notice Emitted when ETH is deposited as fees.
    /// @param depositor The address that deposited.
    /// @param amount The amount deposited in wei.
    event FeeDeposited(address indexed depositor, uint256 amount);

    /// @notice Emitted when ETH fees are withdrawn.
    /// @param withdrawer The address that withdrew.
    /// @param amount The amount withdrawn in wei.
    event FeeWithdrawn(address indexed withdrawer, uint256 amount);

    /// @notice Emitted when the winning prover claims accumulated fees.
    /// @param prover The address of the prover claiming fees.
    /// @param upToProposalId The proposal ID up to which fees were claimed.
    /// @param amount The total amount of ETH paid out in wei.
    event FeesClaimed(address indexed prover, uint48 upToProposalId, uint256 amount);

    /// @notice Emitted when the owner overrides the winner.
    /// @param newWinner The address of the new winner (address(0) to clear).
    /// @param feeInGwei The fee in gwei for the new winner.
    event WinnerOverridden(address indexed newWinner, uint64 feeInGwei);

    // ---------------------------------------------------------------
    // Constructor
    // ---------------------------------------------------------------

    /// @notice Initializes immutable auction parameters.
    /// @param _inboxAddr The address of the Inbox contract.
    /// @param _bondTokenAddr The address of the ERC20 bond token.
    /// @param _baseBondGwei The base bond requirement in gwei.
    /// @param _minFeeReductionBpsVal Minimum fee reduction in basis points to outbid.
    /// @param _globalCooldownVal Cooldown duration in seconds after an ejection.
    /// @param _activationDelayVal Delay in seconds before a new winner becomes active.
    /// @param _slashBountyBpsVal Percentage of slashed bond paid to the ejector in basis points.
    /// @param _maxEscalationVal Maximum escalation exponent for bond requirements.
    /// @param _escalationDecayPeriodVal Time period in seconds for escalation decay.
    constructor(
        address _inboxAddr,
        address _bondTokenAddr,
        uint64 _baseBondGwei,
        uint16 _minFeeReductionBpsVal,
        uint48 _globalCooldownVal,
        uint48 _activationDelayVal,
        uint16 _slashBountyBpsVal,
        uint8 _maxEscalationVal,
        uint48 _escalationDecayPeriodVal
    ) {
        require(_inboxAddr != address(0), ZeroAddress());
        require(_bondTokenAddr != address(0), ZeroAddress());
        require(_slashBountyBpsVal <= 10_000, InvalidBps());
        require(_minFeeReductionBpsVal <= 10_000, InvalidBps());

        _inbox = IInbox(_inboxAddr);
        _bondToken = IERC20(_bondTokenAddr);
        _baseBond = _baseBondGwei;
        _minFeeReductionBps = _minFeeReductionBpsVal;
        _globalCooldown = _globalCooldownVal;
        _activationDelay = _activationDelayVal;
        _slashBountyBps = _slashBountyBpsVal;
        _maxEscalation = _maxEscalationVal;
        _escalationDecayPeriod = _escalationDecayPeriodVal;
    }

    // ---------------------------------------------------------------
    // External Functions
    // ---------------------------------------------------------------

    /// @notice Initializes the contract.
    /// @param _owner The owner of this contract.
    function init(address _owner) external initializer {
        __Essential_init(_owner);
    }

    /// @inheritdoc IProverWhitelist
    function isProverWhitelisted(address _prover)
        external
        view
        returns (bool isWhitelisted_, uint256 proverCount_)
    {
        Winner memory w = winner;
        if (w.addr == address(0)) return (false, 0);
        if (block.timestamp < w.activeAt) return (false, 0);
        return (_prover == w.addr, 1);
    }

    /// @notice Places a bid to become the exclusive prover. The caller must have deposited
    /// sufficient bond and offer a fee lower than the current winner's fee by at least the minimum
    /// reduction percentage.
    /// @param _feeInGwei The fee in gwei the bidder will charge per proven proposal.
    function bid(uint64 _feeInGwei) external nonReentrant {
        require(_feeInGwei > 0, ZeroFee());
        require(msg.sender != winner.addr, AlreadyWinner());
        require(bonds[msg.sender] >= getRequiredBond(), InsufficientBond());
        require(block.timestamp >= marketState.cooldownUntil, MarketOnCooldown());

        Winner memory currentWinner = winner;

        // If there is an active winner (not vacant and past activation delay), enforce minimum
        // fee reduction.
        if (currentWinner.addr != address(0) && block.timestamp >= currentWinner.activeAt) {
            uint256 maxAllowedFee =
                uint256(currentWinner.feeInGwei) * (10_000 - _minFeeReductionBps) / 10_000;
            require(_feeInGwei <= maxAllowedFee, InsufficientFeeReduction());
        }

        address previousWinner = currentWinner.addr;
        winner = Winner({
            addr: msg.sender,
            feeInGwei: _feeInGwei,
            activeAt: uint48(block.timestamp) + _activationDelay
        });

        emit BidPlaced(msg.sender, previousWinner, _feeInGwei);
    }

    /// @notice Slashes the current winner's entire bond and ejects them from the market. Can be
    /// called by anyone when the proving window has expired with unfinalized proposals. The caller
    /// receives a bounty portion of the slashed bond.
    function slashAndEject() external nonReentrant {
        Winner memory w = winner;
        require(w.addr != address(0), NoActiveWinner());
        require(block.timestamp >= w.activeAt, WinnerNotYetActive());

        IInbox.CoreState memory inboxState = _inbox.getCoreState();
        require(
            inboxState.lastFinalizedProposalId + 1 < inboxState.nextProposalId,
            NoPendingProposals()
        );

        uint48 referenceTimestamp =
            inboxState.lastFinalizedTimestamp > 0 ? inboxState.lastFinalizedTimestamp : w.activeAt;
        uint48 provingWindow = _inbox.getConfig().provingWindow;
        require(
            block.timestamp > uint256(referenceTimestamp) + uint256(provingWindow),
            ProvingWindowNotExpired()
        );

        // Slash 100% of the winner's bond
        uint64 bondBalance = bonds[w.addr];
        uint64 bountyAmount;
        uint64 burnAmount;
        if (bondBalance > 0) {
            bountyAmount = uint64(uint256(bondBalance) * _slashBountyBps / 10_000);
            burnAmount = bondBalance - bountyAmount;
            bonds[w.addr] = 0;

            if (bountyAmount > 0) {
                _bondToken.safeTransfer(msg.sender, uint256(bountyAmount) * 1 gwei);
            }
            if (burnAmount > 0) {
                _bondToken.safeTransfer(address(0xdEaD), uint256(burnAmount) * 1 gwei);
            }
        }

        // Update market state with cooldown and escalation
        MarketState memory ms = marketState;
        ms.lastEjectionTimestamp = uint48(block.timestamp);
        ms.cooldownUntil = uint48(block.timestamp) + _globalCooldown;
        if (ms.consecutiveEjections < type(uint8).max) {
            ms.consecutiveEjections++;
        }
        marketState = ms;

        // Clear the winner
        winner = Winner({ addr: address(0), feeInGwei: 0, activeAt: 0 });

        emit WinnerSlashedAndEjected(w.addr, bondBalance, msg.sender);
    }

    /// @notice Allows the current winner to voluntarily exit the market, forfeiting their
    /// exclusive proving rights.
    function exit() external nonReentrant {
        require(msg.sender == winner.addr, NotWinner());
        winner = Winner({ addr: address(0), feeInGwei: 0, activeAt: 0 });
        emit WinnerExited(msg.sender);
    }

    /// @notice Deposits bond tokens into the market. Bond is required to place bids and is
    /// subject to slashing if the winner fails to prove.
    /// @param _amount The amount of bond tokens to deposit in gwei.
    function depositBond(uint64 _amount) external nonReentrant {
        require(_amount > 0, ZeroAmount());
        bonds[msg.sender] += _amount;
        _bondToken.safeTransferFrom(msg.sender, address(this), uint256(_amount) * 1 gwei);
        emit BondDeposited(msg.sender, _amount);
    }

    /// @notice Withdraws bond tokens from the market. The current winner cannot withdraw their
    /// bond.
    /// @param _amount The amount of bond tokens to withdraw in gwei.
    function withdrawBond(uint64 _amount) external nonReentrant {
        require(msg.sender != winner.addr, WinnerCannotWithdraw());

        uint64 balance = bonds[msg.sender];
        uint64 toWithdraw = _amount > balance ? balance : _amount;
        require(toWithdraw > 0, ZeroAmount());

        bonds[msg.sender] = balance - toWithdraw;
        _bondToken.safeTransfer(msg.sender, uint256(toWithdraw) * 1 gwei);
        emit BondWithdrawn(msg.sender, toWithdraw);
    }

    /// @notice Deposits ETH as fees that will be paid to the winning prover for proven proposals.
    function depositFee() external payable nonReentrant {
        require(msg.value > 0, ZeroAmount());
        feeBalances[msg.sender] += msg.value;
        emit FeeDeposited(msg.sender, msg.value);
    }

    /// @notice Withdraws previously deposited ETH fees.
    /// @param _amount The amount of ETH to withdraw in wei.
    function withdrawFee(uint256 _amount) external nonReentrant {
        require(_amount > 0 && _amount <= feeBalances[msg.sender], InsufficientFeeBalance());
        feeBalances[msg.sender] -= _amount;
        msg.sender.sendEtherAndVerify(_amount);
        emit FeeWithdrawn(msg.sender, _amount);
    }

    /// @notice Claims accumulated fees for all newly finalized proposals since the last claim.
    /// Only callable by the current winner.
    function claimFees() external nonReentrant {
        Winner memory w = winner;
        require(msg.sender == w.addr, NotWinner());

        IInbox.CoreState memory inboxState = _inbox.getCoreState();
        uint48 currentFinalized = inboxState.lastFinalizedProposalId;
        require(currentFinalized > lastClaimedProposalId, NothingToClaim());

        uint48 newProposals = currentFinalized - lastClaimedProposalId;
        uint256 totalFee = uint256(newProposals) * uint256(w.feeInGwei) * 1 gwei;
        uint256 available = address(this).balance;
        uint256 toPay = totalFee < available ? totalFee : available;

        lastClaimedProposalId = currentFinalized;

        if (toPay > 0) {
            msg.sender.sendEtherAndVerify(toPay);
        }

        emit FeesClaimed(msg.sender, currentFinalized, toPay);
    }

    /// @notice Allows the owner to override the current winner. Can be used to set an arbitrary
    /// winner or clear the winner by passing address(0).
    /// @param _newWinner The address of the new winner (address(0) to clear).
    /// @param _feeInGwei The fee in gwei for the new winner.
    function setWinnerOverride(address _newWinner, uint64 _feeInGwei) external onlyOwner {
        if (_newWinner == address(0)) {
            winner = Winner({ addr: address(0), feeInGwei: 0, activeAt: 0 });
        } else {
            winner = Winner({
                addr: _newWinner,
                feeInGwei: _feeInGwei,
                activeAt: uint48(block.timestamp)
            });
        }
        emit WinnerOverridden(_newWinner, _feeInGwei);
    }

    // ---------------------------------------------------------------
    // Public View Functions
    // ---------------------------------------------------------------

    /// @notice Computes the current bond required to place a bid. The bond escalates
    /// exponentially based on recent consecutive ejections and decays over time.
    /// @return requiredBond_ The required bond amount in gwei.
    function getRequiredBond() public view returns (uint64 requiredBond_) {
        MarketState memory ms = marketState;

        uint256 elapsed = ms.lastEjectionTimestamp > 0
            ? (block.timestamp - ms.lastEjectionTimestamp) / _escalationDecayPeriod
            : type(uint256).max;

        uint256 decayed =
            elapsed > ms.consecutiveEjections ? 0 : ms.consecutiveEjections - elapsed;
        uint256 escalation = decayed > _maxEscalation ? _maxEscalation : decayed;

        requiredBond_ = _baseBond * uint64(1 << escalation);
    }

    // ---------------------------------------------------------------
    // Receive
    // ---------------------------------------------------------------

    /// @notice Allows the contract to receive ETH directly.
    receive() external payable { }

    // ---------------------------------------------------------------
    // Errors
    // ---------------------------------------------------------------

    error ZeroAddress();
    error InvalidBps();
    error ZeroFee();
    error ZeroAmount();
    error AlreadyWinner();
    error InsufficientBond();
    error MarketOnCooldown();
    error InsufficientFeeReduction();
    error NoActiveWinner();
    error WinnerNotYetActive();
    error NoPendingProposals();
    error ProvingWindowNotExpired();
    error NotWinner();
    error WinnerCannotWithdraw();
    error InsufficientFeeBalance();
    error NothingToClaim();
}
