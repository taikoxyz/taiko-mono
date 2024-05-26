// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "../test/DeployCapability.sol";
import "../contracts/common/AddressManager.sol";
import "../contracts/bridge/Bridge.sol";

// Run with:
//  forge script --rpc-url  https://rpc.mainnet.taiko.xyz script/L2PostGenesisQuery.s.sol
contract L2PostGenesisQuery is DeployCapability {
    uint64 taiko_id = 167_000;

    function run() external view {
        display_general_info();

        console2.log("sam");
        AddressManager am = AddressManager(0x1670000000000000000000000000000000000006);
        console2.log("- taiko_token:", am.getAddress(taiko_id, "taiko_token"));
        console2.log("- signal_service:", am.getAddress(taiko_id, "signal_service"));
        console2.log("- bridge:", am.getAddress(taiko_id, "bridge"));
        console2.log("- erc20_vault:", am.getAddress(taiko_id, "erc20_vault"));
        console2.log("- erc721_vault:", am.getAddress(taiko_id, "erc721_vault"));
        console2.log("- erc1155_vault:", am.getAddress(taiko_id, "erc1155_vault"));

        console2.log("- signal_service@1:", am.getAddress(1, "signal_service"));
        console2.log("- bridge@1:", am.getAddress(1, "bridge"));
        console2.log("- erc20_vault@1:", am.getAddress(1, "erc20_vault"));
        console2.log("- erc721_vault@1:", am.getAddress(1, "erc721_vault"));
        console2.log("- erc1155_vault@1:", am.getAddress(1, "erc1155_vault"));

        console2.log("- bridged_erc20:", am.getAddress(taiko_id, "bridged_erc20"));
        console2.log("- bridged_erc721:", am.getAddress(taiko_id, "bridged_erc721"));
        console2.log("- bridged_erc1155:", am.getAddress(taiko_id, "bridged_erc1155"));
        console2.log("- quota_manager:", am.getAddress(taiko_id, "quota_manager"));
        console2.log("- bridge_watchdog:", am.getAddress(taiko_id, "bridge_watchdog"));

        console2.log("ram");
        am = AddressManager(0x1670000000000000000000000000000000010002);
        console2.log("- taiko_token:", am.getAddress(taiko_id, "taiko_token"));
        console2.log("- signal_service:", am.getAddress(taiko_id, "signal_service"));
        console2.log("- bridge:", am.getAddress(taiko_id, "bridge"));
        console2.log("- taiko:", am.getAddress(taiko_id, "taiko"));
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
