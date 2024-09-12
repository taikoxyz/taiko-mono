// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../../test/shared/DeployCapability.sol";
import "../../contracts/layer1/provers/ProverSet.sol";

contract DeployLabsProverPool is DeployCapability {
    address public addressManager = 0x579f40D0BE111b823962043702cabe6Aaa290780;
    address public owner = 0x9CBeE534B5D8a6280e01a14844Ee8aF350399C7F;

    modifier broadcast() {
        vm.startBroadcast();
        _;
        vm.stopBroadcast();
    }

    function run() external broadcast {
        deployProxy({
            name: "labprover.taiko.eth",
            impl: 0x34f2B21107AfE3584949c184A1E6236FFDAC4f6F,
            data: abi.encodeCall(ProverSet.init, (owner, owner, addressManager))
        });
    }
}
