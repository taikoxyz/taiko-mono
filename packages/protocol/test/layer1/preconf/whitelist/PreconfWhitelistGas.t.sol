// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// forge-config: default.isolate = true

import { IProposerChecker } from "src/layer1/core/iface/IProposerChecker.sol";
import { PreconfWhitelist } from "src/layer1/preconf/impl/PreconfWhitelist.sol";
import { LibPreconfConstants } from "src/layer1/preconf/libs/LibPreconfConstants.sol";
import { CommonTest } from "test/shared/CommonTest.sol";

/// @notice Gas benchmarks for checkProposer in PreconfWhitelist.
/// @dev Measures the gas cost as seen by the caller (Inbox) when doing a
///      staticcall to the ProposerChecker proxy.
contract PreconfWhitelistGasTest is CommonTest {
    PreconfWhitelist internal whitelist;
    address internal whitelistOwner;
    address internal operator;

    function setUpOnEthereum() internal override {
        // setUp() calls this inside vm.startPrank(deployer), so deployer is msg.sender
        whitelistOwner = deployer;
        operator = Bob;

        whitelist = PreconfWhitelist(
            deploy({
                name: "preconf_whitelist",
                impl: address(new PreconfWhitelist()),
                data: abi.encodeCall(PreconfWhitelist.init, (whitelistOwner))
            })
        );

        // Deploy a mock beacon block root contract that always returns a fixed value
        _setBeaconBlockRoot(bytes32(uint256(0x1234)));

        // Warp past the randomness delay so operators can be active
        vm.warp(
            LibPreconfConstants.SECONDS_IN_SLOT
                + LibPreconfConstants.SECONDS_IN_EPOCH * whitelist.RANDOMNESS_DELAY()
        );

        // Add operator (deployer is already the prank sender and is the owner)
        whitelist.addOperator(operator, address(uint160(operator) + 1000));
        for (uint256 i; i < whitelist.OPERATOR_CHANGE_DELAY(); ++i) {
            vm.warp(block.timestamp + LibPreconfConstants.SECONDS_IN_EPOCH);
        }

        // Verify operator is the selected one
        address selected = whitelist.getOperatorForCurrentEpoch();
        require(selected == operator, "operator not selected");
    }

    /// @notice Baseline: checkProposer with 1 active operator (fast path).
    function test_checkProposer_gas_baseline() public {
        // Warm up the proxy
        whitelist.getOperatorForCurrentEpoch();

        vm.startSnapshotGas("shasta-propose", "checkProposer_gas_baseline");
        whitelist.checkProposer(operator, bytes(""));
        vm.stopSnapshotGas();
    }

    /// @notice checkProposer with 3 active operators (fast path).
    function test_checkProposer_gas_3operators() public {
        // Add more operators
        vm.startPrank(whitelistOwner);
        whitelist.addOperator(Carol, address(uint160(Carol) + 1000));
        whitelist.addOperator(David, address(uint160(David) + 1000));
        vm.stopPrank();
        for (uint256 i; i < whitelist.OPERATOR_CHANGE_DELAY(); ++i) {
            vm.warp(block.timestamp + LibPreconfConstants.SECONDS_IN_EPOCH);
        }

        address selected = whitelist.getOperatorForCurrentEpoch();

        // Warm up
        whitelist.getOperatorForCurrentEpoch();

        vm.startSnapshotGas("shasta-propose", "checkProposer_gas_3operators");
        whitelist.checkProposer(selected, bytes(""));
        vm.stopSnapshotGas();
    }

    function _setBeaconBlockRoot(bytes32 _root) internal {
        vm.etch(
            LibPreconfConstants.BEACON_BLOCK_ROOT_CONTRACT,
            address(new BeaconBlockRootFixture(_root)).code
        );
    }
}

contract BeaconBlockRootFixture {
    bytes32 private immutable root;

    constructor(bytes32 _root) {
        root = _root;
    }

    fallback(bytes calldata input) external returns (bytes memory) {
        require(input.length == 32, "Invalid calldata length");
        uint256 _timestamp;
        assembly {
            _timestamp := calldataload(0)
        }
        if (_timestamp > block.timestamp) {
            return abi.encode(bytes32(0));
        }
        return abi.encode(root);
    }
}
