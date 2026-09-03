// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { ERC20Permit } from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";

// An EIP-2612 capable ERC20 token with a mint function anyone can call, for free, to receive
// 50 tokens. Used to exercise ERC20Vault's `sendTokenWithPermit` entrypoint.
contract FreeMintERC20TokenWithPermit is ERC20, ERC20Permit {
    mapping(address minter => bool hasMinted) public minters;

    constructor(string memory name, string memory symbol) ERC20(name, symbol) ERC20Permit(name) { }

    function mint(address to) public {
        require(!minters[to], "minted already");

        minters[to] = true;
        _mint(to, 50 * (10 ** decimals()));
    }
}
