// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import "@risc0/contracts/groth16/RiscZeroGroth16Verifier.sol";
import { SP1Verifier as SuccinctVerifier } from "@sp1-contracts/src/v5.0.0/SP1VerifierPlonk.sol";
import "src/layer1/verifiers/TaikoSP1Verifier.sol";
import "test/shared/DeployCapability.sol";

contract UpgradeVerifier is DeployCapability {
    uint256 public privateKey = vm.envUint("PRIVATE_KEY");
    address public sp1Verifier = vm.envAddress("SP1_VERIFIER");
    uint64 public taikoChainId = uint64(vm.envUint("TAIKO_CHAIN_ID"));

    modifier broadcast() {
        require(privateKey != 0, "invalid private key");
        vm.startBroadcast(privateKey);
        _;
        vm.stopBroadcast();
    }

    function run() external broadcast {
        address sp1RemoteVerifier = address(new SuccinctVerifier());
        address sp1VerifierImpl = address(new TaikoSP1Verifier(taikoChainId, sp1RemoteVerifier));
        UUPSUpgradeable(sp1Verifier).upgradeTo(sp1VerifierImpl);
    }
}
