// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
/// @title Taiko Draw
/// @notice A lottery game utilizing a commit-and-reveal scheme to ensure fairness and transparency.
///         Users commit a secret seed and later reveal it to validate their participation. The game
///         incentivizes activity using Taiko tokens.
///
/// ## Game Overview
/// - The game operates in two phases: commit and reveal.
/// - Participants use Taiko tokens to pay fees proportional to their number of tickets and
/// multiplier.
/// - The game is ownerless, non-upgradeable, and ensures trustless operation.
///
/// ## Commit Period
/// - Users provide:
///   - A secret `seed`.
///   - A `multiplier` (maximum value: 10).
///   - The number of tickets (`numTickets`, maximum value: 20).
/// - The commit is hashed as `hash("COMMIT", msg.sender, round, seed)` and stored on-chain.
/// - Fees include:
///   - A participation fee proportional to `multiplier * numTickets`.
///   - A fixed reveal bond to discourage spamming.
/// - Commits are stored per user for the current round.
/// - Users failing to reveal their commit forfeit their bond, which is added to the next round's
/// pool.
///
/// ## Reveal Period
/// - Participants reveal their `seed` to validate the commit hash.
/// - Valid seeds are processed to derive ticket numbers: `hash("TICKET", msg.sender, round, seed,
/// indexOfTicket) % 2**24`.
/// - The winning ticket is updated based on revealed seeds to ensure fairness:
///   `winningTicket = hash("WINNER", winningTicket XOR seed, round, msg.sender) % 2**24`.
/// - Reveal bonds are refunded upon successful reveal.
/// - Each ticket maps to a list of players, with a limit of 10 players per ticket to optimize gas
/// costs.
/// - Invalid reveals revert the transaction and invalidate associated tickets.
///
/// ## End of Round
/// - At the end of the reveal phase:
///   - The temporary winner becomes the final winner.
///   - If no players reveal, all tokens roll over to the next round.
///   - If there are winners:
///     - 80% of the token balance is distributed proportionally based on their multiplier.
///     - 20% is retained for the next round.
/// - The next round begins automatically with the first commit transaction.
///
/// ## Contract Initialization
/// - The contract is initialized with:
///   - An ERC20 token address for handling fees and bonds.
///   - A bootstrapping function to deposit initial tokens and mark the start of the first round.
/// - The contract is immutable and non-upgradeable for trustless operation.
///
/// ## Optimization Considerations
/// - Compact storage types (`uint8`, `uint24`, `uint64`) are used to minimize costs.
/// - Limits are applied to:
///   - Tickets per user (`numTickets`: max 20).
///   - Players per ticket (max 10) to prevent gas exhaustion.
/// - Storage slots are reused where feasible for efficiency.
///
/// ## Edge Cases
/// - If no reveals occur, all tokens roll over to the next round.
/// - Unclaimed reveal bonds are added to the next round's pool.
/// - Duplicate reveals or invalid seeds are rejected without affecting contract state.

contract TaikoDraw {
    // Constants
    uint256 public constant MAX_MULTIPLIER = 10;
    uint256 public constant MAX_TICKETS_PER_USER = 20;
    uint256 public constant MAX_PLAYERS_PER_TICKET = 10;
    uint256 public constant TICKET_FEE = 10 ether; // 10 TAIKO
    uint256 public constant REVEAL_BOND = 10 ether; // 10 TAIKO
    uint256 public constant COMMIT_PERIOD_DURATION = 2 days;
    uint256 public constant REVEAL_PERIOD_DURATION = 2 days;

    // Structs
    struct Commit {
        uint64 round;
        uint8 multiplier;
        uint8 numTickets;
        bytes32 commitHash;
    }

    struct Player {
        address addr;
        uint8 multiplier;
    }

    struct Ticket {
        uint64 round;
        Player[] players;
    }

    // Events
    event Committed(
        address indexed user, uint256 indexed round, uint8 multiplier, uint8 numTickets
    );
    event Revealed(address indexed user, uint256 indexed round, uint24[] ticketNumbers);
    event RoundEnded(uint256 indexed round, uint24 winingTicket, Player[] winners, uint256 prize);

    // Custom Errors
    error OperationDenied();
    error InvalidMultiplier();
    error InvalidNumTickets();
    error FeeTransferFailed();
    error InvalidRound();
    error InvalidSeed();
    error BondRefundFailed();

    // State Variables
    IERC20 public immutable token;
    uint64 public immutable startTime;
    uint64 public round;
    bytes32 private _aggregatedSeeds;
    mapping(address player => Commit commit) public commits;
    mapping(uint24 ticketNumber => Ticket ticket) public tickets;

    // Constructor
    constructor(address _token) {
        token = IERC20(_token);
        startTime = uint64((block.timestamp / 1 days) * 1 days); // 12:00:00 UTC
        round = 1;
    }

    // Modifiers
    modifier duringCommitPeriod(bool _isInCommitPeriod) {
        (uint64 currentRound, bool isInCommitPeriod) = _currentRoundAndPhase();
        if (isInCommitPeriod != _isInCommitPeriod) revert OperationDenied();

        if (round != currentRound) {
            _settle();
            round = currentRound;
        }
        _;
    }

    // Commit Function
    function commit(
        uint8 _multiplier,
        uint8 _numTickets,
        bytes32 _commitHash
    )
        external
        duringCommitPeriod(true)
    {
        if (_multiplier == 0 || _multiplier > MAX_MULTIPLIER) revert InvalidMultiplier();
        if (_numTickets == 0 || _numTickets > MAX_TICKETS_PER_USER) revert InvalidNumTickets();

        // Calculate participation fee and transfer tokens
        uint256 fee = TICKET_FEE * _multiplier * _numTickets + REVEAL_BOND;
        if (!token.transferFrom(msg.sender, address(this), fee)) revert FeeTransferFailed();

        // Store commit
        commits[msg.sender] = Commit({
            round: round,
            multiplier: _multiplier,
            numTickets: _numTickets,
            commitHash: _commitHash
        });

        emit Committed(msg.sender, round, _multiplier, _numTickets);
    }

    // Reveal Function
    function reveal(bytes32 _seed) external duringCommitPeriod(false) {
        Commit memory userCommit = commits[msg.sender];
        if (userCommit.round != round) revert InvalidRound();
        if (
            userCommit.commitHash != keccak256(abi.encodePacked("COMMIT", msg.sender, round, _seed))
        ) revert InvalidSeed();

        // Calculate ticket numbers
        uint24[] memory ticketNumbers = new uint24[](userCommit.numTickets);
        for (uint256 i; i < userCommit.numTickets; ++i) {
            ticketNumbers[i] =
                uint24(uint256(keccak256(abi.encodePacked("TICKET", msg.sender, round, _seed, i))));

            // Update ticket-to-players mapping
            Ticket storage ticket = tickets[ticketNumbers[i]];

            if (ticket.round != round) {
                ticket.round = round;
                delete ticket.players;
            }

            if (ticket.players.length < MAX_PLAYERS_PER_TICKET) {
                ticket.players.push(Player(msg.sender, userCommit.multiplier));
            }
        }

        // Update winning ticket
        _aggregatedSeeds =
            _aggregatedSeeds ^ keccak256(abi.encodePacked("RANDOM", msg.sender, _seed, round));

        // Refund reveal bond
        if (!token.transfer(msg.sender, REVEAL_BOND)) revert BondRefundFailed();

        emit Revealed(msg.sender, round, ticketNumbers);
    }

    function listWinners() public view returns (uint24 winningTicket_, Player[] memory winners_) {
        (uint64 currentRound, bool isInCommitPhase) = _currentRoundAndPhase();

        if (currentRound == round && isInCommitPhase) {
            winners_ = new Player[](0);
        } else {
            winningTicket_ =
                uint24(uint256(keccak256(abi.encodePacked("WINNER", _aggregatedSeeds))));
            Ticket storage ticket = tickets[winningTicket_];
            winners_ = new Player[](ticket.players.length);

            for (uint256 i; i < ticket.players.length; ++i) {
                winners_[i] = ticket.players[i];
            }
        }
    }

    function _settle() private {
        (uint24 winningTicket, Player[] memory winners) = listWinners();

        if (winners.length == 0) {
            emit RoundEnded(round, winningTicket, winners, 0);
        } else {
            uint256 prize = token.balanceOf(address(this)) / 100 * 80;
            uint256 shares;
            for (uint256 i; i < winners.length; ++i) {
                shares += winners[i].multiplier;
            }
            uint256 shareValue = prize / shares;
            for (uint256 i; i < winners.length; ++i) {
                token.transfer(winners[i].addr, shareValue * winners[i].multiplier);
            }
            emit RoundEnded(round, winningTicket, winners, prize);
        }
    }

    function _currentRoundAndPhase() private view returns (uint64 _round, bool _isInCommitPhase) {
        uint256 timediff = block.timestamp - startTime;
        uint256 roundTime = COMMIT_PERIOD_DURATION + REVEAL_PERIOD_DURATION;
        _round = uint64(timediff / roundTime) + 1;

        uint256 timeInRound = timediff % roundTime;
        _isInCommitPhase = timeInRound < COMMIT_PERIOD_DURATION;
    }
}
