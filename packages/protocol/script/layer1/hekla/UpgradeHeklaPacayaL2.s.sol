// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import "test/shared/thirdparty/Multicall3.sol";
import "src/layer2/DelegateOwner.sol";
import "test/shared/DeployCapability.sol";
import "src/shared/bridge/Bridge.sol";
import "src/shared/common/DefaultResolver.sol";

contract UpgradeHeklaPacayaL2 is DeployCapability {
    address public delegateOwner = 0x95F6077C7786a58FA070D98043b16DF2B1593D2b;
    address public multicall3 = 0xcA11bde05977b3631167028862bE2a173976CA11;

    uint256 public privateKey = vm.envUint("PRIVATE_KEY");
    address public newTaikoAnchor = vm.envAddress("NEW_TAIKO_ANCHOR");
    address public newDelegateOwner = vm.envAddress("NEW_DELEGATE_OWNER");
    address public newResolver = vm.envAddress("NEW_RESOLVER");
    address public newSignalService = vm.envAddress("NEW_SIGNAL_SERVICE");

    modifier broadcast() {
        require(privateKey != 0, "invalid private key");
        vm.startBroadcast(privateKey);
        _;
        vm.stopBroadcast();
    }

    function run() external broadcast {
        Multicall3.Call3[] memory calls = new Multicall3.Call3[](6);
        // DelegateOwner
        calls[0].target = delegateOwner;
        calls[0].allowFailure = false;
        calls[0].callData = abi.encodeCall(UUPSUpgradeable.upgradeTo, (newDelegateOwner));
        // Taiko Anchor
        calls[1].target = 0x1670090000000000000000000000000000010001;
        calls[1].allowFailure = false;
        calls[1].callData = abi.encodeCall(UUPSUpgradeable.upgradeTo, (newTaikoAnchor));
        // Rollup resolver
        calls[2].target = 0x1670090000000000000000000000000000010002;
        calls[2].allowFailure = false;
        calls[2].callData = abi.encodeCall(UUPSUpgradeable.upgradeTo, (newResolver));
        // Shared resolver
        calls[3].target = 0x1670090000000000000000000000000000000006;
        calls[3].allowFailure = false;
        calls[3].callData = abi.encodeCall(UUPSUpgradeable.upgradeTo, (newResolver));
        // Register B_TAIKO
        calls[4].target = 0x1670090000000000000000000000000000000006;
        calls[4].allowFailure = false;
        calls[4].callData = abi.encodeCall(
            DefaultResolver.registerAddress,
            (167_009, bytes32(bytes("taiko")), 0x1670090000000000000000000000000000010001)
        );
        // SignalService
        calls[5].target = 0x1670090000000000000000000000000000000005;
        calls[5].allowFailure = false;
        calls[5].callData = abi.encodeCall(UUPSUpgradeable.upgradeTo, (newSignalService));

        DelegateOwner.Call memory dcall = DelegateOwner.Call({
            txId: 0,
            target: multicall3,
            isDelegateCall: true,
            txdata: abi.encodeCall(Multicall3.aggregate3, (calls))
        });

        IBridge.Message memory message = IBridge.Message({
            id: 0,
            fee: 0,
            gasLimit: 5_000_000,
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
