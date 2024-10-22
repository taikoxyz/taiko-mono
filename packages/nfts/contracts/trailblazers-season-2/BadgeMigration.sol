// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts-upgradeable/token/ERC1155/extensions/ERC1155SupplyUpgradeable.sol";
import "../trailblazers-badges/ECDSAWhitelist.sol";
import "@taiko/blacklist/IMinimalBlacklist.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
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
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import "./TrailblazersS1BadgesV4.sol";
import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "./TrailblazersBadgesS2.sol";

contract BadgeMigration is
    PausableUpgradeable,
    UUPSUpgradeable,
    Ownable2StepUpgradeable,
    AccessControlUpgradeable,
    ERC721HolderUpgradeable
{
    /// @notice Season 1 Badges ERC721 contract
    TrailblazersBadgesV4 public s1Badges;
    /// @notice Season 2 Badges ERC1155 contract
    TrailblazersBadgesS2 public s2Badges;
    /// @notice Wallet authorized to sign as a source of randomness
    address public randomSigner;
    /// @notice Migration-enabled badge IDs per cycle
    mapping(uint256 cycle => mapping(uint256 s1BadgeId => bool enabled)) public enabledBadgeIds;
    /// @notice Current migration cycle
    uint256 private migrationCycle;
    /// @notice Mapping of unique user-per-mint-per-cycle
    mapping(
        uint256 migrationCycle
            => mapping(address minter => mapping(uint256 s1BadgeId => bool mintEnded))
    ) public migrationCycleUniqueMints;

    enum TamperColor {
        Dev, // neutral
        Whale, // based, pink
        Minnow // boosted, purple

    }

    /// @notice Configuration struct
    struct Config {
        uint256 cooldownMigration;
        uint256 cooldownTamper;
        uint256 tamperWeightPercent;
        uint256 baseMaxTampers;
    }
    /// @notice Current config

    Config private config;
    /// @notice Migration struct

    struct Migration {
        uint256 migrationCycle;
        address user;
        uint256 s1BadgeId;
        uint256 s1TokenId;
        uint256 s2TokenId;
        uint256 cooldownExpiration;
        uint256 tamperExpiration;
        uint256 devTampers;
        uint256 whaleTampers;
        uint256 minnowTampers;
    }
    /// @notice Migrations per user

    mapping(address _user => Migration[] _migration) public migrations;
    /// @notice Gap for upgrade safety
    uint256[43] private __gap;
    /// @notice Errors

    error MAX_TAMPERS_REACHED();
    error MIGRATION_NOT_STARTED();
    error MIGRATION_ALREADY_STARTED();
    error TAMPER_IN_PROGRESS();
    error MIGRATION_NOT_READY();
    error MIGRATION_NOT_ENABLED();
    error TOKEN_NOT_OWNED();
    error NOT_RANDOM_SIGNER();
    error ALREADY_MIGRATED_IN_CYCLE();
    error HASH_MISMATCH();
    error NOT_S1_CONTRACT();

    /// @notice Events
    event MigrationCycleToggled(uint256 indexed migrationCycleId, uint256 s1BadgeId, bool enabled);

    event MigrationUpdated(
        uint256 indexed migrationCycle,
        address indexed user,
        uint256 s1BadgeId,
        uint256 s1TokenId,
        uint256 s2TokenId,
        uint256 cooldownExpiration,
        uint256 tamperExpiration,
        uint256 devTampers,
        uint256 whaleTampers,
        uint256 minnowTampers
    );

    /// @notice Check if the message sender has an active migration
    modifier isMigrating() {
        Migration memory migration_ = getActiveMigrationFor(_msgSender());
        if (migration_.cooldownExpiration == 0) {
            revert MIGRATION_NOT_STARTED();
        }
        _;
    }

    /// @notice Reverts if sender is already migrating
    modifier isNotMigrating(address _user) {
        if (
            migrations[_user].length > 0
                && migrations[_user][migrations[_user].length - 1].cooldownExpiration == 0
        ) {
            revert MIGRATION_ALREADY_STARTED();
        }
        _;
    }

    /// @notice Reverts if migrations aren't enabled for that badge
    /// @param _s1BadgeId The badge ID
    modifier migrationOpen(uint256 _s1BadgeId) {
        if (!enabledBadgeIds[migrationCycle][_s1BadgeId]) {
            revert MIGRATION_NOT_ENABLED();
        }
        _;
    }

    /// @notice Limits migrations to one per user, badge and cycle
    /// @param _s1BadgeId The badge ID
    /// @param _minter The minter address
    modifier hasntMigratedInCycle(uint256 _s1BadgeId, address _minter) {
        // check that the minter hasn't used the migration within this cycle
        if (migrationCycleUniqueMints[migrationCycle][_minter][_s1BadgeId]) {
            revert ALREADY_MIGRATED_IN_CYCLE();
        }
        _;
    }

    modifier onlyS1Contract() {
        if (_msgSender() != address(s1Badges)) {
            revert NOT_S1_CONTRACT();
        }
        _;
    }

    /// @notice Contract initializer
    /// @param _s1Badges The Season 1 Badges contract address
    /// @param _s2Badges The Season 2 Badges contract address
    /// @param _randomSigner The random signer address
    /// @param _config The initial configuration
    function initialize(
        address _s1Badges,
        address _s2Badges,
        address _randomSigner,
        Config memory _config
    )
        external
        initializer
    {
        _transferOwnership(_msgSender());
        __Context_init();
        _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());
        s1Badges = TrailblazersBadgesV4(_s1Badges);
        s2Badges = TrailblazersBadgesS2(_s2Badges);
        randomSigner = _randomSigner;
        config = _config;
    }

    /// @notice Upgrade configuration
    /// @param _config The new configuration
    function setConfig(Config memory _config) external onlyRole(DEFAULT_ADMIN_ROLE) {
        config = _config;
    }

    /// @notice Get the current configuration
    /// @return The current configuration
    function getConfig() external view returns (Config memory) {
        return config;
    }

    /// @notice Disable all new migrations
    /// @dev Doesn't allow for new migration attempts, but tampers and active migrations still run
    function _disableMigrations() internal onlyRole(DEFAULT_ADMIN_ROLE) {
        for (uint256 i = 0; i < 8; i++) {
            if (enabledBadgeIds[migrationCycle][i]) {
                emit MigrationCycleToggled(migrationCycle, i, false);
            }

            enabledBadgeIds[migrationCycle][i] = false;
        }
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
            emit MigrationCycleToggled(migrationCycle, _s1BadgeIds[i], true);
        }
    }

    /// @notice Get the current migration cycle
    /// @return The current migration cycle
    function getMigrationCycle() external view returns (uint256) {
        return migrationCycle;
    }

    /// @notice Pause the contract
    /// @dev Can be called only by the contract owner/admin
    function pause() public onlyRole(DEFAULT_ADMIN_ROLE) {
        _disableMigrations();
        _pause();
    }

    /// @notice Start a migration for a badge
    /// @param _s1BadgeId The badge ID (s1)
    /// @dev Not all badges are eligible for migration at the same time
    /// @dev Defines a cooldown for the migration to be complete
    /// @dev the cooldown is lesser the higher the Pass Tier
    /// @dev Must be called from the s1 badges contract
    function startMigration(
        address _user,
        uint256 _s1BadgeId
    )
        external
        onlyS1Contract
        migrationOpen(_s1BadgeId)
        isNotMigrating(_user)
        hasntMigratedInCycle(_s1BadgeId, _user)
    {
        uint256 s1TokenId = s1Badges.getTokenId(_user, _s1BadgeId);

        if (s1Badges.ownerOf(s1TokenId) != _user) {
            revert TOKEN_NOT_OWNED();
        }

        Migration memory _migration = Migration(
            migrationCycle, // migrationCycle
            _user, // user
            _s1BadgeId,
            s1TokenId,
            0, // s2TokenId, unset
            block.timestamp + config.cooldownMigration, // cooldownExpiration
            0, // tamperExpiration, unset
            0, // dev tampers
            0, // whaleTampers
            0 // minnowTampers
        );

        migrations[_user].push(_migration);
        migrationCycleUniqueMints[migrationCycle][_user][_s1BadgeId] = true;

        emit MigrationUpdated(
            _migration.migrationCycle,
            _migration.user,
            _migration.s1BadgeId,
            _migration.s1TokenId,
            _migration.s2TokenId,
            _migration.cooldownExpiration,
            _migration.tamperExpiration,
            _migration.devTampers,
            _migration.whaleTampers,
            _migration.minnowTampers
        );
    }

    /// @notice Get the active migration for a user
    /// @param _user The user address
    /// @return The active migration
    function getActiveMigrationFor(address _user) public view returns (Migration memory) {
        if (migrations[_user].length == 0) {
            revert MIGRATION_NOT_STARTED();
        }
        return migrations[_user][migrations[_user].length - 1];
    }

    /// @notice Update a migration
    /// @param _migration The updated migration
    function _updateMigration(Migration memory _migration) internal virtual {
        migrations[_migration.user][migrations[_migration.user].length - 1] = _migration;

        emit MigrationUpdated(
            _migration.migrationCycle,
            _migration.user,
            _migration.s1BadgeId,
            _migration.s1TokenId,
            _migration.s2TokenId,
            _migration.cooldownExpiration,
            _migration.tamperExpiration,
            _migration.devTampers,
            _migration.whaleTampers,
            _migration.minnowTampers
        );
    }

    /// @notice Get the maximum number of tampers for a given experience
    /// @param _exp The user's experience points
    function maxTampers(uint256 _exp) public view virtual returns (uint256 value) {
        value = _exp / 100;
        value += 2 * config.baseMaxTampers;
        return value;
    }

    /// @notice Tamper (alter) the chances during a migration
    /// @param _hash The hash to sign
    /// @param v signature V field
    /// @param r signature R field
    /// @param s signature S field
    /// @param _tamperColor the tamper's color
    /// @dev Can be called only during an active migration
    /// @dev Implements a cooldown before allowing to re-tamper
    /// @dev The max tamper amount is determined by Pass Tier
    function tamperMigration(
        bytes32 _hash,
        uint8 v,
        bytes32 r,
        bytes32 s,
        uint256 exp,
        TamperColor _tamperColor
    )
        external
        isMigrating
    {
        (address recovered_,,) = ECDSA.tryRecover(_hash, v, r, s);
        if (recovered_ != randomSigner) revert NOT_RANDOM_SIGNER();
        Migration memory migration_ = getActiveMigrationFor(_msgSender());

        if ((migration_.whaleTampers + migration_.minnowTampers) > maxTampers(exp)) {
            revert MAX_TAMPERS_REACHED();
        }

        if (migration_.tamperExpiration > block.timestamp) {
            revert TAMPER_IN_PROGRESS();
        }

        if (_tamperColor == TamperColor.Dev) {
            migration_.devTampers++;
        } else if (_tamperColor == TamperColor.Whale) {
            migration_.whaleTampers++;
        } else {
            migration_.minnowTampers++;
        }

        migration_.tamperExpiration = block.timestamp + config.cooldownTamper;

        _updateMigration(migration_);
    }

    /// @notice Reset the tamper counts
    /// @dev Can be called only during an active migration
    function resetTampers() external isMigrating {
        Migration memory migration_ = getActiveMigrationFor(_msgSender());
        migration_.whaleTampers = 0;
        migration_.minnowTampers = 0;
        migration_.tamperExpiration = 0;

        _updateMigration(migration_);
    }

    /// @notice End a migration
    /// @param _hash The hash to sign
    /// @param _v signature V field
    /// @param _r signature R field
    /// @param _s signature S field
    /// @param _exp The user's experience points
    /// @dev Can be called only during an active migration, after the cooldown is over
    /// @dev The final color is determined randomly, and affected by the tamper amounts
    function endMigration(
        bytes32 _hash,
        uint8 _v,
        bytes32 _r,
        bytes32 _s,
        uint256 _exp
    )
        external
        isMigrating
    {
        Migration memory migration_ = getActiveMigrationFor(_msgSender());

        if (migration_.tamperExpiration > block.timestamp) {
            revert TAMPER_IN_PROGRESS();
        }
        // check if the cooldown is over
        if (migration_.cooldownExpiration > block.timestamp) {
            revert MIGRATION_NOT_READY();
        }
        // ensure the hash corresponds to the start time
        bytes32 calculatedHash_ = generateClaimHash(_msgSender(), _exp);

        if (calculatedHash_ != _hash) {
            revert HASH_MISMATCH();
        }

        // get the tamper amounts
        uint256 whaleTampers_ = migration_.whaleTampers;
        uint256 minnowTampers_ = migration_.minnowTampers;

        uint256 randomSeed_ = randomFromSignature(_hash, _v, _r, _s);
        bool isPinkOrPurple_;
        // Calculate the difference in tampers and adjust chances
        if (whaleTampers_ > minnowTampers_) {
            uint256 extraChance = (whaleTampers_ - minnowTampers_) * config.tamperWeightPercent;
            uint256 chance = 50 + extraChance; // Base 50% + extra chance
            isPinkOrPurple_ = (randomSeed_ % 100) < chance; // True for pink
        } else if (minnowTampers_ > whaleTampers_) {
            uint256 extraChance = (minnowTampers_ - whaleTampers_) * config.tamperWeightPercent;
            uint256 chance = 50 + extraChance; // Base 50% + extra chance
            isPinkOrPurple_ = (randomSeed_ % 100) >= chance; // False for purple
        } else {
            // Equal number of pink and purple tampers, 50/50 chance
            isPinkOrPurple_ = (randomSeed_ % 100) < 50;
        }

        uint256 s1BadgeId_ = migration_.s1BadgeId;

        TrailblazersBadgesS2.MovementType pinkOrPurple = isPinkOrPurple_
            ? TrailblazersBadgesS2.MovementType.Minnow
            : TrailblazersBadgesS2.MovementType.Whale;

        // mint the badge
        s2Badges.mint(_msgSender(), TrailblazersBadgesS2.BadgeType(s1BadgeId_), pinkOrPurple);
        uint256 s2TokenId_ = s2Badges.totalSupply();

        migration_.s2TokenId = s2TokenId_;
        migration_.cooldownExpiration = 0;
        migration_.tamperExpiration = 0;

        _updateMigration(migration_);
    }

    /// @notice Generate a unique hash for each migration uniquely
    /// @param _user The user address
    /// @param _exp The users experience points
    /// @return _hash The unique hash
    function generateClaimHash(address _user, uint256 _exp) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(_user, _exp));
    }

    /// @notice Check if a migration is active for a user
    /// @param _user The user address
    /// @return Whether the user has an active migration
    function isMigrationActive(address _user) public view returns (bool) {
        if (migrations[_user].length == 0) {
            return false;
        }
        Migration memory migration_ = getActiveMigrationFor(_user);
        return migration_.cooldownExpiration != 0;
    }

    /// @notice Generates a random number from a signature
    /// @param _hash The hash to sign
    /// @param _v signature V field
    /// @param _r signature R field
    /// @param _s signature S field
    /// @return _random The pseudo-random number
    function randomFromSignature(
        bytes32 _hash,
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    )
        public
        view
        returns (uint256 _random)
    {
        (address recovered_,,) = ECDSA.tryRecover(_hash, _v, _r, _s);
        if (recovered_ != randomSigner) revert NOT_RANDOM_SIGNER();
        return uint256(keccak256(abi.encodePacked(_r, _s, _v)));
    }

    /// @notice Check if a tamper is active for a user
    /// @param _user The user address
    /// @return Whether the user has an active tamper
    function isTamperActive(address _user) public view returns (bool) {
        Migration memory migration_ = getActiveMigrationFor(_user);
        return migration_.tamperExpiration > block.timestamp;
    }

    /// @notice Get the migration tamper counts for a user
    /// @param _user The user address
    /// @return _devTampers The Dev tamper count
    /// @return _whaleTampers The Whale tamper count
    /// @return _minnowTampers The Minnow tamper count
    function getMigrationTampers(address _user)
        public
        view
        returns (uint256 _devTampers, uint256 _whaleTampers, uint256 _minnowTampers)
    {
        if (!isMigrationActive(_user)) {
            revert MIGRATION_NOT_STARTED();
        }
        Migration memory migration_ = getActiveMigrationFor(_user);
        return (migration_.devTampers, migration_.whaleTampers, migration_.minnowTampers);
    }

    /// @notice supportsInterface implementation
    /// @param _interfaceId The interface ID
    /// @return Whether the interface is supported
    function supportsInterface(bytes4 _interfaceId) public view override returns (bool) {
        return super.supportsInterface(_interfaceId);
    }

    /// @notice Internal method to authorize an upgrade
    function _authorizeUpgrade(address) internal virtual override onlyOwner { }
}
