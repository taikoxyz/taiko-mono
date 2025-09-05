// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// Forge
import "forge-std/src/Script.sol";
import "forge-std/src/console2.sol";

// Shared contracts
import "src/shared/bridge/Bridge.sol";
import "src/shared/bridge/IBridge.sol";

// Layer2 contracts
import "src/layer2/DelegateOwner.sol";

// Layer1 contracts
import "@openzeppelin/contracts/governance/TimelockController.sol";

/// @title L2TimelockedProposalBuilder
/// @notice This script builds a timelocked proposal for sending a cross-chain message to the L2
/// DelegateOwner contract.
/// @dev The script encodes the necessary calls for the SurgeTimelockController to execute.
contract L2TimelockedProposalBuilder is Script {
    // L1 configuration
    // --------------------------------------------------------------------------
    address internal immutable l1Bridge = vm.envAddress("L1_BRIDGE");
    address internal immutable l1TimelockController = vm.envAddress("L1_TIMELOCK_CONTROLLER");

    // L2 configuration
    // --------------------------------------------------------------------------
    uint64 internal immutable l2ChainId = uint64(vm.envUint("L2_CHAINID"));
    address internal immutable l2DelegateOwner = vm.envAddress("L2_DELEGATE_OWNER");
    address internal immutable destOwner = vm.envAddress("DEST_OWNER");

    // Message configuration
    // --------------------------------------------------------------------------
    address internal immutable targetContract = vm.envAddress("TARGET_CONTRACT");
    bool internal immutable isDelegateCall = vm.envBool("IS_DELEGATE_CALL");
    uint32 internal immutable gasLimit = uint32(vm.envUint("GAS_LIMIT"));
    uint256 internal immutable fee = vm.envUint("FEE");
    uint256 internal immutable value = vm.envUint("VALUE");

    // Timelock configuration
    // --------------------------------------------------------------------------
    uint256 internal immutable timelockDelay = vm.envUint("TIMELOCK_DELAY");

    modifier broadcast() {
        vm.startBroadcast();
        _;
        vm.stopBroadcast();
    }

    function run() external broadcast {
        require(l1Bridge != address(0), "config: L1_BRIDGE");
        require(l1TimelockController != address(0), "config: L1_TIMELOCK_CONTROLLER");
        require(l2ChainId != 0, "config: L2_CHAINID");
        require(l2DelegateOwner != address(0), "config: L2_DELEGATE_OWNER");
        require(targetContract != address(0), "config: TARGET_CONTRACT");

        // Build the proposal
        // --------------------------------------------------------------------------
        bytes memory proposalData = buildTimelockedProposal();

        console2.log("Proposal Bytes: ");
        console2.logBytes(proposalData);
        console2.log("----------------\n");

        // Write the proposal data to a JSON file
        // --------------------------------------------------------------------------

        console2.log("** Timelocked proposal built successfully");
    }

    function buildTimelockedProposal() internal view returns (bytes memory) {
        // Step 1: Encode the DelegateOwner call
        bytes memory delegateOwnerCall = encodeDelegateOwnerCall();

        // Step 2: Encode the Bridge message
        IBridge.Message memory bridgeMessage = IBridge.Message({
            id: 0, // Will be set by the bridge
            from: address(0), // Will be set by the bridge
            srcChainId: 0, // Will be set by the bridge
            destChainId: l2ChainId,
            srcOwner: l1TimelockController,
            destOwner: destOwner,
            to: l2DelegateOwner,
            value: value,
            data: delegateOwnerCall,
            gasLimit: gasLimit,
            fee: uint64(fee)
        });

        // Step 3: Encode the Bridge.sendMessage call
        bytes memory bridgeCallData =
            abi.encodeWithSelector(Bridge.sendMessage.selector, bridgeMessage);

        console2.log("Bridge call: ");
        console2.logBytes(bridgeCallData);
        console2.log("----------------\n");

        bytes memory timelockScheduleData = abi.encodeWithSelector(
            TimelockController.schedule.selector,
            l1Bridge, // target
            value + fee, // value + fee
            bridgeCallData, // payload
            bytes32(0), // predecessor (no dependency)
            bytes32(0), // salt (no specific salt)
            timelockDelay // delay
        );

        return timelockScheduleData;
    }

    function encodeDelegateOwnerCall() internal view returns (bytes memory) {
        // Create the Call struct for DelegateOwner.onMessageInvocation
        DelegateOwner.Call memory call = DelegateOwner.Call({
            txId: 0, // Will be set by DelegateOwner
            target: targetContract,
            isDelegateCall: isDelegateCall,
            txdata: vm.envBytes("CALL_DATA")
        });

        bytes memory encodedCall = abi.encode(call);

        console2.log("Encoded Delegate Owner call: ");
        console2.logBytes(encodedCall);
        console2.log("----------------\n");

        // Encode the call data for onMessageInvocation
        return abi.encodeWithSelector(DelegateOwner.onMessageInvocation.selector, encodedCall);
    }
}
