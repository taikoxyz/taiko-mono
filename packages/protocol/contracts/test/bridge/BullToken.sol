// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// An ERC2 token for testing the Taiko Bridge on testnets.
// This token has 50% of failure on transfers so we can
// test the bridge's error handling.
contract BullToken is ERC20 {
    uint256 private constant INITIAL_SUPPLY = 10000000 * 1E18;

    constructor() ERC20("Bull Token", "BLL") {
        _mint(msg.sender, INITIAL_SUPPLY);
    }

    function transfer(
        address to,
        uint256 amount
    ) public override returns (bool) {
        _mayFail();
        return ERC20.transfer(to, amount);
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public override returns (bool) {
        _mayFail();
        return ERC20.transferFrom(from, to, amount);
    }

    // Have a 50% change of failure.
    function _mayFail() private view {
        if (block.number % 2 == 0) {
            revert("Failed");
        }
    }
}
