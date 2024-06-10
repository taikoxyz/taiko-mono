// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { ERC721Upgradeable } from
    "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";

import { ECDSAWhitelist } from "./ECDSAWhitelist.sol";
import { IMinimalBlacklist } from "@taiko/blacklist/IMinimalBlacklist.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { BasedOrBoosted } from "./BasedOrBoosted.sol";

contract TrailblazersBadges is ERC721Upgradeable, ECDSAWhitelist {
    /// @notice Base URI required to interact with IPFS
    string private _baseURIExtended;

    /// @notice Reference to BasedOrBoosted contract
    BasedOrBoosted public basedOrBoosted;

    /// @notice Mapping between tokenId and BadgeId
    mapping(uint256 => uint256) private _tokenIdToBadgeId;

    /// @notice Token counter
    uint256 private _tokenCounter;

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
    event BaseURLUpdated(string newBaseURL);

    /// @notice Contract initializer
    /// @param _owner Contract owner
    /// @param _rootURI Base URI for the token metadata
    /// @param _mintSigner The address that can authorize minting badges
    /// @param _blacklistAddress The address of the blacklist contract
    /// @param _basedOrBoostedAddress The address of the BasedOrBoosted contract
    function initialize(
        address _owner,
        string memory _rootURI,
        address _mintSigner,
        IMinimalBlacklist _blacklistAddress,
        address _basedOrBoostedAddress
    )
        public
        initializer
    {
        __ERC721_init("TrailblazersBadges", "TBB");
        __Ownable_init(_owner);
        __ECDSAWhitelist_init(_owner, _mintSigner, _blacklistAddress);

        _baseURIExtended = _rootURI;
        basedOrBoosted = BasedOrBoosted(_basedOrBoostedAddress);
        transferOwnership(_owner);
    }

    /// @notice Get the URI for a badge
    /// @param _tokenId The badge ID
    /// @return The URI for the badge
    function tokenURI(uint256 _tokenId) public view override returns (string memory) {
        BasedOrBoosted.Movement movement = getMovement(ownerOf(_tokenId));
        uint256 badgeId = _tokenIdToBadgeId[_tokenId];
        return string(
            abi.encodePacked(
                _baseURIExtended,
                "/",
                Strings.toString(uint256(movement)),
                "/",
                Strings.toString(badgeId),
                ".json"
            )
        );
    }

    /// @notice Mint a badge from the calling wallet
    /// @param _signature The signature authorizing the mint
    /// @param _badgeId The badge ID to mint
    function mint(bytes memory _signature, uint256 _badgeId) public {
        if (!canMint(_signature, _msgSender(), _badgeId)) revert MINTER_NOT_WHITELISTED();
        _mintBadgeTo(_signature, _msgSender(), _badgeId);
    }

    /// @notice Mint a badge to a specific address
    /// @param _signature The signature authorizing the mint
    /// @param _minter The address to mint the badge to
    /// @param _badgeId The badge ID to mint
    /// @dev Admin only method
    function mint(bytes memory _signature, address _minter, uint256 _badgeId) public onlyOwner {
        if (!canMint(_signature, _minter, _badgeId)) revert MINTER_NOT_WHITELISTED();
        _mintBadgeTo(_signature, _minter, _badgeId);
    }

    /// @notice Internal method for badge minting
    /// @param _signature The signature authorizing the mint
    /// @param _minter The address to mint the badge to
    /// @param _badgeId The badge ID to mint
    function _mintBadgeTo(bytes memory _signature, address _minter, uint256 _badgeId) internal {
        if (_badgeId > BADGE_SHINTO) revert INVALID_BADGE_ID();
        if (!canMint(_signature, _minter, _badgeId)) revert MINTER_NOT_WHITELISTED();

        _tokenCounter++;
        uint256 tokenId = _tokenCounter;
        _tokenIdToBadgeId[tokenId] = _badgeId;
        _safeMint(_minter, tokenId);
    }

    /// @notice Get the movement type of the user
    /// @param _user The address of the user
    /// @return movement The movement type as a string
    function getMovement(address _user) internal view returns (BasedOrBoosted.Movement movement) {
        movement = basedOrBoosted.isBasedOrBoosted(_user);
    }

    /// @notice Get the total supply of tokens
    /// @return The total supply of tokens
    function totalSupply() public view returns (uint256) {
        return _tokenCounter;
    }

    /// @notice Get the badge ID of a token
    /// @param _tokenId The token ID
    /// @return The badge ID of the token
    function getBadgeId(uint256 _tokenId) public view returns (uint256) {
        return _tokenIdToBadgeId[_tokenId];
    }

    /// @notice Set the base URL for token metadata
    /// @param newBaseURL The new base URL to set
    function setBaseURL(string memory newBaseURL) public onlyOwner {
        _baseURIExtended = newBaseURL;
        emit BaseURLUpdated(newBaseURL);
    }
}
