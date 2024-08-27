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
import "./TrailPass.sol";
import "./TrailblazersBadges.sol";

contract TrailblazersSigils is
    PausableUpgradeable,
    UUPSUpgradeable,
    Ownable2StepUpgradeable,
    AccessControlUpgradeable,
    ERC1155SupplyUpgradeable
{
    TrailPass public trailPass;
    TrailblazersBadges public badges;
    // token ids

    uint256 public constant RAVER_PINK_ID = 0;
    uint256 public constant RAVER_PURPLE_ID = 1;
    uint256 public constant ROBOT_PINK_ID = 2;
    uint256 public constant ROBOT_PURPLE_ID = 3;
    uint256 public constant BOUNCER_PINK_ID = 4;
    uint256 public constant BOUNCER_PURPLE_ID = 5;
    uint256 public constant MASTER_PINK_ID = 6;
    uint256 public constant MASTER_PURPLE_ID = 7;
    uint256 public constant DRUMMER_PINK_ID = 8;
    uint256 public constant DRUMMER_PURPLE_ID = 9;
    uint256 public constant ANDROID_PINK_ID = 10;
    uint256 public constant ANDROID_PURPLE_ID = 11;
    uint256 public constant MONK_PINK_ID = 12;
    uint256 public constant MONK_PURPLE_ID = 13;
    uint256 public constant SHINTO_PINK_ID = 14;
    uint256 public constant SHINTO_PURPLE_ID = 15;

    uint256[] public TOKEN_IDS = [
        RAVER_PINK_ID,
        RAVER_PURPLE_ID,
        ROBOT_PINK_ID,
        ROBOT_PURPLE_ID,
        BOUNCER_PINK_ID,
        BOUNCER_PURPLE_ID,
        MASTER_PINK_ID,
        MASTER_PURPLE_ID,
        DRUMMER_PINK_ID,
        DRUMMER_PURPLE_ID,
        ANDROID_PINK_ID,
        ANDROID_PURPLE_ID,
        MONK_PINK_ID,
        MONK_PURPLE_ID,
        SHINTO_PINK_ID,
        SHINTO_PURPLE_ID
    ];

    uint256[] public pausedBadgeIds;

    mapping(address _user => uint256 _cooldown) public claimCooldowns;
    mapping(address _user => uint256 _cooldown) public tamperCooldowns;

    mapping(address _user => mapping(bool pinkOrPurple => uint256 _tampers)) public migrationTampers;

    mapping(address _user => uint256 _badgeId) public migrationBadgeIds;

    error MAX_TAMPERS_REACHED();

    error MIGRATION_NOT_STARTED();
    error MIGRATION_ALREADY_STARTED();
    error TAMPER_IN_PROGRESS();
    error CONTRACT_PAUSED();

    mapping(uint256 => bool) public enabledBadgeIds;

    function initialize(address _badges, address _trailPass) external initializer {
        __ERC1155_init("");
        __ERC1155Supply_init();
        _transferOwnership(_msgSender());
        __Context_init();

        badges = TrailblazersBadges(_badges);
        trailPass = TrailPass(_trailPass);
    }

    modifier whenUnpaused(uint256 _badgeId) {
        if (paused(_badgeId)) {
            revert CONTRACT_PAUSED();
        }
        _;
    }

    modifier isMigrating() {
        if (claimCooldowns[_msgSender()] == 0 || block.timestamp < claimCooldowns[_msgSender()]) {
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

    // forge methods

    function startMigration(uint256 _badgeTokenId) public whenUnpaused(_badgeTokenId) {
        // transfer the badge tokens to the migration contract
        badges.transferFrom(_msgSender(), address(this), _badgeTokenId);
        // set off the claim cooldown
        uint256 level = trailPass.getLevel(_msgSender());
        claimCooldowns[_msgSender()] = block.timestamp + ((12 - level) * 1 hours);
        migrationTampers[_msgSender()][true] = 0;
        migrationTampers[_msgSender()][false] = 0;
        migrationBadgeIds[_msgSender()] = _badgeTokenId;
    }

    function tamperMigration(bool _pinkOrPurple) public isMigrating isNotTampering {
        uint256 maxTampers = trailPass.getLevel(_msgSender());

        if (migrationTampers[_msgSender()][_pinkOrPurple] >= maxTampers) {
            revert MAX_TAMPERS_REACHED();
        }
        migrationTampers[_msgSender()][_pinkOrPurple] += 1;
        tamperCooldowns[_msgSender()] = block.timestamp + 1 hours;
    }

    function endMigration() public isMigrating {
        // assign final color with 50/50 chances
        bool finalColor = block.number % 2 == 0;

        // have pink and purple influence the final color
        // at most, each can add 50% to the final color choice
        //
        uint256 pink = migrationTampers[_msgSender()][true];
        uint256 purple = migrationTampers[_msgSender()][false];

        if (pink > 0 || purple > 0) {
            uint256 maxTampers = trailPass.getLevel(_msgSender());
            // make the contribution proportioanl to the maxTamper
            uint256 pinkContribution = pink * 100 / (maxTampers - 1);
            uint256 purpleContribution = purple * 100 / (maxTampers - 1);

            // make the final color choice
            if (pinkContribution > purpleContribution) {
                finalColor = true;
            } else if (purpleContribution > pinkContribution) {
                finalColor = false;
            }
        }
        uint256 badgeTokenId = migrationBadgeIds[_msgSender()];
        // mint the sigil
        uint256 sigilId = finalColor ? TOKEN_IDS[badgeTokenId * 2] : TOKEN_IDS[badgeTokenId * 2 + 1];
        _mint(_msgSender(), sigilId, 1, "");
        // reset the cooldown
        claimCooldowns[_msgSender()] = 0;
        migrationTampers[_msgSender()][true] = 0;
        migrationTampers[_msgSender()][false] = 0;
        migrationBadgeIds[_msgSender()] = 0;
    }

    function paused(uint256 _sigilId) public view returns (bool) {
        return super.paused();
    }

    function _disableMigrations() internal onlyRole(DEFAULT_ADMIN_ROLE) {
        for (uint256 i = 0; i < 8; i++) {
            enabledBadgeIds[i] = false;
        }
    }

    function pause() public onlyRole(DEFAULT_ADMIN_ROLE) {
        _disableMigrations();
        _pause();
    }

    function unpause(uint256[] calldata _badgeIds) public onlyRole(DEFAULT_ADMIN_ROLE) {
        _disableMigrations();

        for (uint256 i = 0; i < _badgeIds.length; i++) {
            enabledBadgeIds[_badgeIds[i]] = true;
        }
        _unpause();
    }

    function mint(address _to, uint256 _id, uint256 _amount, bytes memory _data) public {
        require(trailPass.hasPass(_to), "TrailblazersSigils: user does not have a pass");
        _mint(_to, _id, _amount, _data);
    }
}
