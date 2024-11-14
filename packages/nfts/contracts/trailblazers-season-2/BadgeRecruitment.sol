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

contract BadgeRecruitment is
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
    /// @notice Recruitment-enabled badge IDs per cycle
    //mapping(uint256 cycle => mapping(uint256 s1BadgeId => bool enabled)) public enabledBadgeIds;
    // uint256[] public currentCycleEnabledRecruitmentIds;
    /// @notice Current recruitment cycle
    uint256 public recruitmentCycleId;

    /// @notice Mapping of unique user-per-mint-per-cycle
    mapping(
        uint256 recruitmentCycle
            => mapping(
                address minter
                    => mapping(
                        uint256 s1BadgeId
                            => mapping(RecruitmentType recruitmentType => bool mintEnded)
                    )
            )
    ) public recruitmentCycleUniqueMints;
    /// @notice User experience points

    mapping(address user => uint256 experience) public userExperience;
    /// @notice Influence colors available

    enum InfluenceColor {
        Undefined, // unused
        Whale, // based, pink
        Minnow // boosted, purple

    }

    /// @notice Recruitment types
    enum RecruitmentType {
        Undefined,
        Claim,
        Migration
    }
    /// @notice Hash types
    enum HashType {
        Undefined,
        Start,
        End,
        Influence
    }

    /// @notice Configuration struct
    struct Config {
        uint256 cooldownRecruitment;
        uint256 cooldownInfluence;
        uint256 influenceWeightPercent;
        uint256 baseMaxInfluences;
        uint256 maxInfluencesDivider;
        uint256 defaultCycleDuration;
    }
    /// @notice Current config

    Config private config;
    /// @notice Recruitment struct

    struct Recruitment {
        uint256 recruitmentCycle;
        address user;
        uint256 s1BadgeId;
        uint256 s1TokenId;
        uint256 s2TokenId;
        uint256 cooldownExpiration;
        uint256 influenceExpiration;
        uint256 whaleInfluences;
        uint256 minnowInfluences;
    }
    /// @notice Recruitment Cycle struct

    struct RecruitmentCycle {
        uint256 cycleId;
        uint256 startTime;
        uint256 endTime;
        uint256[] s1BadgeIds;
    }

    /// @notice Recruitment cycles
    mapping(uint256 cycleId => RecruitmentCycle recruitmentCycle) public recruitmentCycles;

    /// @notice Recruitments per user

    mapping(address _user => Recruitment[] _recruitment) public recruitments;
    /// @notice Gap for upgrade safety
    uint256[43] private __gap;
    /// @notice Errors

    error MAX_INFLUENCES_REACHED();
    error RECRUITMENT_NOT_STARTED();
    error RECRUITMENT_ALREADY_STARTED();
    error INFLUENCE_IN_PROGRESS();
    error RECRUITMENT_NOT_READY();
    error RECRUITMENT_NOT_ENABLED();
    error TOKEN_NOT_OWNED();
    error NOT_RANDOM_SIGNER();
    error ALREADY_MIGRATED_IN_CYCLE();
    error HASH_MISMATCH();
    error NOT_S1_CONTRACT();
    error EXP_TOO_LOW();
    error INVALID_INFLUENCE_COLOR();
    error CURRENT_CYCLE_NOT_OVER();
    /// @notice Events

    event RecruitmentCycleToggled(
        uint256 indexed recruitmentCycleId,
        uint256 indexed startTime,
        uint256 indexed endTime,
        uint256[] s1BadgeIds,
        bool enabled
    );

    event RecruitmentUpdated(
        uint256 indexed recruitmentCycle,
        address indexed user,
        uint256 s1BadgeId,
        uint256 s1TokenId,
        uint256 s2TokenId,
        uint256 cooldownExpiration,
        uint256 influenceExpiration,
        uint256 whaleInfluences,
        uint256 minnowInfluences
    );

    event RecruitmentComplete(
        uint256 indexed recruitmentCycle,
        address indexed user,
        uint256 s1TokenId,
        uint256 s2TokenId,
        uint256 finalColor
    );

    /// @notice Check if the message sender has an active recruitment
    modifier isMigrating() {
        Recruitment memory recruitment_ = getActiveRecruitmentFor(_msgSender());
        if (recruitment_.cooldownExpiration == 0) {
            revert RECRUITMENT_NOT_STARTED();
        }
        _;
    }

    /// @notice Reverts if sender is already migrating
    modifier isNotMigrating(address _user) {
        if (
            recruitments[_user].length > 0
                && recruitments[_user][recruitments[_user].length - 1].cooldownExpiration
                    > block.timestamp
        ) {
            revert RECRUITMENT_ALREADY_STARTED();
        }
        _;
    }

    /// @notice Reverts if recruitments aren't enabled for that badge
    /// @param _s1BadgeId The badge ID
    modifier recruitmentOpen(uint256 _s1BadgeId) {
        RecruitmentCycle memory cycle_ = recruitmentCycles[recruitmentCycleId];

        if (cycle_.startTime > block.timestamp || cycle_.endTime < block.timestamp) {
            revert RECRUITMENT_NOT_ENABLED();
        }

        bool found_ = false;

        for (uint256 i = 0; i < cycle_.s1BadgeIds.length; i++) {
            if (cycle_.s1BadgeIds[i] == _s1BadgeId) {
                found_ = true;
                break;
            }
        }

        if (!found_) {
            revert RECRUITMENT_NOT_ENABLED();
        }
        _;
    }

    /// @notice Limits recruitments to one per user, badge and cycle
    /// @param _s1BadgeId The badge ID
    /// @param _minter The minter address
    /// @param _recruitmentType The recruitment type
    modifier hasntMigratedInCycle(
        uint256 _s1BadgeId,
        address _minter,
        RecruitmentType _recruitmentType
    ) {
        // check that the minter hasn't used the recruitment within this cycle
        if (recruitmentCycleUniqueMints[recruitmentCycleId][_minter][_s1BadgeId][_recruitmentType])
        {
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

    /// @notice Disable all current recruitments
    /// @dev Bypasses the default date checks
    function forceDisableRecruitments() internal onlyRole(DEFAULT_ADMIN_ROLE) {
        recruitmentCycles[recruitmentCycleId].endTime = block.timestamp;
    }

    /// @notice Enable recruitments for a set of badges
    /// @param _startTime The start time of the recruitment cycle
    /// @param _endTime The end time of the recruitment cycle
    /// @param _s1BadgeIds The badge IDs to enable
    function _enableRecruitments(
        uint256 _startTime,
        uint256 _endTime,
        uint256[] calldata _s1BadgeIds
    )
        internal
    {
        if (
            recruitmentCycleId > 0
                && recruitmentCycles[recruitmentCycleId].endTime > block.timestamp
        ) {
            revert CURRENT_CYCLE_NOT_OVER();
        }
        // emit disabled badges
        emit RecruitmentCycleToggled(
            recruitmentCycleId,
            recruitmentCycles[recruitmentCycleId].startTime,
            recruitmentCycles[recruitmentCycleId].endTime,
            recruitmentCycles[recruitmentCycleId].s1BadgeIds,
            false
        );

        recruitmentCycleId++;
        recruitmentCycles[recruitmentCycleId] =
            RecruitmentCycle(recruitmentCycleId, _startTime, _endTime, _s1BadgeIds);

        // emit enabled badges
        emit RecruitmentCycleToggled(recruitmentCycleId, _startTime, _endTime, _s1BadgeIds, true);
    }

    /// @notice Enable recruitments for a set of badges
    /// @param _s1BadgeIds The badge IDs to enable
    /// @dev Can be called only by the contract owner/admin
    function enableRecruitments(uint256[] calldata _s1BadgeIds)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        _enableRecruitments(
            block.timestamp, block.timestamp + config.defaultCycleDuration, _s1BadgeIds
        );
    }

    /// @notice Enable recruitments for a set of badges
    /// @param _startTime The start time of the recruitment cycle
    /// @param _endTime The end time of the recruitment cycle
    /// @param _s1BadgeIds The badge IDs to enable
    /// @dev Can be called only by the contract owner/admin
    function enableRecruitments(
        uint256 _startTime,
        uint256 _endTime,
        uint256[] calldata _s1BadgeIds
    )
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        _enableRecruitments(_startTime, _endTime, _s1BadgeIds);
    }

    /// @notice Get the current recruitment cycle
    /// @return The current recruitment cycle
    function getRecruitmentCycle(uint256 _cycleId)
        external
        view
        returns (RecruitmentCycle memory)
    {
        return recruitmentCycles[_cycleId];
    }

    /// @notice Internal logic to start a recruitment
    /// @param _user The user address
    /// @param _s1BadgeId The badge ID
    /// @param _s1TokenId The badge token ID
    /// @param _recruitmentType The recruitment type
    function _startRecruitment(
        address _user,
        uint256 _s1BadgeId,
        uint256 _s1TokenId,
        RecruitmentType _recruitmentType
    )
        internal
        virtual
    {
        Recruitment memory _recruitment = Recruitment(
            recruitmentCycleId, // recruitmentCycle
            _user, // user
            _s1BadgeId,
            _s1TokenId,
            0, // s2TokenId, unset
            block.timestamp + config.cooldownRecruitment, // cooldownExpiration
            0, // influenceExpiration, unset
            0, // whaleInfluences
            0 // minnowInfluences
        );

        recruitments[_user].push(_recruitment);
        recruitmentCycleUniqueMints[recruitmentCycleId][_user][_s1BadgeId][_recruitmentType] = true;

        emit RecruitmentUpdated(
            _recruitment.recruitmentCycle,
            _recruitment.user,
            _recruitment.s1BadgeId,
            _recruitment.s1TokenId,
            _recruitment.s2TokenId,
            _recruitment.cooldownExpiration,
            _recruitment.influenceExpiration,
            _recruitment.whaleInfluences,
            _recruitment.minnowInfluences
        );
    }

    /// @notice Start a recruitment for a badge using the user's experience points
    /// @param _hash The hash to sign of the signature
    /// @param _v The signature V field
    /// @param _r The signature R field
    /// @param _s The signature S field
    /// @param _exp The user's experience points
    function startRecruitment(
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
        bytes32 calculatedHash_ = generateClaimHash(HashType.Start, _msgSender(), _exp);

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

        RecruitmentCycle memory cycle_ = recruitmentCycles[recruitmentCycleId];
        if (cycle_.startTime > block.timestamp || cycle_.endTime < block.timestamp) {
            revert RECRUITMENT_NOT_ENABLED();
        }
        uint256 randomSeed_ = randomFromSignature(_hash, _v, _r, _s);
        uint256 s1BadgeId_ = cycle_.s1BadgeIds[randomSeed_ % cycle_.s1BadgeIds.length];

        if (
            recruitmentCycleUniqueMints[recruitmentCycleId][_msgSender()][s1BadgeId_][RecruitmentType
                .Claim]
        ) {
            revert ALREADY_MIGRATED_IN_CYCLE();
        }

        _startRecruitment(_msgSender(), s1BadgeId_, 0, RecruitmentType.Claim);
    }

    /// @notice Start a recruitment for a badge using the user's experience points
    /// @param _hash The hash to sign of the signature
    /// @param _v The signature V field
    /// @param _r The signature R field
    /// @param _s The signature S field
    /// @param _exp The user's experience points
    /// @param _s1BadgeId The badge ID (s1)
    function startRecruitment(
        bytes32 _hash,
        uint8 _v,
        bytes32 _r,
        bytes32 _s,
        uint256 _exp,
        uint256 _s1BadgeId
    )
        external
        virtual
        isNotMigrating(_msgSender())
        recruitmentOpen(_s1BadgeId)
        hasntMigratedInCycle(_s1BadgeId, _msgSender(), RecruitmentType.Claim)
    {
        bytes32 calculatedHash_ = generateClaimHash(HashType.Start, _msgSender(), _s1BadgeId);

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

        _startRecruitment(_msgSender(), _s1BadgeId, 0, RecruitmentType.Claim);
    }

    /// @notice Start a recruitment for a badge
    /// @param _s1BadgeId The badge ID (s1)
    /// @dev Not all badges are eligible for recruitment at the same time
    /// @dev Defines a cooldown for the recruitment to be complete
    /// @dev the cooldown is lesser the higher the Pass Tier
    /// @dev Must be called from the s1 badges contract
    function startRecruitment(
        address _user,
        uint256 _s1BadgeId
    )
        external
        virtual
        onlyRole(S1_BADGES_ROLE)
        recruitmentOpen(_s1BadgeId)
        isNotMigrating(_user)
        hasntMigratedInCycle(_s1BadgeId, _user, RecruitmentType.Migration)
    {
        uint256 s1TokenId_ = s1Badges.getTokenId(_user, _s1BadgeId);

        if (s1Badges.ownerOf(s1TokenId_) != _user) {
            revert TOKEN_NOT_OWNED();
        }
        _startRecruitment(_user, _s1BadgeId, s1TokenId_, RecruitmentType.Migration);
    }

    /// @notice Get the active recruitment for a user
    /// @param _user The user address
    /// @return The active recruitment
    function getActiveRecruitmentFor(address _user) public view returns (Recruitment memory) {
        if (recruitments[_user].length == 0) {
            revert RECRUITMENT_NOT_STARTED();
        }
        return recruitments[_user][recruitments[_user].length - 1];
    }

    /// @notice Update a recruitment
    /// @param _recruitment The updated recruitment
    function _updateRecruitment(Recruitment memory _recruitment) internal virtual {
        recruitments[_recruitment.user][recruitments[_recruitment.user].length - 1] = _recruitment;

        emit RecruitmentUpdated(
            _recruitment.recruitmentCycle,
            _recruitment.user,
            _recruitment.s1BadgeId,
            _recruitment.s1TokenId,
            _recruitment.s2TokenId,
            _recruitment.cooldownExpiration,
            _recruitment.influenceExpiration,
            _recruitment.whaleInfluences,
            _recruitment.minnowInfluences
        );
    }

    /// @notice Get the maximum number of influences for a given experience
    /// @param _exp The user's experience points
    function maxInfluences(uint256 _exp) public view virtual returns (uint256 value) {
        value = _exp / config.maxInfluencesDivider;
        value += 2 * config.baseMaxInfluences;
        return value;
    }

    /// @notice Influence (alter) the chances during a recruitment
    /// @param _hash The hash to sign
    /// @param _v signature V field
    /// @param _r signature R field
    /// @param _s signature S field
    /// @param _influenceColor the influence's color
    /// @dev Can be called only during an active recruitment
    /// @dev Implements a cooldown before allowing to re-influence
    /// @dev The max influence amount is determined by Pass Tier
    function influenceRecruitment(
        bytes32 _hash,
        uint8 _v,
        bytes32 _r,
        bytes32 _s,
        uint256 _exp,
        InfluenceColor _influenceColor
    )
        external
        isMigrating
    {
        bytes32 calculatedHash_ = generateClaimHash(HashType.Influence, _msgSender(), _exp);

        if (calculatedHash_ != _hash) {
            revert HASH_MISMATCH();
        }

        (address recovered_,,) = ECDSA.tryRecover(_hash, _v, _r, _s);
        if (recovered_ != randomSigner) revert NOT_RANDOM_SIGNER();
        Recruitment memory recruitment_ = getActiveRecruitmentFor(_msgSender());

        if ((recruitment_.whaleInfluences + recruitment_.minnowInfluences) > maxInfluences(_exp)) {
            revert MAX_INFLUENCES_REACHED();
        }

        if (recruitment_.influenceExpiration > block.timestamp) {
            revert INFLUENCE_IN_PROGRESS();
        }

        // apply the influence, and reset the other
        if (_influenceColor == InfluenceColor.Whale) {
            recruitment_.whaleInfluences++;
            recruitment_.minnowInfluences = 0;
        } else if (_influenceColor == InfluenceColor.Minnow) {
            recruitment_.minnowInfluences++;
            recruitment_.whaleInfluences = 0;
        } else {
            revert INVALID_INFLUENCE_COLOR();
        }

        recruitment_.influenceExpiration = block.timestamp + config.cooldownInfluence;

        _updateRecruitment(recruitment_);
    }

    /// @notice End a recruitment
    /// @param _hash The hash to sign
    /// @param _v signature V field
    /// @param _r signature R field
    /// @param _s signature S field
    /// @param _exp The user's experience points
    /// @dev Can be called only during an active recruitment, after the cooldown is over
    /// @dev The final color is determined randomly, and affected by the influence amounts
    function endRecruitment(
        bytes32 _hash,
        uint8 _v,
        bytes32 _r,
        bytes32 _s,
        uint256 _exp
    )
        external
        isMigrating
    {
        Recruitment memory recruitment_ = getActiveRecruitmentFor(_msgSender());

        if (recruitment_.influenceExpiration > block.timestamp) {
            revert INFLUENCE_IN_PROGRESS();
        }
        // check if the cooldown is over
        if (recruitment_.cooldownExpiration > block.timestamp) {
            revert RECRUITMENT_NOT_READY();
        }
        // ensure the hash corresponds to the start time
        bytes32 calculatedHash_ = generateClaimHash(HashType.End, _msgSender(), _exp);

        if (calculatedHash_ != _hash) {
            revert HASH_MISMATCH();
        }

        uint256 randomSeed_ = randomFromSignature(_hash, _v, _r, _s);

        uint256 whaleWeight_ = 50 + recruitment_.whaleInfluences * config.influenceWeightPercent;
        uint256 minnowWeight_ = 50 + recruitment_.minnowInfluences * config.influenceWeightPercent;

        uint256 totalWeight_ = whaleWeight_ + minnowWeight_;

        uint256 randomValue = randomSeed_ % totalWeight_;

        TrailblazersBadgesS2.MovementType finalColor_;
        if (randomValue < minnowWeight_) {
            finalColor_ = TrailblazersBadgesS2.MovementType.Minnow;
        } else {
            finalColor_ = TrailblazersBadgesS2.MovementType.Whale;
        }

        uint256 s1BadgeId_ = recruitment_.s1BadgeId;

        // mint the badge
        s2Badges.mint(_msgSender(), TrailblazersBadgesS2.BadgeType(s1BadgeId_), finalColor_);
        uint256 s2TokenId_ = s2Badges.totalSupply();

        recruitment_.s2TokenId = s2TokenId_;
        recruitment_.cooldownExpiration = 0;
        recruitment_.influenceExpiration = 0;

        _updateRecruitment(recruitment_);

        emit RecruitmentComplete(
            recruitment_.recruitmentCycle,
            recruitment_.user,
            recruitment_.s1TokenId,
            recruitment_.s2TokenId,
            uint256(finalColor_)
        );
    }

    /// @notice Generate a unique hash for each recruitment uniquely
    /// @param _user The user address
    /// @param _exp The users experience points
    /// @return _hash The unique hash
    function generateClaimHash(
        HashType _hashType,
        address _user,
        uint256 _exp
    )
        public
        pure
        returns (bytes32)
    {
        return keccak256(abi.encodePacked(_hashType, _user, _exp));
    }

    /// @notice Check if a recruitment is active for a user
    /// @param _user The user address
    /// @return Whether the user has an active recruitment
    function isRecruitmentActive(address _user) public view returns (bool) {
        if (recruitments[_user].length == 0) {
            return false;
        }
        Recruitment memory recruitment_ = getActiveRecruitmentFor(_user);
        return recruitment_.cooldownExpiration != 0;
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

    /// @notice Check if a influence is active for a user
    /// @param _user The user address
    /// @return Whether the user has an active influence
    function isInfluenceActive(address _user) public view returns (bool) {
        Recruitment memory recruitment_ = getActiveRecruitmentFor(_user);
        return recruitment_.influenceExpiration > block.timestamp;
    }

    /// @notice Get the recruitment influence counts for a user
    /// @param _user The user address
    /// @return _whaleInfluences The Whale influence count
    /// @return _minnowInfluences The Minnow influence count
    function getRecruitmentInfluences(address _user)
        public
        view
        returns (uint256 _whaleInfluences, uint256 _minnowInfluences)
    {
        if (!isRecruitmentActive(_user)) {
            revert RECRUITMENT_NOT_STARTED();
        }
        Recruitment memory recruitment_ = getActiveRecruitmentFor(_user);
        return (recruitment_.whaleInfluences, recruitment_.minnowInfluences);
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
