// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "src/layer1/governance/TaikoDAOController.sol";
import "forge-std/src/Test.sol";
import "src/layer2/DelegateOwner.sol";
import "test/shared/thirdparty/Multicall3.sol";
import "src/shared/bridge/IBridge.sol";

abstract contract BuildProposal is Test {
    // L2 Contracts
    address public constant L2_DELEGATE_OWNER_PROXY = 0xEfc270A7c1B34683Ff51e7cCe1B64626293237ed;
    address public constant L2_TAIKO_TOKEN = 0xA9d23408b9bA935c230493c40C73824Df71A0975;
    address public constant L2_MULLTICALL3 = 0xcA11bde05977b3631167028862bE2a173976CA11;
    address public constant L2_EXECUTOR = address(0); // TODO

    // L1 contracts
    address public constant L1_BRIDGE = 0xd60247c6848B7Ca29eDdF63AA924E53dB6Ddd8EC;
    address public constant L1_TAIKO_DAO_CONTROLLER = 0xfC3C4ca95a8C4e5a587373f1718CD91301d6b2D3;

    function buildL1Calls() internal pure virtual returns (TaikoDAOController.Call[] memory);
    function buildL2Calls() internal pure virtual returns (Multicall3.Call3[] memory);

    function buildProposal(uint64 _l2DelegateOwnerNextTxId) internal pure {
        TaikoDAOController.Call[] memory l1Calls = buildL1Calls();
        TaikoDAOController.Call[] memory allCalls =
            new TaikoDAOController.Call[](l1Calls.length + 1);

        for (uint256 i; i < l1Calls.length; ++i) {
            allCalls[i] = l1Calls[i];
            require(allCalls[i].target == L1_TAIKO_DAO_CONTROLLER, "TARGET IS NOT_CONTROLLER");
        }

        IBridge.Message memory message;
        message.destChainId = 167_000;
        message.srcChainId = 1;
        message.destOwner = L2_EXECUTOR;
        message.data = abi.encodeCall(
            DelegateOwner.onMessageInvocation,
            (
                abi.encode(
                    DelegateOwner.Call({
                        txId: _l2DelegateOwnerNextTxId,
                        target: L2_MULLTICALL3,
                        isDelegateCall: true,
                        txdata: abi.encodeCall(Multicall3.aggregate3, (buildL2Calls()))
                    })
                )
            )
        );
        message.to = L2_DELEGATE_OWNER_PROXY;

        allCalls[l1Calls.length] = TaikoDAOController.Call({
            target: L1_BRIDGE,
            value: 0,
            data: abi.encodeCall(IBridge.sendMessage, (message))
        });

        for (uint256 i; i < allCalls.length; ++i) {
            console2.log("ACTION #", 1 + i, "==========================");
            console2.log(allCalls[i].target);
            console2.log(allCalls[i].value);
            console2.logBytes(allCalls[i].data);
            console2.log("");
        }
    }
}
