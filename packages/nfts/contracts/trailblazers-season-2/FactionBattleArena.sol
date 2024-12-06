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
import "./TrailblazersS1BadgesV4.sol";
import "./TrailblazersBadgesS2.sol";

contract FactionBattleArena is
    PausableUpgradeable,
    UUPSUpgradeable,
    Ownable2StepUpgradeable,
    AccessControlUpgradeable
{
    struct Champion {
        address owner;
        address badgeContract;
        uint256 tokenId;
        uint256 leagueId;
        uint256 color; // 0 = neutral, 1 = pink, 2 = purple
        uint256 power;
    }

    struct League {
        uint64 openTime; // registration starts
        uint64 closeTime; // registration ends
        uint64 startTime; // league starts (requires admin action)
        uint256 seed;
    }

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
        uint256 indexed leagueId,
        address indexed owner,
        address badgesContract,
        uint256 tokenId,
        uint256 power,
        uint256 badgeId
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

    modifier leagueOpen(uint256 _leagueId) {
        League memory league = leagues[_leagueId];
        if (block.timestamp < league.openTime || block.timestamp > league.closeTime) {
            revert TOURNAMENT_NOT_OPEN();
        }

        _;
    }

    modifier ownedToken(address _badgeContract, uint256 _badgeId) {
        // TODO: erc1155 ownership checkup for s2 badges
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

    function initialize(address _season1Badges, address _season2Badges) external initializer {
        __Context_init();
        _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _transferOwnership(_msgSender());
        season1Badges = TrailblazersBadges(_season1Badges);
        season2Badges = TrailblazersBadgesS2(_season2Badges);
    }

    function getCurrentLeague() public view returns (League memory league) {
        return getLeague(currentLeagueId);
    }

    function getLeague(uint256 _leagueId) public view returns (League memory league) {
        return leagues[_leagueId];
    }

    function createLeague(
        uint64 _openTime,
        uint64 _closeTime,
        uint64 _startTime
    )
        public
        onlyOwner
    {
        League memory league =
            League({ openTime: _openTime, closeTime: _closeTime, startTime: _startTime, seed: 0 });
        currentLeagueId += 1;

        leagues[currentLeagueId] = league;

        emit LeagueCreated(currentLeagueId, _openTime, _closeTime, _startTime);
    }

    function calculatePower(uint256 _badgeId) public pure returns (uint256) {
        return ((1 + _badgeId) * 125) / 10;
        //return powerLevels[_badgeId % powerLevels.length];
    }

    function _registerChampionFor(
        address _player,
        address _badgeContract,
        uint256 _badgeId
    )
        internal
    {
        if (_badgeContract != address(season1Badges) && _badgeContract != address(season2Badges)) {
            revert INVALID_CHAMPION_CONTRACT();
        }

        uint256 tokenId = season1Badges.getTokenId(_player, _badgeId);
        uint256 power = calculatePower(_badgeId);

        emit ChampionRegistered(currentLeagueId, _player, _badgeContract, tokenId, power, _badgeId);
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

    function getChampionId(
        uint256 _leagueId,
        address _owner,
        address _badgeContract,
        uint256 _tokenId
    )
        public
        pure
        returns (bytes32)
    {
        return keccak256(abi.encodePacked(_owner, _badgeContract, _tokenId, _leagueId));
    }

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
