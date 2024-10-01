// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import "../../test/shared/DeployCapability.sol";
import "../../contracts/layer2/hekla/HeklaTaikoL2.sol";
import "../../contracts/shared/bridge/Bridge.sol";
import "../../contracts/shared/common/AddressManager.sol";
import "../../test/shared/thirdparty/Multicall3.sol";
import "../../contracts/layer2/DelegateOwner.sol";

contract UpgradeHeklaOntakeL2 is DeployCapability {
    address public delegateOwner = 0x95F6077C7786a58FA070D98043b16DF2B1593D2b;
    address public multicall3 = 0xcA11bde05977b3631167028862bE2a173976CA11;

    uint256 public privateKey = vm.envUint("PRIVATE_KEY");
    address public newHeklaTaikoL2 = vm.envAddress("NEW_HEKLA_TAIKO_L2");
    address public newBridge = vm.envAddress("NEW_BRIDGE");
    address public newAddressManager = vm.envAddress("NEW_ADDRESS_MANAGER");

    modifier broadcast() {
        require(privateKey != 0, "invalid private key");
        vm.startBroadcast(privateKey);
        _;
        vm.stopBroadcast();
    }

    function run() external broadcast {
        Multicall3.Call3[] memory calls = new Multicall3.Call3[](4);
        // TaikoL2
        calls[0].target = 0x1670090000000000000000000000000000010001;
        calls[0].allowFailure = false;
        calls[0].callData = abi.encodeCall(UUPSUpgradeable.upgradeTo, (newHeklaTaikoL2));
        // Bridge
        calls[1].target = 0x1670090000000000000000000000000000000001;
        calls[1].allowFailure = false;
        calls[1].callData = abi.encodeCall(UUPSUpgradeable.upgradeTo, (newBridge));
        // Rollup address manager
        calls[2].target = 0x1670090000000000000000000000000000010002;
        calls[2].allowFailure = false;
        calls[2].callData = abi.encodeCall(UUPSUpgradeable.upgradeTo, (newAddressManager));
        // Shared address manager
        calls[3].target = 0x1670090000000000000000000000000000000006;
        calls[3].allowFailure = false;
        calls[3].callData = abi.encodeCall(UUPSUpgradeable.upgradeTo, (newAddressManager));

        DelegateOwner.Call memory dcall = DelegateOwner.Call({
            txId: 0,
            target: multicall3,
            isDelegateCall: true,
            txdata: abi.encodeCall(Multicall3.aggregate3, (calls))
        });

        IBridge.Message memory message = IBridge.Message({
            id: 0,
            fee: 0,
            gasLimit: 3_000_000,
            from: msg.sender,
            srcChainId: 17_000,
            srcOwner: msg.sender,
            destChainId: 167_009,
            destOwner: delegateOwner,
            to: delegateOwner,
            value: 0,
            data: abi.encodeCall(DelegateOwner.onMessageInvocation, abi.encode(dcall))
        });

        IBridge(0xA098b76a3Dd499D3F6D58D8AcCaFC8efBFd06807).sendMessage(message);
    }
}
