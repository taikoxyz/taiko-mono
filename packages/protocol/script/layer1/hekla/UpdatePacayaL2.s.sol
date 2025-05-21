// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import "test/shared/thirdparty/Multicall3.sol";
import "src/layer2/DelegateOwner.sol";
import "test/shared/DeployCapability.sol";
import "src/shared/bridge/Bridge.sol";
import "src/shared/common/DefaultResolver.sol";

contract UpdatePacayaL2 is DeployCapability {
    address public delegateOwner = 0x95F6077C7786a58FA070D98043b16DF2B1593D2b;
    address public multicall3 = 0xcA11bde05977b3631167028862bE2a173976CA11;

    uint256 public privateKey = vm.envUint("PRIVATE_KEY");
    address public newTaikoAnchor = vm.envAddress("NEW_TAIKO_ANCHOR");
    address public newSignalService = vm.envAddress("NEW_SIGNAL_SERVICE");
    address public newAddressManager = vm.envAddress("NEW_ADDRESS_MANAGER");

    modifier broadcast() {
        require(privateKey != 0, "invalid private key");
        vm.startBroadcast(privateKey);
        _;
        vm.stopBroadcast();
    }

    function run() external broadcast {
        Multicall3.Call3[] memory calls = new Multicall3.Call3[](4);
        // Upgrade Taiko Anchor
        calls[0].target = 0x1670090000000000000000000000000000010001;
        calls[0].allowFailure = false;
        calls[0].callData = abi.encodeCall(UUPSUpgradeable.upgradeTo, (newTaikoAnchor));
        // Upgrade Signal Service
        calls[1].target = 0x1670090000000000000000000000000000000005;
        calls[1].allowFailure = false;
        calls[1].callData = abi.encodeCall(UUPSUpgradeable.upgradeTo, (newSignalService));
        // Downgrade resolver to address manager
        calls[2].target = 0x1670090000000000000000000000000000000006;
        calls[2].allowFailure = false;
        calls[2].callData = abi.encodeCall(UUPSUpgradeable.upgradeTo, (newAddressManager));
        calls[3].target = 0x1670090000000000000000000000000000010002;
        calls[3].allowFailure = false;
        calls[3].callData = abi.encodeCall(UUPSUpgradeable.upgradeTo, (newAddressManager));

        DelegateOwner.Call memory dcall = DelegateOwner.Call({
            txId: 0,
            target: multicall3,
            isDelegateCall: true,
            txdata: abi.encodeCall(Multicall3.aggregate3, (calls))
        });

        bytes memory cData = abi.encodeCall(DelegateOwner.onMessageInvocation, abi.encode(dcall));
        console.logBytes(cData);
    }
}
