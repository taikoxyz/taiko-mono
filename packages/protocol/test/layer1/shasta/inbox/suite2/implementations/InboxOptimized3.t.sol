// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../InboxTest.t.sol";
import "../TestInbox.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/// @title InboxOptimized3Test
/// @notice Test suite for Optimized3 Inbox implementation
/// @custom:security-contact security@taiko.xyz
contract InboxOptimized3Test is InboxTest {
    function deployInbox() internal override returns (IInbox) {
        // TODO: Deploy actual InboxOptimized3 implementation
        // For now, using the same TestInbox
        TestInbox impl = new TestInbox();
        
        ERC1967Proxy proxy = new ERC1967Proxy(
            address(impl),
            abi.encodeCall(impl.init, (address(this), GENESIS_BLOCK_HASH))
        );
        
        TestInbox inboxProxy = TestInbox(address(proxy));
        inboxProxy.setConfig(getDefaultConfig());
        
        return IInbox(address(proxy));
    }
}