// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "../../../contracts/layer1/alethia-hoodi/AlethiaHoodiInbox.sol";
import "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import "src/layer2/governance/DelegateController.sol";
import "test/shared/DeployCapability.sol";
import "test/shared/thirdparty/Multicall3.sol";

contract UpgradeInboxAndAnchor is DeployCapability {
    address public delegateOwner = 0xF7176c3aC622be8bab1B839b113230396E6877ab;

    uint256 public privateKey = vm.envUint("PRIVATE_KEY");

    modifier broadcast() {
        require(privateKey != 0, "invalid private key");
        vm.startBroadcast(privateKey);
        _;
        vm.stopBroadcast();
    }

    function run() external broadcast {
        AlethiaHoodiInbox(0xf6eA848c7d7aC83de84db45Ae28EAbf377fe0eF9)
            .upgradeTo(
                address(
                    new AlethiaHoodiInbox(
                        0xB843132A26C13D751470a6bAf5F926EbF5d0E4b8,
                        0xd9F11261AE4B873bE0f09D0Fc41d2E3F70CD8C59,
                        0xf3b83e226202ECf7E7bb2419a4C6e3eC99e963DA,
                        0x4c70b7F5E153D497faFa0476575903F9299ed811
                    )
                )
            );

        Controller.Action[] memory dcall = new Controller.Action[](1);
        dcall[0] = Controller.Action({
            target: 0x1670130000000000000000000000000000010001,
            value: 0,
            data: abi.encodeCall(
                Ownable2StepUpgradeable.upgradeTo, (0xDa4114299c2cFa39c5B8458894a5819D6FF8b702)
            )
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
            data: abi.encodeCall(
                DelegateController.onMessageInvocation,
                (abi.encodePacked(uint64(0), abi.encode(dcall)))
            )
        });

        IBridge(0x6a4cf607DaC2C4784B7D934Bcb3AD7F2ED18Ed80).sendMessage(message);
    }
}
