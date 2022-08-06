// SPDX-License-Identifier: MIT
//
// ╭━━━━╮╱╱╭╮╱╱╱╱╱╭╮╱╱╱╱╱╭╮
// ┃╭╮╭╮┃╱╱┃┃╱╱╱╱╱┃┃╱╱╱╱╱┃┃
// ╰╯┃┃┣┻━┳┫┃╭┳━━╮┃┃╱╱╭━━┫╰━┳━━╮
// ╱╱┃┃┃╭╮┣┫╰╯┫╭╮┃┃┃╱╭┫╭╮┃╭╮┃━━┫
// ╱╱┃┃┃╭╮┃┃╭╮┫╰╯┃┃╰━╯┃╭╮┃╰╯┣━━┃
// ╱╱╰╯╰╯╰┻┻╯╰┻━━╯╰━━━┻╯╰┻━━┻━━╯
pragma solidity ^0.8.9;

import "../../common/IMintableERC20.sol";
import "./AbstractBroker.sol";

contract TaiBroker is AbstractBroker {
    function feeToken() public view override returns (address) {
        return resolve("tai_token");
    }

    function pay(address recipient, uint256 amount)
        internal
        override
        returns (bool success)
    {
        if (amount > 0) {
            IMintableERC20(feeToken()).mint(recipient, amount);
        }
        return true;
    }

    function charge(address recipient, uint256 amount)
        internal
        override
        returns (bool success)
    {
        if (amount > 0) {
            IMintableERC20(feeToken()).burn(recipient, amount);
        }
        return true;
    }
}
