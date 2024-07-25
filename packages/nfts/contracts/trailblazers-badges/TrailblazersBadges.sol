// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { ERC721EnumerableUpgradeable } from
    "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import { ECDSAWhitelist } from "./ECDSAWhitelist.sol";
import { IMinimalBlacklist } from "@taiko/blacklist/IMinimalBlacklist.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";

contract TrailblazersBadges is ERC721EnumerableUpgradeable, ECDSAWhitelist {
    /// @notice Movement IDs
    uint256 public constant MOVEMENT_NEUTRAL = 0;
    uint256 public constant MOVEMENT_BASED = 1;
    uint256 public constant MOVEMENT_BOOSTED = 2;
    /// @notice Badge IDs
    uint256 public constant BADGE_RAVERS = 0;
    uint256 public constant BADGE_ROBOTS = 1;
    uint256 public constant BADGE_BOUNCERS = 2;
    uint256 public constant BADGE_MASTERS = 3;
    uint256 public constant BADGE_MONKS = 4;
    uint256 public constant BADGE_DRUMMERS = 5;
    uint256 public constant BADGE_ANDROIDS = 6;
    uint256 public constant BADGE_SHINTO = 7;

    /// @notice Base URI required to interact with IPFS
    string private _baseURIExtended;
    /// @notice Token ID to badge ID mapping
    mapping(uint256 _tokenId => uint256 _badgeId) public badges;
    /// @notice Wallet-to-Movement mapping
    mapping(address _user => uint256 _movement) public movements;
    /// @notice Wallet to badge ID, token ID mapping
    mapping(address _user => mapping(uint256 _badgeId => uint256 _tokenId)) public userBadges;
    /// @notice Movement to badge ID, token ID mapping
    mapping(bytes32 movementBadgeHash => uint256[2] movementBadge) public movementBadges;
    /// @notice Gap for upgrade safety
    uint256[43] private __gap;

    error MINTER_NOT_WHITELISTED();
    error INVALID_INPUT();
    error INVALID_BADGE_ID();
    error INVALID_MOVEMENT_ID();

    event BadgeCreated(uint256 _tokenId, address _minter, uint256 _badgeId);
    event MovementSet(address _user, uint256 _movementId);
    event UriSet(string _uri);

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
        __ERC721_init("Trailblazers Badges", "TBB");
        _baseURIExtended = _rootURI;
        __ECDSAWhitelist_init(_owner, _mintSigner, _blacklistAddress);
    }

    /// @notice Ensure update of userBadges on transfers
    /// @param to The address to transfer to
    /// @param tokenId The token id to transfer
    /// @param auth The authorizer of the transfer
    function _update(
        address to,
        uint256 tokenId,
        address auth
    )
        internal
        virtual
        override
        returns (address)
    {
        userBadges[_ownerOf(tokenId)][badges[tokenId]] = 0;
        userBadges[to][badges[tokenId]] = tokenId;
        return super._update(to, tokenId, auth);
    }

    /// @notice Update the base URI
    /// @param _uri The new base URI
    function setUri(string memory _uri) public onlyOwner {
        _baseURIExtended = _uri;
        emit UriSet(_uri);
    }

    /// @notice Get the URI for a tokenId
    /// @param _tokenId The badge ID
    /// @return URI The URI for the badge
    function tokenURI(uint256 _tokenId) public view override returns (string memory) {
        uint256 movementId = movements[ownerOf(_tokenId)];
        uint256 badgeId = badges[_tokenId];
        return string(
            abi.encodePacked(
                _baseURIExtended, "/", Strings.toString(movementId), "/", Strings.toString(badgeId)
            )
        );
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

        _consumeMint(_signature, _minter, _badgeId);

        uint256 tokenId = totalSupply() + 1;
        badges[tokenId] = _badgeId;

        _mint(_minter, tokenId);

        emit BadgeCreated(tokenId, _minter, _badgeId);
    }

    /// @notice Sets movement for the calling wallet
    /// @param _movementId The movement ID to set
    function setMovement(uint256 _movementId) public {
        _setMovement(_msgSender(), _movementId);
    }

    /// @notice Sets movement for a specific address
    /// @param _user The address to set the movement for
    /// @param _movementId The movement ID to set
    /// @dev Owner-only method
    function setMovement(address _user, uint256 _movementId) public onlyOwner {
        _setMovement(_user, _movementId);
    }

    /// @notice Internal method for setting movement
    /// @param _user The address to set the movement for
    /// @param _movementId The movement ID to set
    function _setMovement(address _user, uint256 _movementId) internal {
        if (_movementId > MOVEMENT_BOOSTED) revert INVALID_MOVEMENT_ID();
        movements[_user] = _movementId;
        emit MovementSet(_user, _movementId);
    }

    /// @notice Retrieve a token ID given their owner and Badge ID
    /// @param _user The address of the badge owner
    /// @param _badgeId The badge ID
    /// @return tokenId The token ID
    function getTokenId(address _user, uint256 _badgeId) public view returns (uint256) {
        return userBadges[_user][_badgeId];
    }

    /// @notice Retrieve boolean balance for each badge
    /// @param _owner The addresses to check
    /// @return balances The badges atomic balances
    function badgeBalances(address _owner) public view returns (bool[] memory) {
        bool[] memory balances = new bool[](8);
        balances[0] = 0 != getTokenId(_owner, BADGE_RAVERS);
        balances[1] = 0 != getTokenId(_owner, BADGE_ROBOTS);
        balances[2] = 0 != getTokenId(_owner, BADGE_BOUNCERS);
        balances[3] = 0 != getTokenId(_owner, BADGE_MASTERS);
        balances[4] = 0 != getTokenId(_owner, BADGE_MONKS);
        balances[5] = 0 != getTokenId(_owner, BADGE_DRUMMERS);
        balances[6] = 0 != getTokenId(_owner, BADGE_ANDROIDS);
        balances[7] = 0 != getTokenId(_owner, BADGE_SHINTO);
        return balances;
    }

    /// @notice v2

    /// @notice Upgraded badgeBalances using tokenOfOwnerByIndex
    /// @param _owner The addresses to check
    /// @return balances The badges atomic balances
    function badgeBalancesV2(address _owner) public view returns (bool[] memory balances) {
        uint256 balance = balanceOf(_owner);
        uint256[] memory tokenIds = new uint256[](balance);
        for (uint256 i = 0; i < balance; i++) {
            tokenIds[i] = tokenOfOwnerByIndex(_owner, i);
        }
        balances = new bool[](8);

        for (uint256 i = 0; i < balance; i++) {
            uint256 badgeId = badges[tokenIds[i]];
            balances[badgeId] = true;
        }

        return balances;
    }

    /// @notice Return the total badge supply by badgeId
    /// @return balances The amount of each badge id
    function totalBadgeSupply() public view returns (uint256[] memory balances) {
        uint256 totalSupply = totalSupply();
        balances = new uint256[](8);

        for (uint256 i = 1; i <= totalSupply; i++) {
            uint256 badgeId = badges[i];
            balances[badgeId]++;
        }

        return balances;
    }
}
