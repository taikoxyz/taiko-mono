// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Pausable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import { ERC721EnumerableUpgradeable } from
    "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import { AccessControlUpgradeable } from
    "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import { PausableUpgradeable } from
    "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import { IMinimalBlacklist } from "@taiko/blacklist/IMinimalBlacklist.sol";
import { UUPSUpgradeable } from
    "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { Ownable2StepUpgradeable } from
    "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import "./TrailblazersBadges.sol";

contract BadgeChampions is
    PausableUpgradeable,
    UUPSUpgradeable,
    Ownable2StepUpgradeable,
    AccessControlUpgradeable
{
    struct Champion {
        address badgeContract;
        uint256 tokenId;
        address owner;
        uint256 color; // 0 = neutral, 1 = pink, 2 = purple
        uint256 energy;
        uint256 power;
    }

    struct Tournament {
        uint256 openTime; // registration starts
        uint256 closeTime; // registration ends
        uint256 startTime; // tournament starts (requires admin action)
        uint256 endTime;
        uint256 seed;
        uint256 rounds;
        address[] participants;
    }

    mapping(address owner => Champion) public champions;
    mapping(uint256 tournamentId => Tournament) public tournaments;
    uint256 public currentTournamentId = 0;

    TrailblazersBadges public season1Badges;

    uint256[8] public powerLevels = [
        4, // Ravers
        58, // Robots
        40, // Bouncers
        43, // Masters
        99, // Monks
        51, // Androids
        42, // Drummers
        77 // Shinto
    ];

    event TournamentCreated(
        uint256 indexed tournamentId, uint256 openTime, uint256 startTime, uint256 endTime
    );
    event TournamentStarted(uint256 tournamentId, uint256 seed);
    event TournamentEnded(uint256 tournamentId, uint256 endTime);

    event ChampionRegistered(
        uint256 tournamentId, address owner, uint256 tokenId, uint256 energy, uint256 power
    );

    error ELEMENT_NOT_FOUND();
    error TOURNAMENT_NOT_STARTED();
    error TOURNAMENT_NOT_OPEN();
    error TOURNAMENT_NOT_CLOSED();
    error TOURNAMENT_NOT_ENDED();
    error CHAMPION_NOT_OWNED();
    error INVALID_PARTICIPANT_COUNT();
    error INVALID_ROUND();

    function initialize(address _season1Badges, address _season2Badges) external initializer {
        __Context_init();
        _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _transferOwnership(_msgSender());
        season1Badges = TrailblazersBadges(_season1Badges);
    }

    function calculateEnergy(uint256 _tokenId) public pure returns (uint256) {
        return _tokenId % 100;
    }

    function calculatePower(uint256 _badgeId) public view returns (uint256) {
        return powerLevels[_badgeId];
    }

    function getCurrentTournament()
        public
        view
        returns (
            uint256 openTime,
            uint256 closeTime,
            uint256 startTime,
            uint256 endTime,
            uint256 seed,
            uint256 rounds,
            address[] memory participants
        )
    {
        return getTournament(currentTournamentId);
    }

    function getTournament(uint256 _tournamentId)
        public
        view
        returns (
            uint256 openTime,
            uint256 closeTime,
            uint256 startTime,
            uint256 endTime,
            uint256 seed,
            uint256 rounds,
            address[] memory participants
        )
    {
        Tournament memory tournament = tournaments[_tournamentId];
        return (
            tournament.openTime,
            tournament.closeTime,
            tournament.startTime,
            tournament.endTime,
            tournament.seed,
            tournament.rounds,
            tournament.participants
        );
    }

    function createTournament(
        uint256 _openTime,
        uint256 _closeTime,
        uint256 _startTime,
        uint256 _endTime
    )
        public
        onlyOwner
    {
        Tournament memory tournament = Tournament({
            openTime: _openTime,
            closeTime: _closeTime,
            startTime: _startTime,
            endTime: _endTime,
            seed: 0,
            rounds: 0,
            participants: new address[](0)
        });
        currentTournamentId += 1;

        tournaments[currentTournamentId] = tournament;

        emit TournamentCreated(currentTournamentId, _openTime, _startTime, _endTime);
    }

    modifier tournamentOpen(uint256 _tournamentId) {
        Tournament memory tournament = tournaments[_tournamentId];
        if (block.timestamp < tournament.openTime || block.timestamp > tournament.closeTime) {
            revert TOURNAMENT_NOT_OPEN();
        }

        _;
    }

    modifier ownedToken(address _badgeContract, uint256 _badgeId) {
        uint256 tokenId = season1Badges.getTokenId(_msgSender(), _badgeId);

        if (
            season1Badges.ownerOf(tokenId) != _msgSender()
                && season1Badges.getApproved(tokenId) != address(this)
                && season1Badges.isApprovedForAll(_msgSender(), address(this))
        ) {
            revert CHAMPION_NOT_OWNED();
        }

        _;
    }

    function registerChampion(
        address _badgeContract,
        uint256 _badgeId
    )
        public
        tournamentOpen(currentTournamentId)
        ownedToken(_badgeContract, _badgeId)
    {
        uint256 color = 0; // TODO: make it based on the badge

        uint256 tokenId = season1Badges.getTokenId(_msgSender(), _badgeId);
        uint256 energy = calculateEnergy(tokenId);
        uint256 power = calculatePower(_badgeId);

        Champion memory champion = Champion({
            badgeContract: _badgeContract,
            tokenId: tokenId,
            owner: _msgSender(),
            energy: energy,
            color: color,
            power: power
        });

        champions[_msgSender()] = champion;
        Tournament storage tournament = tournaments[currentTournamentId];
        tournament.participants.push(_msgSender());

        emit ChampionRegistered(currentTournamentId, _msgSender(), tokenId, energy, power);
    }

    function calculateTotalRounds(uint256 participantCount) public pure returns (uint256) {
        if (participantCount == 0) {
            revert INVALID_PARTICIPANT_COUNT();
        }

        uint256 rounds = 0;
        uint256 count = participantCount;

        while (count > 1) {
            count = (count + 1) / 2; // Each round halves the number of participants
            rounds++;
        }

        return rounds;
    }

    function startTournament(uint256 seed) public onlyOwner {
        Tournament storage tournament = tournaments[currentTournamentId];
        tournament.seed = seed;
        tournament.rounds = calculateTotalRounds(tournament.participants.length);
        emit TournamentStarted(currentTournamentId, seed);
    }

    function calculateAdvantage(
        uint256 _colorLeft,
        uint256 _colorRight
    )
        public
        pure
        returns (bool leftAdvantage, bool rightAdvantage)
    {
        // neutral >> pink >> purple
        // 0 >> 1 >> 2
        if (_colorLeft == 0 && _colorRight == 1) {
            return (true, false);
        } else if (_colorLeft == 0 && _colorRight == 2) {
            return (true, false);
        } else if (_colorLeft == 1 && _colorRight == 0) {
            return (false, true);
        } else if (_colorLeft == 1 && _colorRight == 2) {
            return (true, false);
        } else if (_colorLeft == 2 && _colorRight == 0) {
            return (false, true);
        } else if (_colorLeft == 2 && _colorRight == 1) {
            return (false, true);
        } else {
            return (false, false);
        }
    }

    function _indexOf(address[] memory _array, address _element) internal pure returns (uint256) {
        for (uint256 i = 0; i < _array.length; i++) {
            if (_array[i] == _element) {
                return i;
            }
        }
        revert ELEMENT_NOT_FOUND();
    }

    function _seedBasedRandom(uint256 _extraSeed) internal view returns (uint256) {
        Tournament memory tournament = tournaments[currentTournamentId];
        uint256 seed = tournament.seed + _extraSeed;
        return seed;
    }

    function _calculateBattle(
        address _ownerLeft,
        address _ownerRight
    )
        internal
        view
        returns (bool leftWins)
    {
        Champion memory championLeft = champions[_ownerLeft];
        Champion memory championRight = champions[_ownerRight];

        // calculate base powers
        uint256 powerLeft = championLeft.power + championLeft.energy;
        uint256 powerRight = championRight.power + championRight.energy;

        // determine color advantage
        (bool leftAdvantage, bool rightAdvantage) =
            calculateAdvantage(championLeft.color, championRight.color);
        // apply color bonuses
        if (leftAdvantage) {
            powerLeft += championLeft.energy;
        } else if (rightAdvantage) {
            powerRight += championRight.energy;
        }

        // determine winner
        if (powerLeft > powerRight) {
            return true;
        } else if (powerRight > powerLeft) {
            return false;
        } else {
            // if a tie, determine randomly
            uint256 tieSeed = _seedBasedRandom(powerLeft);
            return (tieSeed % 2 == 0);
        }
    }

    function _randomizeAddresses(
        address[] memory addresses,
        uint256 seed
    )
        internal
        pure
        returns (address[] memory)
    {
        address[] memory shuffledAddresses = addresses;
        uint256 n = shuffledAddresses.length;

        for (uint256 i = n - 1; i > 0; i--) {
            uint256 j = uint256(keccak256(abi.encodePacked(seed, i))) % (i + 1);
            // Swap elements
            (shuffledAddresses[i], shuffledAddresses[j]) =
                (shuffledAddresses[j], shuffledAddresses[i]);
        }

        return shuffledAddresses;
    }

    ////////////////////////////////////////////////////////////////

    function calculateMatchesInRound(
        uint256 round,
        uint256 initialParticipantCount
    )
        public
        pure
        returns (uint256)
    {
        if (initialParticipantCount == 0) {
            revert INVALID_PARTICIPANT_COUNT();
        }

        if (round == 0) {
            revert INVALID_ROUND();
        }
        // Calculate the number of participants in the given round
        uint256 participantsInRound = initialParticipantCount / (2 ** (round - 1));

        // Calculate the number of matches in the given round
        uint256 matchesInRound = participantsInRound / 2;

        return matchesInRound;
    }

    function getMatchup(uint256 round, uint256 matchIndex) public view returns (uint256, uint256) {
        if (round == 0) {
            revert INVALID_ROUND();
        }
        Tournament memory tournament = tournaments[currentTournamentId];

        uint256 firstIndex = matchIndex * 2;
        uint256 secondIndex = firstIndex + 1;

        uint256 firstParticipantIndex =
            deterministicIndex(tournament.seed, firstIndex, round, tournament.participants.length);
        uint256 secondParticipantIndex =
            deterministicIndex(tournament.seed, secondIndex, round, tournament.participants.length);

        // Ensure the indices are distinct
        if (firstParticipantIndex == secondParticipantIndex) {
            secondParticipantIndex = (secondParticipantIndex + 1) % tournament.participants.length;
        }

        return (firstParticipantIndex, secondParticipantIndex);
    }

    function deterministicIndex(
        uint256 seed,
        uint256 index,
        uint256 round,
        uint256 participantsLength
    )
        internal
        pure
        returns (uint256)
    {
        return uint256(keccak256(abi.encode(seed, index, round))) % participantsLength;
    }

    function getParticipants(
        uint256 round,
        uint256 matchIndex
    )
        public
        view
        returns (address, address)
    {
        (uint256 first, uint256 second) = getMatchup(round, matchIndex);
        Tournament memory tournament = tournaments[currentTournamentId];
        return (tournament.participants[first], tournament.participants[second]);
    }

    function getWinner(uint256 round, uint256 matchIndex) public view returns (address) {
        (uint256 first, uint256 second) = getMatchup(round, matchIndex);
        Tournament memory tournament = tournaments[currentTournamentId];

        bool result =
            _calculateBattle(tournament.participants[first], tournament.participants[second]);
        if (result) {
            return tournament.participants[first];
        } else {
            return tournament.participants[second];
        }
    }

    ////////////////////////////////////////////////////////////////
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(AccessControlUpgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    function _authorizeUpgrade(address) internal virtual override onlyOwner { }
}
