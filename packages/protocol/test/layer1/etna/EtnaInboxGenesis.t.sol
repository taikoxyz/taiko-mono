// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { EtnaInboxTestBase } from "./EtnaInboxTestBase.sol";
import { IEtnaInbox } from "src/layer1/etna/iface/IEtnaInbox.sol";
import { EtnaInbox } from "src/layer1/etna/impl/EtnaInbox.sol";
import { EssentialContract } from "src/shared/common/EssentialContract.sol";
import { ICheckpointStore } from "src/shared/signal/ICheckpointStore.sol";
import { SignalService } from "src/shared/signal/SignalService.sol";

contract EtnaInboxGenesisTest is EtnaInboxTestBase {
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

    function test_constructor_RevertWhen_ForcedInclusionFeeOrThresholdIsZero() external {
        IEtnaInbox.Config memory cfg = etnaConfig;
        cfg.forcedInclusionFeeInGwei = 0;
        vm.expectRevert(EtnaInbox.ForcedInclusionFeeZero.selector);
        new EtnaInbox(cfg);

        cfg = etnaConfig;
        cfg.forcedInclusionFeeDoubleThreshold = 0;
        vm.expectRevert(EtnaInbox.ForcedInclusionFeeDoubleThresholdZero.selector);
        new EtnaInbox(cfg);
    }

    function test_init_InitializesAFreshProxyAtomicallyAtBlockZero() external view {
        assertEq(etnaInbox.owner(), address(this), "owner");
        assertFalse(etnaInbox.paused(), "unpaused");
        assertEq(etnaInbox.migrationState(), 3, "active status");
        assertEq(etnaInbox.recoveryGeneration(), 0, "recovery generation");
        assertEq(etnaInbox.genesisCutoff(), registryCheckpointBlock, "genesis cutoff");
        assertEq(etnaInbox.genesisCommitteeRecordHash(), COMMITTEE_RECORD_0, "committee 0");
        assertEq(etnaInbox.committeeConfigHash(), COMMITTEE_CONFIG_HASH, "committee config");

        IEtnaInbox.LandedCheckpoint memory checkpoint = etnaInbox.lastCheckpoint();
        assertEq(checkpoint.height, 0, "checkpoint height");
        assertEq(checkpoint.blockHash, genesisBlockHash, "checkpoint hash");

        IEtnaInbox.Activation memory record = etnaInbox.activation();
        assertEq(record.genesisHeight, 0, "genesis height");
        assertEq(record.l1Block, initializedAtBlock, "initialization block");
        assertEq(record.epochLenL2, EPOCH_LEN_L2, "epoch length L2");
        assertEq(record.epochLenL1, EPOCH_LEN_L1, "epoch length L1");
        assertEq(record.genesisBlockHash, genesisBlockHash, "genesis hash");
        assertEq(record.genesisStateRoot, genesisStateRoot, "genesis state root");
    }

    function test_init_StoresAuthenticatedConfigAtSlot269() external view {
        assertEq(bytes32(_loadSlot(269)), COMMITTEE_CONFIG_HASH, "authenticated config installed");
        assertEq(
            etnaInbox.committeeConfigHash(), COMMITTEE_CONFIG_HASH, "authenticated config getter"
        );
    }

    function test_init_StoresGenesisCommitteeDirectlyAtSlot278() external view {
        assertEq(bytes32(_loadSlot(278)), COMMITTEE_RECORD_0, "bootstrap committee installed");
    }

    function test_init_SavesTheBlockZeroSignalCheckpoint() external view {
        ICheckpointStore.Checkpoint memory checkpoint = signalService.getCheckpoint(0);
        assertEq(checkpoint.blockNumber, 0, "checkpoint block");
        assertEq(checkpoint.blockHash, genesisBlockHash, "genesis hash");
        assertEq(checkpoint.stateRoot, genesisStateRoot, "genesis state root");
    }

    function test_init_RestrictsSignalCheckpointsToTheFreshInbox() external {
        ICheckpointStore.Checkpoint memory checkpoint = ICheckpointStore.Checkpoint({
            blockNumber: 1, blockHash: keccak256("unauthorized block"), stateRoot: genesisStateRoot
        });
        vm.expectRevert(SignalService.SS_UNAUTHORIZED.selector);
        vm.prank(Alice);
        signalService.saveCheckpoint(checkpoint);
    }

    function test_init_WritesTheExactNodeReadSlots() external view {
        assertEq(_loadSlot(STATUS_SLOT), 3, "258: active status without migration timestamps");
        assertEq(_loadSlot(RECOVERY_GENERATION_SLOT), 0, "268: recovery generation");
        assertEq(_loadSlot(LAST_CHECKPOINT_SLOT), 0, "270: checkpoint height");
        assertEq(
            bytes32(_loadSlot(LAST_CHECKPOINT_SLOT + 1)), genesisBlockHash, "271: checkpoint hash"
        );
        uint256 activationWord = (uint256(initializedAtBlock) << 64)
            | (uint256(EPOCH_LEN_L2) << 128) | (uint256(EPOCH_LEN_L1) << 192);
        assertEq(_loadSlot(ACTIVATION_SLOT), activationWord, "272: genesis parameters");
        assertEq(bytes32(_loadSlot(ACTIVATION_SLOT + 1)), genesisBlockHash, "273: genesis hash");
        assertEq(bytes32(_loadSlot(ACTIVATION_SLOT + 2)), genesisStateRoot, "274: state root");
        assertEq(
            bytes32(_loadSlot(GENESIS_COMMITTEE_SLOT)), COMMITTEE_RECORD_0, "278: genesis committee"
        );
        assertEq(_loadSlot(GENESIS_CUTOFF_SLOT), registryCheckpointBlock, "279: genesis cutoff");
    }

    function test_init_LeavesReservedSlotsEmpty() external view {
        for (uint256 slot = 251; slot <= 257; ++slot) {
            assertEq(_loadSlot(slot), 0, "251-257");
        }
        for (uint256 slot = 259; slot <= 267; ++slot) {
            assertEq(_loadSlot(slot), 0, "259-267");
        }
        assertEq(bytes32(_loadSlot(COMMITTEE_CONFIG_SLOT)), COMMITTEE_CONFIG_HASH, "269: config");
        for (uint256 slot = 275; slot <= 277; ++slot) {
            assertEq(_loadSlot(slot), 0, "275-277");
        }
        for (uint256 slot = 280; slot <= 300; ++slot) {
            assertEq(_loadSlot(slot), 0, "280-300");
        }
    }

    function test_init_RevertWhen_AlreadyInitialized() external {
        IEtnaInbox.GenesisParams memory params = _defaultGenesisParams();
        vm.expectRevert("Initializable: contract is already initialized");
        etnaInbox.init(Alice, params);
        assertEq(etnaInbox.owner(), address(this), "owner unchanged");
        assertEq(etnaInbox.activation().genesisBlockHash, genesisBlockHash, "genesis unchanged");
    }

    function test_init_RevertWhen_CalledOnTheImplementation() external {
        IEtnaInbox.GenesisParams memory params = _defaultGenesisParams();
        vm.expectRevert("Initializable: contract is already initialized");
        etnaImplementation.init(address(this), params);
        assertEq(etnaImplementation.owner(), address(0), "implementation owner");
        assertEq(etnaImplementation.migrationState(), 0, "implementation status");
    }
}

/// @notice Uses an empty proxy only to exercise initialization failures and atomic rollback.
contract EtnaInboxGenesisValidationTest is EtnaInboxTestBase {
    function _initializeOnDeploy() internal pure override returns (bool) {
        return false;
    }

    function test_views_BeforeInitialization() external {
        _assertUninitialized();
        IEtnaInbox.Activation memory record = etnaInbox.activation();
        assertEq(record.genesisHeight, 0, "genesis height");
        assertEq(record.l1Block, 0, "initialization block");
        assertEq(record.genesisBlockHash, bytes32(0), "genesis hash");
        assertEq(record.genesisStateRoot, bytes32(0), "genesis root");
    }

    function test_init_RecordsGenesisAndTheSelectedOwner() external {
        IEtnaInbox.GenesisParams memory params = _defaultGenesisParams();
        vm.expectEmit();
        emit ICheckpointStore.CheckpointSaved(0, genesisBlockHash, genesisStateRoot);
        vm.expectEmit();
        emit IEtnaInbox.EtnaInitialized(
            genesisBlockHash,
            genesisStateRoot,
            uint64(block.number),
            EPOCH_LEN_L2,
            EPOCH_LEN_L1,
            registryCheckpointBlock,
            COMMITTEE_RECORD_0
        );
        etnaInbox.init(Alice, params);
        assertEq(etnaInbox.owner(), Alice, "selected owner");
        assertEq(etnaInbox.migrationState(), 3, "active status");
    }

    function test_init_AcceptsTheBoundaryParameters() external {
        IEtnaInbox.GenesisParams memory params = _defaultGenesisParams();
        params.epochLenL2 = 3;
        params.epochLenL1 = 1;
        params.genesisCutoff = uint64(block.number - 1);
        etnaInbox.init(address(this), params);
        assertEq(etnaInbox.activation().epochLenL2, 3, "epoch length L2");
        assertEq(etnaInbox.activation().epochLenL1, 1, "epoch length L1");
        assertEq(etnaInbox.genesisCutoff(), block.number - 1, "genesis cutoff");
    }

    function test_init_RevertWhen_GenesisBlockHashIsZero() external {
        IEtnaInbox.GenesisParams memory params = _defaultGenesisParams();
        params.genesisBlockHash = 0;
        _expectInvalidGenesis(params, EtnaInbox.InvalidGenesis.selector);
    }

    function test_init_RevertWhen_GenesisStateRootIsZero() external {
        IEtnaInbox.GenesisParams memory params = _defaultGenesisParams();
        params.genesisStateRoot = 0;
        _expectInvalidGenesis(params, EtnaInbox.InvalidGenesis.selector);
    }

    function test_init_RevertWhen_EpochLenL2BelowThree() external {
        IEtnaInbox.GenesisParams memory params = _defaultGenesisParams();
        params.epochLenL2 = 2;
        _expectInvalidGenesis(params, EtnaInbox.InvalidEpochLength.selector);
    }

    function test_init_RevertWhen_EpochLenL1IsZero() external {
        IEtnaInbox.GenesisParams memory params = _defaultGenesisParams();
        params.epochLenL1 = 0;
        _expectInvalidGenesis(params, EtnaInbox.InvalidEpochLength.selector);
    }

    function test_init_RevertWhen_GenesisCutoffNotInThePast() external {
        IEtnaInbox.GenesisParams memory params = _defaultGenesisParams();
        params.genesisCutoff = uint64(block.number);
        _expectInvalidGenesis(params, EtnaInbox.InvalidGenesisCutoff.selector);
        params.genesisCutoff += 1;
        _expectInvalidGenesis(params, EtnaInbox.InvalidGenesisCutoff.selector);
    }

    function test_init_RevertWhen_GenesisCutoffBeforeFirstRegistryCheckpoint() external {
        IEtnaInbox.GenesisParams memory params = _defaultGenesisParams();
        params.genesisCutoff = registryCheckpointBlock - 1;
        _expectInvalidGenesis(params, EtnaInbox.InvalidGenesisCutoff.selector);
    }

    function test_init_RevertWhen_RegistryHasNoCheckpoint() external {
        registry = _deployRegistry();
        _deployFreshInbox(false);
        _expectInvalidGenesis(_defaultGenesisParams(), EtnaInbox.InvalidGenesisCutoff.selector);
    }

    function test_init_RevertWhen_CommitteeRecordIsZero() external {
        IEtnaInbox.GenesisParams memory params = _defaultGenesisParams();
        params.committeeRecordHash = 0;
        _expectInvalidGenesis(params, EtnaInbox.ZeroCommitteeRecord.selector);
    }

    function test_init_RevertWhen_CommitteeConfigHashIsZero() external {
        IEtnaInbox.GenesisParams memory params = _defaultGenesisParams();
        params.committeeConfigHash = 0;
        _expectInvalidGenesis(params, EtnaInbox.ZeroCommitteeConfigHash.selector);
    }

    function test_init_CanRetryAfterRejectedParameters() external {
        IEtnaInbox.GenesisParams memory params = _defaultGenesisParams();
        params.genesisBlockHash = 0;
        _expectInvalidGenesis(params, EtnaInbox.InvalidGenesis.selector);
        etnaInbox.init(address(this), _defaultGenesisParams());
        assertEq(etnaInbox.owner(), address(this), "owner");
        assertEq(signalService.getCheckpoint(0).blockHash, genesisBlockHash, "checkpoint zero");
    }

    function test_init_RollsBackIfSignalCheckpointCannotBeSaved() external {
        signalService.upgradeTo(
            address(new SignalService(Alice, REMOTE_SIGNAL_SERVICE, address(0)))
        );
        _expectInvalidGenesis(_defaultGenesisParams(), SignalService.SS_UNAUTHORIZED.selector);

        signalService.upgradeTo(
            address(new SignalService(address(etnaInbox), REMOTE_SIGNAL_SERVICE, address(0)))
        );
        etnaInbox.init(address(this), _defaultGenesisParams());
        assertEq(etnaInbox.migrationState(), 3, "retry initialized");
        assertEq(signalService.getCheckpoint(0).stateRoot, genesisStateRoot, "retry checkpoint");
    }

    function _expectInvalidGenesis(
        IEtnaInbox.GenesisParams memory _params,
        bytes4 _error
    )
        internal
    {
        vm.expectRevert(_error);
        etnaInbox.init(address(this), _params);
        _assertUninitialized();
    }

    function _assertUninitialized() internal {
        assertEq(etnaInbox.owner(), address(0), "owner not installed");
        assertEq(etnaInbox.migrationState(), 0, "inactive status");
        assertEq(etnaInbox.recoveryGeneration(), 0, "recovery generation");
        assertEq(etnaInbox.genesisCutoff(), 0, "cutoff not installed");
        assertEq(etnaInbox.genesisCommitteeRecordHash(), bytes32(0), "committee not installed");
        assertEq(etnaInbox.committeeConfigHash(), bytes32(0), "config not installed");
        assertEq(_loadSlot(COMMITTEE_CONFIG_SLOT), 0, "config storage not installed");
        assertEq(_loadSlot(GENESIS_COMMITTEE_SLOT), 0, "committee storage not installed");
        assertEq(etnaInbox.lastCheckpoint().blockHash, bytes32(0), "checkpoint not installed");
        for (uint256 slot = 251; slot <= 300; ++slot) {
            assertEq(_loadSlot(slot), 0, "genesis storage unchanged");
        }
        vm.expectRevert(SignalService.SS_CHECKPOINT_NOT_FOUND.selector);
        signalService.getCheckpoint(0);
    }
}
