// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/layer1/fork-router/ShastaForkRouter.sol";
import "src/layer1/preconf/impl/PreconfWhitelist.sol";
import "src/layer1/verifiers/compose/ComposeVerifier.sol";
import "src/layer1/devnet/verifiers/DevnetVerifier.sol";
import { ShastaDevnetInbox } from "contracts/layer1/shasta/impl/ShastaDevnetInbox.sol";
import "test/shared/DeployCapability.sol";
import "src/layer1/shasta/impl/Inbox.sol";
import "src/layer1/fork-router/PacayaForkRouter.sol";
import "test/layer1/shasta/inbox/suite2/mocks/MockContracts.sol";
import { CodecOptimized } from "src/layer1/shasta/impl/CodecOptimized.sol";

contract UpgradeShastaL1 is DeployCapability {
    uint256 public privateKey = vm.envUint("PRIVATE_KEY");
    address payable public pacayaInbox = payable(vm.envAddress("INBOX"));
    address public sharedResolver = vm.envAddress("SHARED_RESOLVER");

    modifier broadcast() {
        require(privateKey != 0, "invalid private key");
        require(pacayaInbox != address(0), "invalid pacaya inbox");
        require(sharedResolver != address(0), "invalid shared resolver");
        require(vm.envBytes32("L2_GENESIS_HASH") != 0, "L2_GENESIS_HASH");

        vm.startBroadcast(privateKey);
        _;
        vm.stopBroadcast();
    }

    function run() external broadcast {
        // Initializable the proxy for proofVerifier to get the contract address at first.
        // Proof verifier
        address proofVerifier = address(new MockProofVerifier());
        address proposer = vm.envAddress("PROPOSER_ADDRESS");
        address shastaInitializer = vm.envAddress("SHASTA_INITIALIZER");

        address whitelist = deployProxy({
            name: "preconf_whitelist",
            impl: address(new PreconfWhitelist()),
            data: abi.encodeCall(PreconfWhitelist.init, (address(0), 0, 0))
        });
        PreconfWhitelist(whitelist).addOperator(proposer, proposer);

        address bondToken = IResolver(vm.envAddress("SHARED_RESOLVER")).resolve(
            uint64(block.chainid), "bond_token", false
        );
        address codec = address(new CodecOptimized());

        address signalService = IResolver(vm.envAddress("SHARED_RESOLVER")).resolve(
            uint64(block.chainid), "signal_service", false
        );
        
        address newFork = deployProxy({
            name: "shasta_inbox",
            impl: address(new ShastaDevnetInbox(codec, proofVerifier, whitelist, bondToken, signalService)),
            data: abi.encodeCall(Inbox.init, (address(0), shastaInitializer))
        });

        console2.log("  pacaya_inbox       :", pacayaInbox);
        console2.log("  shasta_inbox       :", newFork);
    }
}
