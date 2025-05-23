// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "../../Layer1Test.sol";
import "../mocks/MockTaikoInbox.sol";
import "src/layer1/preconf/impl/PreconfRouter.sol";
import "src/layer1/preconf/impl/PreconfWhitelist.sol";

abstract contract PreconfRouterTestBase is Layer1Test {
    PreconfRouter internal router;
    PreconfWhitelist internal whitelist;
    address internal routerOwner;
    address internal whitelistOwner;
    address internal fallbackPreconfer;

    function setUpOnEthereum() internal virtual override {
        routerOwner = Alice;
        whitelistOwner = Alice;
        fallbackPreconfer = Frank;

        vm.chainId(1);

        address taikoWrapper = deploy({
            name: "taiko_wrapper",
            impl: address(new MockTaikoInbox()),
            data: abi.encodeCall(MockTaikoInbox.init, (address(0)))
        });

        // Deploy and initialize whitelist first
        whitelist = PreconfWhitelist(
            deploy({
                name: "preconf_whitelist",
                impl: address(new PreconfWhitelist()),
                data: abi.encodeCall(PreconfWhitelist.init, (whitelistOwner, 2))
            })
        );

        // Deploy and initialize router
        router = PreconfRouter(
            deploy({
                name: "preconf_router",
                impl: address(new PreconfRouter(taikoWrapper, address(whitelist), fallbackPreconfer)),
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
