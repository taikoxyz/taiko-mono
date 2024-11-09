// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "script/BaseScript.sol";
import "src/layer1/provers/ProverSet.sol";

contract DeployLabsProverPool is BaseScript {
    address public owner = 0x9CBeE534B5D8a6280e01a14844Ee8aF350399C7F;

    function run() external broadcast {
        resolver = 0x579f40D0BE111b823962043702cabe6Aaa290780;
        deploy({
            name: "labprover",
            impl: 0x34f2B21107AfE3584949c184A1E6236FFDAC4f6F,
            data: abi.encodeCall(ProverSet.init, (owner, owner, resolver))
        });
    }
}
