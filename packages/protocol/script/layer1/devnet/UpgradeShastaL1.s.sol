// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/layer1/fork-router/ShastaForkRouter.sol";
import "src/layer1/preconf/impl/PreconfWhitelist.sol";
import "src/layer1/verifiers/compose/ComposeVerifier.sol";
import "src/layer1/devnet/verifiers/DevnetVerifier.sol";
import { Inbox } from "contracts/layer1/shasta/impl/Inbox.sol";
import { DevnetShastaInbox } from "contracts/layer1/shasta/impl/DevnetShastaInbox.sol";
import "src/shared/based/impl/CheckpointManager.sol";
import "test/shared/DeployCapability.sol";
import "src/layer1/fork-router/PacayaForkRouter.sol";

contract UpgradeShastaL1 is DeployCapability {
    uint256 public privateKey = vm.envUint("PRIVATE_KEY");
    address payable public inbox = payable(vm.envAddress("INBOX"));
    address public sharedResolver = vm.envAddress("SHARED_RESOLVER");

    modifier broadcast() {
        require(privateKey != 0, "invalid private key");
        require(inbox != address(0), "invalid rollup resolver");
        require(sharedResolver != address(0), "invalid shared resolver");
        require(vm.envBytes32("L2_GENESIS_HASH") != 0, "L2_GENESIS_HASH");

        vm.startBroadcast(privateKey);
        _;
        vm.stopBroadcast();
    }

    function run() external broadcast {
        // Initializable the proxy for proofVerifier to get the contract address at first.
        // Proof verifier
        address proofVerifier = deployProxy({
            name: "proof_verifier",
            impl: address(
                new DevnetVerifier(
                    address(0), address(0), address(0), address(0), address(0), address(0)
                )
            ),
            data: abi.encodeCall(ComposeVerifier.init, (address(0)))
        });
        address proposer = vm.envAddress("PROPOSER_ADDRESS");

        address whitelist = deployProxy({
            name: "preconf_whitelist",
            impl: address(new PreconfWhitelist(proposer)),
            data: abi.encodeCall(PreconfWhitelist.init, (address(0), 2, 2))
        });
        PreconfWhitelist(whitelist).addOperator(proposer, proposer);

        address bondToken = IResolver(vm.envAddress("SHARED_RESOLVER")).resolve(
            uint64(block.chainid), "bond_token", false
        );

        address oldFork = PacayaForkRouter(inbox).newFork();
        address tempFork =
            address(new DevnetShastaInbox(address(0), proofVerifier, whitelist, bondToken));

        address shastaForkRouterAddr = deployProxy({
            name: "taiko",
            impl: address(new ShastaForkRouter(oldFork, tempFork)),
            data: abi.encodeCall(Inbox.initV3, (msg.sender, vm.envBytes32("L2_GENESIS_HASH")))
        });

        address checkPointManager = deployProxy({
            name: "checkpoint_manager",
            impl: address(
                new CheckpointManager(
                    shastaForkRouterAddr,
                    2400 // refer to DevnetShastaInbox._RING_BUFFER_SIZE
                )
            ),
            data: abi.encodeCall(CheckpointManager.init, (address(0)))
        });

        address newFork =
            address(new DevnetShastaInbox(checkPointManager, proofVerifier, whitelist, bondToken));

        console2.log("  oldFork       :", oldFork);
        console2.log("  newFork       :", newFork);

        UUPSUpgradeable(shastaForkRouterAddr).upgradeTo({
            newImplementation: address(new ShastaForkRouter(oldFork, newFork))
        });
    }
}
