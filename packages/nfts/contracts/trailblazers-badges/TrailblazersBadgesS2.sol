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
import "@openzeppelin/contracts-upgradeable/token/ERC721/utils/ERC721HolderUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@taiko/blacklist/IMinimalBlacklist.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import "./TrailblazersBadges.sol";
import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract TrailblazersBadgesS2 is
    PausableUpgradeable,
    UUPSUpgradeable,
    Ownable2StepUpgradeable,
    AccessControlUpgradeable,
    ERC1155SupplyUpgradeable,
    ERC721HolderUpgradeable
{
    /// @notice Time between start and end of a migration
    uint256 public constant COOLDOWN_MIGRATION = 6 hours;
    /// @notice Time between tamper attempts
    uint256 public constant COOLDOWN_TAMPER = 1 hours;
    /// @notice Weight of tamper attempts, in %
    uint256 public constant TAMPER_WEIGHT_PERCENT = 5;
    /// @notice Maximum tamper attempts, per color
    uint256 public constant MAX_TAMPERS = 3;
    /// @notice S2 Badge IDs
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
    /// @notice Total badge count
    uint256 public constant BADGE_COUNT = 16;

    /// @notice Cooldown for migration
    mapping(address _user => uint256 _cooldown) public claimCooldowns;
    /// @notice Cooldown for tampering
    mapping(address _user => uint256 _cooldown) public tamperCooldowns;
    /// @notice Tamper count
    mapping(address _user => mapping(bool pinkOrPurple => uint256 _tampers)) public migrationTampers;
    /// @notice S1 Migration Badge ID mapping
    mapping(address _user => uint256 _badgeId) private migrationS1BadgeIds;
    /// @notice S1 Migration Token ID mapping
    mapping(address _user => uint256 _tokenId) private migrationS1TokenIds;
    /// @notice User to badge ID, token ID mapping
    mapping(address _user => mapping(uint256 _badgeId => uint256 _tokenId)) public userBadges;
    /// @notice Migration-enabled badge IDs per cycle
    mapping(uint256 _cycle => mapping(uint256 _s1BadgeId => bool _enabled)) public enabledBadgeIds;
    /// @notice S1 Badge contract
    TrailblazersBadges public badges;
    /// @notice Address authorized to sign the random seeds
    address public randomSigner;
    /// @notice Current migration cycle
    uint256 public migrationCycle;
    /// @notice Mapping of unique user-per-mint-per-cycle
    mapping(
        uint256 _migrationCycle
            => mapping(address _minter => mapping(uint256 _s1BadgeId => bool _mintEnded))
    ) public migrationCycleUniqueMints;
    /// @notice Gap for upgrade safety
    uint256[43] private __gap;

    /// @notice Errors
    error MAX_TAMPERS_REACHED();
    error MIGRATION_NOT_STARTED();
    error MIGRATION_ALREADY_STARTED();
    error TAMPER_IN_PROGRESS();
    error CONTRACT_PAUSED();
    error MIGRATION_NOT_READY();
    error TOKEN_NOT_MINTED();
    error MIGRATION_NOT_ENABLED();
    error TOKEN_NOT_OWNED();
    error NOT_RANDOM_SIGNER();
    error ALREADY_MIGRATED_IN_CYCLE();

    /// @notice Events
    event MigrationToggled(uint256 _s1BadgeId, bool _enabled);
    event MigrationStarted(
        address _user, uint256 _s1BadgeId, uint256 _s1TokenId, uint256 _cooldownExpiration
    );
    event MigrationTampered(address _user, bool _pinkOrPurple, uint256 _cooldownExpiration);
    event MigrationEnded(address _user, uint256 _s2BadgeId, uint256 _s2TokenId);

    /// @notice Modifiers
    modifier isMigrating() {
        if (claimCooldowns[_msgSender()] == 0) {
            revert MIGRATION_NOT_STARTED();
        }
        _;
    }
    /// @notice Reverts if sender is already migrating

    modifier isNotMigrating() {
        if (claimCooldowns[_msgSender()] != 0) {
            revert MIGRATION_ALREADY_STARTED();
        }
        _;
    }
    /// @notice Reverts if migrations aren't enabled for that badge

    modifier migrationOpen(uint256 _s1BadgeId) {
        if (!enabledBadgeIds[migrationCycle][_s1BadgeId]) {
            revert MIGRATION_NOT_ENABLED();
        }
        _;
    }

    /// @notice Limits migrations to one per user, badge and cycle
    modifier hasntMigratedInCycle(uint256 _s1BadgeId, address _minter) {
        // check that the minter hasn't used the migration within this cycle
        if (migrationCycleUniqueMints[migrationCycle][_minter][_s1BadgeId]) {
            revert ALREADY_MIGRATED_IN_CYCLE();
        }
        _;
    }

    /// @notice Contract initializer
    /// @param _badges The address of the S1 badges contract
    function initialize(address _badges, address _randomSigner) external initializer {
        __ERC1155_init("");
        __ERC1155Supply_init();
        _transferOwnership(_msgSender());
        __Context_init();
        _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());
        badges = TrailblazersBadges(_badges);
        randomSigner = _randomSigner;
    }

    /// @notice Start a migration for a badge
    /// @param _s1BadgeId The badge ID (s1)
    /// @dev Not all badges are eligible for migration at the same time
    /// @dev Defines a cooldown for the migration to be complete
    /// @dev the cooldown is lesser the higher the Pass Tier
    function startMigration(uint256 _s1BadgeId)
        external
        migrationOpen(_s1BadgeId)
        isNotMigrating
        hasntMigratedInCycle(_s1BadgeId, _msgSender())
    {
        uint256 s1TokenId = badges.getTokenId(_msgSender(), _s1BadgeId);

        if (badges.ownerOf(s1TokenId) != _msgSender()) {
            revert TOKEN_NOT_OWNED();
        }

        // set off the claim cooldown
        claimCooldowns[_msgSender()] = block.timestamp + COOLDOWN_MIGRATION;
        migrationTampers[_msgSender()][true] = 0;
        migrationTampers[_msgSender()][false] = 0;
        migrationS1BadgeIds[_msgSender()] = _s1BadgeId;
        migrationS1TokenIds[_msgSender()] = s1TokenId;
        tamperCooldowns[_msgSender()] = 0;
        // transfer the badge tokens to the migration contract
        badges.transferFrom(_msgSender(), address(this), s1TokenId);

        emit MigrationStarted(_msgSender(), _s1BadgeId, s1TokenId, claimCooldowns[_msgSender()]);
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

        if (tamperCooldowns[_msgSender()] > block.timestamp) {
            revert TAMPER_IN_PROGRESS();
        }

        migrationTampers[_msgSender()][_pinkOrPurple]++;
        tamperCooldowns[_msgSender()] = block.timestamp + COOLDOWN_TAMPER;
        emit MigrationTampered(_msgSender(), _pinkOrPurple, tamperCooldowns[_msgSender()]);
    }

    /// @notice Reset the tamper counts
    /// @dev Can be called only during an active migration
    function resetTampers() external isMigrating {
        migrationTampers[_msgSender()][true] = 0;
        migrationTampers[_msgSender()][false] = 0;
        tamperCooldowns[_msgSender()] = 0;
    }

    /// @notice End a migration
    /// @dev Can be called only during an active migration, after the cooldown is over
    /// @dev The final color is determined randomly, and affected by the tamper amounts
    function endMigration(bytes32 _hash, uint8 v, bytes32 r, bytes32 s) external isMigrating {
        if (tamperCooldowns[_msgSender()] > block.timestamp) {
            revert TAMPER_IN_PROGRESS();
        }
        // check if the cooldown is over
        if (claimCooldowns[_msgSender()] > block.timestamp) {
            revert MIGRATION_NOT_READY();
        }

        // get the tamper amounts
        uint256 pinkTampers = migrationTampers[_msgSender()][true];
        uint256 purpleTampers = migrationTampers[_msgSender()][false];

        uint256 randomSeed = randomFromSignature(_hash, v, r, s);
        bool isPinkOrPurple;
        // Calculate the difference in tampers and adjust chances
        if (pinkTampers > purpleTampers) {
            uint256 extraChance = (pinkTampers - purpleTampers) * TAMPER_WEIGHT_PERCENT;
            uint256 chance = 50 + extraChance; // Base 50% + extra chance
            isPinkOrPurple = (randomSeed % 100) < chance; // True for pink
        } else if (purpleTampers > pinkTampers) {
            uint256 extraChance = (purpleTampers - pinkTampers) * TAMPER_WEIGHT_PERCENT;
            uint256 chance = 50 + extraChance; // Base 50% + extra chance
            isPinkOrPurple = (randomSeed % 100) >= chance; // False for purple
        } else {
            // Equal number of pink and purple tampers, 50/50 chance
            isPinkOrPurple = (randomSeed % 100) < 50;
        }

        uint256 s1BadgeId = migrationS1BadgeIds[_msgSender()];
        (uint256 pinkBadgeId, uint256 purpleBadgeId) = getSeason2BadgeIds(s1BadgeId);
        uint256 s2BadgeId = isPinkOrPurple ? pinkBadgeId : purpleBadgeId;

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
        tamperCooldowns[_msgSender()] = 0;
        migrationS1BadgeIds[_msgSender()] = 0;
        migrationS1TokenIds[_msgSender()] = 0;
        userBadges[_msgSender()][s2BadgeId] = s2TokenId;
        migrationCycleUniqueMints[migrationCycle][_msgSender()][s1BadgeId] = true;
        emit MigrationEnded(_msgSender(), s2BadgeId, s2TokenId);
    }

    /// @notice Enable migrations for a set of badges
    /// @param _s1BadgeIds The badge IDs to enable
    /// @dev Can be called only by the contract owner/admin
    function enableMigrations(uint256[] calldata _s1BadgeIds)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        migrationCycle++;
        for (uint256 i = 0; i < _s1BadgeIds.length; i++) {
            enabledBadgeIds[migrationCycle][_s1BadgeIds[i]] = true;
            emit MigrationToggled(_s1BadgeIds[i], true);
        }
    }

    /// @notice Check if the migrations for a badge are enabled
    /// @param _s1Badge The badge ID to check
    /// @return Whether the badge is enabled for migration
    function canMigrate(uint256 _s1Badge) public view returns (bool) {
        for (uint256 i = 0; i < 8; i++) {
            if (enabledBadgeIds[migrationCycle][i] && i == _s1Badge) {
                return true;
            }
        }
        return false;
    }

    /// @notice Pause the contract
    /// @dev Can be called only by the contract owner/admin
    function pause() public onlyRole(DEFAULT_ADMIN_ROLE) {
        _disableMigrations();
        _pause();
    }

    /// @notice S1 --> S2 badge ID mapping
    /// @param _s1BadgeId The S1 badge ID
    /// @return _pinkBadgeId The S2 pink badge ID
    /// @return _purpleBadgeId The S2 purple badge ID
    function getSeason2BadgeIds(uint256 _s1BadgeId)
        public
        pure
        returns (uint256 _pinkBadgeId, uint256 _purpleBadgeId)
    {
        return (_s1BadgeId * 2, _s1BadgeId * 2 + 1);
    }

    /// @notice S2 --> S1 badge ID mapping
    /// @param _s2BadgeId The S2 badge ID
    /// @return _s1BadgeId The S1 badge ID
    function getSeason1BadgeId(uint256 _s2BadgeId) public pure returns (uint256 _s1BadgeId) {
        return _s2BadgeId / 2;
    }

    /// @notice Check if a migration is active for a user
    /// @param _user The user address
    /// @return Whether the user has an active migration
    function isMigrationActive(address _user) public view returns (bool) {
        return claimCooldowns[_user] != 0;
    }

    /// @notice Check if a tamper is active for a user
    /// @param _user The user address
    /// @return Whether the user has an active tamper
    function isTamperActive(address _user) public view returns (bool) {
        return tamperCooldowns[_user] > block.timestamp;
    }

    /// @notice Get the migration tamper counts for a user
    /// @param _user The user address
    /// @return _pinkTampers The pink tamper count
    /// @return _purpleTampers The purple tamper count
    function getMigrationTampers(address _user)
        public
        view
        returns (uint256 _pinkTampers, uint256 _purpleTampers)
    {
        if (!isMigrationActive(_user)) {
            revert MIGRATION_NOT_STARTED();
        }
        return (migrationTampers[_user][true], migrationTampers[_user][false]);
    }

    /// @notice Retrieve a token ID given their owner and S2 Badge ID
    /// @param _user The address of the badge owner
    /// @param _s2BadgeId The S2 badge ID
    /// @return _tokenId The token ID
    function getTokenId(address _user, uint256 _s2BadgeId) public view returns (uint256 _tokenId) {
        return userBadges[_user][_s2BadgeId];
    }

    /// @notice Retrieve boolean balance for each badge
    /// @param _owner The addresses to check
    /// @return _balances The badges atomic balances
    function badgeBalances(address _owner) public view returns (bool[16] memory _balances) {
        for (uint256 i = 0; i < BADGE_COUNT; i++) {
            uint256 tokenId = getTokenId(_owner, i);
            _balances[i] = tokenId > 0;
        }

        return _balances;
    }

    /// @notice Retrieve the total S2 unique badge balance of an address
    /// @param _owner The address to check
    /// @return _balance The total badge balance (count)
    function badgeBalanceOf(address _owner) public view returns (uint256 _balance) {
        bool[16] memory balances = badgeBalances(_owner);

        for (uint256 i = 0; i < balances.length; i++) {
            if (balances[i]) {
                _balance++;
            }
        }

        return _balance;
    }

    /// @notice Disable all new migrations
    /// @dev Doesn't allow for new migration attempts, but tampers and active migrations still run
    function _disableMigrations() internal onlyRole(DEFAULT_ADMIN_ROLE) {
        for (uint256 i = 0; i < 8; i++) {
            if (enabledBadgeIds[migrationCycle][i]) {
                emit MigrationToggled(i, false);
            }

            enabledBadgeIds[migrationCycle][i] = false;
        }
    }

    /// @notice Generate a unique hash for each migration uniquely
    /// @param _user The user address
    /// @return _hash The unique hash
    function generateClaimHash(address _user) external view returns (bytes32) {
        if (claimCooldowns[_user] == 0) {
            revert MIGRATION_NOT_STARTED();
        }
        return keccak256(abi.encodePacked(_user, claimCooldowns[_user]));
    }

    /// @notice Generates a random number from a signature
    /// @param _hash The hash to sign (keccak256(startMigrationBlockHash, _msgSender()))
    /// @param v signature V field
    /// @param r signature R field
    /// @param s signature S field
    /// @return _random The pseudo-random number
    function randomFromSignature(
        bytes32 _hash,
        uint8 v,
        bytes32 r,
        bytes32 s
    )
        public
        view
        returns (uint256 _random)
    {
        (address _recovered,,) = ECDSA.tryRecover(_hash, v, r, s);
        if (_recovered != randomSigner) revert NOT_RANDOM_SIGNER();
        // Hash the signature parts to get a deterministic pseudo-random number
        return uint256(keccak256(abi.encodePacked(r, s, v)));
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
}
