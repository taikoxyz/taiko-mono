//SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { IProposerChecker } from "src/layer1/core/iface/IProposerChecker.sol";
import { PreconfWhitelist } from "src/layer1/preconf/impl/PreconfWhitelist.sol";
import { CommonTest } from "test/shared/CommonTest.sol";

/// @title PreconfWhitelistSetup
/// @notice Utilities for setting up and managing PreconfWhitelist for tests
contract PreconfWhitelistSetup is CommonTest {
    // ---------------------------------------------------------------
    // PreconfWhitelist Deployment and Setup
    // ---------------------------------------------------------------

    function _deployPreconfWhitelist(address _owner) public returns (IProposerChecker) {
        // Deploy PreconfWhitelist
        address impl = address(new PreconfWhitelist());

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

    function _selectProposer(
        IProposerChecker _proposerChecker,
        address _proposer
    )
        public
        returns (address)
    {
        PreconfWhitelist whitelist = PreconfWhitelist(address(_proposerChecker));

        // Verify we have operators
        uint256 opCount = whitelist.operatorCount();
        require(opCount > 0, "No operators in whitelist");

        // Directly mock the getOperatorForCurrentEpoch function to return the desired proposer
        vm.mockCall(
            address(whitelist),
            abi.encodeWithSelector(PreconfWhitelist.getOperatorForCurrentEpoch.selector),
            abi.encode(_proposer)
        );

        address selectedProposer = whitelist.getOperatorForCurrentEpoch();

        // Verify the selection worked as expected
        require(selectedProposer == _proposer, "Mock failed: proposer mismatch");

        return selectedProposer;
    }
}
