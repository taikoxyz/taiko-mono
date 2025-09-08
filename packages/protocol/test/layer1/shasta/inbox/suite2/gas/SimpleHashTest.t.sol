// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { InboxOptimized4 } from "contracts/layer1/shasta/impl/InboxOptimized4.sol";
import { IInbox } from "contracts/layer1/shasta/iface/IInbox.sol";
import { ICheckpointManager } from "src/shared/based/iface/ICheckpointManager.sol";

/// @title SimpleHashTest  
/// @notice Simple test for InboxOptimized4 hash functions without external dependencies
contract SimpleHashTest {
    InboxOptimized4 public optimizedInbox;

    constructor() {
        // Create sample configuration
        IInbox.Config memory config = IInbox.Config({
            bondToken: address(0x123),
            checkpointManager: address(0x456),
            proofVerifier: address(0x789),
            proposerChecker: address(0xabc),
            provingWindow: 3600,
            extendedProvingWindow: 7200,
            maxFinalizationCount: 10,
            finalizationGracePeriod: 1800,
            ringBufferSize: 1024,
            basefeeSharingPctg: 50,
            minForcedInclusionCount: 1,
            forcedInclusionDelay: 300,
            forcedInclusionFeeInGwei: 10
        });

        optimizedInbox = new InboxOptimized4(config);
    }

    function testHashTransition() external view returns (bytes32) {
        IInbox.Transition memory transition = IInbox.Transition({
            proposalHash: keccak256("proposal1"),
            parentTransitionHash: keccak256("parent1"),
            checkpoint: ICheckpointManager.Checkpoint({
                blockNumber: 12345,
                blockHash: keccak256("block1"),
                stateRoot: keccak256("state1")
            }),
            designatedProver: address(0x111),
            actualProver: address(0x222)
        });

        return optimizedInbox.hashTransition(transition);
    }
}