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
    address public constant L2_DELEGATE_OWNER = 0xEfc270A7c1B34683Ff51e7cCe1B64626293237ed;
    address public constant L2_TAIKO_TOKEN = 0xA9d23408b9bA935c230493c40C73824Df71A0975;
    address public constant L2_MULLTICALL3 = 0xcA11bde05977b3631167028862bE2a173976CA11;
    address public constant L2_PERMISSIONLESS_EXECUTOR = 0x4EBeC8a624ac6f01Bb6C7F13947E6Af3727319CA;

    // L1 contracts
    address public constant L1_BRIDGE = 0xd60247c6848B7Ca29eDdF63AA924E53dB6Ddd8EC;
    address public constant L1_TAIKO_DAO_CONTROLLER = 0xfC3C4ca95a8C4e5a587373f1718CD91301d6b2D3;

    function buildL1Calls() internal pure virtual returns (TaikoDAOController.Call[] memory);
    function buildL2Calls() internal pure virtual returns (Multicall3.Call3[] memory);

    function buildL1UpgradeCall(
        address _target,
        address _newImpl
    )
        internal
        pure
        returns (TaikoDAOController.Call memory)
    {
        return TaikoDAOController.Call({
            target: _target,
            value: 0,
            data: abi.encodeCall(UUPSUpgradeable.upgradeTo, (_newImpl))
        });
    }

    function buildL2UpgradeCall(
        address _target,
        address _newImpl
    )
        internal
        pure
        returns (Multicall3.Call3 memory)
    {
        return Multicall3.Call3({
            target: _target,
            allowFailure: false,
            callData: abi.encodeCall(UUPSUpgradeable.upgradeTo, (_newImpl))
        });
    }

    function buildProposal(
        uint64 nextTxId,
        bool l2AllowFailure,
        address l2Executor
    )
        internal
        pure
    {
        require(l2Executor != address(0), "NO EXECUTOR");
        TaikoDAOController.Call[] memory l1Calls = buildL1Calls();
        TaikoDAOController.Call[] memory allCalls =
            new TaikoDAOController.Call[](l1Calls.length + 1);

        for (uint256 i; i < l1Calls.length; ++i) {
            allCalls[i] = l1Calls[i];
            require(allCalls[i].target == L1_TAIKO_DAO_CONTROLLER, "TARGET IS NOT_CONTROLLER");
        }

        Multicall3.Call3[] memory l2Calls = buildL2Calls();
        for (uint256 i; i < l2Calls.length; ++i) {
            l2Calls[i].allowFailure = l2AllowFailure;
        }

        IBridge.Message memory message;
        message.destChainId = 167_000;
        message.destOwner = l2Executor;
        message.data = abi.encodeCall(
            DelegateOwner.onMessageInvocation,
            (
                abi.encode(
                    DelegateOwner.Call({
                        txId: nextTxId,
                        target: L2_MULLTICALL3,
                        isDelegateCall: true,
                        txdata: abi.encodeCall(Multicall3.aggregate3, (l2Calls))
                    })
                )
            )
        );
        message.to = L2_DELEGATE_OWNER;

        allCalls[l1Calls.length] = TaikoDAOController.Call({
            target: L1_BRIDGE,
            value: 0,
            data: abi.encodeCall(IBridge.sendMessage, (message))
        });

        for (uint256 i; i < allCalls.length; ++i) {
            console2.log("ACTION #", 1 + i, "==========================");
            console2.log("target:", allCalls[i].target);
            if (allCalls[i].value > 0) {
                console2.log("value:", allCalls[i].value);
            }

            console2.log("data:");
            console2.logBytes(allCalls[i].data);
            console2.log("");
        }
    }
}
