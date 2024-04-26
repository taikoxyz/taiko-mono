// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "forge-std/src/console2.sol";
import "forge-std/src/Script.sol";

import "../contracts/L1/hooks/AssignmentHook.sol";
import "../contracts/L1/tiers/ITierProvider.sol";
import "../contracts/L1/TaikoData.sol";

contract AssembleProposeBlock is Script {
    uint256 public proverPrivateKey = vm.envUint("PROVER_PRIVATE_KEY");
    bytes public txListBytes = vm.envBytes("TX_LIST_BYTES");
    address public hookAddress = vm.envAddress("HOOK_ADDRESS");
    address public taikoL1Address = vm.envAddress("TAIKO_L1_ADDRESS");
    address public l1ProposerAddress = vm.envAddress("L1_PROPOSER_ADDRESS");
    address public assignedProver = vm.envAddress("ASSIGNED_PROVER");
    uint256 public l2ChainId = vm.envUint("L2_CHAIN_ID");

    function run() external {
        TaikoData.TierFee[] memory tierFees = new TaikoData.TierFee[](2);

        tierFees[0] = TaikoData.TierFee(LibTiers.TIER_SGX, 1);
        tierFees[1] = TaikoData.TierFee(LibTiers.TIER_SGX_ZKVM, 2);

        AssignmentHook.ProverAssignment memory assignment = AssignmentHook.ProverAssignment({
            feeToken: address(0),
            expiry: 0,
            maxBlockId: 0,
            maxProposedIn: 0,
            metaHash: bytes32(0),
            parentMetaHash: bytes32(0),
            tierFees: tierFees,
            signature: new bytes(0)
        });

        bytes32 assignmentHash = AssignmentHook(hookAddress).hashAssignment(
            assignment, taikoL1Address, l1ProposerAddress, assignedProver, keccak256(txListBytes)
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(proverPrivateKey, assignmentHash);
        assignment.signature = abi.encodePacked(r, s, v);

        TaikoData.HookCall[] memory hookCalls = new TaikoData.HookCall[](1);
        hookCalls[0] = TaikoData.HookCall({
            hook: hookAddress,
            data: abi.encode(AssignmentHook.Input({ assignment: assignment, tip: 0 }))
        });

        bytes memory params = abi.encode(
            TaikoData.BlockParams({
                assignedProver: assignedProver,
                coinbase: l1ProposerAddress,
                extraData: bytes32(0),
                parentMetaHash: bytes32(0),
                hookCalls: hookCalls,
                signature: new bytes(0) // TODO: for the first EOA proposer, this value can be zero
                    // later on.
             })
        );

        console2.log("encoded TaikoData.BlockParams: ");
        console2.logBytes(params);
    }
}
