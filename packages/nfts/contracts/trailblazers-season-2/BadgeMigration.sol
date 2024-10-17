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
    TrailblazersBadgesV4 public s1Badges;
    TrailblazersBadgesS2 public s2Badges;
    address public randomSigner;
    /*
    /// @notice Time between start and end of a migration
    uint256 public constant COOLDOWN_MIGRATION = 1 minutes; //6 hours;
    /// @notice Time between tamper attempts
    uint256 public constant COOLDOWN_TAMPER = 1 minutes; // 1 hours;
    /// @notice Weight of tamper attempts, in %
    uint256 public constant TAMPER_WEIGHT_PERCENT = 5;
    /// @notice Maximum tamper attempts, per color
    uint256 public constant MAX_TAMPERS = 3;

    */

    /// @notice Migration-enabled badge IDs per cycle
    mapping(uint256 _cycle => mapping(uint256 _s1BadgeId => bool _enabled)) public enabledBadgeIds;

    /// @notice Current migration cycle
    uint256 public migrationCycle;
    /// @notice Mapping of unique user-per-mint-per-cycle
    mapping(
        uint256 _migrationCycle
            => mapping(address _minter => mapping(uint256 _s1BadgeId => bool _mintEnded))
    ) public migrationCycleUniqueMints;

    struct Config {
        uint256 cooldownMigration;
        uint256 cooldownTamper;
        uint256 tamperWeightPercent;
        uint256 maxTampers;
    }

    Config private config;

    struct Migration {
        uint256 migrationCycle;
        address user;
        uint256 s1BadgeId;
        uint256 s1TokenId;
        uint256 s2TokenId;
        uint256 cooldownExpiration;
        uint256 tamperExpiration;
        uint256 pinkTampers;
        uint256 purpleTampers;
    }

    mapping(address _user => Migration[] _migration) public migrations;

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
    error HASH_MISMATCH();

    /// @notice Events
    event MigrationToggled(uint256 indexed _migrationCycleId, uint256 _s1BadgeId, bool _enabled);
    event MigrationStarted(
        address _user, uint256 _s1BadgeId, uint256 _s1TokenId, uint256 _cooldownExpiration
    );
    event MigrationTampered(
        address indexed _user,
        uint256 indexed _s1TokenId,
        bool _pinkOrPurple,
        uint256 _cooldownExpiration
    );
    event MigrationEnded(
        address _user, uint256 _s2BadgeId, uint256 _s2MovementId, uint256 _s2TokenId
    );

    event MigrationTamperReset(address _user);

    /// @notice Modifiers
    modifier isMigrating() {
        Migration memory _migration = getActiveMigrationFor(_msgSender());
        if (_migration.cooldownExpiration == 0) {
            revert MIGRATION_NOT_STARTED();
        }
        _;
    }

    /// @notice Reverts if sender is already migrating
    modifier isNotMigrating() {
        if (
            migrations[_msgSender()].length > 0
                && migrations[_msgSender()][migrations[_msgSender()].length - 1].cooldownExpiration == 0
        ) {
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

    function setConfig(Config memory _config) external onlyRole(DEFAULT_ADMIN_ROLE) {
        config = _config;
    }

    function getConfig() external view returns (Config memory) {
        return config;
    }

    /// @notice Disable all new migrations
    /// @dev Doesn't allow for new migration attempts, but tampers and active migrations still run
    function _disableMigrations() internal onlyRole(DEFAULT_ADMIN_ROLE) {
        for (uint256 i = 0; i < 8; i++) {
            if (enabledBadgeIds[migrationCycle][i]) {
                emit MigrationToggled(migrationCycle, i, false);
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
            emit MigrationToggled(migrationCycle, _s1BadgeIds[i], true);
        }
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
    function startMigration(uint256 _s1BadgeId) external migrationOpen(_s1BadgeId) isNotMigrating 
    //  hasntMigratedInCycle(_s1BadgeId, _msgSender())
    {
        uint256 s1TokenId = s1Badges.getTokenId(_msgSender(), _s1BadgeId);

        if (s1Badges.ownerOf(s1TokenId) != _msgSender()) {
            revert TOKEN_NOT_OWNED();
        }

        Migration memory _migration = Migration(
            migrationCycle, // migrationCycle
            _msgSender(), // user
            _s1BadgeId,
            s1TokenId,
            0, // s2TokenId, unset
            block.timestamp + config.cooldownMigration, // cooldownExpiration
            0, // tamperExpiration, unset
            0, // pinkTampers
            0 // purpleTampers
        );

        migrations[_msgSender()].push(_migration);

        // transfer the badge tokens to the migration contract
        s1Badges.transferFrom(_msgSender(), address(this), s1TokenId);

        emit MigrationStarted(_msgSender(), _s1BadgeId, s1TokenId, _migration.cooldownExpiration);
    }

    function getActiveMigrationFor(address _user) public view returns (Migration memory) {
        if (migrations[_user].length == 0) {
            revert MIGRATION_NOT_STARTED();
        }
        return migrations[_user][migrations[_user].length - 1];
    }

    function _updateMigration(Migration memory _migration) internal virtual {
        migrations[_migration.user][migrations[_migration.user].length - 1] = _migration;
    }

    /// @notice Tamper (alter) the chances during a migration
    /// @param _pinkOrPurple true for pink, false for purple
    /// @dev Can be called only during an active migration
    /// @dev Implements a cooldown before allowing to re-tamper
    /// @dev The max tamper amount is determined by Pass Tier
    function tamperMigration(bool _pinkOrPurple) external isMigrating {
        Migration memory _migration = getActiveMigrationFor(_msgSender());

        if ((_migration.pinkTampers + _migration.purpleTampers) > config.maxTampers * 2) {
            revert MAX_TAMPERS_REACHED();
        }

        if (_migration.tamperExpiration > block.timestamp) {
            revert TAMPER_IN_PROGRESS();
        }

        if (_pinkOrPurple) {
            _migration.pinkTampers++;
        } else {
            _migration.purpleTampers++;
        }

        _migration.tamperExpiration = block.timestamp + config.cooldownTamper;

        // update migration
        _updateMigration(_migration);
        emit MigrationTampered(
            _msgSender(), _migration.s1TokenId, _pinkOrPurple, _migration.tamperExpiration
        );
    }

    /// @notice Reset the tamper counts
    /// @dev Can be called only during an active migration
    function resetTampers() external isMigrating {
        Migration memory _migration = getActiveMigrationFor(_msgSender());
        _migration.pinkTampers = 0;
        _migration.purpleTampers = 0;
        _migration.tamperExpiration = 0;

        _updateMigration(_migration);

        emit MigrationTamperReset(_msgSender());
    }

    /// @notice End a migration
    /// @param _hash The hash to sign
    /// @param v signature V field
    /// @param r signature R field
    /// @param s signature S field
    /// @param exp The user's experience points
    /// @dev Can be called only during an active migration, after the cooldown is over
    /// @dev The final color is determined randomly, and affected by the tamper amounts
    function endMigration(
        bytes32 _hash,
        uint8 v,
        bytes32 r,
        bytes32 s,
        uint256 exp
    )
        external
        isMigrating
    {
        Migration memory _migration = getActiveMigrationFor(_msgSender());

        if (_migration.tamperExpiration > block.timestamp) {
            revert TAMPER_IN_PROGRESS();
        }
        // check if the cooldown is over
        if (_migration.cooldownExpiration > block.timestamp) {
            revert MIGRATION_NOT_READY();
        }

        // ensure the hash corresponds to the start time
        bytes32 calculatedHash = generateClaimHash(_msgSender(), exp);

        if (calculatedHash != _hash) {
            revert HASH_MISMATCH();
        }

        // get the tamper amounts
        uint256 pinkTampers = _migration.pinkTampers;
        uint256 purpleTampers = _migration.purpleTampers;

        uint256 randomSeed = randomFromSignature(_hash, v, r, s);
        bool isPinkOrPurple;
        // Calculate the difference in tampers and adjust chances
        if (pinkTampers > purpleTampers) {
            uint256 extraChance = (pinkTampers - purpleTampers) * config.tamperWeightPercent;
            uint256 chance = 50 + extraChance; // Base 50% + extra chance
            isPinkOrPurple = (randomSeed % 100) < chance; // True for pink
        } else if (purpleTampers > pinkTampers) {
            uint256 extraChance = (purpleTampers - pinkTampers) * config.tamperWeightPercent;
            uint256 chance = 50 + extraChance; // Base 50% + extra chance
            isPinkOrPurple = (randomSeed % 100) >= chance; // False for purple
        } else {
            // Equal number of pink and purple tampers, 50/50 chance
            isPinkOrPurple = (randomSeed % 100) < 50;
        }

        uint256 s1BadgeId = _migration.s1BadgeId;
        uint256 s1TokenId = _migration.s1TokenId;
        s1Badges.burn(s1TokenId);

        TrailblazersBadgesS2.MovementType pinkOrPurple = isPinkOrPurple
            ? TrailblazersBadgesS2.MovementType.Minnow
            : TrailblazersBadgesS2.MovementType.Whale;

        // mint the badge
        s2Badges.mint(_msgSender(), TrailblazersBadgesS2.BadgeType(s1BadgeId), pinkOrPurple);

        uint256 s2TokenId = s2Badges.totalSupply();

        _migration.s2TokenId = s2TokenId;
        _migration.cooldownExpiration = 0;
        _migration.tamperExpiration = 0;

        _updateMigration(_migration);

        emit MigrationEnded(_msgSender(), s1BadgeId, uint256(pinkOrPurple), s2TokenId);
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
        Migration memory _migration = getActiveMigrationFor(_user);
        return _migration.cooldownExpiration != 0;
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

    /// @notice Check if a tamper is active for a user
    /// @param _user The user address
    /// @return Whether the user has an active tamper
    function isTamperActive(address _user) public view returns (bool) {
        Migration memory _migration = getActiveMigrationFor(_user);
        return _migration.tamperExpiration > block.timestamp;
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
        Migration memory _migration = getActiveMigrationFor(_user);
        return (_migration.pinkTampers, _migration.purpleTampers);
    }

    /// @notice supportsInterface implementation
    /// @param interfaceId The interface ID
    /// @return Whether the interface is supported
    function supportsInterface(bytes4 interfaceId) public view override returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    /// @notice Internal method to authorize an upgrade
    function _authorizeUpgrade(address) internal virtual override onlyOwner { }
}
