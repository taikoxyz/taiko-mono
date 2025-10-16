// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// An ERC20 Token with a mint function anyone can call, for free, to receive
// 5 tokens.
contract FreeMintERC20Token is ERC20 {
    mapping(address minter => bool hasMinted) public minters;

    constructor(string memory name, string memory symbol) ERC20(name, symbol) { }

    function mint(address to) public {
        require(!minters[to], "minted already");

        minters[to] = true;
        _mint(to, 50 * (10 ** decimals()));
    }
}
