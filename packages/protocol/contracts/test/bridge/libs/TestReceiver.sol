// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.9;

import "hardhat/console.sol";

contract TestReceiver {
    event Received(address from, uint256 amount);
    event Fallback(address from, uint256 amount);

    receive() external payable {
        emit Received(msg.sender, msg.value);
    }

    fallback() external payable {
        emit Fallback(msg.sender, msg.value);
    }

    function receiveTokens(uint256 amt) external payable {
        emit Received(msg.sender, amt);
    }

    function getBalance() external view returns (uint256) {
        return address(this).balance;
    }
}
