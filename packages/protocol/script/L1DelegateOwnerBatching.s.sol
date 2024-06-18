// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "../test/DeployCapability.sol";
import "../contracts/L2/DelegateOwner.sol";
import "../contracts/bridge/Bridge.sol";
import "../test/common/TestMulticall3.sol";

// forge script \
// --rpc-url https://mainnet.infura.io/v3/... \
// --private-key ... \
// --legacy \
// --broadcast \
// script/DeployL2DelegateOwner.s.sol
contract L2DelegateOwnerBatching is DeployCapability {
    address public l2Admin = 0x8F13E3a9dFf52e282884aA70eAe93F57DD601298; // same
    address public l2DelegateOwner = 0x08c82ab90f86BF8d98440b96754a67411D656130;
    address public constant l2Multicall3 = 0xcA11bde05977b3631167028862bE2a173976CA11;

    modifier broadcast() {
        vm.startBroadcast();
        _;
        vm.stopBroadcast();
    }

    function run() external broadcast {
        TestMulticall3.Call3[] memory calls = new TestMulticall3.Call3[](2);
        calls[0].target = 0x08c82ab90f86BF8d98440b96754a67411D656130;
        calls[0].allowFailure = false;
        calls[0].callData =
            abi.encodeCall(DelegateOwner.setAdmin, (0x4757D97449acA795510b9f3152C6a9019A3545c3));

        calls[1].target = 0xf4707c2821b3067bdF9c4D48eB133851FF3e7ea7;
        calls[1].allowFailure = false;
        calls[1].callData =
            abi.encodeCall(UUPSUpgradeable.upgradeTo, (0x0167000000000000000000000000000000010002));

        sendMessage(0, calls);
    }

    function sendMessage(uint64 txId, TestMulticall3.Call3[] memory calls) internal {
        IBridge.Message memory message;
        message.fee = 20_000_000_000_000;
        message.gasLimit = 2_000_000;
        message.destChainId = 167_000;

        // TODO: What if l2Admin becomes 0x0?
        message.srcOwner = l2Admin;
        message.destOwner = l2Admin;
        message.to = l2DelegateOwner;

        message.data = abi.encodeCall(
            DelegateOwner.onMessageInvocation,
            abi.encode(
                DelegateOwner.Call(
                    txId,
                    l2Multicall3,
                    true, // DELEGATECALL
                    abi.encodeCall(TestMulticall3.aggregate3, (calls))
                )
            )
        );

        Bridge(0xd60247c6848B7Ca29eDdF63AA924E53dB6Ddd8EC).sendMessage{ value: message.fee }(
            message
        );
    }
}
