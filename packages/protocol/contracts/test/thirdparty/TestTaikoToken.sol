// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;
import {TaikoToken} from "../../L1/TaikoToken.sol";

contract TestTaikoToken is TaikoToken {
    function mintAnyone(address account, uint256 amount) public {
        _mint(account, amount);
    }
}
