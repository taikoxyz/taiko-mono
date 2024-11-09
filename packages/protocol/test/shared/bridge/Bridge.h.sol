// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../CommonTest.sol";

// A contract which is not our ErcXXXTokenVault
// Which in such case, the sent funds are still recoverable, but not via the
// onMessageRecall() but Bridge will send it back
contract UntrustedSendMessageRelayer {
    function sendMessage(
        address bridge,
        IBridge.Message memory message,
        uint256 message_value
    )
        public
        returns (bytes32 msgHash, IBridge.Message memory updatedMessage)
    {
        return IBridge(bridge).sendMessage{ value: message_value }(message);
    }
}

// A malicious contract that attempts to exhaust gas
contract MaliciousContract2 {
    fallback() external payable {
        while (true) { } // infinite loop
    }
}

// Non malicious contract that does not exhaust gas
contract NonMaliciousContract1 {
    fallback() external payable { }
}
