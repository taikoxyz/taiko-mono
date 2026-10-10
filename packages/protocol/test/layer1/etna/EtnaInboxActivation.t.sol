// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { EtnaInboxTestBase } from "./EtnaInboxTestBase.sol";
import { IBondManager } from "src/layer1/core/iface/IBondManager.sol";
import { ICodec } from "src/layer1/core/iface/ICodec.sol";
import { IForcedInclusionStore } from "src/layer1/core/iface/IForcedInclusionStore.sol";
import { IInbox } from "src/layer1/core/iface/IInbox.sol";
import { Inbox } from "src/layer1/core/impl/Inbox.sol";
import { LibBonds } from "src/layer1/core/libs/LibBonds.sol";
import { LibInboxMigration } from "src/layer1/core/libs/LibInboxMigration.sol";
import { IEtnaInbox } from "src/layer1/etna/iface/IEtnaInbox.sol";
import { EtnaInbox } from "src/layer1/etna/impl/EtnaInbox.sol";
import { EssentialContract } from "src/shared/common/EssentialContract.sol";

contract EtnaInboxActivationTest is EtnaInboxTestBase {
    // ---------------------------------------------------------------
    // constructor
    // ---------------------------------------------------------------

    function test_constructor_RevertWhen_AddressIsZero() external {
        IEtnaInbox.Config memory cfg = etnaConfig;
        cfg.proofVerifier = address(0);
        vm.expectRevert(EssentialContract.ZERO_ADDRESS.selector);
        new EtnaInbox(cfg);

        cfg = etnaConfig;
        cfg.signalService = address(0);
        vm.expectRevert(EssentialContract.ZERO_ADDRESS.selector);
        new EtnaInbox(cfg);

        cfg = etnaConfig;
        cfg.stakingRegistry = address(0);
        vm.expectRevert(EssentialContract.ZERO_ADDRESS.selector);
        new EtnaInbox(cfg);

        cfg = etnaConfig;
        cfg.bondToken = address(0);
        vm.expectRevert(EssentialContract.ZERO_ADDRESS.selector);
        new EtnaInbox(cfg);
    }

    function test_constructor_RevertWhen_ChainIdOrBatchLimitIsZero() external {
        IEtnaInbox.Config memory cfg = etnaConfig;
        cfg.l2ChainId = 0;
        vm.expectRevert(EssentialContract.ZERO_VALUE.selector);
        new EtnaInbox(cfg);

        cfg = etnaConfig;
        cfg.maxBatchBlocks = 0;
        vm.expectRevert(EssentialContract.ZERO_VALUE.selector);
        new EtnaInbox(cfg);
    }

    // ---------------------------------------------------------------
    // Views before activation
    // ---------------------------------------------------------------

    function test_views_BeforeActivation() external view {
        assertEq(etnaInbox.migrationState(), LibInboxMigration.FROZEN, "migration state");
        assertEq(etnaInbox.recoveryGeneration(), 0, "recovery generation");
        assertEq(etnaInbox.genesisCutoff(), 0, "genesis cutoff");
        assertEq(etnaInbox.committee(0), bytes32(0), "committee 0");

        IEtnaInbox.LandedCheckpoint memory checkpoint = etnaInbox.lastCheckpoint();
        assertEq(checkpoint.height, 0, "checkpoint height");
        assertEq(checkpoint.blockHash, bytes32(0), "checkpoint hash");

        IEtnaInbox.Activation memory record = etnaInbox.activation();
        assertEq(record.genesisHeight, 0, "genesis height");
        assertEq(record.l1Block, 0, "activation block");
        assertEq(record.genesisBlockHash, bytes32(0), "genesis hash");
    }

    // ---------------------------------------------------------------
    // activateEtna
    // ---------------------------------------------------------------

    function test_activateEtna_RecordsTheActivation() external {
        IEtnaInbox.ActivationParams memory params = _defaultActivationParams();
        uint64 l1Block = uint64(block.number);

        vm.expectEmit();
        emit IEtnaInbox.EtnaActivated(
            genesisHeight,
            genesisBlockHash,
            genesisStateRoot,
            l1Block,
            EPOCH_LEN_L2,
            EPOCH_LEN_L1,
            registryCheckpointBlock,
            COMMITTEE_RECORD_0
        );
        etnaInbox.activateEtna(params);

        assertEq(etnaInbox.migrationState(), LibInboxMigration.ETNA_ACTIVE, "migration state");
        assertEq(etnaInbox.recoveryGeneration(), 0, "recovery generation");
        assertEq(etnaInbox.genesisCutoff(), registryCheckpointBlock, "genesis cutoff");
        assertEq(etnaInbox.committee(0), COMMITTEE_RECORD_0, "committee 0");
        assertEq(etnaInbox.committee(1), bytes32(0), "committee 1");

        IEtnaInbox.LandedCheckpoint memory checkpoint = etnaInbox.lastCheckpoint();
        assertEq(checkpoint.height, genesisHeight, "checkpoint height");
        assertEq(checkpoint.blockHash, genesisBlockHash, "checkpoint hash");

        IEtnaInbox.Activation memory record = etnaInbox.activation();
        assertEq(record.genesisHeight, genesisHeight, "genesis height");
        assertEq(record.l1Block, l1Block, "activation block");
        assertEq(record.epochLenL2, EPOCH_LEN_L2, "epoch length L2");
        assertEq(record.epochLenL1, EPOCH_LEN_L1, "epoch length L1");
        assertEq(record.genesisBlockHash, genesisBlockHash, "genesis hash");
        assertEq(record.genesisStateRoot, genesisStateRoot, "genesis state root");
    }

    function test_activateEtna_WritesTheNodeReadSlots() external {
        IEtnaInbox.ActivationParams memory params = _defaultActivationParams();
        params.epochLenL2 = 0x1111;
        params.epochLenL1 = 0x2222;
        uint64 l1Block = uint64(block.number);
        etnaInbox.activateEtna(params);

        uint256 word = _loadSlot(MIGRATION_SLOT);
        assertEq(uint8(word), LibInboxMigration.ETNA_ACTIVE, "258 bits 0-7: migration state");
        assertEq(uint64(word >> 8), frozenAtBlock, "258 bits 8-71: frozen at");
        assertEq(uint64(word >> 72), l1Block, "258 bits 72-135: drained at");
        assertEq(word >> 136, 0, "258 high bits");

        assertEq(_loadSlot(RECOVERY_GENERATION_SLOT), 0, "268: recovery generation");

        assertEq(_loadSlot(LAST_CHECKPOINT_SLOT), genesisHeight, "270: checkpoint height");
        assertEq(
            bytes32(_loadSlot(LAST_CHECKPOINT_SLOT + 1)), genesisBlockHash, "271: checkpoint hash"
        );

        word = _loadSlot(ACTIVATION_SLOT);
        assertEq(uint64(word), genesisHeight, "272 bits 0-63: genesis height");
        assertEq(uint64(word >> 64), l1Block, "272 bits 64-127: activation block");
        assertEq(uint64(word >> 128), 0x1111, "272 bits 128-191: epoch length L2");
        assertEq(uint64(word >> 192), 0x2222, "272 bits 192-255: epoch length L1");
        assertEq(bytes32(_loadSlot(ACTIVATION_SLOT + 1)), genesisBlockHash, "273: genesis hash");
        assertEq(bytes32(_loadSlot(ACTIVATION_SLOT + 2)), genesisStateRoot, "274: state root");

        assertEq(vm.load(address(inbox), _committeeSlot(0)), COMMITTEE_RECORD_0, "278: committee 0");
        assertEq(_loadSlot(GENESIS_CUTOFF_SLOT), registryCheckpointBlock, "279: genesis cutoff");
    }

    function test_activateEtna_LeavesReservedSlotsEmpty() external {
        _activate();

        for (uint256 slot = 259; slot <= 267; ++slot) {
            assertEq(_loadSlot(slot), 0, "259-267");
        }
        assertEq(_loadSlot(269), 0, "269");
        for (uint256 slot = 275; slot <= 277; ++slot) {
            assertEq(_loadSlot(slot), 0, "275-277");
        }
        for (uint256 slot = 280; slot <= 300; ++slot) {
            assertEq(_loadSlot(slot), 0, "280-300");
        }
    }

    function test_activateEtna_AcceptsTheBoundaryParameters() external {
        IEtnaInbox.ActivationParams memory params = _defaultActivationParams();
        params.epochLenL2 = 3;
        params.epochLenL1 = 1;
        params.genesisCutoff = uint64(block.number - 1);
        etnaInbox.activateEtna(params);

        assertEq(etnaInbox.activation().epochLenL2, 3, "epoch length L2");
        assertEq(etnaInbox.genesisCutoff(), block.number - 1, "genesis cutoff");
    }

    function test_activateEtna_RevertWhen_CallerNotOwner() external {
        IEtnaInbox.ActivationParams memory params = _defaultActivationParams();
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(Alice);
        etnaInbox.activateEtna(params);
    }

    function test_activateEtna_RevertWhen_AlreadyActive() external {
        _activate();
        _advanceBlock();

        IEtnaInbox.ActivationParams memory params = _defaultActivationParams();
        vm.expectRevert(EtnaInbox.NotFrozen.selector);
        etnaInbox.activateEtna(params);
    }

    function test_activateEtna_RevertWhen_GenesisHeightHasNoCheckpoint() external {
        IEtnaInbox.ActivationParams memory params = _defaultActivationParams();
        params.genesisHeight = genesisHeight + 1;
        vm.expectRevert(EtnaInbox.GenesisMismatch.selector);
        etnaInbox.activateEtna(params);
    }

    function test_activateEtna_RevertWhen_GenesisCheckpointIsNotTheLastFinalized() external {
        IEtnaInbox.ActivationParams memory params = _defaultActivationParams();
        params.genesisHeight = staleHeight;
        assertTrue(signalService.getCheckpoint(uint48(staleHeight)).blockHash != 0, "stale");

        vm.expectRevert(EtnaInbox.GenesisMismatch.selector);
        etnaInbox.activateEtna(params);
    }

    function test_activateEtna_RevertWhen_GenesisHeightExceedsUint48() external {
        IEtnaInbox.ActivationParams memory params = _defaultActivationParams();
        params.genesisHeight = uint64(type(uint48).max) + 1;
        vm.expectRevert(EtnaInbox.GenesisMismatch.selector);
        etnaInbox.activateEtna(params);
    }

    function test_activateEtna_RevertWhen_EpochLenL2BelowThree() external {
        IEtnaInbox.ActivationParams memory params = _defaultActivationParams();
        params.epochLenL2 = 2;
        vm.expectRevert(EtnaInbox.InvalidEpochLength.selector);
        etnaInbox.activateEtna(params);
    }

    function test_activateEtna_RevertWhen_EpochLenL1IsZero() external {
        IEtnaInbox.ActivationParams memory params = _defaultActivationParams();
        params.epochLenL1 = 0;
        vm.expectRevert(EtnaInbox.InvalidEpochLength.selector);
        etnaInbox.activateEtna(params);
    }

    function test_activateEtna_RevertWhen_GenesisCutoffNotInThePast() external {
        IEtnaInbox.ActivationParams memory params = _defaultActivationParams();
        params.genesisCutoff = uint64(block.number);
        vm.expectRevert(EtnaInbox.InvalidGenesisCutoff.selector);
        etnaInbox.activateEtna(params);
    }

    function test_activateEtna_RevertWhen_GenesisCutoffBeforeFirstRegistryCheckpoint() external {
        IEtnaInbox.ActivationParams memory params = _defaultActivationParams();
        params.genesisCutoff = registryCheckpointBlock - 1;
        vm.expectRevert(EtnaInbox.InvalidGenesisCutoff.selector);
        etnaInbox.activateEtna(params);
    }

    function test_activateEtna_RevertWhen_RegistryHasNoCheckpoint() external {
        etnaConfig.stakingRegistry = address(_deployRegistry());
        inbox.upgradeTo(address(new EtnaInbox(etnaConfig)));

        IEtnaInbox.ActivationParams memory params = _defaultActivationParams();
        vm.expectRevert(EtnaInbox.InvalidGenesisCutoff.selector);
        etnaInbox.activateEtna(params);
    }

    function test_activateEtna_RevertWhen_CommitteeRecordIsZero() external {
        IEtnaInbox.ActivationParams memory params = _defaultActivationParams();
        params.committeeRecordHash = 0;
        vm.expectRevert(EtnaInbox.ZeroCommitteeRecord.selector);
        etnaInbox.activateEtna(params);
    }

    // ---------------------------------------------------------------
    // Legacy bond exit
    // ---------------------------------------------------------------

    function test_getBond_ReadsTheShastaBalances() external view {
        IBondManager.Bond memory bond = etnaInbox.getBond(David);
        assertEq(bond.balance, MIN_BOND_GWEI + LIVENESS_BOND_GWEI, "balance");
        assertEq(bond.withdrawalRequestedAt, 0, "request");
    }

    function test_withdraw_PaysOutTheLegacyBondAfterActivation() external {
        _activate();
        uint64 balance = etnaInbox.getBond(David).balance;
        uint256 tokensBefore = bondToken.balanceOf(David);

        vm.expectEmit();
        emit IBondManager.WithdrawalRequested(David, uint48(block.timestamp + WITHDRAWAL_DELAY));
        vm.prank(David);
        etnaInbox.requestWithdrawal();
        assertEq(etnaInbox.getBond(David).withdrawalRequestedAt, block.timestamp, "requested");

        vm.warp(block.timestamp + WITHDRAWAL_DELAY);
        vm.expectEmit();
        emit IBondManager.BondWithdrawn(David, balance);
        vm.prank(David);
        etnaInbox.withdraw(Emma, balance);

        IBondManager.Bond memory bond = etnaInbox.getBond(David);
        assertEq(bond.balance, 0, "balance");
        assertEq(bond.withdrawalRequestedAt, 0, "request cleared");
        assertEq(bondToken.balanceOf(David), tokensBefore, "owner tokens");
        assertEq(bondToken.balanceOf(Emma), _toTokenAmount(balance), "recipient tokens");
    }

    function test_withdraw_AllowsTheExcessOverTheMinimumBondWithoutRequest() external {
        vm.prank(David);
        etnaInbox.withdraw(David, LIVENESS_BOND_GWEI);
        assertEq(etnaInbox.getBond(David).balance, MIN_BOND_GWEI, "balance");
    }

    function test_withdraw_RevertWhen_BelowTheMinimumBondWithoutRequest() external {
        vm.expectRevert(LibBonds.MustMaintainMinBond.selector);
        vm.prank(David);
        etnaInbox.withdraw(David, LIVENESS_BOND_GWEI + 1);
    }

    function test_withdraw_RevertWhen_DelayNotPassed() external {
        vm.startPrank(David);
        etnaInbox.requestWithdrawal();
        vm.warp(block.timestamp + WITHDRAWAL_DELAY - 1);
        vm.expectRevert(LibBonds.MustMaintainMinBond.selector);
        etnaInbox.withdraw(David, MIN_BOND_GWEI + LIVENESS_BOND_GWEI);
        vm.stopPrank();
    }

    function test_cancelWithdrawal_ClearsTheRequest() external {
        vm.startPrank(David);
        etnaInbox.requestWithdrawal();

        vm.expectEmit();
        emit IBondManager.WithdrawalCancelled(David);
        etnaInbox.cancelWithdrawal();
        vm.stopPrank();

        assertEq(etnaInbox.getBond(David).withdrawalRequestedAt, 0, "request");
    }

    function test_requestWithdrawal_RevertWhen_AlreadyRequested() external {
        vm.startPrank(David);
        etnaInbox.requestWithdrawal();
        vm.expectRevert(LibBonds.WithdrawalAlreadyRequested.selector);
        etnaInbox.requestWithdrawal();
        vm.stopPrank();
    }

    function test_cancelWithdrawal_RevertWhen_NotRequested() external {
        vm.expectRevert(LibBonds.NoWithdrawalRequested.selector);
        vm.prank(David);
        etnaInbox.cancelWithdrawal();
    }

    // ---------------------------------------------------------------
    // Shasta entry points
    // ---------------------------------------------------------------

    function test_shastaEntryPoints_AreGone() external {
        bytes4[13] memory selectors = [
            Inbox.propose.selector,
            Inbox.prove.selector,
            Inbox.activate.selector,
            Inbox.freeze.selector,
            Inbox.migration.selector,
            IBondManager.deposit.selector,
            IBondManager.depositTo.selector,
            IForcedInclusionStore.saveForcedInclusion.selector,
            IForcedInclusionStore.getForcedInclusionState.selector,
            IInbox.getCoreState.selector,
            IInbox.getConfig.selector,
            IInbox.getProposalHash.selector,
            ICodec.encodeProposeInput.selector
        ];
        for (uint256 i; i < selectors.length; ++i) {
            (bool success,) = address(inbox).call(abi.encodeWithSelector(selectors[i]));
            assertFalse(success, "selector still served");
        }
    }
}

/// @notice Activation from the states before the upgrade: setUp stops after the Shasta history.
contract EtnaInboxActivationPreconditionsTest is EtnaInboxTestBase {
    function _migrate() internal override { }

    function test_activateEtna_SucceedsInTheUpgradeTransaction() external {
        _freeze();
        _advanceBlock();
        address impl = address(new EtnaInbox(etnaConfig));
        IEtnaInbox.ActivationParams memory params = _defaultActivationParams();

        vm.expectEmit();
        emit IEtnaInbox.EtnaActivated(
            genesisHeight,
            genesisBlockHash,
            genesisStateRoot,
            uint64(block.number),
            EPOCH_LEN_L2,
            EPOCH_LEN_L1,
            registryCheckpointBlock,
            COMMITTEE_RECORD_0
        );
        inbox.upgradeToAndCall(impl, abi.encodeCall(EtnaInbox.activateEtna, (params)));

        assertEq(inbox.impl(), impl, "implementation");
        assertEq(
            EtnaInbox(address(inbox)).migrationState(),
            LibInboxMigration.ETNA_ACTIVE,
            "migration state"
        );
    }

    function test_activateEtna_RevertWhen_NotFrozen() external {
        _upgradeToEtna();

        IEtnaInbox.ActivationParams memory params = _defaultActivationParams();
        vm.expectRevert(EtnaInbox.NotFrozen.selector);
        etnaInbox.activateEtna(params);
    }

    function test_activateEtna_RevertWhen_NotDrained() external {
        _advanceBlock();
        _proposeOne();
        _freeze();
        _upgradeToEtna();

        IEtnaInbox.ActivationParams memory params = _defaultActivationParams();
        vm.expectRevert(EtnaInbox.NotDrained.selector);
        etnaInbox.activateEtna(params);
    }
}
