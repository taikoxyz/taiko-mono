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

// TODO(dani): override the name() function, learn from BridgedERC20
// There is nothing to overwrite because ERC1155 has no name and symbol
// But i'll put a public name and symbol into this contract. (public name()
// and symbol() functions will be generated this way.
contract BridgedERC1155 is
    EssentialContract,
    IERC1155Upgradeable,
    IERC1155MetadataURIUpgradeable,
    ERC1155Upgradeable
{
    address public srcToken;
    uint256 public srcChainId;
    string public name;
    string public symbol;
    string private _srcUri;

    uint256[47] private __gap;

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
        string memory _name,
        string memory _uri
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
        __ERC1155_init(_uri);
        srcToken = _srcToken;
        srcChainId = _srcChainId;
        _srcUri = _uri;
        // name and symbol can be "" intentionally, so check
        // not required (not part of the ERC1155 standard).
        name = _name;
        symbol = _symbol;
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

    /// @dev returns the srcToken being bridged and the srcChainId
    // of the tokens being bridged
    function source() public view returns (address, uint256) {
        return (srcToken, srcChainId);
    }

    function uri(uint256)
        public
        view
        virtual
        override(ERC1155Upgradeable, IERC1155MetadataURIUpgradeable)
        returns (string memory)
    {
        return _srcUri;
    }
}
