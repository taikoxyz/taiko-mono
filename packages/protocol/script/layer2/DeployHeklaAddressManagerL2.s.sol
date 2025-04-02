// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/shared/common/AddressManager.sol";
import "test/shared/DeployCapability.sol";
import "src/shared/bridge/Bridge.sol";
import "src/shared/bridge/OnlyOwnerBridge.sol";
import { Bridge } from "../../contracts/shared/bridge/Bridge.sol";

contract DeployHeklaAddressManagerL2 is DeployCapability {
    uint256 public privateKey = vm.envUint("PRIVATE_KEY");
    address public sharedResolver = 0x1670090000000000000000000000000000000006;
    address public delegateOwner = 0x95F6077C7786a58FA070D98043b16DF2B1593D2b;

    modifier broadcast() {
        require(privateKey != 0, "invalid private key");
        vm.startBroadcast(privateKey);
        _;
        vm.stopBroadcast();
    }

    function run() external broadcast {
        address sharedAddressManager = deployProxy({
            name: "shared_address_manager",
            impl: address(new AddressManager()),
            data: abi.encodeCall(AddressManager.init, (address(0)))
        });
        address rollupAddressManager = deployProxy({
            name: "rollup_address_manager",
            impl: address(new AddressManager()),
            data: abi.encodeCall(AddressManager.init, (address(0)))
        });
        // register copy
        copyRegister(sharedAddressManager, sharedResolver, "taiko_token");
        copyRegister(sharedAddressManager, sharedResolver, "bond_token");
        copyRegister(sharedAddressManager, sharedResolver, "bridge");
        copyRegister(sharedAddressManager, sharedResolver, "signal_service");
        copyRegister(sharedAddressManager, sharedResolver, "erc20_vault");
        copyRegister(sharedAddressManager, sharedResolver, "erc721_vault");
        copyRegister(sharedAddressManager, sharedResolver, "erc1155_vault");
        copyRegister(sharedAddressManager, sharedResolver, "bridged_erc20");
        copyRegister(sharedAddressManager, sharedResolver, "bridged_erc721");
        copyRegister(sharedAddressManager, sharedResolver, "bridged_erc1155");
        copyRegister(sharedAddressManager, sharedResolver, "taiko");
        copyRegister(rollupAddressManager, sharedResolver, "taiko_token");
        copyRegister(rollupAddressManager, sharedResolver, "bond_token");
        copyRegister(rollupAddressManager, sharedResolver, "bridge");
        copyRegister(rollupAddressManager, sharedResolver, "signal_service");
        copyRegister(rollupAddressManager, sharedResolver, "erc20_vault");
        copyRegister(rollupAddressManager, sharedResolver, "erc721_vault");
        copyRegister(rollupAddressManager, sharedResolver, "erc1155_vault");
        copyRegister(rollupAddressManager, sharedResolver, "bridged_erc20");
        copyRegister(rollupAddressManager, sharedResolver, "bridged_erc721");
        copyRegister(rollupAddressManager, sharedResolver, "bridged_erc1155");
        copyRegister(rollupAddressManager, sharedResolver, "taiko");
        // transfer ownership
        Ownable2StepUpgradeable(sharedAddressManager).transferOwnership(delegateOwner);
        Ownable2StepUpgradeable(rollupAddressManager).transferOwnership(delegateOwner);
        // Bridge
        address onlyOwnerBridgeImpl = address(new OnlyOwnerBridge());
        console2.log("only_owner_bridge", onlyOwnerBridgeImpl);
        address bridgeImpl = address(new Bridge());
        console2.log("bridge", bridgeImpl);
    }
}
