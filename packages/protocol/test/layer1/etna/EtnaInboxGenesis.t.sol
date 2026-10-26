// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { EtnaInboxTestBase } from "./EtnaInboxTestBase.sol";
import { IEtnaInbox } from "src/layer1/etna/iface/IEtnaInbox.sol";
import { EtnaInbox } from "src/layer1/etna/impl/EtnaInbox.sol";
import { EtnaInboxBootstrap } from "src/layer1/etna/impl/EtnaInboxBootstrap.sol";
import { EssentialContract } from "src/shared/common/EssentialContract.sol";

contract EtnaInboxGenesisTest is EtnaInboxTestBase {
    // ---------------------------------------------------------------
    // constructor
    // ---------------------------------------------------------------

    function test_constructor_SetsTheImmutableViews() external {
        EtnaInbox impl = _newInboxImpl(_defaultConfig());
        assertEq(impl.proofVerifier(), address(landVerifier), "verifier");
        assertEq(impl.signalService(), address(signalService), "signal service");
        assertEq(impl.stakingRegistry(), address(registry), "registry");
        assertEq(impl.l2ChainId(), L2_CHAIN_ID, "l2 chain id");
        assertEq(impl.maxBatchBlocks(), MAX_BATCH_BLOCKS, "max batch blocks");
        assertEq(impl.forcedInclusionFeeInGwei(), FORCED_INCLUSION_FEE_GWEI, "fee");
        assertEq(
            impl.forcedInclusionFeeDoubleThreshold(),
            FORCED_INCLUSION_FEE_DOUBLE_THRESHOLD,
            "fee threshold"
        );
        assertEq(impl.protocolFeeRecipient(), PROTOCOL_FEE_RECIPIENT, "protocol fee recipient");
    }

    function test_constructor_RevertWhen_AddressIsZero() external {
        IEtnaInbox.Config memory cfg = _defaultConfig();
        cfg.proofVerifier = address(0);
        vm.expectRevert(EssentialContract.ZERO_ADDRESS.selector);
        _newInboxImpl(cfg);

        cfg = _defaultConfig();
        cfg.signalService = address(0);
        vm.expectRevert(EssentialContract.ZERO_ADDRESS.selector);
        _newInboxImpl(cfg);

        cfg = _defaultConfig();
        cfg.stakingRegistry = address(0);
        vm.expectRevert(EssentialContract.ZERO_ADDRESS.selector);
        _newInboxImpl(cfg);

        cfg = _defaultConfig();
        cfg.protocolFeeRecipient = address(0);
        vm.expectRevert(EssentialContract.ZERO_ADDRESS.selector);
        _newInboxImpl(cfg);
    }

    function test_constructor_RevertWhen_L2ChainIdIsZero() external {
        IEtnaInbox.Config memory cfg = _defaultConfig();
        cfg.l2ChainId = 0;
        vm.expectRevert(EssentialContract.ZERO_VALUE.selector);
        _newInboxImpl(cfg);
    }

    function test_constructor_RevertWhen_MaxBatchBlocksBelowSix() external {
        IEtnaInbox.Config memory cfg = _defaultConfig();
        cfg.maxBatchBlocks = 0;
        vm.expectRevert(IEtnaInbox.InvalidMaxBatchBlocks.selector);
        _newInboxImpl(cfg);

        cfg.maxBatchBlocks = 5;
        vm.expectRevert(IEtnaInbox.InvalidMaxBatchBlocks.selector);
        _newInboxImpl(cfg);

        // One grid segment; no multiple-of-six rule (C15).
        cfg.maxBatchBlocks = 6;
        assertEq(_newInboxImpl(cfg).maxBatchBlocks(), 6);
        cfg.maxBatchBlocks = 7;
        assertEq(_newInboxImpl(cfg).maxBatchBlocks(), 7);
    }

    function test_constructor_RevertWhen_ForcedInclusionFeeOrThresholdIsZero() external {
        IEtnaInbox.Config memory cfg = _defaultConfig();
        cfg.forcedInclusionFeeInGwei = 0;
        vm.expectRevert(IEtnaInbox.ForcedInclusionFeeZero.selector);
        _newInboxImpl(cfg);

        cfg = _defaultConfig();
        cfg.forcedInclusionFeeDoubleThreshold = 0;
        vm.expectRevert(IEtnaInbox.ForcedInclusionFeeDoubleThresholdZero.selector);
        _newInboxImpl(cfg);
    }

    // ---------------------------------------------------------------
    // bootstrap (C2)
    // ---------------------------------------------------------------

    function test_bootstrap_SetsOwnerAndReportsUninitialized() external view {
        assertEq(EssentialContract(inboxProxy).owner(), address(this), "owner");
        assertFalse(IEtnaInbox(inboxProxy).isInitialized(), "uninitialized");
        assertEq(
            uint256(vm.load(inboxProxy, bytes32(INITIALIZATION_STATUS_SLOT))),
            0,
            "slot 258 stays zero"
        );
    }

    function test_bootstrap_RevertWhen_InitializedTwice() external {
        vm.expectRevert("Initializable: contract is already initialized");
        EtnaInboxBootstrap(inboxProxy).init(Alice);
        assertEq(EssentialContract(inboxProxy).owner(), address(this), "owner unchanged");
    }

    function test_bootstrap_ImplementationCannotBeInitialized() external {
        EtnaInboxBootstrap impl = new EtnaInboxBootstrap();
        vm.expectRevert("Initializable: contract is already initialized");
        impl.init(address(this));
    }
}
