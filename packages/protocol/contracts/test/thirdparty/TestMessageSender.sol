// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "../../bridge/IBridge.sol";

contract TestMessageSender {
    bytes32 public signal =
        0x3fd54831f488a22b28398de0c567a3b064b937f54f81739ae9bd545967f3abab;

    function sendMessage(
        IBridge.Message calldata message
    ) external payable returns (bytes32) {
        message;
        return signal;
    }
}
