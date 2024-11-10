// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./FreeMintERC20Token.sol";

// An ERC20 token for testing the Taiko Bridge on testnets.
// This token has 50% of failure on transfers so we can
// test the bridge's error handling.
contract FreeMintERC20Token_With50PctgMintAndTransferFailure is FreeMintERC20Token {

    modifier mayFail() {
        require(block.number % 2 != 0, "random failure");
        _;
    }

        constructor(string memory name, string memory symbol) FreeMintERC20Token(name, symbol) { }


    function transfer(address to, uint256 amount) public override mayFail returns (bool) {
        return ERC20.transfer(to, amount);
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    )
        public
        override
        mayFail
        returns (bool)
    {
        return ERC20.transferFrom(from, to, amount);
    }
}
