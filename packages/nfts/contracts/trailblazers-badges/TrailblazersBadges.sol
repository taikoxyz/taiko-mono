// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { ERC1155Upgradeable } from
    "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import { ECDSAWhitelist } from "./ECDSAWhitelist.sol";
import { IMinimalBlacklist } from "@taiko/blacklist/IMinimalBlacklist.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";

contract TrailblazersBadges is ERC1155Upgradeable, ECDSAWhitelist {
    /// @notice Base URI required to interact with IPFS
    string private _baseURIExtended;

    /// @notice Badge IDs
    uint256 public constant BADGE_RAVERS = 0;
    uint256 public constant BADGE_ROBOTS = 1;
    uint256 public constant BADGE_BOUNCERS = 2;
    uint256 public constant BADGE_MASTERS = 3;
    uint256 public constant BADGE_MONKS = 4;
    uint256 public constant BADGE_DRUMMERS = 5;
    uint256 public constant BADGE_ANDROIDS = 6;
    uint256 public constant BADGE_SHINTO = 7;
    /// @notice Gap for upgrade safety
    uint256[48] private __gap;

    error MINTER_NOT_WHITELISTED();
    error INVALID_INPUT();
    error INVALID_BADGE_ID();

    event BadgeCreated(uint256 _badgeId, string _badgeName);

    /// @notice Contract initializer
    /// @param _owner Contract owner
    /// @param _rootURI Base URI for the token metadata
    /// @param _mintSigner The address that can authorize minting badges
    /// @param _blacklistAddress The address of the blacklist contract
    function initialize(
        address _owner,
        string memory _rootURI,
        address _mintSigner,
        IMinimalBlacklist _blacklistAddress
    )
        external
        initializer
    {
        __ERC1155_init(_rootURI);
        _baseURIExtended = _rootURI;
        __ECDSAWhitelist_init(_owner, _mintSigner, _blacklistAddress);
    }

    /// @notice Get the URI for a badge
    /// @param _badgeId The badge ID
    /// @return The URI for the badge
    function uri(uint256 _badgeId) public view override returns (string memory) {
        return string(abi.encodePacked(_baseURIExtended, Strings.toString(_badgeId)));
    }

    /// @notice Mint a badge from the calling wallet
    /// @param _signature The signature authorizing the mint
    /// @param _badgeId The badge ID to mint
    function mint(bytes memory _signature, uint256 _badgeId) public {
        _mintBadgeTo(_signature, _msgSender(), _badgeId);
    }

    /// @notice Mint a badge to a specific address
    /// @param _signature The signature authorizing the mint
    /// @param _minter The address to mint the badge to
    /// @param _badgeId The badge ID to mint
    /// @dev Admin only method
    function mint(bytes memory _signature, address _minter, uint256 _badgeId) public onlyOwner {
        _mintBadgeTo(_signature, _minter, _badgeId);
    }

    /// @notice Internal method for badge minting
    /// @param _signature The signature authorizing the mint
    /// @param _minter The address to mint the badge to
    /// @param _badgeId The badge ID to mint
    function _mintBadgeTo(bytes memory _signature, address _minter, uint256 _badgeId) internal {
        if (_badgeId > BADGE_SHINTO) revert INVALID_BADGE_ID();
        if (!canMint(_signature, _minter, _badgeId)) revert MINTER_NOT_WHITELISTED();
        _consumeMint(_signature, _minter, _badgeId);
        _mint(
            _minter,
            _badgeId,
            1, // amount
            "" // empty data
        );
    }
}
