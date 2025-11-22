// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import "@risc0/contracts/groth16/RiscZeroGroth16Verifier.sol";
import "src/layer1/verifiers/SP1Verifier.sol";
import "test/shared/DeployCapability.sol";
import "@risc0/contracts/groth16/RiscZeroGroth16Verifier.sol";
import "src/layer1/verifiers/Risc0Verifier.sol";

contract UpgradeVerifier is DeployCapability {
    uint256 public privateKey = vm.envUint("PRIVATE_KEY");
    address public sp1Verifier = vm.envAddress("SP1_VERIFIER");
    uint64 public taikoChainId = uint64(vm.envUint("TAIKO_CHAIN_ID"));
    address public risc0Verifier = vm.envAddress("RISC0_VERIFIER");

    modifier broadcast() {
        require(privateKey != 0, "invalid private key");
        vm.startBroadcast(privateKey);
        _;
        vm.stopBroadcast();
    }

    function run() external broadcast {
        // address sp1RemoteVerifier = address(new SuccinctVerifier());
        // address sp1VerifierImpl = address(new TaikoSP1Verifier(taikoChainId, sp1RemoteVerifier));
        // UUPSUpgradeable(sp1Verifier).upgradeTo(sp1VerifierImpl);

        // Deploy r0 groth16 verifier
        RiscZeroGroth16Verifier r0Groth16verifier =
            new RiscZeroGroth16Verifier(ControlID.CONTROL_ROOT, ControlID.BN254_CONTROL_ID);
        address risc0VerifierImpl =
            address(new Risc0Verifier(taikoChainId, address(r0Groth16verifier)));
        UUPSUpgradeable(risc0Verifier).upgradeTo(risc0VerifierImpl);
    }
}
