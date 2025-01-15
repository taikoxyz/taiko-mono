// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract FreeMintERC721Token is ERC721 {
    string _baseTokenURI;
    uint256 minted;

    constructor(string memory baseURI) ERC721("TT", "TT") {
        _baseTokenURI = baseURI;
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return _baseTokenURI;
    }

    function mint(uint256 amount) public {
        for (uint256 i; i < amount; ++i) {
            _safeMint(msg.sender, minted + i);
        }
        minted += amount;
    }
}
