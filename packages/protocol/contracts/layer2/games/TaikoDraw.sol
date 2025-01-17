// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract TaikoDraw {
    // Constants
    uint8 public constant MAX_MULTIPLIER = 10;
    uint8 public constant MAX_TICKETS_PER_USER = 20;
    uint8 public constant MAX_PLAYERS_PER_TICKET = 10;
    uint128 public constant TICKET_FEE = 10 ether;
    uint256 public constant REVEAL_BOND = 10 ether;
    uint256 public constant COMMIT_PERIOD_DURATION = 2 days;
    uint256 public constant REVEAL_PERIOD_DURATION = 2 days;

    // State Variables
    IERC20 public immutable token;
    uint64 public immutable startTime;
    uint64 public round;
    bytes32 private _random;

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

    // Mappings
    mapping(address => Commit) public commits;
    mapping(uint24 => Ticket) public tickets;

    // Events
    event Committed(
        address indexed user, uint256 indexed round, uint8 multiplier, uint8 numTickets
    );
    event Revealed(address indexed user, uint256 indexed round, uint24[] ticketNumbers);
    event RoundEnded(uint256 indexed round, uint24 winingTicket, Player[] winners, uint256 prize);

    // Constructor
    constructor(address _token) {
        token = IERC20(_token);
        startTime = uint64((block.timestamp / 1 days) * 1 days); // 12:00:00 UTC
        round = 1;
    }

    // Modifiers
    modifier duringCommitPeriod(bool _isInCommitPeriod) {
        (uint64 currentRound, bool isInCommitPeriod) = _currentRoundAndPhase();
        require(isInCommitPeriod == _isInCommitPeriod, "Wrong phase");

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
        require(_multiplier > 0 && _multiplier <= MAX_MULTIPLIER, "Invalid multiplier");
        require(_numTickets > 0 && _numTickets <= MAX_TICKETS_PER_USER, "Invalid numTickets");

        // Calculate participation fee and transfer tokens
        uint256 fee = TICKET_FEE * _multiplier * _numTickets + REVEAL_BOND;
        require(token.transferFrom(msg.sender, address(this), fee), "Fee transfer failed");

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
        require(userCommit.round == round, "Invalid round");
        require(
            userCommit.commitHash == keccak256(abi.encodePacked("COMMIT", msg.sender, round, _seed)),
            "Invalid seed"
        );

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
        _random = _random ^ keccak256(abi.encodePacked("RANDOM", msg.sender, _seed, round));

        // Refund reveal bond
        require(token.transfer(msg.sender, REVEAL_BOND), "Bond refund failed");

        emit Revealed(msg.sender, round, ticketNumbers);
    }

    function listWinners() public view returns (uint24 winningTicket_, Player[] memory winners_) {
        (uint64 currentRound, bool isInCommitPhase) = _currentRoundAndPhase();

        if (currentRound == round && isInCommitPhase) {
            winners_ = new Player[](0);
        } else {
            winningTicket_ = uint24(uint256(keccak256(abi.encodePacked("WINNER", _random))));
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
