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
import { Proxied } from "../common/Proxied.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";

contract BridgedERC1155 is
    EssentialContract,
    IERC1155Upgradeable,
    IERC1155MetadataURIUpgradeable,
    ERC1155Upgradeable
{
    address public srcToken;
    uint256 public srcChainId;
    string public symbol;
    string private name_;

    uint256[46] private __gap;

    event Transfer(
        address indexed from,
        address indexed to,
        uint256 tokenId,
        uint256 amount
    );

    error BRIDGED_TOKEN_CANNOT_RECEIVE();
    error BRIDGED_TOKEN_INVALID_PARAMS();

    /// @dev Initializer to be called after being deployed behind a proxy.
    // Intention is for a different BridgedERC1155 Contract to be deployed
    // per unique _srcToken.
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
        // name and symbol can be "" intentionally, so check
        // not required (not part of the ERC1155 standard).
        symbol = _symbol;
        name_ = _name;
    }

    /// @dev only a TokenVault can call this function
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

    /// @dev only a TokenVault can call this function
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

    function name() public view returns (string memory) {
        return string.concat(name_, unicode" ⭀", Strings.toString(srcChainId));
    }
}

contract ProxiedBridgedERC1155 is Proxied, BridgedERC1155 { }
