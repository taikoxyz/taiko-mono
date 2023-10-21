// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

import { ERC1155Upgradeable } from
    "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import { EssentialContract } from "../common/EssentialContract.sol";
import { IERC1155MetadataURIUpgradeable } from
    "@openzeppelin/contracts-upgradeable/token/ERC1155/extensions/IERC1155MetadataURIUpgradeable.sol";
import { IERC1155Upgradeable } from
    "@openzeppelin/contracts-upgradeable/token/ERC1155/IERC1155Upgradeable.sol";
import { Proxied } from "../common/Proxied.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";

/// @title BridgedERC1155
/// @notice Contract for bridging ERC1155 tokens across different chains.
contract BridgedERC1155 is
    EssentialContract,
    IERC1155Upgradeable,
    IERC1155MetadataURIUpgradeable,
    ERC1155Upgradeable
{
    address public srcToken; // Address of the source token contract.
    uint256 public srcChainId; // Source chain ID where the token originates.
    string public symbol; // Symbol of the bridged token.
    string private name_; // Name of the bridged token.

    uint256[46] private __gap;

    // Event triggered upon token transfer.
    event Transfer(
        address indexed from,
        address indexed to,
        uint256 tokenId,
        uint256 amount
    );

    error BRIDGED_TOKEN_CANNOT_RECEIVE();
    error BRIDGED_TOKEN_INVALID_PARAMS();

    /// @dev Initializer function to be called after deployment.
    /// @param _addressManager The address of the address manager.
    /// @param _srcToken Address of the source token.
    /// @param _srcChainId Source chain ID.
    /// @param _symbol Symbol of the bridged token.
    /// @param _name Name of the bridged token.
    function init(
        address _addressManager,
        address _srcToken,
        uint256 _srcChainId,
        string memory _symbol,
        string memory _name
    )
        external
        initializer
    {
        if (
            _srcToken == address(0) || _srcChainId == 0
                || _srcChainId == block.chainid
        ) {
            revert BRIDGED_TOKEN_INVALID_PARAMS();
        }
        EssentialContract._init(_addressManager);
        __ERC1155_init("");
        srcToken = _srcToken;
        srcChainId = _srcChainId;
        // Note: name and symbol can intentionally be empty ("") as it's not
        // part of the ERC1155 standard.
        symbol = _symbol;
        name_ = _name;
    }

    /// @dev Mints tokens.
    /// @param account Address to receive the minted tokens.
    /// @param tokenId ID of the token to mint.
    /// @param amount Amount of tokens to mint.
    function mint(
        address account,
        uint256 tokenId,
        uint256 amount
    )
        public
        onlyFromNamed("erc1155_vault")
    {
        _mint(account, tokenId, amount, "");
        emit Transfer(address(0), account, tokenId, amount);
    }

    /// @dev Burns tokens.
    /// @param account Address from which tokens are burned.
    /// @param tokenId ID of the token to burn.
    /// @param amount Amount of tokens to burn.
    function burn(
        address account,
        uint256 tokenId,
        uint256 amount
    )
        public
        onlyFromNamed("erc1155_vault")
    {
        _burn(account, tokenId, amount);
        emit Transfer(account, address(0), tokenId, amount);
    }

    /// @dev Safely transfers tokens from one address to another.
    /// @param from Address from which tokens are transferred.
    /// @param to Address to which tokens are transferred.
    /// @param tokenId ID of the token to transfer.
    /// @param amount Amount of tokens to transfer.
    /// @param data Additional data.
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

    /// @notice Gets the concatenated name of the bridged token.
    /// @return The concatenated name.
    function name() public view returns (string memory) {
        return string.concat(name_, unicode" ⭀", Strings.toString(srcChainId));
    }
}

/// @title ProxiedBridgedERC1155
/// @notice Proxied version of the parent contract.
contract ProxiedBridgedERC1155 is Proxied, BridgedERC1155 { }
