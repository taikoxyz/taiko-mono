// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import "test/shared/thirdparty/Multicall3.sol";
import "src/layer2/DelegateOwner.sol";
import "test/shared/DeployCapability.sol";
import "src/shared/bridge/Bridge.sol";
import "src/shared/common/DefaultResolver.sol";

contract UpgradeMainnetPacayaL2 is DeployCapability {
    uint256 public privateKey = vm.envUint("PRIVATE_KEY");
    address public newTaikoAnchor = vm.envAddress("NEW_TAIKO_ANCHOR");
    address public newDelegateOwner = vm.envAddress("NEW_DELEGATE_OWNER");
    address public newSignalService = vm.envAddress("NEW_SIGNAL_SERVICE");
    address public delegateOwner = vm.envAddress("DELEGATE_OWNER");
    address public multicall3 = vm.envAddress("MULTI_CALL_3");

    modifier broadcast() {
        require(privateKey != 0, "invalid private key");
        vm.startBroadcast(privateKey);
        _;
        vm.stopBroadcast();
    }

    function run() external broadcast {
        Multicall3.Call3[] memory calls = new Multicall3.Call3[](3);
        // DelegateOwner
        calls[0].target = delegateOwner;
        calls[0].allowFailure = false;
        calls[0].callData = abi.encodeCall(UUPSUpgradeable.upgradeTo, (newDelegateOwner));
        // Taiko Anchor
        calls[1].target = 0x1670000000000000000000000000000000010001;
        calls[1].allowFailure = false;
        calls[1].callData = abi.encodeCall(UUPSUpgradeable.upgradeTo, (newTaikoAnchor));
        // SignalService
        calls[2].target = 0x1670000000000000000000000000000000000005;
        calls[2].allowFailure = false;
        calls[2].callData = abi.encodeCall(UUPSUpgradeable.upgradeTo, (newSignalService));

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
            srcChainId: 1,
            srcOwner: msg.sender,
            destChainId: 167_000,
            destOwner: delegateOwner,
            to: delegateOwner,
            value: 0,
            data: abi.encodeCall(DelegateOwner.onMessageInvocation, abi.encode(dcall))
        });

        IBridge(0xd60247c6848B7Ca29eDdF63AA924E53dB6Ddd8EC).sendMessage(message);
    }
}
