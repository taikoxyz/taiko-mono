// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

import { EssentialContract } from "../common/EssentialContract.sol";
import { ERC721Upgradeable } from
    "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import { Proxied } from "../common/Proxied.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";

contract BridgedERC721 is EssentialContract, ERC721Upgradeable {
    address public srcToken;
    uint256 public srcChainId;

    uint256[48] private __gap;

    error BRIDGED_TOKEN_CANNOT_RECEIVE();
    error BRIDGED_TOKEN_INVALID_PARAMS();
    error BRIDGED_TOKEN_INVALID_BURN();

    /// @dev Initializer to be called after being deployed behind a proxy.
    // Intention is for a different BridgedERC721 Contract to be deployed
    // per unique _srcToken i.e. one for Loopheads, one for CryptoPunks, etc.
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
                || _srcChainId == block.chainid || bytes(_symbol).length == 0
                || bytes(_name).length == 0
        ) {
            revert BRIDGED_TOKEN_INVALID_PARAMS();
        }
        EssentialContract._init(_addressManager);
        __ERC721_init(_name, _symbol);
        srcToken = _srcToken;
        srcChainId = _srcChainId;
    }

    /// @dev only a TokenVault can call this function
    function mint(
        address account,
        uint256 tokenId
    )
        public
        onlyFromNamed("erc721_vault")
    {
        _mint(account, tokenId);
        emit Transfer(address(0), account, tokenId);
    }

    /// @dev only a TokenVault can call this function
    function burn(
        address account,
        uint256 tokenId
    )
        public
        onlyFromNamed("erc721_vault")
    {
        // ERC721Upgradeable internal _burn() function
        // does not have this ownership check so we
        // need to be careful when exposing the function.
        if (ownerOf(tokenId) != account) {
            revert BRIDGED_TOKEN_INVALID_BURN();
        }

        _burn(tokenId);
        emit Transfer(account, address(0), tokenId);
    }

    /// @dev any address can call this
    // caller must have allowance over this tokenId from from,
    // or be the current owner.
    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    )
        public
        override(ERC721Upgradeable)
    {
        if (to == address(this)) {
            revert BRIDGED_TOKEN_CANNOT_RECEIVE();
        }
        return ERC721Upgradeable.transferFrom(from, to, tokenId);
    }

    function name()
        public
        view
        override(ERC721Upgradeable)
        returns (string memory)
    {
        return string.concat(
            super.name(), unicode" ⭀", Strings.toString(srcChainId)
        );
    }

    /// @dev returns the srcToken being bridged and the srcChainId
    // of the tokens being bridged
    function source() public view returns (address, uint256) {
        return (srcToken, srcChainId);
    }

    function tokenURI(uint256)
        public
        pure
        virtual
        override
        returns (string memory)
    {
        return "";
    }
}

contract ProxiedBridgedERC721 is Proxied, BridgedERC721 { }
