// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { EtnaTestConstants } from "./EtnaTestConstants.sol";
import { EtnaTestKeys } from "./EtnaTestKeys.sol";
import { MockEtnaInbox } from "./MockEtnaInbox.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { EtnaStakingRegistry } from "src/layer1/etna/impl/EtnaStakingRegistry.sol";
import { TaikoToken } from "src/layer1/mainnet/TaikoToken.sol";
import { CommonTest } from "test/shared/CommonTest.sol";

/// @title EtnaStakingRegistryTestBase
/// @notice Deploys a staking registry proxy staking TAIKO and fixed to a `MockEtnaInbox`.
/// @dev The test contract holds the whole TAIKO supply and funds stakers from it.
abstract contract EtnaStakingRegistryTestBase is CommonTest, EtnaTestConstants {
    TaikoToken internal token;
    MockEtnaInbox internal mockInbox;
    EtnaStakingRegistry internal registry;

    function setUpOnEthereum() internal virtual override {
        token = deployTaikoToken();
    }

    function setUp() public virtual override {
        super.setUp();
        mockInbox = new MockEtnaInbox();
        registry = _deployRegistry(address(mockInbox));
    }

    /// @dev Deploys a registry proxy, owned by this test, whose Inbox is fixed to `_inbox`.
    function _deployRegistry(address _inbox) internal returns (EtnaStakingRegistry) {
        return EtnaStakingRegistry(
            address(
                new ERC1967Proxy(
                    address(new EtnaStakingRegistry(_registryConfig(address(token), _inbox))),
                    abi.encodeCall(EtnaStakingRegistry.init, (address(0)))
                )
            )
        );
    }

    /// @dev Sends `_amount` TAIKO to `_staker`, who approves the registry for any amount.
    function _fund(address _staker, uint256 _amount) internal {
        assertTrue(token.transfer(_staker, _amount), "fund");
        vm.prank(_staker);
        token.approve(address(registry), type(uint256).max);
    }

    /// @dev Registers the consensus key of `_pk` for `_staker` with `MIN_STAKE`.
    function _register(address _staker, uint256 _pk) internal returns (uint256 bondId_) {
        _fund(_staker, MIN_STAKE);
        bytes memory publicKey = EtnaTestKeys.publicKey(_pk);
        bytes memory pop = EtnaTestKeys.popSig(_pk, registry, _staker);
        vm.prank(_staker);
        bondId_ = registry.register(publicKey, MIN_STAKE, pop);
    }
}
