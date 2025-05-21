// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "forge-std/src/Test.sol";
import "src/layer2/DelegateController.sol";
import "test/shared/thirdparty/Multicall3.sol";
import "src/shared/bridge/IBridge.sol";

abstract contract BuildProposal is Test {
    // L2 contracts
    address public constant L2_DELEGATE_OWNER = 0xEfc270A7c1B34683Ff51e7cCe1B64626293237ed;
    address public constant L2_TAIKO_TOKEN = 0xA9d23408b9bA935c230493c40C73824Df71A0975;
    address public constant L2_MULLTICALL3 = 0xcA11bde05977b3631167028862bE2a173976CA11;
    address public constant L2_PERMISSIONLESS_EXECUTOR = 0x4EBeC8a624ac6f01Bb6C7F13947E6Af3727319CA;

    // L1 contracts
    address public constant L1_BRIDGE = 0xd60247c6848B7Ca29eDdF63AA924E53dB6Ddd8EC;
    address public constant L1_TAIKO_DAO_CONTROLLER = 0xfC3C4ca95a8C4e5a587373f1718CD91301d6b2D3;

    function buildL1Actions() internal pure virtual returns (Controller.Action[] memory);
    function buildL2Actions() internal pure virtual returns (Controller.Action[] memory);

    function buildUpgradeAction(
        address _target,
        address _newImpl
    )
        internal
        pure
        returns (Controller.Action memory)
    {
        return Controller.Action({
            target: _target,
            value: 0,
            data: abi.encodeCall(UUPSUpgradeable.upgradeTo, (_newImpl))
        });
    }

    function buildProposal(uint64 executionId) internal pure {
        Controller.Action[] memory l1Actions = buildL1Actions();
        Controller.Action[] memory allActions = new Controller.Action[](l1Actions.length + 1);

        for (uint256 i; i < l1Actions.length; ++i) {
            allActions[i] = l1Actions[i];
            require(allActions[i].target == L1_TAIKO_DAO_CONTROLLER, "TARGET IS NOT_CONTROLLER");
        }

        Controller.Action[] memory l2Actions = buildL2Actions();

        IBridge.Message memory message;
        message.destChainId = 167_000;
        message.destOwner = L2_PERMISSIONLESS_EXECUTOR;
        message.data = abi.encodeCall(
            DelegateController.onMessageInvocation, (abi.encode(executionId, l2Actions))
        );

        allActions[l1Actions.length] = Controller.Action({
            target: L1_BRIDGE,
            value: 0,
            data: abi.encodeCall(IBridge.sendMessage, (message))
        });

        for (uint256 i; i < allActions.length; ++i) {
            console2.log("ACTION #", 1 + i, "==========================");
            console2.log("target:", allActions[i].target);
            if (allActions[i].value > 0) {
                console2.log("value:", allActions[i].value);
            }

            console2.log("data:");
            console2.logBytes(allActions[i].data);
            console2.log("");
        }
    }
}
