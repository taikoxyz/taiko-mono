// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../common/EssentialContract.sol";
import "../libs/LibNames.sol";
import "./IBridgedERC721.sol";
import "./LibBridgedToken.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";

/// @title BridgedERC721
/// @notice Contract for bridging ERC721 tokens across different chains.
/// @custom:security-contact security@taiko.xyz
contract BridgedERC721 is
    EssentialContract,
    IBridgedERC721,
    IBridgedERC721Initializable,
    ERC721Upgradeable
{
    address public immutable erc721Vault;

    /// @notice Address of the source token contract.
    address public srcToken;

    /// @notice Source chain ID where the token originates.
    uint256 public srcChainId;

    uint256[48] private __gap;

    error BTOKEN_INVALID_BURN();

    constructor(address _erc721Vault) {
        erc721Vault = _erc721Vault;
    }

    /// @inheritdoc IBridgedERC721Initializable
    function init(
        address _owner,
        address _srcToken,
        uint256 _srcChainId,
        string calldata _symbol,
        string calldata _name
    )
        external
        initializer
    {
        // Check if provided parameters are valid
        LibBridgedToken.validateInputs(_srcToken, _srcChainId);
        __Essential_init(_owner);
        __ERC721_init(_name, _symbol);

        srcToken = _srcToken;
        srcChainId = _srcChainId;
    }

    /// @inheritdoc IBridgedERC721
    function mint(
        address _account,
        uint256 _tokenId
    )
        external
        whenNotPaused
        onlyFrom(erc721Vault)
        nonReentrant
    {
        _safeMint(_account, _tokenId);
    }

    /// @inheritdoc IBridgedERC721
    function burn(uint256 _tokenId) external whenNotPaused onlyFrom(erc721Vault) nonReentrant {
        // Check if the caller is the owner of the token. Somehow this is not done inside the
        // _burn() function below.
        if (ownerOf(_tokenId) != msg.sender) {
            revert BTOKEN_INVALID_BURN();
        }
        _burn(_tokenId);
    }

    /// @inheritdoc IBridgedERC721
    function canonical() external view returns (address, uint256) {
        return (srcToken, srcChainId);
    }

    /// @notice Returns the token URI.
    /// @param _tokenId The token id.
    /// @return The token URI following EIP-681.
    function tokenURI(uint256 _tokenId) public view override returns (string memory) {
        // https://github.com/crytic/slither/wiki/Detector-Documentation#abi-encodePacked-collision
        // The abi.encodePacked() call below takes multiple dynamic arguments. This is known and
        // considered acceptable in terms of risk.
        return LibBridgedToken.buildURI(srcToken, srcChainId, Strings.toString(_tokenId));
    }

    function supportsInterface(bytes4 _interfaceId) public view override returns (bool) {
        return _interfaceId == type(IBridgedERC721).interfaceId
            || _interfaceId == type(IBridgedERC721Initializable).interfaceId
            || super.supportsInterface(_interfaceId);
    }

    function _beforeTokenTransfer(
        address _from,
        address _to,
        uint256 _firstTokenId,
        uint256 _numBlocks
    )
        internal
        override
        whenNotPaused
    {
        LibBridgedToken.checkToAddress(_to);
        super._beforeTokenTransfer(_from, _to, _firstTokenId, _numBlocks);
    }
}

// Storage Layout ---------------------------------------------------------------
//
//   _initialized                   | uint8                                              | Slot: 0    | Offset: 0    | Bytes: 1
//   _initializing                  | bool                                               | Slot: 0    | Offset: 1    | Bytes: 1
//   __gap                          | uint256[50]                                        | Slot: 1    | Offset: 0    | Bytes: 1600
//   _owner                         | address                                            | Slot: 51   | Offset: 0    | Bytes: 20
//   __gap                          | uint256[49]                                        | Slot: 52   | Offset: 0    | Bytes: 1568
//   _pendingOwner                  | address                                            | Slot: 101  | Offset: 0    | Bytes: 20
//   __gap                          | uint256[49]                                        | Slot: 102  | Offset: 0    | Bytes: 1568
//   __gapFromOldAddressResolver    | uint256[50]                                        | Slot: 151  | Offset: 0    | Bytes: 1600
//   __reentry                      | uint8                                              | Slot: 201  | Offset: 0    | Bytes: 1
//   __paused                       | uint8                                              | Slot: 201  | Offset: 1    | Bytes: 1
//   __gap                          | uint256[49]                                        | Slot: 202  | Offset: 0    | Bytes: 1568
//   __gap                          | uint256[50]                                        | Slot: 251  | Offset: 0    | Bytes: 1600
//   _name                          | string                                             | Slot: 301  | Offset: 0    | Bytes: 32
//   _symbol                        | string                                             | Slot: 302  | Offset: 0    | Bytes: 32
//   _owners                        | mapping(uint256 => address)                        | Slot: 303  | Offset: 0    | Bytes: 32
//   _balances                      | mapping(address => uint256)                        | Slot: 304  | Offset: 0    | Bytes: 32
//   _tokenApprovals                | mapping(uint256 => address)                        | Slot: 305  | Offset: 0    | Bytes: 32
//   _operatorApprovals             | mapping(address => mapping(address => bool))       | Slot: 306  | Offset: 0    | Bytes: 32
//   __gap                          | uint256[44]                                        | Slot: 307  | Offset: 0    | Bytes: 1408
//   srcToken                       | address                                            | Slot: 351  | Offset: 0    | Bytes: 20
//   srcChainId                     | uint256                                            | Slot: 352  | Offset: 0    | Bytes: 32
//   __gap                          | uint256[48]                                        | Slot: 353  | Offset: 0    | Bytes: 1536
