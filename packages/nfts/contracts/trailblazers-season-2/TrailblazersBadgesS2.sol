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
    ERC1155SupplyUpgradeable
{
    enum BadgeType {
        Ravers, // s1 id: 0
        Robots, // s1 id: 1
        Bouncers, // s1 id: 2
        Masters, // s1 id: 3
        Monks, // s1 id: 4
        Drummers, // s1 id: 5
        Androids, // s1 id: 6
        Shinto // s1 id: 7

    }

    enum MovementType {
        Dev, // s1 neutral
        Minnow, // s1 based/pink
        Whale // s1 boosted/purple

    }

    struct Badge {
        uint256 tokenId;
        BadgeType badgeType;
        MovementType movementType;
    }

    mapping(uint256 tokenId => Badge badge) private badges;

    string public uriTemplate;

    address public minter;

    /// @notice Gap for upgrade safety
    uint256[43] private __gap;

    /// @notice Errors
    error NOT_MINTER();
    error TOKEN_NOT_MINTED();
    /// @notice Modifiers

    modifier onlyMinter() {
        if (minter != _msgSender()) {
            revert NOT_MINTER();
        }
        _;
    }

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

        minter = _minter;
        uriTemplate = _uriTemplate;
    }

    function updateMinter(address _minter) external virtual onlyOwner {
        minter = _minter;
    }

    function mint(
        address _to,
        BadgeType _badgeType,
        MovementType _movementType
    )
        external
        virtual
        onlyMinter
    {
        uint256 tokenId = totalSupply() + 1;
        Badge memory badge = Badge(tokenId, _badgeType, _movementType);
        _mint(_to, tokenId, 1, "");
        badges[tokenId] = badge;
    }

    function _uri(
        BadgeType _badgeType,
        MovementType _movementType
    )
        internal
        view
        virtual
        returns (string memory)
    {
        string memory badgeType = Strings.toString(uint256(_badgeType));
        string memory movementType = Strings.toString(uint256(_movementType));

        return string(abi.encodePacked(uriTemplate, badgeType, "/", movementType, ".json"));
    }

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

    function uri(uint256 tokenId) public view virtual override returns (string memory) {
        if (tokenId > totalSupply()) {
            revert TOKEN_NOT_MINTED();
        }
        Badge memory badge = badges[tokenId];
        return _uri(badge.badgeType, badge.movementType);
    }

    function getBadge(uint256 tokenId) external view virtual returns (Badge memory) {
        if (tokenId < totalSupply()) {
            revert TOKEN_NOT_MINTED();
        }
        return badges[tokenId];
    }

    /// @notice supportsInterface implementation
    /// @param interfaceId The interface ID
    /// @return Whether the interface is supported
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    /// @notice Internal method to authorize an upgrade
    function _authorizeUpgrade(address) internal virtual override onlyOwner { }
}
