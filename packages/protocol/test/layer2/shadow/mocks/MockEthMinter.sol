// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { IEthMinter } from "src/shared/bridge/IEthMinter.sol";

contract MockEthMinter is IEthMinter {
    address public lastRecipient;
    uint256 public lastAmount;
    uint256 public mintCount;

    function mintEth(address _recipient, uint256 _amount) external {
        lastRecipient = _recipient;
        lastAmount = _amount;
        mintCount++;
    }
}
