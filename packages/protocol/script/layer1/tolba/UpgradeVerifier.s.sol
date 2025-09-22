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
        address r0Verifier = 0xD1359ba7297e207b9B2519B0E1e15b0E0c8b790e;
        address sp1Verifier = 0x81d64E57E24AFae7E941976AB5A2976b390eAcD8;
        address sgxGethVerifier = 0xA75c8FCB2609eB66E0DAdd4ECA438870F4f22FE8;
        address sgxRethVerifier = 0x237506C97895771Ae3177dF31FC40D27c99fD382;

    UUPSUpgradeable(proofVerifier).upgradeTo(
            address(new TolbaVerifier(taikoInbox, sgxGethVerifier, sgxRethVerifier, r0Verifier, sp1Verifier))
        );
    }
}
