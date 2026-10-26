// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { EtnaTestConstants } from "./EtnaTestConstants.sol";
import { EtnaTestKeys } from "./EtnaTestKeys.sol";
import { MockEtnaInbox } from "./MockEtnaInbox.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { IEtnaStakingRegistry } from "src/layer1/etna/iface/IEtnaStakingRegistry.sol";
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
        return _deployRegistry(address(token), _inbox);
    }

    /// @dev Deploys a registry proxy, owned by this test, staking `_token` and fixed to `_inbox`.
    function _deployRegistry(address _token, address _inbox)
        internal
        returns (EtnaStakingRegistry)
    {
        return _deployRegistry(_registryConfig(_token, _inbox));
    }

    /// @dev Deploys a registry proxy, owned by this test, with `_config`.
    function _deployRegistry(IEtnaStakingRegistry.Config memory _config)
        internal
        returns (EtnaStakingRegistry)
    {
        return EtnaStakingRegistry(
            address(
                new ERC1967Proxy(
                    address(new EtnaStakingRegistry(_config)),
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

    /// @dev Confirms the exit already set on bond `_bondId`: initializes the mock Inbox, raises
    /// its snapshot to the exit if it is lower and confirms in the current block.
    function _confirmExit(uint256 _bondId) internal {
        mockInbox.setInitialized(true);
        uint256 exitEffectiveL1 = registry.entryAt(_bondId).exitEffectiveL1;
        if (mockInbox.activeCommitteeSnapshot() < exitEffectiveL1) {
            mockInbox.setActiveCommitteeSnapshot(exitEffectiveL1);
        }
        registry.confirmExit(_bondId);
    }

    /// @dev Releases bond `_bondId` the owner's way: requests its exit, confirms it, rolls the
    /// withdrawal delay forward and withdraws the stake to the owner.
    function _release(uint256 _bondId) internal {
        address bondOwner = registry.ownerOf(_bondId);
        vm.prank(bondOwner);
        registry.requestExit(_bondId);
        _confirmExit(_bondId);
        vm.roll(block.number + WITHDRAWAL_DELAY);
        vm.prank(bondOwner);
        registry.withdraw(_bondId, bondOwner);
    }

    /// @dev Asserts that the registry holds `_expected` at `_bondId`.
    function _assertEntry(
        uint256 _bondId,
        IEtnaStakingRegistry.Entry memory _expected
    )
        internal
        view
    {
        IEtnaStakingRegistry.Entry memory entry = registry.entryAt(_bondId);
        assertEq(entry.ckX, _expected.ckX, "ckX");
        assertEq(entry.effStake, _expected.effStake, "effStake");
        assertEq(entry.ckPrefix, _expected.ckPrefix, "ckPrefix");
        assertEq(entry.activeFromL1, _expected.activeFromL1, "activeFromL1");
        assertEq(entry.exitEffectiveL1, _expected.exitEffectiveL1, "exitEffectiveL1");
    }

    /// @dev Asserts checkpoint `_index`'s block, slot count and entries root.
    function _assertCheckpoint(
        uint256 _index,
        uint256 _l1Block,
        uint256 _count,
        bytes32 _root
    )
        internal
        view
    {
        IEtnaStakingRegistry.Checkpoint memory checkpoint = registry.checkpointAt(_index);
        assertEq(checkpoint.l1Block, _l1Block, "checkpoint l1Block");
        assertEq(checkpoint.count, _count, "checkpoint count");
        assertEq(checkpoint.entriesRoot, _root, "checkpoint entriesRoot");
    }
}
