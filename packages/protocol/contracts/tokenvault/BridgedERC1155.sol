// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

import { IERC1155Upgradeable } from
    "@openzeppelin/contracts-upgradeable/token/ERC1155/IERC1155Upgradeable.sol";
import { IERC1155MetadataURIUpgradeable } from
    "@openzeppelin/contracts-upgradeable/token/ERC1155/extensions/IERC1155MetadataURIUpgradeable.sol";

import { ERC1155Upgradeable } from
    "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import { EssentialContract } from "../common/EssentialContract.sol";

contract BridgedERC1155 is
    EssentialContract,
    IERC1155Upgradeable,
    IERC1155MetadataURIUpgradeable,
    ERC1155Upgradeable
{
    error BRIDGED_TOKEN_CANNOT_RECEIVE();
    error BRIDGED_TOKEN_INVALID_PARAMS();

    address public srcToken;
    uint256 public srcChainId;
    string public srcUri;
    uint256[47] private gap;

    // TODO(dani): remove these events, use Transfer event
    event BridgeERC1155Mint(
        address indexed account, uint256 tokenId, uint256 amount
    );
    event BridgeERC1155Burn(
        address indexed account, uint256 tokenId, uint256 amount
    );

    /// @dev Initializer to be called after being deployed behind a proxy.
    // Intention is for a different BridgedERC1155 Contract to be deployed
    // per unique _srcToken.
    function init(
        address _addressManager,
        address _srcToken,
        uint256 _srcChainId,
        string memory _uri
    )
        external
        initializer
    {
        if (
            _srcToken == address(0) || _srcChainId == 0
                || _srcChainId == block.chainid || bytes(_uri).length == 0
        ) {
            revert BRIDGED_TOKEN_INVALID_PARAMS();
        }
        EssentialContract._init(_addressManager);
        __ERC1155_init(_uri);
        srcToken = _srcToken;
        srcChainId = _srcChainId;
        srcUri = _uri;
    }

    /// @dev only a TokenVault can call this function
    function bridgeMintTo(
        address account,
        uint256 tokenId,
        uint256 amount,
        bytes memory data
    )
        public
        onlyFromNamed("erc1155_vault")
    {
        _mint(account, tokenId, amount, data);
        emit BridgeERC1155Mint(account, tokenId, amount);
    }

    /// @dev only a TokenVault can call this function
    function bridgeBurnFrom(
        address account,
        uint256 tokenId,
        uint256 amount
    )
        public
        onlyFromNamed("erc1155_vault")
    {
        _burn(account, tokenId, amount);
        emit BridgeERC1155Burn(account, tokenId, amount);
    }

    /// @dev any address can call this
    // caller must have allowance over this tokenId from from,
    // or be the current owner.
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        uint256 amount,
        bytes memory data
    )
        public
        override(ERC1155Upgradeable, IERC1155Upgradeable)
    {
        if (to == address(this)) {
            revert BRIDGED_TOKEN_CANNOT_RECEIVE();
        }
        return
            ERC1155Upgradeable.safeTransferFrom(from, to, tokenId, amount, data);
    }

    /// @dev returns the srcToken being bridged and the srcChainId
    // of the tokens being bridged
    function source() public view returns (address, uint256) {
        return (srcToken, srcChainId);
    }
}
