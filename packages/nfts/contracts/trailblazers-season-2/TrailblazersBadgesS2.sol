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
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";

contract TrailblazersBadgesS2 is
    ContextUpgradeable,
    UUPSUpgradeable,
    Ownable2StepUpgradeable,
    AccessControlUpgradeable,
    ERC1155SupplyUpgradeable
{
    /// @notice Badge types
    enum BadgeType {
        Ravers, // s1 id: 0
        Robots, // s1 id: 1
        Bouncers, // s1 id: 2
        Masters, // s1 id: 3
        Monks, // s1 id: 4
        Androids, // s1 id: 5
        Drummers, // s1 id: 6
        Shinto // s1 id: 7

    }

    /// @notice Movement types
    enum MovementType {
        Undefined, // unused
        Whale, // s1 based/pink
        Minnow // s1 boosted/purple

    }

    /// @notice Badge struct
    struct Badge {
        uint256 tokenId;
        BadgeType badgeType;
        MovementType movementType;
    }

    /// @notice Badge mapping
    mapping(uint256 tokenId => Badge badge) private badges;
    /// @notice User, Badge, and Movement relation to tokenId
    mapping(
        address user
            => mapping(BadgeType badgeType => mapping(MovementType movementType => uint256 tokenId))
    ) private userBadges;
    /// @notice Badge URI template
    string public uriTemplate;
    /// @notice Minter address; BadgeMigration contract
    address public minter;
    /// @notice Minter role
    bytes32 public constant MINTER_ROLE = keccak256("MINTER");
    /// @notice Gap for upgrade safety
    uint256[43] private __gap;

    /// @notice Errors
    error NOT_MINTER();
    error TOKEN_NOT_MINTED();

    /// @notice Initialize the contract
    /// @param _minter The minter address
    /// @param _uriTemplate The badge URI template
    function initialize(
        address _minter,
        string calldata _uriTemplate
    )
        external
        virtual
        initializer
    {
        __ERC1155_init("");
        __ERC1155Supply_init();
        _transferOwnership(_msgSender());
        __Context_init();
        _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _grantRole(MINTER_ROLE, _minter);
        minter = _minter;
        uriTemplate = _uriTemplate;
    }

    /// @notice Set the minter address
    /// @param _minter The minter address
    /// @dev Only the owner can call this function
    function setMinter(address _minter) external virtual onlyRole(DEFAULT_ADMIN_ROLE) {
        minter = _minter;
        _grantRole(MINTER_ROLE, _minter);
    }

    /// @notice Mint a badge
    /// @param _to The address to mint the badge to
    /// @param _badgeType The badge type
    /// @param _movementType The movement type
    /// @dev Only the minter can call this function
    function mint(
        address _to,
        BadgeType _badgeType,
        MovementType _movementType
    )
        external
        virtual
        onlyRole(MINTER_ROLE)
    {
        uint256 tokenId_ = totalSupply() + 1;
        Badge memory badge_ = Badge(tokenId_, _badgeType, _movementType);
        _mint(_to, tokenId_, 1, "");
        badges[tokenId_] = badge_;
    }

    /// @notice Internal method to assemble URIs
    /// @param _badgeType The badge type
    /// @param _movementType The movement type
    /// @return The URI
    function _uri(
        BadgeType _badgeType,
        MovementType _movementType
    )
        internal
        view
        virtual
        returns (string memory)
    {
        string memory badgeType_ = Strings.toString(uint256(_badgeType));
        string memory movementType_ = Strings.toString(uint256(_movementType));

        return string(abi.encodePacked(uriTemplate, "/", movementType_, "/", badgeType_));
    }

    /// @notice Retrieve the URI for a badge given the type & movement
    /// @param _badgeType The badge type
    /// @param _movementType The movement type
    /// @return The URI
    function uri(
        BadgeType _badgeType,
        MovementType _movementType
    )
        external
        view
        virtual
        returns (string memory)
    {
        return _uri(_badgeType, _movementType);
    }

    /// @notice Retrieve the URI for a badge given the token ID
    /// @param _tokenId The token ID
    /// @return The URI
    function uri(uint256 _tokenId) public view virtual override returns (string memory) {
        if (_tokenId > totalSupply()) {
            revert TOKEN_NOT_MINTED();
        }
        Badge memory badge_ = badges[_tokenId];
        return _uri(badge_.badgeType, badge_.movementType);
    }

    /// @notice Retrieve a badge
    /// @param _tokenId The token ID
    /// @return The badge
    function getBadge(uint256 _tokenId) external view virtual returns (Badge memory) {
        if (_tokenId < totalSupply()) {
            revert TOKEN_NOT_MINTED();
        }
        return badges[_tokenId];
    }

    /// @notice supportsInterface implementation
    /// @param _interfaceId The interface ID
    /// @return Whether the interface is supported
    function supportsInterface(bytes4 _interfaceId)
        public
        view
        virtual
        override(AccessControlUpgradeable, ERC1155Upgradeable)
        returns (bool)
    {
        return super.supportsInterface(_interfaceId);
    }

    /// @notice Internal method to authorize an upgrade
    function _authorizeUpgrade(address) internal virtual override onlyOwner { }
}
