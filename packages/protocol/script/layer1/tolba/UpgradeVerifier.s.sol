// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import "test/shared/DeployCapability.sol";
import { TolbaVerifier } from "../../../contracts/layer1/tolba/verifiers/TolbaVerifier.sol";
import {OpVerifier} from "../../../contracts/layer1/devnet/verifiers/OpVerifier.sol";

contract UpgradeVerifier is DeployCapability {
    uint256 public privateKey = vm.envUint("PRIVATE_KEY");

    modifier broadcast() {
        require(privateKey != 0, "invalid private key");
        vm.startBroadcast(privateKey);
        _;
        vm.stopBroadcast();
    }

    function run() external broadcast {
        address resolver = 0xfbd7067AbB85330Df5ED2B26B9Ca1b293D6e8055;
        address proofVerifier = 0xdF712d14E40b99448048Dbf9E7FC5488CCdde991;
        address taikoInbox = 0x50A576435E2D9c179124D657d804eb56A10b6999;
        address opVerifier = 0x5E652dC4033C6860b27d6860164369D15b421A42;
        address r0Verifier = 0xD1359ba7297e207b9B2519B0E1e15b0E0c8b790e;
        address sp1Verifier = 0x81d64E57E24AFae7E941976AB5A2976b390eAcD8;

        UUPSUpgradeable(proofVerifier).upgradeTo(
            address(new TolbaVerifier(taikoInbox, opVerifier, address(new OpVerifier(resolver)), r0Verifier, sp1Verifier))
        );
    }
}
