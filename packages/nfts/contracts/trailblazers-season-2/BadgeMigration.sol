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
    /// @notice badges role key
    bytes32 public constant S1_BADGES_ROLE = keccak256("S1_BADGES_ROLE");
    /// @notice Season 2 Badges ERC1155 contract
    TrailblazersBadgesS2 public s2Badges;
    /// @notice Wallet authorized to sign as a source of randomness
    address public randomSigner;
    /// @notice Migration-enabled badge IDs per cycle
    mapping(uint256 cycle => mapping(uint256 s1BadgeId => bool enabled)) public enabledBadgeIds;
    uint256[] public currentCycleEnabledMigrationIds;
    /// @notice Current migration cycle
    uint256 private migrationCycle;
    /// @notice Mapping of unique user-per-mint-per-cycle
    mapping(
        uint256 migrationCycle
            => mapping(address minter => mapping(uint256 s1BadgeId => bool mintEnded))
    ) public migrationCycleUniqueMints;
    /// @notice User experience points
    mapping(address user => uint256 experience) public userExperience;
    /// @notice Tamper colors available

    enum TamperColor {
        Undefined, // unused
        Whale, // based, pink
        Minnow // boosted, purple

    }

    /// @notice Configuration struct
    struct Config {
        uint256 cooldownMigration;
        uint256 cooldownTamper;
        uint256 tamperWeightPercent;
        uint256 baseMaxTampers;
        uint256 pointsClaimMultiplicationFactor;
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
    error EXP_TOO_LOW();
    error INVALID_TAMPER_COLOR();
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
        uint256 whaleTampers,
        uint256 minnowTampers
    );

    event MigrationComplete(
        uint256 indexed migrationCycle,
        address indexed user,
        uint256 s1TokenId,
        uint256 s2TokenId,
        uint256 finalColor
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
                && migrations[_user][migrations[_user].length - 1].cooldownExpiration > block.timestamp
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
        _grantRole(S1_BADGES_ROLE, _s1Badges);
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
        currentCycleEnabledMigrationIds = new uint256[](0);
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
        currentCycleEnabledMigrationIds = _s1BadgeIds;
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

    /// @notice Internal logic to start a migration
    /// @param _user The user address
    /// @param _s1BadgeId The badge ID
    /// @param _s1TokenId The badge token ID
    function _startMigration(
        address _user,
        uint256 _s1BadgeId,
        uint256 _s1TokenId
    )
        internal
        virtual
    {
        Migration memory _migration = Migration(
            migrationCycle, // migrationCycle
            _user, // user
            _s1BadgeId,
            _s1TokenId,
            0, // s2TokenId, unset
            block.timestamp + config.cooldownMigration, // cooldownExpiration
            0, // tamperExpiration, unset
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
            _migration.whaleTampers,
            _migration.minnowTampers
        );
    }

    /// @notice Start a migration for a badge using the user's experience points
    /// @param _hash The hash to sign of the signature
    /// @param _v The signature V field
    /// @param _r The signature R field
    /// @param _s The signature S field
    /// @param _exp The user's experience points
    function startMigration(
        bytes32 _hash,
        uint8 _v,
        bytes32 _r,
        bytes32 _s,
        uint256 _exp
    )
        external
        virtual
        isNotMigrating(_msgSender())
    {
        bytes32 calculatedHash_ = generateClaimHash(_msgSender(), _exp);

        if (calculatedHash_ != _hash) {
            revert HASH_MISMATCH();
        }

        (address recovered_,,) = ECDSA.tryRecover(_hash, _v, _r, _s);
        if (recovered_ != randomSigner) {
            revert NOT_RANDOM_SIGNER();
        }

        if (_exp < userExperience[_msgSender()]) {
            revert EXP_TOO_LOW();
        }

        userExperience[_msgSender()] = _exp;

        uint256 randomSeed_ = randomFromSignature(_hash, _v, _r, _s);
        uint256 s1BadgeId_ =
            currentCycleEnabledMigrationIds[randomSeed_ % currentCycleEnabledMigrationIds.length];

        if (migrationCycleUniqueMints[migrationCycle][_msgSender()][s1BadgeId_]) {
            revert ALREADY_MIGRATED_IN_CYCLE();
        }

        _startMigration(_msgSender(), (randomSeed_ % 8), 0);
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
        virtual
        onlyRole(S1_BADGES_ROLE)
        migrationOpen(_s1BadgeId)
        isNotMigrating(_user)
        hasntMigratedInCycle(_s1BadgeId, _user)
    {
        uint256 s1TokenId_ = s1Badges.getTokenId(_user, _s1BadgeId);

        if (s1Badges.ownerOf(s1TokenId_) != _user) {
            revert TOKEN_NOT_OWNED();
        }
        _startMigration(_user, _s1BadgeId, s1TokenId_);
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

        if (_tamperColor == TamperColor.Whale) {
            migration_.whaleTampers++;
        } else if (_tamperColor == TamperColor.Minnow) {
            migration_.minnowTampers++;
        } else {
            revert INVALID_TAMPER_COLOR();
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

        uint256 randomSeed_ = randomFromSignature(_hash, _v, _r, _s);

        uint256 whaleWeight_ = 50 + migration_.whaleTampers * config.tamperWeightPercent;
        uint256 minnowWeight_ = 50 + migration_.minnowTampers * config.tamperWeightPercent;

        uint256 totalWeight_ = whaleWeight_ + minnowWeight_;

        uint256 randomValue = randomSeed_ % totalWeight_;

        TrailblazersBadgesS2.MovementType finalColor_;
        if (randomValue < minnowWeight_) {
            finalColor_ = TrailblazersBadgesS2.MovementType.Minnow;
        } else {
            finalColor_ = TrailblazersBadgesS2.MovementType.Whale;
        }

        uint256 s1BadgeId_ = migration_.s1BadgeId;

        // mint the badge
        s2Badges.mint(_msgSender(), TrailblazersBadgesS2.BadgeType(s1BadgeId_), finalColor_);
        uint256 s2TokenId_ = s2Badges.totalSupply();

        migration_.s2TokenId = s2TokenId_;
        migration_.cooldownExpiration = 0;
        migration_.tamperExpiration = 0;

        _updateMigration(migration_);

        emit MigrationComplete(
            migration_.migrationCycle,
            migration_.user,
            migration_.s1TokenId,
            migration_.s2TokenId,
            uint256(finalColor_)
        );
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
    /// @return _whaleTampers The Whale tamper count
    /// @return _minnowTampers The Minnow tamper count
    function getMigrationTampers(address _user)
        public
        view
        returns (uint256 _whaleTampers, uint256 _minnowTampers)
    {
        if (!isMigrationActive(_user)) {
            revert MIGRATION_NOT_STARTED();
        }
        Migration memory migration_ = getActiveMigrationFor(_user);
        return (migration_.whaleTampers, migration_.minnowTampers);
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
