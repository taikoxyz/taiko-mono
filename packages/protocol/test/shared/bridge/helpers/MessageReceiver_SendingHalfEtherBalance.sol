// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/shared/bridge/Bridge.sol";
import "src/shared/signal/SignalService.sol";

contract MessageReceiver_SendingHalfEtherBalance is IMessageInvocable {
    receive() external payable { }

    function onMessageInvocation(bytes calldata data) public payable {
        address addr = abi.decode(data, (address));
        payable(addr).transfer(address(this).balance / 2);
    }
}
