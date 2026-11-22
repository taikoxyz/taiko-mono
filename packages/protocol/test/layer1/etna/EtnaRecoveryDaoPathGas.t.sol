// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { EtnaFallbackRecoveryGasBase } from "./EtnaInboxGas.t.sol";
import { Action } from "script/layer1/governance/IAragonGovernance.sol";
import { LibL1Addrs as L1 } from "src/layer1/mainnet/LibL1Addrs.sol";
import { MainnetDAOController } from "src/layer1/mainnet/MainnetDAOController.sol";
import { EssentialContract } from "src/shared/common/EssentialContract.sol";

/// @notice The Standard Multisig entry points the recovery proposal uses (upstream `Multisig.sol`,
/// taikoxyz/dao-contracts tag `dao-contracts-v1.0.0`).
interface IEtnaGasStandardMultisig {
    function createProposal(
        bytes calldata _metadataURI,
        Action[] calldata _destinationActions,
        address _destinationPlugin,
        bool _approveProposal
    )
        external
        returns (uint256 proposalId_);

    function approve(uint256 _proposalId, bool _tryExecution) external;

    function execute(uint256 _proposalId) external;

    function multisigSettings()
        external
        view
        returns (
            bool onlyListed_,
            uint16 minApprovals_,
            uint32 destinationProposalDuration_,
            address signerList_,
            uint32 proposalExpirationPeriod_
        );
}

/// @notice The Emergency Multisig entry points the recovery proposal uses (upstream
/// `EmergencyMultisig.sol`, the same tag).
interface IEtnaGasEmergencyMultisig {
    function createProposal(
        bytes calldata _encryptedPayloadURI,
        bytes32 _publicMetadataUriHash,
        bytes32 _destinationActionsHash,
        address _destinationPlugin,
        bool _approveProposal
    )
        external
        returns (uint256 proposalId_);

    function approve(uint256 _proposalId) external;

    function execute(
        uint256 _proposalId,
        bytes memory _metadataUri,
        Action[] calldata _actions
    )
        external;

    function multisigSettings()
        external
        view
        returns (
            bool onlyListed_,
            uint16 minApprovals_,
            address signerList_,
            uint32 proposalExpirationPeriod_
        );
}

/// @notice The optimistic token voting plugin entry points (upstream
/// `OptimisticTokenVotingPlugin.sol`, the same tag).
interface IEtnaGasOptimisticPlugin {
    function proposalCount() external view returns (uint256);

    function proposalIds(uint256 _index) external view returns (uint256);

    function canExecute(uint256 _proposalId) external view returns (bool);

    function execute(uint256 _proposalId) external;

    function governanceSettings()
        external
        view
        returns (
            uint32 minVetoRatio_,
            uint32 minDuration_,
            uint32 timelockPeriod_,
            uint32 l2InactivityPeriod_,
            uint32 l2AggregationGracePeriod_,
            bool skipL2_
        );
}

/// @notice The SignerList census lookups (upstream `SignerList.sol`, the same tag).
interface IEtnaGasSignerList {
    function isListedAtBlock(
        address _account,
        uint256 _blockNumber
    )
        external
        view
        returns (bool);

    function resolveEncryptionAccountAtBlock(
        address _address,
        uint256 _blockNumber
    )
        external
        view
        returns (address owner_, address agent_);
}

/// @title EtnaRecoveryDaoPathGasBase
/// @notice The recovery of `EtnaFallbackRecoveryGasBase`, which sets 128 fallback keys and then
/// recovers in one controller call, on the deployed DAO stack: the Etna Inbox is owned by the live
/// `MainnetDAOController`, and the recovery is proposed and executed through the live Aragon DAO,
/// its optimistic token voting plugin and the Standard and Emergency Multisigs on a mainnet fork.
/// Each test sends one top-level transaction of a path, exactly as an operator sends it, prepared
/// by `setUp`, so it starts cold, and requires it to fit the per-transaction gas cap. Each test
/// also measures, first and from cold, the controller-only transaction the DAO itself would send,
/// and requires the step to need at most `DAO_PATH_EXTRA` more: the value the local tests add to
/// their controller-only transactions.
/// The DAO can execute a recovery along two paths:
/// - Standard: `Multisig.createProposal` stores the actions; the approval that reaches the
///   threshold forwards them to the plugin, which stores them again; after the veto period and the
///   timelock, anyone calls `plugin.execute`, which reads them back from storage, and the DAO
///   calls the controller.
/// - Emergency: `EmergencyMultisig.createProposal` stores only the actions' hash; once approved,
///   anyone calls `EmergencyMultisig.execute` with the actions in calldata, which creates a plugin
///   proposal with no veto period (storing the actions) and executes it in the same transaction.
/// The emergency `execute` is the costliest transaction of either path, so it is measured with no
/// blank and with `FI_TO_CLEAR_MEASURED` blanks, and each Standard step with the longer list. The
/// proposal carries a metadata URI of 128 bytes, the longest a recovery proposal may use: each
/// further 32 bytes of URI costs about 23,000 gas more.
/// @dev Skipped unless `L1_FORK_URL` is set, because CI configures no RPC endpoints. Run with:
///
///   L1_FORK_URL=<l1 archive rpc> FOUNDRY_PROFILE=layer1 \
///     forge test --match-path test/layer1/etna/EtnaRecoveryDaoPathGas.t.sol -vv
///
/// The fork is at `L1_FORK_BLOCK`, by default the recorded block below. The Etna fixtures run from
/// block 1 and timestamp 1, as in the local suites; the DAO steps then run one block after the
/// fork block on mainnet's clock, so the census and voting snapshots exist.
abstract contract EtnaRecoveryDaoPathGasBase is EtnaFallbackRecoveryGasBase {
    /// @dev A mainnet block after Proposal0020 set the five-seat council.
    uint256 private constant _DEFAULT_L1_FORK_BLOCK = 26_460_000;

    /// @dev The proposal's public metadata URI at the longest length a recovery proposal may use,
    /// 128 bytes: a 66-byte CIDv1 IPFS URI with a file name. A bare CIDv0 URI has 53.
    bytes internal constant METADATA_URI = "ipfs://bafybeigdyrzt5sfp7udm7hu76uh7y26nf3efuylqabf3oclgtqy55fbzdi"
        "/etna-quorum-recovery-proposal-metadata-for-the-taiko-dao.json";

    /// @dev The council seats `LibL1Addrs` names, current and removed.
    address[11] private _seats = [
        L1.SC_TAIKO_LABS,
        L1.SC_L2BEAT,
        L1.SC_ARAGON,
        L1.SC_GUSTAVO_GONZALEZ,
        L1.SC_DANIEL_WANG,
        L1.SC_NETHERMIND,
        L1.SC_CHAINBOUND,
        L1.SC_HALBORN,
        L1.SC_DREW_VAN_DER_WERFF,
        L1.SC_TONI_WAHRSTATTER,
        L1.SC_GATTACA
    ];

    /// @dev Whether `setUp` forked mainnet.
    bool internal forked;

    /// @dev The DAO's actions: one call of the controller's `execute` with the recovery.
    Action[] internal daoActions;

    /// @dev The voting accounts of the listed seats at the census block, each seat's appointed
    /// agent or the seat itself.
    address[] internal voters;

    /// @dev The measured transaction.
    address internal txFrom;
    address internal txTo;
    bytes internal txData;

    /// @dev Skips a test when `setUp` did not fork.
    modifier whenForked() {
        if (!forked) {
            vm.skip(true, "L1_FORK_URL is not set");
            return;
        }
        _;
    }

    /// @notice Calls `_to` with `_data` and exactly `_gas` as `_from`, then reverts with whether
    /// the call succeeded and the gas of its frame.
    /// @dev Called by this contract only. The revert undoes the call's state changes and the
    /// accounts and slots it warmed, so the transaction measured after it still starts cold.
    function probeCall(
        address _from,
        address _to,
        bytes calldata _data,
        uint256 _gas
    )
        external
    {
        require(msg.sender == address(this), "self only");
        vm.prank(_from);
        (bool ok,) = _to.call{ gas: _gas }(_data);
        bytes memory outcome = abi.encode(ok, vm.lastCallGas().gasTotalUsed);
        assembly ("memory-safe") {
            revert(add(outcome, 32), mload(outcome))
        }
    }

    function setUp() public virtual override {
        string memory url = vm.envOr("L1_FORK_URL", string(""));
        if (bytes(url).length == 0) return;
        vm.createSelectFork(url, vm.envOr("L1_FORK_BLOCK", _DEFAULT_L1_FORK_BLOCK));
        forked = true;
        uint256 forkBlock = block.number;
        uint256 forkTime = block.timestamp;

        vm.roll(1);
        vm.warp(1);
        super.setUp();
        EssentialContract(inboxProxy).transferOwnership(L1.DAO_CONTROLLER);
        MainnetDAOController(payable(L1.DAO_CONTROLLER)).acceptOwnershipOf(inboxProxy);
        assertEq(_inbox().owner(), L1.DAO_CONTROLLER, "the live controller owns the Inbox");
        assertEq(
            MainnetDAOController(payable(L1.DAO_CONTROLLER)).owner(), L1.DAO, "the DAO owns it"
        );

        vm.roll(forkBlock + 1);
        vm.warp(forkTime + 12);
        daoActions.push(
            Action({
                to: L1.DAO_CONTROLLER,
                value: 0,
                data: abi.encodeCall(
                    MainnetDAOController.execute, (abi.encode(_recoveryActions(_blanks())))
                )
            })
        );
        assertEq(METADATA_URI.length, 128, "metadata URI length");
        _resolveVoters();
        _prepare();
    }

    /// @dev The number of queued forced inclusions the measured recovery blanks.
    function _blanks() internal pure virtual returns (uint256);

    /// @dev Prepares the path up to the measured transaction and sets `txFrom`, `txTo` and
    /// `txData`.
    function _prepare() internal virtual;

    /// @dev Creates the Standard Multisig proposal of `daoActions` as the first voter, who
    /// approves it.
    /// @return id_ The multisig proposal id.
    function _createStandardProposal() internal returns (uint256 id_) {
        Action[] memory actions = daoActions;
        vm.prank(voters[0]);
        id_ = IEtnaGasStandardMultisig(L1.DAO_STANDARD_MULTISIG)
            .createProposal(METADATA_URI, actions, L1.DAO_OPTIMISTIC_TOKEN_VOTING_PLUGIN, true);
    }

    /// @dev The Standard Multisig's approval threshold.
    function _standardMinApprovals() internal view returns (uint256 min_) {
        (, min_,,,) = IEtnaGasStandardMultisig(L1.DAO_STANDARD_MULTISIG).multisigSettings();
    }

    /// @dev Approves Standard Multisig proposal `_id` as voters 1 up to, excluding, `_end`,
    /// without trying execution.
    function _approveStandard(uint256 _id, uint256 _end) internal {
        for (uint256 i = 1; i < _end; ++i) {
            vm.prank(voters[i]);
            IEtnaGasStandardMultisig(L1.DAO_STANDARD_MULTISIG).approve(_id, false);
        }
    }

    /// @dev The id of the plugin's latest proposal.
    function _latestPluginProposal() internal view returns (uint256) {
        IEtnaGasOptimisticPlugin plugin =
            IEtnaGasOptimisticPlugin(L1.DAO_OPTIMISTIC_TOKEN_VOTING_PLUGIN);
        return plugin.proposalIds(plugin.proposalCount() - 1);
    }

    /// @dev Sends the measured transaction, requires it to fit 2^24 and checks the recovery.
    function _assertRecoveryFits(string memory _label) internal {
        _assertStepFits(_label);
        _assertRecovered(_blanks());
    }

    /// @dev Sends the measured transaction once, with exactly the execution gas a 2^24 gas limit
    /// leaves after its intrinsic cost, and requires it to succeed and fit 2^24 before refunds.
    /// It must need at most `DAO_PATH_EXTRA` more gas than the controller-only transaction,
    /// measured first and undone.
    function _assertStepFits(string memory _label) internal {
        uint256 controllerTxGas = _controllerOnlyTxGas();
        (address from, address to, bytes memory data) = (txFrom, txTo, txData);
        uint256 budget = _executionBudget(data);
        vm.prank(from);
        (bool ok,) = to.call{ gas: budget }(data);
        uint256 gasUsed = vm.lastCallGas().gasTotalUsed;

        assertTrue(ok, "succeeds with a 2^24 gas limit");
        uint256 txGas = _assertFitsTxGasCap(_label, data, gasUsed);
        emit log_named_uint(string.concat(_label, "_controller_only_tx_gas"), controllerTxGas);
        uint256 extra = txGas > controllerTxGas ? txGas - controllerTxGas : 0;
        emit log_named_uint(string.concat(_label, "_dao_path_extra"), extra);
        assertLe(extra, DAO_PATH_EXTRA, "the DAO path adds at most DAO_PATH_EXTRA");
    }

    /// @dev The gas before refunds of the DAO's own controller-only transaction of `daoActions`,
    /// sent with a 2^24 gas limit inside a probe that undoes it, which must succeed.
    function _controllerOnlyTxGas() private returns (uint256 txGas_) {
        bytes memory data = daoActions[0].data;
        try this.probeCall(L1.DAO, L1.DAO_CONTROLLER, data, _executionBudget(data)) {
            revert("probe returned");
        } catch (bytes memory outcome) {
            require(outcome.length == 64, "probe failed");
            (bool ok, uint256 execution) = abi.decode(outcome, (bool, uint256));
            require(ok, "the controller-only transaction reverts");
            txGas_ = _txGas(data, execution);
        }
    }

    /// @dev Collects the voting account of every seat listed at the census block, the block
    /// before the proposals are created.
    function _resolveVoters() private {
        IEtnaGasSignerList signerList = IEtnaGasSignerList(L1.DAO_SIGNER_LIST);
        uint256 census = block.number - 1;
        for (uint256 i; i < _seats.length; ++i) {
            if (!signerList.isListedAtBlock(_seats[i], census)) continue;
            (, address agent) = signerList.resolveEncryptionAccountAtBlock(_seats[i], census);
            voters.push(agent);
        }
        assertGe(voters.length, _standardMinApprovals(), "enough listed seats");
    }
}

/// @title EtnaRecoveryEmergencyPathGasBase
/// @notice The Emergency Multisig's `execute` of an approved recovery proposal: the one
/// transaction that carries the actions in calldata, stores them in a new plugin proposal and
/// executes it.
abstract contract EtnaRecoveryEmergencyPathGasBase is EtnaRecoveryDaoPathGasBase {
    function _prepare() internal override {
        IEtnaGasEmergencyMultisig emergency = IEtnaGasEmergencyMultisig(L1.DAO_EMERGENCY_MULTISIG);
        (, uint16 minApprovals,,) = emergency.multisigSettings();
        assertGe(voters.length, minApprovals, "enough voters for the emergency threshold");
        Action[] memory actions = daoActions;
        vm.prank(voters[0]);
        uint256 id = emergency.createProposal(
            METADATA_URI,
            keccak256(METADATA_URI),
            keccak256(abi.encode(actions)),
            L1.DAO_OPTIMISTIC_TOKEN_VOTING_PLUGIN,
            true
        );
        for (uint256 i = 1; i < minApprovals; ++i) {
            vm.prank(voters[i]);
            emergency.approve(id);
        }
        txFrom = Henry;
        txTo = L1.DAO_EMERGENCY_MULTISIG;
        txData = abi.encodeCall(IEtnaGasEmergencyMultisig.execute, (id, METADATA_URI, actions));
    }
}

/// @title EtnaRecoveryEmergencyNoBlankGasTest
/// @notice The Emergency Multisig's execution of the recovery that sets 128 fallback keys and
/// blanks no forced inclusion fits 2^24.
contract EtnaRecoveryEmergencyNoBlankGasTest is EtnaRecoveryEmergencyPathGasBase {
    function _blanks() internal pure override returns (uint256) {
        return 0;
    }

    function test_gas_EmergencyExecuteSet128KeysAndRecoverWithNoBlankFitsTheTransactionCap()
        external
        whenForked
    {
        _assertRecoveryFits("emergency_execute_no_blank");
    }
}

/// @title EtnaRecoveryEmergencySixteenBlanksGasTest
/// @notice The Emergency Multisig's execution of the recovery that sets 128 fallback keys and
/// blanks `FI_TO_CLEAR_MEASURED` forced inclusions fits 2^24: the costliest transaction measured.
contract EtnaRecoveryEmergencySixteenBlanksGasTest is EtnaRecoveryEmergencyPathGasBase {
    function _blanks() internal pure override returns (uint256) {
        return FI_TO_CLEAR_MEASURED;
    }

    function test_gas_EmergencyExecuteSet128KeysAndRecoverWithSixteenBlanksFitsTheTransactionCap()
        external
        whenForked
    {
        _assertRecoveryFits("emergency_execute_16_blanks");
    }
}

/// @title EtnaRecoveryStandardCreateGasTest
/// @notice The Standard Multisig's `createProposal` of the recovery that sets 128 fallback keys and
/// blanks `FI_TO_CLEAR_MEASURED` forced inclusions, approved by its creator, fits 2^24: it stores
/// the actions.
contract EtnaRecoveryStandardCreateGasTest is EtnaRecoveryDaoPathGasBase {
    function _blanks() internal pure override returns (uint256) {
        return FI_TO_CLEAR_MEASURED;
    }

    function _prepare() internal override {
        txFrom = voters[0];
        txTo = L1.DAO_STANDARD_MULTISIG;
        txData = abi.encodeCall(
            IEtnaGasStandardMultisig.createProposal,
            (METADATA_URI, daoActions, L1.DAO_OPTIMISTIC_TOKEN_VOTING_PLUGIN, true)
        );
    }

    function test_gas_StandardCreateSet128KeysAndRecoverFitsTheTransactionCap()
        external
        whenForked
    {
        _assertStepFits("standard_create_16_blanks");
    }
}

/// @title EtnaRecoveryStandardForwardGasTest
/// @notice The approval that reaches the Standard Multisig's threshold, with execution, fits 2^24:
/// it reads the stored actions of the recovery that sets 128 fallback keys and blanks
/// `FI_TO_CLEAR_MEASURED` forced inclusions, and creates the plugin proposal, which stores them
/// again.
contract EtnaRecoveryStandardForwardGasTest is EtnaRecoveryDaoPathGasBase {
    /// @dev The plugin's proposal count before the forward.
    uint256 internal pluginProposalsBefore;

    function _blanks() internal pure override returns (uint256) {
        return FI_TO_CLEAR_MEASURED;
    }

    function _prepare() internal override {
        uint256 id = _createStandardProposal();
        uint256 min = _standardMinApprovals();
        _approveStandard(id, min - 1);
        pluginProposalsBefore =
            IEtnaGasOptimisticPlugin(L1.DAO_OPTIMISTIC_TOKEN_VOTING_PLUGIN).proposalCount();
        txFrom = voters[min - 1];
        txTo = L1.DAO_STANDARD_MULTISIG;
        txData = abi.encodeCall(IEtnaGasStandardMultisig.approve, (id, true));
    }

    function test_gas_StandardForwardSet128KeysAndRecoverFitsTheTransactionCap()
        external
        whenForked
    {
        _assertStepFits("standard_forward_16_blanks");
        assertEq(
            IEtnaGasOptimisticPlugin(L1.DAO_OPTIMISTIC_TOKEN_VOTING_PLUGIN).proposalCount(),
            pluginProposalsBefore + 1,
            "forwarded to the plugin"
        );
    }
}

/// @title EtnaRecoveryStandardExecuteGasTest
/// @notice The plugin's `execute` of the forwarded recovery that sets 128 fallback keys and blanks
/// `FI_TO_CLEAR_MEASURED` forced inclusions, after the veto period and the timelock, fits 2^24.
contract EtnaRecoveryStandardExecuteGasTest is EtnaRecoveryDaoPathGasBase {
    function _blanks() internal pure override returns (uint256) {
        return FI_TO_CLEAR_MEASURED;
    }

    function _prepare() internal override {
        uint256 id = _createStandardProposal();
        uint256 min = _standardMinApprovals();
        _approveStandard(id, min);
        IEtnaGasStandardMultisig(L1.DAO_STANDARD_MULTISIG).execute(id);
        uint256 pluginId = _latestPluginProposal();

        IEtnaGasOptimisticPlugin plugin =
            IEtnaGasOptimisticPlugin(L1.DAO_OPTIMISTIC_TOKEN_VOTING_PLUGIN);
        (,, uint32 timelock,, uint32 grace,) = plugin.governanceSettings();
        uint256 vetoEnd = uint64(pluginId >> 64);
        uint256 executable = vetoEnd + timelock + grace;
        vm.roll(block.number + (executable - block.timestamp) / 12 + 1);
        vm.warp(executable);
        assertTrue(plugin.canExecute(pluginId), "executable after the veto period and timelock");

        txFrom = Henry;
        txTo = L1.DAO_OPTIMISTIC_TOKEN_VOTING_PLUGIN;
        txData = abi.encodeCall(IEtnaGasOptimisticPlugin.execute, (pluginId));
    }

    function test_gas_StandardExecuteSet128KeysAndRecoverFitsTheTransactionCap()
        external
        whenForked
    {
        _assertRecoveryFits("standard_execute_16_blanks");
    }
}
