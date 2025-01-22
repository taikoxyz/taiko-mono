// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "../../Layer1Test.sol";
import "../mocks/MockTaikoInbox.sol";
import "src/layer1/preconf/impl/PreconfRouter.sol";
import "src/layer1/preconf/impl/PreconfWhitelist.sol";

abstract contract RouterTestBase is Layer1Test {
    PreconfRouter internal router;
    PreconfWhitelist internal whitelist;
    address internal routerOwner;
    address internal whitelistOwner;
    bytes internal testTxList = "test transaction list";
    bytes32 internal testTxListHash;
    uint256 internal initialTimestamp;

    function setUpOnEthereum() internal virtual override {
        routerOwner = Alice;
        whitelistOwner = Alice;
        testTxListHash = keccak256(testTxList);
        initialTimestamp = block.timestamp;

        vm.chainId(1);

        deploy({
            name: "taiko",
            impl: address(new MockTaikoInbox(address(resolver))),
            data: abi.encodeCall(MockTaikoInbox.init, (address(0)))
        });

        // Deploy and initialize whitelist first
        whitelist = PreconfWhitelist(
            deploy({
                name: "preconf_whitelist",
                impl: address(new PreconfWhitelist(address(resolver))),
                data: abi.encodeCall(PreconfWhitelist.init, (whitelistOwner))
            })
        );

        // Deploy and initialize router
        router = PreconfRouter(
            deploy({
                name: "preconf_router",
                impl: address(new PreconfRouter(address(resolver), 60, 0.01 ether)),
                data: abi.encodeCall(PreconfRouter.init, (routerOwner))
            })
        );
    }

    function addOperators(address[] memory operators) internal {
        for (uint256 i = 0; i < operators.length; i++) {
            vm.prank(whitelistOwner);
            whitelist.addOperator(operators[i]);
        }
    }
}
