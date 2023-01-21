// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;
import "../../L1/TkoToken.sol";

contract TestTkoToken is TkoToken {
    function mintAnyone(address account, uint256 amount) public {
        _mint(account, amount);
    }
}
