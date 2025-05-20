// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/shared/bridge/IBridge.sol";
import "src/layer2/DelegateOwner.sol";
import "test/shared/thirdparty/Multicall3.sol";
import "script/BaseScript.sol";

contract SendMessageToDelegateOwner is BaseScript {
    address public delegateOwner = 0x5995941Df88F30Ac140515AA39832db963E2f863;
    address public delegateOwnerImpl = 0x1f0511cDae2fbfD93563469dA02b82dEd320C8Bd;
    address public multicall3 = 0xcA11bde05977b3631167028862bE2a173976CA11;
    address public l1Bridge = 0xd60247c6848B7Ca29eDdF63AA924E53dB6Ddd8EC;
    address public testAddress1 =
        vm.envOr("TEST_ADDRESS_1", address(0x0000000000000000000000000000000000000000));

    function run() external broadcast {
        Multicall3.Call3[] memory calls = new Multicall3.Call3[](1);

        calls[0].target = delegateOwner;
        calls[0].allowFailure = false;
        calls[0].callData = abi.encodeCall(UUPSUpgradeable.upgradeTo, (delegateOwnerImpl));

        DelegateOwner.Call memory dcall = DelegateOwner.Call({
            txId: 1, // Has to match with DelegateOwner's nextTxId or 0
            target: multicall3,
            isDelegateCall: true,
            txdata: abi.encodeCall(Multicall3.aggregate3, (calls))
        });

        // Use https://bridge.taiko.xyz/relayer to manually trigger the message if necessary.
        IBridge.Message memory message = IBridge.Message({
            id: 0,
            fee: 0,
            gasLimit: 1_000_000, // cannot be zero
            from: msg.sender,
            srcChainId: 1,
            srcOwner: msg.sender,
            destChainId: 167_000,
            destOwner: delegateOwner,
            to: delegateOwner,
            value: 0,
            data: abi.encodeCall(DelegateOwner.onMessageInvocation, abi.encode(dcall))
        });

        IBridge(l1Bridge).sendMessage(message);
    }
}
