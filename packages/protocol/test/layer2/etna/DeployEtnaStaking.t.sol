// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { EtnaStakingTestBase } from "./EtnaStakingTestBase.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { DeployEtnaStaking } from "script/layer2/etna/DeployEtnaStaking.s.sol";
import { LibEtnaStakingEnv } from "script/layer2/etna/LibEtnaStakingEnv.sol";
import { EtnaStaking } from "src/layer2/etna/EtnaStaking.sol";
import { EtnaStakingDeployer } from "src/layer2/etna/EtnaStakingDeployer.sol";
import { IEtnaStaking } from "src/layer2/etna/iface/IEtnaStaking.sol";

/// @notice Runs `DeployEtnaStaking` against the CREATE2 factory as it is deployed on Taiko mainnet
/// and Taiko Hoodi L2: one transaction deploys the implementation and the initialized proxy at
/// addresses `predict` gives in advance.
contract DeployEtnaStakingTest is EtnaStakingTestBase {
    /// @dev The runtime code of the CREATE2 factory at `CREATE2_FACTORY`
    /// (0x4e59b44847b379578588920cA78FbF26c0B4956C).
    bytes private constant _FACTORY_CODE =
        hex"7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe03601600081602082378035828234f58015156039578182fd5b8082525050506014600cf3";

    /// @dev The ERC-1967 implementation slot.
    bytes32 private constant _IMPLEMENTATION_SLOT =
        0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    /// @dev U, the Inbox's maximum number of unsettled L2 blocks, and the evidence window, in L2
    /// blocks. `WITHDRAWAL_DELAY` is exactly U + 2 + the window.
    uint256 private constant _UNSETTLED_LIMIT = 151_200;
    uint256 private constant _EVIDENCE_WINDOW = 151_200;

    /// @dev The factory salt of the direct `deploy` calls.
    bytes32 private constant _SALT = bytes32(uint256(0xe7a));

    DeployEtnaStaking private _script;

    function setUp() public override {
        super.setUp();
        vm.etch(CREATE2_FACTORY, _FACTORY_CODE);
        _script = new DeployEtnaStaking();
    }

    // ---------------------------------------------------------------
    // deploy
    // ---------------------------------------------------------------

    function test_deploy_OneTransactionAtPredictedAddresses() external {
        IEtnaStaking.Config memory cfg = _config();
        (address deployer_, address predictedImpl, address predictedProxy) =
            _script.predict(cfg, STAKING_OWNER, _SALT);
        assertEq(deployer_.code.length, 0, "no deployer before");
        assertEq(predictedImpl.code.length, 0, "no implementation before");
        assertEq(predictedProxy.code.length, 0, "no proxy before");
        // Without a prank, `vm.broadcast()` sends from tx.origin.
        uint64 nonce = vm.getNonce(tx.origin);

        (address impl, address proxy) =
            _script.deploy(cfg, STAKING_OWNER, _SALT, _UNSETTLED_LIMIT, _EVIDENCE_WINDOW);

        assertEq(vm.getNonce(tx.origin), nonce + 1, "one transaction");
        assertEq(impl, predictedImpl, "implementation at the predicted address");
        assertEq(proxy, predictedProxy, "proxy at the predicted address");
        assertGt(impl.code.length, 0, "implementation code");
        assertEq(EtnaStakingDeployer(deployer_).implementation(), impl, "deployer's implementation");
        assertEq(EtnaStakingDeployer(deployer_).proxy(), proxy, "deployer's proxy");
        assertEq(
            keccak256(proxy.code), keccak256(type(ERC1967Proxy).runtimeCode), "stock proxy code"
        );
        assertEq(
            vm.load(proxy, _IMPLEMENTATION_SLOT),
            bytes32(uint256(uint160(impl))),
            "proxy's implementation slot"
        );
        EtnaStaking deployed = EtnaStaking(proxy);
        assertEq(deployed.owner(), STAKING_OWNER, "owner");
        assertEq(deployed.pendingOwner(), address(0), "no pending owner");
        _assertImmutables(deployed, cfg);
    }

    function test_deploy_ProxyCannotBeReinitialized() external {
        (address impl, address proxy) =
            _script.deploy(_config(), STAKING_OWNER, _SALT, _UNSETTLED_LIMIT, _EVIDENCE_WINDOW);

        vm.prank(Alice);
        vm.expectRevert("Initializable: contract is already initialized");
        EtnaStaking(proxy).init(Alice);
        vm.prank(Alice);
        vm.expectRevert("Initializable: contract is already initialized");
        EtnaStaking(impl).init(Alice);
        assertEq(EtnaStaking(proxy).owner(), STAKING_OWNER, "owner unchanged");
    }

    /// @dev withdrawalDelay must reach U + 2 + the evidence window: 302,402 with U and the window
    /// both 151,200.
    function test_deploy_WithdrawalDelayBound() external {
        IEtnaStaking.Config memory cfg = _config();
        cfg.withdrawalDelay = 302_401;
        vm.expectRevert(LibEtnaStakingEnv.WithdrawalDelayTooShort.selector);
        _script.deploy(cfg, STAKING_OWNER, _SALT, _UNSETTLED_LIMIT, _EVIDENCE_WINDOW);

        cfg.withdrawalDelay = 302_402;
        (, address proxy) =
            _script.deploy(cfg, STAKING_OWNER, _SALT, _UNSETTLED_LIMIT, _EVIDENCE_WINDOW);
        assertEq(EtnaStaking(proxy).withdrawalDelay(), 302_402, "at the bound");
    }

    /// @dev Environment variables are process-wide; this is the only test in the profile that sets
    /// them, so no other test races it.
    function test_deploy_RevertWhen_InputsInvalid() external {
        IEtnaStaking.Config memory cfg = _config();
        vm.expectRevert(LibEtnaStakingEnv.InvalidUnsettledLimit.selector);
        _script.deploy(cfg, STAKING_OWNER, _SALT, 0, _EVIDENCE_WINDOW);
        vm.expectRevert(LibEtnaStakingEnv.InvalidUnsettledLimit.selector);
        _script.deploy(cfg, STAKING_OWNER, _SALT, 262_145, _EVIDENCE_WINDOW);
        vm.expectRevert(LibEtnaStakingEnv.ZeroEvidenceWindow.selector);
        _script.deploy(cfg, STAKING_OWNER, _SALT, _UNSETTLED_LIMIT, 0);
        vm.expectRevert(DeployEtnaStaking.ZeroOwner.selector);
        _script.deploy(cfg, address(0), _SALT, _UNSETTLED_LIMIT, _EVIDENCE_WINDOW);
        // `init` would make a zero owner the deployer contract itself.
        vm.expectRevert(EtnaStakingDeployer.ZeroOwner.selector);
        new EtnaStakingDeployer(cfg, address(0));
        // The factory reverts without data when the constructor refuses the configuration.
        IEtnaStaking.Config memory sinkIsToken = _config();
        sinkIsToken.slashSink = sinkIsToken.token;
        vm.expectRevert(IEtnaStaking.SlashSinkIsToken.selector);
        new EtnaStakingDeployer(sinkIsToken, STAKING_OWNER);
        vm.expectRevert(DeployEtnaStaking.DeploymentFailed.selector);
        _script.deploy(sinkIsToken, STAKING_OWNER, _SALT, _UNSETTLED_LIMIT, _EVIDENCE_WINDOW);

        _setEnvironment();
        vm.setEnv("L2_CHAIN_ID", vm.toString(block.chainid + 1));
        vm.expectRevert(DeployEtnaStaking.L2ChainIdMismatch.selector);
        _script.run();
        vm.setEnv("L2_CHAIN_ID", vm.toString(block.chainid));

        // An empty ETNA_UNSETTLED_LIMIT reads as 151,200: one block more of evidence window is too
        // much for the delay of 302,402, and the window of 151,200 fits.
        vm.setEnv("EVIDENCE_WINDOW_BLOCKS", vm.toString(_EVIDENCE_WINDOW + 1));
        vm.expectRevert(LibEtnaStakingEnv.WithdrawalDelayTooShort.selector);
        _script.run();
        vm.setEnv("EVIDENCE_WINDOW_BLOCKS", vm.toString(_EVIDENCE_WINDOW));

        // The empty variables read as their defaults, which are the base's reference values, and
        // an empty DEPLOYMENT_SALT as zero.
        (, address predictedImpl, address predictedProxy) =
            _script.predict(cfg, STAKING_OWNER, bytes32(0));
        (address impl, address proxy) = _script.run();
        assertEq(impl, predictedImpl, "implementation at the predicted address");
        assertEq(proxy, predictedProxy, "proxy at the predicted address");
        assertEq(EtnaStaking(proxy).owner(), STAKING_OWNER, "owner");
        _assertImmutables(EtnaStaking(proxy), cfg);

        vm.expectRevert(DeployEtnaStaking.AlreadyDeployed.selector);
        _script.run();
    }

    // ---------------------------------------------------------------
    // Helpers
    // ---------------------------------------------------------------

    /// @dev Sets every variable `run` reads to the base's reference deployment: the five
    /// variables with defaults empty, and DEPLOYMENT_SALT and ETNA_UNSETTLED_LIMIT empty.
    function _setEnvironment() private {
        vm.setEnv("L2_CHAIN_ID", vm.toString(block.chainid));
        vm.setEnv("CONTRACT_OWNER", vm.toString(STAKING_OWNER));
        vm.setEnv("ETNA_UNSETTLED_LIMIT", "");
        vm.setEnv("EVIDENCE_WINDOW_BLOCKS", vm.toString(_EVIDENCE_WINDOW));
        vm.setEnv("DEPLOYMENT_SALT", "");
        vm.setEnv("TAIKO_TOKEN", vm.toString(address(token)));
        vm.setEnv("L1_CHAIN_ID", vm.toString(L1_CHAIN_ID));
        vm.setEnv("INBOX_PROXY", vm.toString(INBOX));
        vm.setEnv("ETNA_WITHDRAWAL_DELAY", vm.toString(WITHDRAWAL_DELAY));
        vm.setEnv("ETNA_SLASH_BOUNTY_BPS", vm.toString(SLASH_BOUNTY_BPS));
        vm.setEnv("ETNA_SLASH_SINK", vm.toString(SLASH_SINK));
        vm.setEnv("ETNA_FORFEIT_BPS", vm.toString(FORFEIT_BPS));
        vm.setEnv("ETNA_MIN_STAKE", "");
        vm.setEnv("ETNA_VP_UNIT", "");
        vm.setEnv("ETNA_N_MAX", "");
        vm.setEnv("ETNA_MISS_LIMIT", "");
        vm.setEnv("ETNA_MISS_SLASH_BPS", "");
    }

    /// @dev Asserts the twelve immutables `_staking` serves against `_cfg`.
    function _assertImmutables(
        EtnaStaking _staking,
        IEtnaStaking.Config memory _cfg
    )
        private
        view
    {
        assertEq(_staking.token(), _cfg.token, "token");
        assertEq(_staking.l1ChainId(), _cfg.l1ChainId, "l1 chain id");
        assertEq(_staking.inbox(), _cfg.inbox, "inbox");
        assertEq(_staking.minStake(), _cfg.minStake, "min stake");
        assertEq(_staking.vpUnit(), _cfg.vpUnit, "vp unit");
        assertEq(_staking.nMax(), _cfg.nMax, "n max");
        assertEq(_staking.missLimit(), _cfg.missLimit, "miss limit");
        assertEq(_staking.missSlashBps(), _cfg.missSlashBps, "miss slash bps");
        assertEq(_staking.withdrawalDelay(), _cfg.withdrawalDelay, "withdrawal delay");
        assertEq(_staking.slashBountyBps(), _cfg.slashBountyBps, "slash bounty bps");
        assertEq(_staking.slashSink(), _cfg.slashSink, "slash sink");
        assertEq(_staking.forfeitBps(), _cfg.forfeitBps, "forfeit bps");
    }
}
