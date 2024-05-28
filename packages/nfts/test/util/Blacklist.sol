// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { IMinimalBlacklist } from "@taiko/blacklist/IMinimalBlacklist.sol";

// Blacklist contract mock
contract MockBlacklist is IMinimalBlacklist {
    address[] public blacklist;

    constructor() {
        // hardhat accounts, #5 to #9
        blacklist.push(0x9965507D1a55bcC2695C58ba16FB37d819B0A4dc);
        blacklist.push(0x976EA74026E726554dB657fA54763abd0C3a0aa9);
        blacklist.push(0x14dC79964da2C08b23698B3D3cc7Ca32193d9955);
        blacklist.push(0x23618e81E3f5cdF7f54C3d65f7FBc0aBf5B21E8f);
        blacklist.push(0xa0Ee7A142d267C1f36714E4a8F75612F20a79720);
    }

    function isBlacklisted(address _address) public view returns (bool) {
        for (uint256 i = 0; i < blacklist.length; i++) {
            if (blacklist[i] == _address) {
                return true;
            }
        }
        return false;
    }
}
