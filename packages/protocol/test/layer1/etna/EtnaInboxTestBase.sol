// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { IInbox } from "src/layer1/core/iface/IInbox.sol";
import { IEtnaInbox } from "src/layer1/etna/iface/IEtnaInbox.sol";
import { EtnaInbox } from "src/layer1/etna/impl/EtnaInbox.sol";
import { EtnaStakingRegistry } from "src/layer1/etna/impl/EtnaStakingRegistry.sol";
import { IProofVerifier } from "src/layer1/verifiers/IProofVerifier.sol";
import { InboxTestBase } from "test/layer1/core/inbox/InboxTestBase.sol";
import { TestERC20 } from "test/mocks/TestERC20.sol";

/// @notice A `land` proof verifier that accepts every proof until it is told to reject.
/// @dev `verifyProof` is a view (called with STATICCALL), so it cannot record the statement hash;
/// tests observe it with `vm.expectCall` and the `BatchLanded` event instead.
contract MockLandProofVerifier is IProofVerifier {
    bool public rejects;

    function setRejects(bool _rejects) external {
        rejects = _rejects;
    }

    function verifyProof(uint256 _proposalAge, bytes32, bytes calldata) external view {
        require(!rejects && _proposalAge == 0, ProofRejected());
    }

    error ProofRejected();
}

/// @title EtnaInboxTestBase
/// @notice Runs the Shasta-to-Etna migration of the Inbox proxy: proves two Shasta batches,
/// deploys the staking registry with one checkpoint, freezes the Shasta Inbox and upgrades it to
/// `EtnaInbox`. Tests activate with `_activate`.
abstract contract EtnaInboxTestBase is InboxTestBase {
    // ---------------------------------------------------------------
    // Node-read slots of the Inbox proxy (taiko-client-rs `l1::layout::inbox`)
    // ---------------------------------------------------------------

    uint256 internal constant MIGRATION_SLOT = 258;
    uint256 internal constant RECOVERY_GENERATION_SLOT = 268;
    uint256 internal constant LAST_CHECKPOINT_SLOT = 270;
    uint256 internal constant ACTIVATION_SLOT = 272;
    uint256 internal constant COMMITTEE_SLOT = 278;
    uint256 internal constant GENESIS_CUTOFF_SLOT = 279;

    // ---------------------------------------------------------------
    // Parameters
    // ---------------------------------------------------------------

    uint64 internal constant L2_CHAIN_ID = 167_001;
    uint64 internal constant MAX_BATCH_BLOCKS = 1000;
    uint64 internal constant EPOCH_LEN_L2 = 10;
    uint64 internal constant EPOCH_LEN_L1 = 32;
    bytes32 internal constant COMMITTEE_RECORD_0 = keccak256("committee record 0");

    uint256 internal constant MIN_STAKE = 1000 ether;
    bytes32 internal constant VALIDATOR_KEY = bytes32(uint256(0xa1));

    // ---------------------------------------------------------------
    // State
    // ---------------------------------------------------------------

    MockLandProofVerifier internal landVerifier;
    TestERC20 internal taikoToken;
    EtnaStakingRegistry internal registry;
    IEtnaInbox.Config internal etnaConfig;

    /// @dev The Inbox proxy seen through the Etna implementation; set by `_upgradeToEtna`.
    EtnaInbox internal etnaInbox;

    /// @dev The L2 height of the first proven batch's checkpoint, which is not the last one.
    uint64 internal staleHeight;
    /// @dev `B*`, `H*`, `S*`: the last finalized Shasta block.
    uint64 internal genesisHeight;
    bytes32 internal genesisBlockHash;
    bytes32 internal genesisStateRoot;

    /// @dev The L1 block of the registry's first checkpoint.
    uint64 internal registryCheckpointBlock;
    /// @dev The L1 block in which the Shasta Inbox was frozen.
    uint64 internal frozenAtBlock;

    function setUp() public virtual override {
        super.setUp();
        _proveShastaHistory();
        _deployRegistryWithValidator();
        landVerifier = new MockLandProofVerifier();
        etnaConfig = _buildEtnaConfig();
        _migrate();
    }

    // ---------------------------------------------------------------
    // Hooks (internal virtual)
    // ---------------------------------------------------------------

    /// @dev The last setUp step: freezes the Shasta Inbox and upgrades it to `EtnaInbox`.
    /// Overridden by tests of the states before the upgrade.
    function _migrate() internal virtual {
        _freeze();
        _upgradeToEtna();
    }

    function _buildEtnaConfig() internal virtual returns (IEtnaInbox.Config memory) {
        return IEtnaInbox.Config({
            proofVerifier: address(landVerifier),
            signalService: address(signalService),
            stakingRegistry: address(registry),
            bondToken: address(bondToken),
            l2ChainId: L2_CHAIN_ID,
            maxBatchBlocks: MAX_BATCH_BLOCKS,
            minBond: MIN_BOND_GWEI,
            withdrawalDelay: WITHDRAWAL_DELAY
        });
    }

    // ---------------------------------------------------------------
    // Migration helpers
    // ---------------------------------------------------------------

    /// @dev Proposes and proves two Shasta batches (2 and 3 proposals), leaving the Inbox drained.
    function _proveShastaHistory() internal {
        IInbox.ProveInput memory first = _buildBatchInput(2);
        _prove(first);
        staleHeight = first.commitment.endBlockNumber;

        _advanceBlock();
        IInbox.ProveInput memory last = _buildBatchInput(3);
        _prove(last);
        genesisHeight = last.commitment.endBlockNumber;
        genesisBlockHash = last.commitment.transitions[2].blockHash;
        genesisStateRoot = last.commitment.endStateRoot;

        IInbox.CoreState memory state = inbox.getCoreState();
        assertEq(state.lastFinalizedProposalId + 1, state.nextProposalId, "drained");
        assertEq(state.lastFinalizedBlockHash, genesisBlockHash, "last finalized hash");
    }

    /// @dev Deploys the staking registry and registers one validator, writing checkpoint 0.
    function _deployRegistryWithValidator() internal {
        _advanceBlock();
        taikoToken = new TestERC20("Taiko Token", "TAIKO");
        registry = _deployRegistry();

        taikoToken.mint(Alice, MIN_STAKE);
        vm.startPrank(Alice);
        taikoToken.approve(address(registry), MIN_STAKE);
        registry.register(VALIDATOR_KEY, MIN_STAKE);
        vm.stopPrank();

        registryCheckpointBlock = uint64(block.number);
        assertEq(registry.checkpointCount(), 1, "registry checkpoints");
    }

    /// @dev Deploys an empty staking registry proxy owned by this contract.
    function _deployRegistry() internal returns (EtnaStakingRegistry) {
        EtnaStakingRegistry impl =
            new EtnaStakingRegistry(address(taikoToken), MIN_STAKE, 10, 20, 30, 50);
        return EtnaStakingRegistry(
            address(
                new ERC1967Proxy(
                    address(impl), abi.encodeCall(EtnaStakingRegistry.init, (address(this)))
                )
            )
        );
    }

    function _freeze() internal {
        _advanceBlock();
        inbox.freeze();
        frozenAtBlock = uint64(block.number);
    }

    function _upgradeToEtna() internal {
        _advanceBlock();
        inbox.upgradeTo(address(new EtnaInbox(etnaConfig)));
        etnaInbox = EtnaInbox(address(inbox));
    }

    // ---------------------------------------------------------------
    // Activation helpers
    // ---------------------------------------------------------------

    function _defaultActivationParams() internal view returns (IEtnaInbox.ActivationParams memory) {
        return IEtnaInbox.ActivationParams({
            genesisHeight: genesisHeight,
            epochLenL2: EPOCH_LEN_L2,
            epochLenL1: EPOCH_LEN_L1,
            genesisCutoff: registryCheckpointBlock,
            committeeRecordHash: COMMITTEE_RECORD_0
        });
    }

    function _activate() internal {
        etnaInbox.activateEtna(_defaultActivationParams());
    }

    // ---------------------------------------------------------------
    // Storage helpers
    // ---------------------------------------------------------------

    function _loadSlot(uint256 _slot) internal view returns (uint256) {
        return uint256(vm.load(address(inbox), bytes32(_slot)));
    }

    function _committeeSlot(uint64 _epoch) internal pure returns (bytes32) {
        return keccak256(abi.encode(uint256(_epoch), COMMITTEE_SLOT));
    }
}
