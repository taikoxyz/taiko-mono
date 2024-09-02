// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts-upgradeable/token/ERC1155/extensions/ERC1155SupplyUpgradeable.sol";
import "./ECDSAWhitelist.sol";
import "@taiko/blacklist/IMinimalBlacklist.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import "@taiko/blacklist/IMinimalBlacklist.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Pausable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@taiko/blacklist/IMinimalBlacklist.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import "./TrailblazersBadges.sol";

contract TrailblazersBadgesS2 is
    PausableUpgradeable,
    UUPSUpgradeable,
    Ownable2StepUpgradeable,
    AccessControlUpgradeable,
    ERC1155SupplyUpgradeable
{
    uint256 public constant MAX_TAMPERS = 3;

    uint256 public constant RAVER_PINK_ID = 0;
    uint256 public constant RAVER_PURPLE_ID = 1;
    uint256 public constant ROBOT_PINK_ID = 2;
    uint256 public constant ROBOT_PURPLE_ID = 3;
    uint256 public constant BOUNCER_PINK_ID = 4;
    uint256 public constant BOUNCER_PURPLE_ID = 5;
    uint256 public constant MASTER_PINK_ID = 6;
    uint256 public constant MASTER_PURPLE_ID = 7;
    uint256 public constant MONK_PINK_ID = 8;
    uint256 public constant MONK_PURPLE_ID = 9;
    uint256 public constant DRUMMER_PINK_ID = 10;
    uint256 public constant DRUMMER_PURPLE_ID = 11;
    uint256 public constant ANDROID_PINK_ID = 12;
    uint256 public constant ANDROID_PURPLE_ID = 13;
    uint256 public constant SHINTO_PINK_ID = 14;
    uint256 public constant SHINTO_PURPLE_ID = 15;

    uint256 public constant BADGE_COUNT = 16;

    mapping(address _user => uint256 _cooldown) public claimCooldowns;
    mapping(address _user => uint256 _cooldown) public tamperCooldowns;
    mapping(address _user => mapping(bool pinkOrPurple => uint256 _tampers)) public migrationTampers;

    mapping(address _user => uint256 _badgeId) public migrationS1BadgeIds;
    mapping(address _user => uint256 _tokenId) public migrationS1TokenIds;
    mapping(address _user => mapping(uint256 _badgeId => uint256 _tokenId)) public userBadges;

    error MAX_TAMPERS_REACHED();

    error MIGRATION_NOT_STARTED();
    error MIGRATION_ALREADY_STARTED();
    error TAMPER_IN_PROGRESS();
    error CONTRACT_PAUSED();
    error MIGRATION_NOT_READY();
    error TOKEN_NOT_MINTED();

    mapping(uint256 _s1BadgeId => bool _enabled) public enabledBadgeIds;

    modifier whenUnpaused(uint256 _badgeId) {
        if (paused(_badgeId)) {
            revert CONTRACT_PAUSED();
        }
        _;
    }

    TrailblazersBadges public badges;

    modifier isMigrating() {
        if (claimCooldowns[_msgSender()] == 0) {
            revert MIGRATION_NOT_STARTED();
        }
        _;
    }

    modifier isNotMigrating() {
        if (claimCooldowns[_msgSender()] != 0) {
            revert MIGRATION_ALREADY_STARTED();
        }
        _;
    }

    modifier isNotTampering() {
        // revert if the user is tampering; ie, their cooldown
        // has not expired

        if (tamperCooldowns[_msgSender()] < block.timestamp) {
            revert TAMPER_IN_PROGRESS();
        }
        _;
    }

    function initialize(address _badges) external initializer {
        __ERC1155_init("");
        __ERC1155Supply_init();
        _transferOwnership(_msgSender());
        __Context_init();

        badges = TrailblazersBadges(_badges);
    }

    /// @notice Start a migration for a badge
    /// @param _s1BadgeId The badge token ID (s1)
    /// @dev Not all badges are eligible for migration at the same time
    /// @dev Defines a cooldown for the migration to be complete
    /// @dev the cooldown is lesser the higher the Pass Tier
    function startMigration(uint256 _s1BadgeId) external {
        uint256 s1TokenId = badges.getTokenId(_msgSender(), _s1BadgeId);
        if (badges.ownerOf(s1TokenId) != _msgSender()) {
            revert TOKEN_NOT_MINTED();
        }
        // transfer the badge tokens to the migration contract
        badges.transferFrom(_msgSender(), address(this), s1TokenId);
        // set off the claim cooldown
        claimCooldowns[_msgSender()] = block.timestamp + 1 hours;
        migrationTampers[_msgSender()][true] = 0;
        migrationTampers[_msgSender()][false] = 0;
        migrationS1BadgeIds[_msgSender()] = _s1BadgeId;
        migrationS1TokenIds[_msgSender()] = s1TokenId;
    }

    /// @notice Tamper (alter) the chances during a migration
    /// @param _pinkOrPurple true for pink, false for purple
    /// @dev Can be called only during an active migration
    /// @dev Implements a cooldown before allowing to re-tamper
    /// @dev The max tamper amount is determined by Pass Tier
    function tamperMigration(bool _pinkOrPurple) external isMigrating {
        if (migrationTampers[_msgSender()][_pinkOrPurple] >= MAX_TAMPERS) {
            revert MAX_TAMPERS_REACHED();
        }
        migrationTampers[_msgSender()][_pinkOrPurple]++;
        tamperCooldowns[_msgSender()] = block.timestamp + 1 hours;
    }

    /// @notice End a migration
    /// @dev Can be called only during an active migration, after the cooldown is over
    /// @dev The final color is determined randomly, and affected by the tamper amounts
    function endMigration() external isMigrating {
        // check if the cooldown is over
        if (block.timestamp < claimCooldowns[_msgSender()]) {
            revert MIGRATION_NOT_READY();
        }

        // get the tamper amounts
        uint256 pinkTampers = migrationTampers[_msgSender()][true];
        uint256 purpleTampers = migrationTampers[_msgSender()][false];

        // determine the final color, with the tampers adding a max 50% chance if maxxed out
        bool isPink =
            pinkTampers < 3 && purpleTampers < 3 ? block.timestamp % 2 == 0 : pinkTampers < 3;

        (uint256 pinkBadgeId, uint256 purpleBadgeId) =
            getSeason2BadgeIds(migrationS1BadgeIds[_msgSender()]);
        uint256 s2BadgeId = isPink ? pinkBadgeId : purpleBadgeId;

        // burn the s1 badge
        uint256 s1TokenId = migrationS1TokenIds[_msgSender()];
        badges.burn(s1TokenId);

        uint256 s2TokenId = totalSupply() + 1;
        // mint the badge
        _mint(_msgSender(), s2TokenId, 1, "");

        // reset the cooldowns
        claimCooldowns[_msgSender()] = 0;
        migrationTampers[_msgSender()][true] = 0;
        migrationTampers[_msgSender()][false] = 0;
        migrationS1BadgeIds[_msgSender()] = 0;
        migrationS1TokenIds[_msgSender()] = 0;
        userBadges[_msgSender()][s2BadgeId] = s2TokenId;
    }

    /// @notice Get the max tamper amount for the calling user and their Trail tier
    /// @return The maximum tamper amount
    function getMaximumTampers() external view returns (uint256) { }

    /// @notice supportsInterface implementation
    /// @param interfaceId The interface ID
    /// @return Whether the interface is supported
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC1155Upgradeable, AccessControlUpgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    /// @notice Internal method to authorize an upgrade
    function _authorizeUpgrade(address) internal virtual override onlyOwner { }

    function _disableMigrations() internal onlyRole(DEFAULT_ADMIN_ROLE) {
        for (uint256 i = 0; i < 8; i++) {
            enabledBadgeIds[i] = false;
        }
    }

    function paused(uint256 _s1Badge) public view returns (bool) {
        for (uint256 i = 0; i < 8; i++) {
            if (enabledBadgeIds[i] && i == _s1Badge) {
                return true;
            }
        }
        return super.paused();
    }

    function pause() public onlyRole(DEFAULT_ADMIN_ROLE) {
        _disableMigrations();
        _pause();
    }

    function getSeason2BadgeIds(uint256 _s1BadgeId)
        public
        pure
        returns (uint256 _pinkBadgeId, uint256 _purpleBadgeId)
    {
        return (_s1BadgeId * 2, _s1BadgeId * 2 + 1);
    }

    function getSeason1BadgeId(uint256 _s2BadgeId) public pure returns (uint256 _s1BadgeId) {
        return _s2BadgeId / 2;
    }

    function isMigrationActive(address _user) public view returns (bool) {
        return claimCooldowns[_user] != 0;
    }

    function isTamperActive(address _user) public view returns (bool) {
        return tamperCooldowns[_user] > block.timestamp;
    }

    function getMigrationTampers(address _user)
        public
        view
        returns (uint256 _pinkTampers, uint256 _purpleTampers)
    {
        return (migrationTampers[_user][true], migrationTampers[_user][false]);
    }

    function getTokenId(address _user, uint256 _s2BadgeId) public view returns (uint256 _tokenId) {
        return userBadges[_user][_s2BadgeId];
    }

    function badgeBalances(address _owner) public view returns (bool[16] memory _balances) {
        for (uint256 i = 0; i < BADGE_COUNT; i++) {
            uint256 tokenId = getTokenId(_owner, i);
            _balances[i] = tokenId > 0;
        }

        return _balances;
    }

    function badgeBalanceOf(address _owner) public view returns (uint256 _balance) {
        bool[16] memory balances = badgeBalances(_owner);

        for (uint256 i = 0; i < balances.length; i++) {
            if (balances[i]) {
                _balance++;
            }
        }

        return _balance;
    }
}
