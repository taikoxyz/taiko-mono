// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {IEtherMinter} from "../../src/iface/IEtherMinter.sol";

contract MockEtherMinter is IEtherMinter {
    address public lastRecipient;
    uint256 public lastAmount;
    uint256 public mintCount;

    function mintEther(address _recipient, uint256 _amount) external {
        lastRecipient = _recipient;
        lastAmount = _amount;
        mintCount++;
    }
}
