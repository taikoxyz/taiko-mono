pragma solidity ^0.8.24;

import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import "test/shared/thirdparty/Multicall3.sol";
import "src/layer2/DelegateOwner.sol";
import "test/shared/DeployCapability.sol";
import "src/shared/bridge/Bridge.sol";

contract UpgradeHeklaPacayaL2 is DeployCapability {
    address public delegateOwner = 0x95F6077C7786a58FA070D98043b16DF2B1593D2b;
    address public multicall3 = 0xcA11bde05977b3631167028862bE2a173976CA11;

    uint256 public privateKey = vm.envUint("PRIVATE_KEY");
    address public onlyOwnerBridgeImpl = vm.envAddress("ONLY_OWNER_BRIDGE_IMPL");
    address public bridgeImpl = vm.envAddress("BRIDGE_IMPL");
    address public sharedAddressManager = vm.envAddress("SHARED_ADDRESS_MANAGER");

    modifier broadcast() {
        require(privateKey != 0, "invalid private key");
        vm.startBroadcast(privateKey);
        _;
        vm.stopBroadcast();
    }

    function run() external broadcast {
        Multicall3.Call3[] memory calls = new Multicall3.Call3[](3);
        // bridge upgrades to onlyOwnerBridgeImpl
        calls[0].target = 0x1670090000000000000000000000000000000001;
        calls[0].allowFailure = false;
        calls[0].callData = abi.encodeCall(UUPSUpgradeable.upgradeTo, (onlyOwnerBridgeImpl));
        // init to store new sharedAddressManager
        calls[1].target = 0x1670090000000000000000000000000000000001;
        calls[1].allowFailure = false;
        calls[1].callData = abi.encodeCall(Bridge.init, (delegateOwner, sharedAddressManager));
        // bridge upgrades to original bridgeImpl
        calls[2].target = 0x1670090000000000000000000000000000000001;
        calls[2].allowFailure = false;
        calls[2].callData = abi.encodeCall(UUPSUpgradeable.upgradeTo, (bridgeImpl));

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
