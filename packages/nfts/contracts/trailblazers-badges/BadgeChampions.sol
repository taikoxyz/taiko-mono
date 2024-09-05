// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Pausable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import { AccessControlUpgradeable } from
    "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import { PausableUpgradeable } from
    "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
// import { IMinimalBlacklist } from "@taiko/blacklist/IMinimalBlacklist.sol";
import { UUPSUpgradeable } from
    "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { Ownable2StepUpgradeable } from
    "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import "./TrailblazersBadges.sol";
import "./TrailblazersBadgesS2.sol";

contract BadgeChampions is
    PausableUpgradeable,
    UUPSUpgradeable,
    Ownable2StepUpgradeable,
    AccessControlUpgradeable
{
    struct Champion {
            address owner;
            uint256 leagueId;
        address badgeContract;
        uint256 tokenId;
        uint256 color; // 0 = neutral, 1 = pink, 2 = purple
        uint256 power;
    }

    struct League {
        uint256 openTime; // registration starts
        uint256 closeTime; // registration ends
        uint256 startTime; // league starts (requires admin action)
        uint256 seed;
        address[] participants;
    }

    mapping(address owner => Champion champion) public champions;
    mapping(uint256 leagueId => League league) public leagues;
    uint256 public currentLeagueId = 0;

    TrailblazersBadges public season1Badges;
    TrailblazersBadgesS2 public season2Badges;

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



    event LeagueCreated(
        uint256 indexed leagueId, uint256 openTime, uint256 startTime, uint256 endTime
    );
    event LeagueStarted(uint256 leagueId, uint256 seed);

    event ChampionRegistered(
        uint256 indexed leagueId, address indexed owner,
        address badgesContract, uint256 tokenId, uint256 power
    );

    error ELEMENT_NOT_FOUND();
    error TOURNAMENT_NOT_STARTED();
    error TOURNAMENT_NOT_OPEN();
    error TOURNAMENT_NOT_CLOSED();
    error TOURNAMENT_NOT_ENDED();
    error CHAMPION_NOT_OWNED();
    error INVALID_PARTICIPANT_COUNT();
    error INVALID_ROUND();
error INVALID_CHAMPION_CONTRACT();
error INVALID_MATCH();

    function initialize(address _season1Badges, address _season2Badges) external initializer {
        __Context_init();
        _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _transferOwnership(_msgSender());
        season1Badges = TrailblazersBadges(_season1Badges);
        season2Badges = TrailblazersBadgesS2(_season2Badges);
    }

    function getCurrentLeague()
        public
        view
        returns (
            uint256 openTime,
            uint256 closeTime,
            uint256 startTime,
            uint256 seed,
            address[] memory participants
        )
    {
        return getLeague(currentLeagueId);
    }

    function getLeague(uint256 _leagueId)
        public
        view
        returns (
            uint256 openTime,
            uint256 closeTime,
            uint256 startTime,
            uint256 seed,
            address[] memory participants
        )
    {
        League memory league = leagues[_leagueId];
        return (
            league.openTime,
            league.closeTime,
            league.startTime,
            league.seed,
            league.participants
        );
    }

    function createLeague(
        uint256 _openTime,
        uint256 _closeTime,
        uint256 _startTime
    )
        public
        onlyOwner
    {
        League memory league = League({
            openTime: _openTime,
            closeTime: _closeTime,
            startTime: _startTime,
            seed: 0,
            participants: new address[](0)
        });
        currentLeagueId += 1;

        leagues[currentLeagueId] = league;

        emit LeagueCreated(currentLeagueId, _openTime, _closeTime,  _startTime
        );
        }

    modifier leagueOpen(uint256 _leagueId) {
        League memory league = leagues[_leagueId];
        if (block.timestamp < league.openTime || block.timestamp > league.closeTime) {
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

    function calculatePower(uint256 _badgeId) public view returns (uint256) {
        return powerLevels[_badgeId % powerLevels.length];
    }

    function _registerChampionFor(
        address _player,
        address _badgeContract,
        uint256 _badgeId
    ) internal
    {
        if (_badgeContract != address(season1Badges) && _badgeContract != address(season2Badges)) {
            revert INVALID_CHAMPION_CONTRACT();
        }
        uint256 color = 0; // TODO: make it based on the badge

        uint256 tokenId = season1Badges.getTokenId(_player, _badgeId);
        uint256 power = calculatePower(_badgeId);

        Champion memory champion = Champion({
            leagueId: currentLeagueId,
            badgeContract: _badgeContract,
            tokenId: tokenId,
            owner: _player,
            color: color,
            power: power
        });

        champions[_player] = champion;
        League storage league = leagues[currentLeagueId];
        league.participants.push(_player);

        emit ChampionRegistered(
            currentLeagueId, _player, _badgeContract, tokenId, power);
    }

    function registerChampionFor(
        address _player,
        address _badgeContract,
        uint256 _badgeId
    )
        public
        onlyOwner
    {
        _registerChampionFor(_player, _badgeContract, _badgeId);
    }

    function registerChampion(
        address _badgeContract,
        uint256 _badgeId
    )
        public
        leagueOpen(currentLeagueId)
        ownedToken(_badgeContract, _badgeId)
    {
        _registerChampionFor(_msgSender(), _badgeContract, _badgeId);
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

    function startLeague(uint256 seed) public onlyOwner {
        League storage league = leagues[currentLeagueId];
        league.seed = seed;
        emit LeagueStarted(currentLeagueId, seed);
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
        League memory league = leagues[currentLeagueId];
        uint256 seed = league.seed + _extraSeed;
        return seed;
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
        League memory league = leagues[currentLeagueId];

        uint256 firstIndex = matchIndex * 2;
        uint256 secondIndex = firstIndex + 1;

        uint256 firstParticipantIndex =
            deterministicIndex(league.seed, firstIndex, round, league.participants.length);
        uint256 secondParticipantIndex =
            deterministicIndex(league.seed, secondIndex, round, league.participants.length);

        // Ensure the indices are distinct
        if (firstParticipantIndex == secondParticipantIndex) {
            secondParticipantIndex = (secondParticipantIndex + 1) % league.participants.length;
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
        uint256 maxMatchIndex = calculateMatchesInRound(round, leagues[currentLeagueId].participants.length);
        if (matchIndex >= maxMatchIndex) {
            revert INVALID_MATCH();
        }
        (uint256 first, uint256 second) = getMatchup(round, matchIndex);
        League memory league = leagues[currentLeagueId];
        return (league.participants[first], league.participants[second]);
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



    ////////////////////////////////////////////////////////////////


// Deterministically shuffle an array of addresses based on a uint256 seed
      // Simple linear congruential generator (LCG)
    function linearCongruentialGenerator(uint256 seed) private pure returns (uint256) {
        // Parameters for LCG
        uint256 a = 1664525;
        uint256 c = 1013904223;
        uint256 m = 2**32;

        return (a * seed + c) % m;
    }

     function shuffleAddresses(address[] calldata addresses, uint256 seed) public pure returns (address[] memory) {
        uint256 n = addresses.length;
        // Create a memory copy of the calldata array since calldata is read-only
        address[] memory shuffled = new address[](n);

        for (uint256 i = 0; i < n; i++) {
            shuffled[i] = addresses[i];
        }

        // Perform the Fisher-Yates shuffle on the memory array
        for (uint256 i = n - 1; i > 0; i--) {
            // Generate a pseudo-random index based on the seed
            uint256 randomIndex = (linearCongruentialGenerator(seed + i) % (i + 1));

            // Swap the current element with the random index
            address temp = shuffled[i];
            shuffled[i] = shuffled[randomIndex];
            shuffled[randomIndex] = temp;
        }

        return shuffled;
    }

    /*
        we relly on a seed-sort for the participants
        implement js iterator to extract results
            - the blocknumber at use is startBlockNumber + round



    */
}
