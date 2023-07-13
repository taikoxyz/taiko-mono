// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

import { EssentialContract } from "../common/EssentialContract.sol";
import { ERC721Upgradeable } from
    "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";

contract BridgedERC721 is EssentialContract, ERC721Upgradeable {
    address public srcToken;
    uint256 public srcChainId;
    string public srcBaseUri;
    uint256[47] private __gap;

    error BRIDGED_TOKEN_CANNOT_RECEIVE();
    error BRIDGED_TOKEN_INVALID_PARAMS();

    // TODO(dani): remove these events, use Transfer event
    event BridgeERC721Mint(address indexed account, uint256 tokenId);
    event BridgeERC721Burn(address indexed account, uint256 tokenId);

    /// @dev Initializer to be called after being deployed behind a proxy.
    // Intention is for a different BridgedERC721 Contract to be deployed
    // per unique _srcToken i.e. one for Loopheads, one for CryptoPunks, etc.
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
                || _srcChainId == block.chainid || bytes(_symbol).length == 0
                || bytes(_name).length == 0 || bytes(_uri).length == 0
        ) {
            revert BRIDGED_TOKEN_INVALID_PARAMS();
        }
        EssentialContract._init(_addressManager);
        __ERC721_init(_name, _symbol);
        srcToken = _srcToken;
        srcChainId = _srcChainId;
        srcBaseUri = _uri;
    }

    /// @dev only a TokenVault can call this function
    function bridgeMintTo(
        address account,
        uint256 tokenId
    )
        public
        onlyFromNamed("erc721_vault")
    {
        _mint(account, tokenId);
        emit BridgeERC721Mint(account, tokenId);
    }

    /// @dev only a TokenVault can call this function
    function bridgeBurnFrom(
        address account,
        uint256 tokenId
    )
        public
        onlyFromNamed("erc721_vault")
    {
        _burn(tokenId);
        emit BridgeERC721Burn(account, tokenId);
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

    function _baseURI() internal view override returns (string memory) {
        return srcBaseUri;
    }

    /// @dev returns the srcToken being bridged and the srcChainId
    // of the tokens being bridged
    function source() public view returns (address, uint256) {
        return (srcToken, srcChainId);
    }
}
