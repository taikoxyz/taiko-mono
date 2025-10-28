// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../common/EssentialContract.sol";
import "../libs/LibNames.sol";
import "./IBridgedERC1155.sol";
import "./LibBridgedToken.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";

/// @title BridgedERC1155
/// @notice Contract for bridging ERC1155 tokens across different chains.
/// @custom:security-contact security@taiko.xyz
contract BridgedERC1155 is
    EssentialContract,
    IBridgedERC1155,
    IBridgedERC1155Initializable,
    ERC1155Upgradeable
{
    address public immutable erc1155Vault;

    /// @notice Address of the source token contract.
    address public srcToken;

    /// @notice Source chain ID where the token originates.
    uint256 public srcChainId;

    /// @dev Symbol of the bridged token.
    string public symbol;

    /// @dev Name of the bridged token.
    string public name;

    uint256[46] private __gap;

    error BTOKEN_INVALID_PARAMS();

    constructor(address _erc1155Vault) {
        erc1155Vault = _erc1155Vault;
    }

    /// @inheritdoc IBridgedERC1155Initializable
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
        // Check if provided parameters are valid.
        // The symbol and the name can be empty for ERC1155 tokens so we use some placeholder data
        // for them instead.
        LibBridgedToken.validateInputs(_srcToken, _srcChainId);
        __Essential_init(_owner);

        // The token URI here is not important as the client will have to read the URI from the
        // canonical contract to fetch meta data.
        __ERC1155_init(LibBridgedToken.buildURI(_srcToken, _srcChainId, ""));

        srcToken = _srcToken;
        srcChainId = _srcChainId;
        symbol = _symbol;
        name = _name;
    }

    /// @inheritdoc IBridgedERC1155
    function mintBatch(
        address _to,
        uint256[] calldata _tokenIds,
        uint256[] calldata _amounts
    )
        external
        whenNotPaused
        onlyFrom(erc1155Vault)
        nonReentrant
    {
        _mintBatch(_to, _tokenIds, _amounts, "");
    }

    /// @inheritdoc IBridgedERC1155
    function burn(
        uint256 _id,
        uint256 _amount
    )
        external
        whenNotPaused
        onlyFrom(erc1155Vault)
        nonReentrant
    {
        _burn(msg.sender, _id, _amount);
    }

    /// @inheritdoc IBridgedERC1155
    function canonical() external view returns (address, uint256) {
        return (srcToken, srcChainId);
    }

    function supportsInterface(bytes4 _interfaceId) public view override returns (bool) {
        return _interfaceId == type(IBridgedERC1155).interfaceId
            || _interfaceId == type(IBridgedERC1155Initializable).interfaceId
            || super.supportsInterface(_interfaceId);
    }

    function _beforeTokenTransfer(
        address _operator,
        address _from,
        address _to,
        uint256[] memory _ids,
        uint256[] memory _amounts,
        bytes memory _data
    )
        internal
        override
        whenNotPaused
    {
        LibBridgedToken.checkToAddress(_to);
        super._beforeTokenTransfer(_operator, _from, _to, _ids, _amounts, _data);
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
//   _balances                      | mapping(uint256 => mapping(address => uint256))    | Slot: 301  | Offset: 0    | Bytes: 32
//   _operatorApprovals             | mapping(address => mapping(address => bool))       | Slot: 302  | Offset: 0    | Bytes: 32
//   _uri                           | string                                             | Slot: 303  | Offset: 0    | Bytes: 32
//   __gap                          | uint256[47]                                        | Slot: 304  | Offset: 0    | Bytes: 1504
//   srcToken                       | address                                            | Slot: 351  | Offset: 0    | Bytes: 20
//   srcChainId                     | uint256                                            | Slot: 352  | Offset: 0    | Bytes: 32
//   symbol                         | string                                             | Slot: 353  | Offset: 0    | Bytes: 32
//   name                           | string                                             | Slot: 354  | Offset: 0    | Bytes: 32
//   __gap                          | uint256[46]                                        | Slot: 355  | Offset: 0    | Bytes: 1472
