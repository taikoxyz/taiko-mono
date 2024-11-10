// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

abstract contract CanSayHelloWorld {
    function helloWorld() public pure returns (string memory) {
        return "helloworld";
    }
}
