// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract SisterContract is ERC721, Ownable {
    mapping(uint256 tokenId => string tokenURI) tokenToUri;

    constructor(
        string memory name,
        string memory symbol
    )
        ERC721(name, symbol)
    { }

    // Owner wil be the Vault - which is fine
    function safeMintOrTransfer(
        address to,
        uint256 tokenId,
        string memory uri
    )
        public
        onlyOwner
    {
        if (_exists(tokenId)) {
            // NFT bridge will be message.sender it will have the token
            _safeTransfer(msg.sender, to, tokenId, "");
        } else {
            _safeMint(to, tokenId);
            _setTokenURI(tokenId, uri);
        }
    }

    // The following functions are overrides required by Solidity.
    function _setTokenURI(uint256 tokenId, string memory uri) internal {
        tokenToUri[tokenId] = uri;
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721)
        returns (string memory)
    {
        _requireMinted(tokenId);
        return tokenToUri[tokenId];
    }
}
