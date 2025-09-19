// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test, Vm } from "forge-std/src/Test.sol";
import { console } from "forge-std/src/console.sol";
import { DevnetShastaInbox } from "../../../../../contracts/layer1/shasta/impl/DevnetShastaInbox.sol";
import { ShastaForkRouter } from "../../../../../contracts/layer1/fork-router/ShastaForkRouter.sol";
import { CheckpointManager } from "../../../../../contracts/shared/based/impl/CheckpointManager.sol";
import { PreconfWhitelist } from "../../../../../contracts/layer1/preconf/impl/PreconfWhitelist.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";

/// @title ProposeGasDevnetFork
/// @notice Gas usage test for actual propose transaction from devnet
/// @dev Transaction: 0xfddbfe564da882e69d2165be2d41f20087bdf65de7221628f6ef27867e9dbbc4
contract ProposeGasDevnetFork is Test {
    // Devnet configuration
    string constant DEVNET_RPC = "https://l1rpc.internal.taiko.xyz";
    uint256 constant FORK_BLOCK = 10218;
    address payable constant ROUTER_ADDRESS = payable(0x3b37a799290950fef954dfF547608baC52A12571);
    address payable constant INBOX_ADDRESS = payable(0x8c42D6a0Ff518C99c7215097AD7b1d9DCE20765B);
    address constant CHECKPOINT_MANAGER = 0xf307b51d2e2dBf72D69a444AEC955b8FD23C22A0;
    address constant PROPOSER = 0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC;
    address constant OWNER = 0x4779d18931B35540F84b0cd0e9633855B84df7b8;
    address constant PRECONF_WHITELIST_IMPL = 0x63Ec87f54cCed71B0DC879ce6cEDfA6f3D582670;
    string constant TEST_DATA_PATH = "/test/layer1/shasta/inbox/suite2/testdata/devnet_tx.json";

    function setUp() public {
        vm.createSelectFork(DEVNET_RPC, FORK_BLOCK - 1);

        // Verify fork is working
        console.log("Block number:", block.number);
        console.log("Chain ID:", block.chainid);
        console.log("Transaction was at block:", FORK_BLOCK);
        console.log("Router address:", ROUTER_ADDRESS);
        console.log("Router code size:", ROUTER_ADDRESS.code.length);
    }

    /// @notice Replays the actual propose transaction from devnet to measure gas
    /// forge-config: default.isolate = true
    function test_proposeGas_actualDevnetTransaction() public {

        // Deploy DevnetShastaInbox with the provided configuration
        DevnetShastaInbox inbox = new DevnetShastaInbox(
            CHECKPOINT_MANAGER, // _checkpointManager
            0x429B4115e773a0Cf0e49c0443685dd290aE426ef, // _proofVerifier
            0xD70B7EeF93B00a3A809228498eE9b458B02308C0, // _proposerChecker
            0xa20182131658295f37C1A1EFdBDc89Eff97D9C58  // _taikoToken (bondToken)
        );

        // Deploy PreconfWhitelist with zero address as fallback operator
        PreconfWhitelist preconfWhitelist = new PreconfWhitelist(address(0));

        // Setup blob hashes
        // NOTE: This is currently failing when using in a  test that runs with isolation
        // bytes32[] memory blobHashes = new bytes32[](2);
        // blobHashes[0] = bytes32("0x1");
        // blobHashes[1] = bytes32("0x2");
        // vm.blobhashes(blobHashes);

        console.log("Deployed DevnetShastaInbox at:", address(inbox));

        // Replace code at INBOX_ADDRESS with the new inbox
        bytes memory inboxCode = address(inbox).code;
        vm.etch(INBOX_ADDRESS, inboxCode);

        // Replace code at PRECONF_WHITELIST_IMPL with the new preconf whitelist
        bytes memory actualPreconfCode = address(preconfWhitelist).code;
        vm.etch(PRECONF_WHITELIST_IMPL, actualPreconfCode);

        // Read the actual calldata
        string memory root = vm.projectRoot();
        string memory path = string.concat(root, TEST_DATA_PATH);
        string memory json = vm.readFile(path);
        bytes memory actualCalldata = vm.parseJsonBytes(json, ".calldata");

        console.log("Transaction: 0xfddbfe564da882e69d2165be2d41f20087bdf65de7221628f6ef27867e9dbbc4");
        console.log("Calldata length:", actualCalldata.length);

        // Ensure proposer has balance
        vm.deal(PROPOSER, 10000 ether);

        // Measure gas
        vm.startPrank(PROPOSER);

        vm.startSnapshotGas("shasta-devnet-propose", "actual_tx_replay");

        (bool success, bytes memory returnData) = ROUTER_ADDRESS.call(actualCalldata);

        vm.stopSnapshotGas();

        vm.stopPrank();

    }
}
