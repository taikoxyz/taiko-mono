// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "test/shared/thirdparty/Multicall3.sol";
import "src/layer2/governance/DelegateController.sol";
import "test/shared/DeployCapability.sol";
import "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";


contract TransferL2ContractOwnership is DeployCapability {
    address public delegateOwner = 0xF7176c3aC622be8bab1B839b113230396E6877ab;
    address public multicall3 = 0xcA11bde05977b3631167028862bE2a173976CA11;

    uint256 public privateKey = vm.envUint("PRIVATE_KEY");

    modifier broadcast() {
        require(privateKey != 0, "invalid private key");
        vm.startBroadcast(privateKey);
        _;
        vm.stopBroadcast();
    }

    function run() external broadcast {
        Multicall3.Call3[] memory calls = new Multicall3.Call3[](1);

        calls[0].target = 0x8113A6f7a3D5B273Fa96E89D1F1D6eFfBC9042A2;
        calls[0].allowFailure = false;
        calls[0].callData = abi.encodeCall(Ownable2StepUpgradeable.transferOwnership, (0x1D2D1bb9D180541E88a6a682aCf3f61c1605B190));

        Controller.Action memory dcall = Controller.Action({
            target: multicall3,
            value:0,
            data: abi.encodeCall(Multicall3.aggregate3, (calls))
        });

        IBridge.Message memory message = IBridge.Message({
            id: 0,
            fee: 0,
            gasLimit: 5_000_000,
            from: msg.sender,
            srcChainId: 560_048,
            srcOwner: msg.sender,
            destChainId: 167_013,
            destOwner: delegateOwner,
            to: delegateOwner,
            value: 0,
            data: abi.encodeCall(DelegateController.onMessageInvocation, (abi.encodePacked(uint64(0), abi.encode(dcall))))
        });

        IBridge(0x6a4cf607DaC2C4784B7D934Bcb3AD7F2ED18Ed80).sendMessage(message);
    }
}
