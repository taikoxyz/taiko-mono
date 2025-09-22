// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { PreconfWhitelist } from "src/layer1/preconf/impl/PreconfWhitelist.sol";
import { LibPreconfConstants } from "src/layer1/preconf/libs/LibPreconfConstants.sol";
import { IProposerChecker } from "src/layer1/shasta/iface/IProposerChecker.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { CommonTest } from "test/shared/CommonTest.sol";

/// @title PreconfWhitelistSetup
/// @notice Utilities for setting up and managing PreconfWhitelist for tests
contract PreconfWhitelistSetup is CommonTest {
    // ---------------------------------------------------------------
    // PreconfWhitelist Deployment and Setup
    // ---------------------------------------------------------------

    function _deployPreconfWhitelist(address _owner) public returns (IProposerChecker) {
        // Deploy PreconfWhitelist with Alice as fallback preconfer
        address impl = address(new PreconfWhitelist(Alice)); // Alice as fallback

        address proxy = address(
            new ERC1967Proxy(
                impl,
                abi.encodeCall(
                    PreconfWhitelist.init,
                    (
                        _owner, // owner
                        0, // operatorChangeDelay (immediate for tests)
                        0 // randomnessDelay (immediate for tests)
                    )
                )
            )
        );

        PreconfWhitelist whitelist = PreconfWhitelist(proxy);

        // Add 4 test operators to mimic mainnet setup
        vm.prank(_owner);
        whitelist.addOperator(Bob, Bob);

        vm.prank(_owner);
        whitelist.addOperator(Carol, Carol);

        vm.prank(_owner);
        whitelist.addOperator(David, David);

        vm.prank(_owner);
        whitelist.addOperator(Emma, Emma);

        return IProposerChecker(proxy);
    }

    // ---------------------------------------------------------------
    // Proposer Selection Helper Functions
    // ---------------------------------------------------------------

    function _mockBeaconRootForProposer(address _desiredProposer) internal {
        // Get current epoch timestamp
        uint256 epochTimestamp = _getCurrentEpochTimestamp();

        // Use a deterministic beacon root that will reliably select the desired proposer
        // Now we have 4 operators: Bob, Carol, David, Emma
        bytes32 deterministicRoot;
        if (_desiredProposer == Bob) {
            deterministicRoot = keccak256(abi.encode("select_bob"));
        } else if (_desiredProposer == Carol) {
            deterministicRoot = keccak256(abi.encode("select_carol"));
        } else if (_desiredProposer == David) {
            deterministicRoot = keccak256(abi.encode("select_david"));
        } else if (_desiredProposer == Emma) {
            deterministicRoot = keccak256(abi.encode("select_emma"));
        } else {
            deterministicRoot = keccak256(abi.encode(_desiredProposer, "fallback"));
        }

        // Mock the beacon root call
        vm.mockCall(
            LibPreconfConstants.BEACON_BLOCK_ROOT_CONTRACT,
            abi.encode(epochTimestamp),
            abi.encode(deterministicRoot)
        );
    }

    function _getCurrentEpochTimestamp() internal view returns (uint256) {
        // Simple approach: just return current timestamp aligned to epoch boundary
        // This avoids issues with genesis timestamp calculations in test environments
        uint256 epochSeconds = LibPreconfConstants.SECONDS_IN_EPOCH;
        /// forge-lint: disable-next-line(divide-before-multiply)
        return (block.timestamp / epochSeconds) * epochSeconds;
    }

    function _selectProposer(
        IProposerChecker _proposerChecker,
        address _proposer
    )
        public
        returns (address)
    {
        // Mock beacon root to select a specific proposer
        _mockBeaconRootForProposer(_proposer);

        PreconfWhitelist whitelist = PreconfWhitelist(address(_proposerChecker));
        address selectedProposer = whitelist.getOperatorForCurrentEpoch();

        // If no proposer selected, fall back to the fallback preconfer (Alice)
        if (selectedProposer == address(0)) {
            selectedProposer = Alice;
        }

        return selectedProposer;
    }
}
