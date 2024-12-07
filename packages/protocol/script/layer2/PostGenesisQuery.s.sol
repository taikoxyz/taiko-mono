// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "script/BaseScript.sol";

// Run with:
//  forge script --rpc-url  https://rpc.mainnet.taiko.xyz script/PostGenesisQuery.s.sol
contract PostGenesisQuery is BaseScript {
    uint256 public constant ethereumChainId = 1;
    uint256 public constant taikoChainId = 167_000;

    function run() external view {
        display_general_info();

        console2.log("sharedResolver");
        DefaultResolver sharedResolver = DefaultResolver(0x1670000000000000000000000000000000000006);
        console2.log("- taiko_token:", sharedResolver.resolve(taikoChainId, "taiko_token", true));
        console2.log(
            "- signal_service:", sharedResolver.resolve(taikoChainId, "signal_service", true)
        );
        console2.log("- bridge:", sharedResolver.resolve(taikoChainId, "bridge", true));
        console2.log("- erc20_vault:", sharedResolver.resolve(taikoChainId, "erc20_vault", true));
        console2.log("- erc721_vault:", sharedResolver.resolve(taikoChainId, "erc721_vault", true));
        console2.log(
            "- erc1155_vault:", sharedResolver.resolve(taikoChainId, "erc1155_vault", true)
        );

        console2.log(
            "- signal_service@1:", sharedResolver.resolve(ethereumChainId, "signal_service", true)
        );
        console2.log("- bridge@1:", sharedResolver.resolve(ethereumChainId, "bridge", true));
        console2.log(
            "- erc20_vault@1:", sharedResolver.resolve(ethereumChainId, "erc20_vault", true)
        );
        console2.log(
            "- erc721_vault@1:", sharedResolver.resolve(ethereumChainId, "erc721_vault", true)
        );
        console2.log(
            "- erc1155_vault@1:", sharedResolver.resolve(ethereumChainId, "erc1155_vault", true)
        );

        console2.log(
            "- bridged_erc20:", sharedResolver.resolve(taikoChainId, "bridged_erc20", true)
        );
        console2.log(
            "- bridged_erc721:", sharedResolver.resolve(taikoChainId, "bridged_erc721", true)
        );
        console2.log(
            "- bridged_erc1155:", sharedResolver.resolve(taikoChainId, "bridged_erc1155", true)
        );
        console2.log(
            "- quota_manager:", sharedResolver.resolve(taikoChainId, "quota_manager", true)
        );
        console2.log(
            "- bridge_watchdog:", sharedResolver.resolve(taikoChainId, "bridge_watchdog", true)
        );

        console2.log("sharedResolver");
        sharedResolver = DefaultResolver(0x1670000000000000000000000000000000010002);
        console2.log("- taiko_token:", sharedResolver.resolve(taikoChainId, "taiko_token", true));
        console2.log(
            "- signal_service:", sharedResolver.resolve(taikoChainId, "signal_service", true)
        );
        console2.log("- bridge:", sharedResolver.resolve(taikoChainId, "bridge", true));
        console2.log("- taiko:", sharedResolver.resolve(taikoChainId, "taiko", true));
    }

    function display_general_info() internal view {
        console2.log("display_general_info");
        address[] memory addresses = new address[](8);
        addresses[0] = 0x1670000000000000000000000000000000010002; // ram
        addresses[1] = 0x1670000000000000000000000000000000010001; // taikoL2
        addresses[2] = 0x1670000000000000000000000000000000000006; // sam
        addresses[3] = 0x1670000000000000000000000000000000000001; // bridge
        addresses[4] = 0x1670000000000000000000000000000000000002; // e20
        addresses[5] = 0x1670000000000000000000000000000000000003; // e721
        addresses[6] = 0x1670000000000000000000000000000000000004; // e1155
        addresses[7] = 0x1670000000000000000000000000000000000005; // ss

        for (uint256 i; i < addresses.length; ++i) {
            EssentialContract c = EssentialContract(addresses[i]);
            console2.log("addr:", address(c));
            console2.log("impl:", c.impl());
            console2.log("owner:", c.owner());
            console2.log("");
        }
    }
}
