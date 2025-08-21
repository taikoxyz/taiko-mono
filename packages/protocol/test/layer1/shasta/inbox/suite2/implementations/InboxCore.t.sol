// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../InboxTest.t.sol";
import "../TestInbox.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/// @title InboxCoreTest
/// @notice Test suite for core Inbox implementation
/// @custom:security-contact security@taiko.xyz
contract InboxCoreTest is InboxTest {
    function deployInbox() internal override returns (IInbox) {
        // Deploy implementation
        TestInbox impl = new TestInbox();
        
        // Deploy proxy with initialization
        ERC1967Proxy proxy = new ERC1967Proxy(
            address(impl),
            abi.encodeCall(impl.init, (address(this), GENESIS_BLOCK_HASH))
        );
        
        // Set config on the proxy
        TestInbox inboxProxy = TestInbox(address(proxy));
        inboxProxy.setConfig(getDefaultConfig());
        
        return IInbox(address(proxy));
    }
}