// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// forge-config: default.isolate = true

import { IProposerChecker } from "src/layer1/core/iface/IProposerChecker.sol";
import { PreconfWhitelist } from "src/layer1/preconf/impl/PreconfWhitelist.sol";
import { PreconfWhitelistV2 } from "src/layer1/preconf/impl/PreconfWhitelistV2.sol";
import { LibPreconfConstants } from "src/layer1/preconf/libs/LibPreconfConstants.sol";
import { CommonTest } from "test/shared/CommonTest.sol";

/// @notice Gas benchmarks for checkProposer — proxy (V1) vs direct (V2).
contract PreconfWhitelistGasTest is CommonTest {
    PreconfWhitelist internal whitelist;
    PreconfWhitelistV2 internal whitelistV2;
    address internal whitelistOwner;
    address internal operator;

    function setUpOnEthereum() internal override {
        // setUp() calls this inside vm.startPrank(deployer), so deployer is msg.sender
        whitelistOwner = deployer;
        operator = Bob;

        // V1: behind ERC1967 proxy (upgradeable)
        whitelist = PreconfWhitelist(
            deploy({
                name: "preconf_whitelist",
                impl: address(new PreconfWhitelist()),
                data: abi.encodeCall(PreconfWhitelist.init, (whitelistOwner))
            })
        );

        // V2: deployed directly (non-upgradeable)
        whitelistV2 = new PreconfWhitelistV2(whitelistOwner);

        // Deploy a mock beacon block root contract that always returns a fixed value
        _setBeaconBlockRoot(bytes32(uint256(0x1234)));

        // Warp past the randomness delay so operators can be active
        vm.warp(
            LibPreconfConstants.SECONDS_IN_SLOT
                + LibPreconfConstants.SECONDS_IN_EPOCH * whitelist.RANDOMNESS_DELAY()
        );

        // Add operator to both whitelists
        whitelist.addOperator(operator, address(uint160(operator) + 1000));
        whitelistV2.addOperator(operator, address(uint160(operator) + 1000));

        for (uint256 i; i < whitelist.OPERATOR_CHANGE_DELAY(); ++i) {
            vm.warp(block.timestamp + LibPreconfConstants.SECONDS_IN_EPOCH);
        }

        // Verify operator is the selected one in both
        require(whitelist.getOperatorForCurrentEpoch() == operator, "v1: operator not selected");
        require(whitelistV2.getOperatorForCurrentEpoch() == operator, "v2: operator not selected");
    }

    // ---------------------------------------------------------------
    // V1 (proxy) benchmarks
    // ---------------------------------------------------------------

    /// @notice V1 baseline: checkProposer with 1 active operator through proxy.
    function test_checkProposer_gas_baseline() public {
        whitelist.getOperatorForCurrentEpoch();

        vm.startSnapshotGas("shasta-propose", "checkProposer_gas_baseline");
        whitelist.checkProposer(operator, bytes(""));
        vm.stopSnapshotGas();
    }

    /// @notice V1: checkProposer with 3 active operators through proxy.
    function test_checkProposer_gas_3operators() public {
        vm.startPrank(whitelistOwner);
        whitelist.addOperator(Carol, address(uint160(Carol) + 1000));
        whitelist.addOperator(David, address(uint160(David) + 1000));
        vm.stopPrank();
        for (uint256 i; i < whitelist.OPERATOR_CHANGE_DELAY(); ++i) {
            vm.warp(block.timestamp + LibPreconfConstants.SECONDS_IN_EPOCH);
        }

        address selected = whitelist.getOperatorForCurrentEpoch();
        whitelist.getOperatorForCurrentEpoch();

        vm.startSnapshotGas("shasta-propose", "checkProposer_gas_3operators");
        whitelist.checkProposer(selected, bytes(""));
        vm.stopSnapshotGas();
    }

    // ---------------------------------------------------------------
    // V2 (direct, no proxy) benchmarks
    // ---------------------------------------------------------------

    /// @notice V2 baseline: checkProposer with 1 active operator, no proxy.
    function test_checkProposer_v2_gas_baseline() public {
        whitelistV2.getOperatorForCurrentEpoch();

        vm.startSnapshotGas("shasta-propose", "checkProposer_v2_gas_baseline");
        whitelistV2.checkProposer(operator, bytes(""));
        vm.stopSnapshotGas();
    }

    /// @notice V2: checkProposer with 3 active operators, no proxy.
    function test_checkProposer_v2_gas_3operators() public {
        vm.startPrank(whitelistOwner);
        whitelistV2.addOperator(Carol, address(uint160(Carol) + 1000));
        whitelistV2.addOperator(David, address(uint160(David) + 1000));
        vm.stopPrank();
        for (uint256 i; i < whitelistV2.OPERATOR_CHANGE_DELAY(); ++i) {
            vm.warp(block.timestamp + LibPreconfConstants.SECONDS_IN_EPOCH);
        }

        address selected = whitelistV2.getOperatorForCurrentEpoch();
        whitelistV2.getOperatorForCurrentEpoch();

        vm.startSnapshotGas("shasta-propose", "checkProposer_v2_gas_3operators");
        whitelistV2.checkProposer(selected, bytes(""));
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
