// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Proposal0024Harness } from "./Proposal0024Harness.sol";
import { Proposal0025Harness } from "./Proposal0025Harness.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Test, console2 } from "forge-std/src/Test.sol";
import { Proposal0025 } from "script/layer1/proposals/Proposal0025.s.sol";
import { LibL1Addrs as L1 } from "src/layer1/mainnet/LibL1Addrs.sol";
import { LibL2Addrs as L2 } from "src/layer2/mainnet/LibL2Addrs.sol";
import { Bridge } from "src/shared/bridge/Bridge.sol";
import { IBridge, IMessageInvocable } from "src/shared/bridge/IBridge.sol";
import { QuotaManager } from "src/shared/bridge/QuotaManager.sol";
import { DefaultResolver } from "src/shared/common/DefaultResolver.sol";
import { Controller } from "src/shared/governance/Controller.sol";
import { LibNames } from "src/shared/libs/LibNames.sol";
import { ISignalService } from "src/shared/signal/ISignalService.sol";
import { ERC20Vault } from "src/shared/vault/ERC20Vault.sol";

/// @notice Rehearses the Proposal0025 upgrades against live mainnet state.
/// @dev Skipped unless `L1_FORK_URL` / `L2_FORK_URL` are set, because CI configures no RPC
/// endpoints. Run with:
///
///   L1_FORK_URL=<l1 rpc> L2_FORK_URL=https://rpc.mainnet.taiko.xyz \
///     FOUNDRY_PROFILE=layer1 forge test --match-contract Proposal0025ForkTest -vv
///
/// Proposal0025 executes after Proposal0024. While a fork still runs the pre-Proposal0024
/// implementations, the rehearsal first executes Proposal0024's batch on that fork, the way
/// `Proposal0024Fork.t.sol` does, so it always rehearses the transition Proposal0025 will actually
/// make. While the constants in `Proposal0025.s.sol` are still placeholders, the implementations
/// are built from this tree inside the fork, with the immutables the deploy scripts bake in; once
/// the constants name deployed contracts, those are used and nothing is deployed.
///
/// On L1 the rehearsal pins the defect first, on the implementations Proposal0024 installs, then
/// executes the batch and shows the fix: the same send-fail-recall cycles now stop at the recall
/// with `B_RECALL_DISABLED`, leaving both quotas untouched, and an L2 -> L1 delivery is still
/// debited. On L2 the bridge upgrades itself from inside its own `processMessage` frame and keeps
/// sending, delivering and serving governance afterwards. The signal proofs are mocked on both
/// forks, as in `Proposal0024Fork.t.sol`: a valid proof cannot be synthesised against a fork.
/// @custom:security-contact security@taiko.xyz
contract Proposal0025ForkTest is Test {
    /// @dev Live values read before a batch executes, compared against afterwards.
    struct Before {
        uint64 messageId;
        address bridgeOwner;
        address vaultOwner;
        // L2 only: a bridged token the 1.10.0 vault deployed, which must keep working.
        address bridgedUsdt;
    }

    /// @dev EIP-1967 implementation slot.
    bytes32 private constant _IMPL_SLOT =
        0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    /// @dev The canonical Permit2 deployment, present on both chains.
    address private constant _PERMIT2 = 0x000000000022D473030F116dDEE9F6B43aC78BA3;

    /// @dev The amount every token movement below uses, in the token's smallest unit.
    uint256 private constant _TOKEN_AMOUNT = 50e6;

    /// @dev The implementations Proposal0024 installs and this proposal replaces. The rehearsal
    /// starts from them on both chains.
    address private constant _P24_BRIDGE_IMPL_L1 = 0xA15dca0A72da684f20e0FC708DECFb230a715462;
    address private constant _P24_ERC20_VAULT_IMPL_L1 = 0x32E47c04E8c329E8c10062731448e7658aDEEB8e;
    address private constant _P24_BRIDGE_IMPL_L2 = 0xa200c2268d77737a8Fd2CA1698dA6eeab2a85CEb;
    address private constant _P24_ERC20_VAULT_IMPL_L2 = 0xa01d464ca3982DAa97B19fa7F8a232eB11A9DDb3;

    /// @dev The implementations live before Proposal0024. A fork still running them has
    /// Proposal0024's batch executed first.
    address private constant _P17_BRIDGE_IMPL_L1 = 0x1c94D798CFA08F396E5BA9F81697289c53273381;
    address private constant _V110_BRIDGE_IMPL_L2 = 0x95ae2918dcbc6aFF8B4c1F1BCC1bf819b6e08B83;

    function test_l1_upgradesAgainstLiveState() external {
        if (!_forkOrSkip("L1_FORK_URL")) return;
        _mockSignalProofs(L1.SIGNAL_SERVICE);
        _ensureProposal0024ExecutedOnL1();

        Proposal0025Harness harness = new Proposal0025Harness();
        Proposal0025.L1Deployment memory l1 = _l1Deployment(harness);
        Proposal0025.L2Deployment memory l2 = _l2AddressesForEncoding(harness);

        // Start from a full quota, whatever the fork's recent traffic left.
        QuotaManager qm = QuotaManager(L1.QUOTA_MANAGER);
        vm.warp(block.timestamp + 24 hours);
        uint256 ethQuota = qm.availableQuota(address(0), 0);
        uint256 wethQuota = qm.availableQuota(L1.WETH_TOKEN, 0);
        assertTrue(ethQuota > 0 && ethQuota != qm.UNLIMITED_QUOTA(), "no Ether quota on this fork");
        assertTrue(wethQuota > 0 && wethQuota != qm.UNLIMITED_QUOTA(), "no WETH quota on this fork");

        // Pin the defect on the implementations Proposal0024 installs: a recall of the whole
        // quota's worth drains the Ether quota, and a token refund is debited too.
        _sendAndRecallEther(makeAddr("attacker before"), ethQuota);
        assertEq(qm.availableQuota(address(0), 0), 0, "defect: the recall did not drain the quota");
        _sendAndRecallWeth(makeAddr("holder before"));
        assertEq(
            qm.availableQuota(L1.WETH_TOKEN, 0),
            wethQuota - _TOKEN_AMOUNT,
            "defect: the refund did not debit the token quota"
        );

        Before memory before = Before({
            messageId: Bridge(payable(L1.BRIDGE)).nextMessageId(),
            bridgeOwner: Bridge(payable(L1.BRIDGE)).owner(),
            vaultOwner: ERC20Vault(L1.ERC20_VAULT).owner(),
            bridgedUsdt: address(0)
        });

        // Execute the whole L1 batch the way the DAO controller will: both upgrades, then the
        // sendMessage that BuildProposal appends, through the just-upgraded bridge.
        Controller.Action[] memory actions = harness.exposedBuildAllActions(l1, l2);
        assertEq(actions.length, 3);
        _executeAs(L1.DAO_CONTROLLER, actions);

        _assertL1AfterUpgrade(l1, before);

        // The fix: recalls are switched off. Once the quotas have refilled, the same cycles stop at
        // the recall and leave both exactly where they were...
        vm.warp(block.timestamp + 24 hours);
        assertEq(qm.availableQuota(address(0), 0), ethQuota);
        assertEq(qm.availableQuota(L1.WETH_TOKEN, 0), wethQuota);
        _assertRecallDisabled(_sendEther(makeAddr("attacker after"), ethQuota));
        _assertRecallDisabled(_sendWeth(makeAddr("holder after")));
        assertEq(qm.availableQuota(address(0), 0), ethQuota);
        assertEq(qm.availableQuota(L1.WETH_TOKEN, 0), wethQuota);

        // ...and a real withdrawal is still debited.
        _deliverEtherFromL2(makeAddr("recipient on L1"), 1 ether);
        assertEq(qm.availableQuota(address(0), 0), ethQuota - 1 ether);
    }

    function test_l2_selfUpgradeThroughProcessMessage() external {
        if (!_forkOrSkip("L2_FORK_URL")) return;
        _rehearseL2Upgrade(L2.PERMISSIONLESS_EXECUTOR);
    }

    /// @dev The same rehearsal driven by a relayer rather than the destination owner: a relayer
    /// receives `_invocationGasLimit` rather than `gasleft()`, which is what this case covers.
    function test_l2_selfUpgradeThroughProcessMessage_byRelayer() external {
        if (!_forkOrSkip("L2_FORK_URL")) return;
        _rehearseL2Upgrade(makeAddr("relayer"));
    }

    // ---------------------------------------------------------------
    // L1
    // ---------------------------------------------------------------

    /// @dev Brings the L1 fork to the state Proposal0025 executes from: the Proposal0024
    /// implementations. A fork still on the Proposal0017 bridge has Proposal0024's L1 batch
    /// executed first.
    function _ensureProposal0024ExecutedOnL1() private {
        if (_implementationOf(L1.BRIDGE) == _P17_BRIDGE_IMPL_L1) {
            console2.log("L1 fork predates Proposal0024; executing its L1 batch first");
            Proposal0024Harness p24 = new Proposal0024Harness();
            _executeAs(L1.DAO_CONTROLLER, p24.exposedBuildAllActions());
        }
        assertEq(
            _implementationOf(L1.BRIDGE),
            _P24_BRIDGE_IMPL_L1,
            "L1 fork does not run the Proposal0024 bridge implementation"
        );
        assertEq(
            _implementationOf(L1.ERC20_VAULT),
            _P24_ERC20_VAULT_IMPL_L1,
            "L1 fork does not run the Proposal0024 vault implementation"
        );
    }

    /// @dev The implementations the L1 leg points at: the deployed ones once the constants name
    /// them, otherwise ones built from this tree with the immutables `DeployProposal0025L1` bakes
    /// in.
    /// @param _harness The proposal.
    /// @return d_ The L1 implementations.
    function _l1Deployment(Proposal0025Harness _harness)
        private
        returns (Proposal0025.L1Deployment memory d_)
    {
        d_ = Proposal0025.L1Deployment({
            bridgeImpl: _harness.BRIDGE_NEW_IMPL_L1(),
            erc20VaultImpl: _harness.ERC20_VAULT_NEW_IMPL_L1()
        });
        if (d_.bridgeImpl == address(0) || d_.erc20VaultImpl == address(0)) {
            console2.log("Proposal0025 L1 constants are placeholders; building the implementations");
            d_.bridgeImpl = address(
                new Bridge(
                    L1.SHARED_RESOLVER,
                    L1.SIGNAL_SERVICE,
                    L1.QUOTA_MANAGER,
                    L1.MULTISIG_ADMIN_TAIKO_ETH,
                    false
                )
            );
            d_.erc20VaultImpl = address(new ERC20Vault(L1.SHARED_RESOLVER, L1.QUOTA_MANAGER));
        } else {
            assertGt(d_.bridgeImpl.code.length, 0, "L1 bridge implementation is not deployed");
            assertGt(d_.erc20VaultImpl.code.length, 0, "L1 vault implementation is not deployed");
        }
    }

    /// @dev The L2 addresses the L1 leg encodes into its bridge message. The L2 leg itself is
    /// rehearsed on the L2 fork, so while the constants are placeholders any non-zero addresses
    /// give the L1 batch its final shape.
    /// @param _harness The proposal.
    /// @return d_ The L2 implementations, or stand-ins.
    function _l2AddressesForEncoding(Proposal0025Harness _harness)
        private
        returns (Proposal0025.L2Deployment memory d_)
    {
        d_ = Proposal0025.L2Deployment({
            bridgeImpl: _harness.BRIDGE_NEW_IMPL_L2(),
            erc20VaultImpl: _harness.ERC20_VAULT_NEW_IMPL_L2()
        });
        if (d_.bridgeImpl == address(0)) d_.bridgeImpl = makeAddr("L2 bridge implementation");
        if (d_.erc20VaultImpl == address(0)) {
            d_.erc20VaultImpl = makeAddr("L2 vault implementation");
        }
    }

    /// @dev Checks the L1 proxies after the batch: implementations, immutables and owners kept,
    /// and the governance message left through the new bridge implementation.
    /// @param _l1 The implementations the proxies must now run.
    /// @param _before The live values read before the batch.
    function _assertL1AfterUpgrade(
        Proposal0025.L1Deployment memory _l1,
        Before memory _before
    )
        private
        view
    {
        Bridge bridge = Bridge(payable(L1.BRIDGE));
        assertEq(_implementationOf(L1.BRIDGE), _l1.bridgeImpl);
        assertEq(bridge.owner(), _before.bridgeOwner);
        assertEq(bridge.resolver(), L1.SHARED_RESOLVER);
        assertEq(address(bridge.signalService()), L1.SIGNAL_SERVICE);
        assertEq(address(bridge.quotaManager()), L1.QUOTA_MANAGER);
        assertEq(bridge.pauser(), L1.MULTISIG_ADMIN_TAIKO_ETH);
        assertFalse(bridge.recallEnabled());
        (bool enabled, address destBridge) = bridge.isDestChainEnabled(167_000);
        assertTrue(enabled);
        assertEq(destBridge, L2.BRIDGE);
        assertEq(bridge.nextMessageId(), _before.messageId + 1);

        ERC20Vault vault = ERC20Vault(L1.ERC20_VAULT);
        assertEq(_implementationOf(L1.ERC20_VAULT), _l1.erc20VaultImpl);
        assertEq(vault.owner(), _before.vaultOwner);
        assertEq(vault.resolver(), L1.SHARED_RESOLVER);
        assertEq(address(vault.quotaManager()), L1.QUOTA_MANAGER);
        assertEq(vault.PERMIT2(), _PERMIT2);
    }

    /// @dev The cycle from the report: `_attacker` locks `_amount` of Ether for L2 and recalls it
    /// once the failure is "proven", ending with the Ether back in hand.
    /// @param _attacker A fresh account.
    /// @param _amount The amount to lock and recall.
    function _sendAndRecallEther(address _attacker, uint256 _amount) private {
        IBridge.Message memory sent = _sendEther(_attacker, _amount);

        Bridge bridge = Bridge(payable(L1.BRIDGE));
        bridge.recallMessage(sent, "");
        assertEq(
            uint8(bridge.messageStatus(bridge.hashMessage(sent))), uint8(IBridge.Status.RECALLED)
        );
        assertEq(_attacker.balance, _amount);
    }

    /// @dev The token flavour of the cycle: `_holder` sends WETH to L2 through the vault and
    /// recalls it, ending with the WETH back in hand.
    /// @param _holder A fresh account.
    function _sendAndRecallWeth(address _holder) private {
        Bridge(payable(L1.BRIDGE)).recallMessage(_sendWeth(_holder), "");
        assertEq(IERC20(L1.WETH_TOKEN).balanceOf(_holder), _TOKEN_AMOUNT);
    }

    /// @dev Recalling `_sent` reverts and leaves it `NEW`.
    /// @param _sent A message the L1 bridge sent.
    function _assertRecallDisabled(IBridge.Message memory _sent) private {
        Bridge bridge = Bridge(payable(L1.BRIDGE));
        vm.expectRevert(Bridge.B_RECALL_DISABLED.selector);
        bridge.recallMessage(_sent, "");
        assertEq(uint8(bridge.messageStatus(bridge.hashMessage(_sent))), uint8(IBridge.Status.NEW));
    }

    /// @dev `_attacker` locks `_amount` of Ether for L2.
    /// @param _attacker A fresh account.
    /// @param _amount The amount to lock.
    /// @return sent_ The message the bridge sent.
    function _sendEther(
        address _attacker,
        uint256 _amount
    )
        private
        returns (IBridge.Message memory sent_)
    {
        vm.deal(_attacker, _amount);

        IBridge.Message memory message;
        message.srcOwner = _attacker;
        message.destOwner = _attacker;
        message.destChainId = 167_000;
        message.to = _attacker;
        message.value = _amount;

        vm.prank(_attacker);
        (, sent_) = Bridge(payable(L1.BRIDGE)).sendMessage{ value: _amount }(message);
        assertEq(_attacker.balance, 0);
    }

    /// @dev `_holder` sends `_TOKEN_AMOUNT` of WETH to L2 through the vault.
    /// @param _holder A fresh account.
    /// @return sent_ The message the vault sent.
    function _sendWeth(address _holder) private returns (IBridge.Message memory sent_) {
        deal(L1.WETH_TOKEN, _holder, _TOKEN_AMOUNT);
        ERC20Vault vault = ERC20Vault(L1.ERC20_VAULT);

        vm.startPrank(_holder);
        IERC20(L1.WETH_TOKEN).approve(address(vault), _TOKEN_AMOUNT);
        sent_ = vault.sendToken(
            ERC20Vault.BridgeTransferOp({
                destChainId: 167_000,
                destOwner: _holder,
                to: _holder,
                fee: 0,
                token: L1.WETH_TOKEN,
                gasLimit: 1_000_000,
                amount: _TOKEN_AMOUNT
            })
        );
        vm.stopPrank();
        assertEq(IERC20(L1.WETH_TOKEN).balanceOf(_holder), 0);
    }

    /// @dev Delivers `_value` of Ether from L2 to `_recipient`, the way a relayer delivers an L2
    /// withdrawal, processed by the recipient itself.
    /// @param _recipient A fresh account.
    /// @param _value The amount delivered.
    function _deliverEtherFromL2(address _recipient, uint256 _value) private {
        IBridge.Message memory message;
        message.id = 8_250_001;
        message.from = makeAddr("L2 sender");
        message.srcChainId = 167_000;
        message.srcOwner = message.from;
        message.destChainId = 1;
        message.destOwner = _recipient;
        message.to = _recipient;
        message.value = _value;

        vm.prank(_recipient);
        (IBridge.Status status, IBridge.StatusReason reason) =
            Bridge(payable(L1.BRIDGE)).processMessage(message, "");
        assertEq(uint8(status), uint8(IBridge.Status.DONE));
        assertEq(uint8(reason), uint8(IBridge.StatusReason.INVOCATION_OK));
        assertEq(_recipient.balance, _value);
    }

    // ---------------------------------------------------------------
    // L2
    // ---------------------------------------------------------------

    /// @dev Runs the L2 rehearsal with `_caller` processing the governance message.
    /// @param _caller The address that calls `processMessage`.
    function _rehearseL2Upgrade(address _caller) private {
        _mockSignalProofs(L2.SIGNAL_SERVICE);
        _ensureProposal0024ExecutedOnL2(_caller);

        Bridge bridge = Bridge(payable(L2.BRIDGE));
        ERC20Vault vault = ERC20Vault(L2.ERC20_VAULT);

        Proposal0025Harness harness = new Proposal0025Harness();
        Proposal0025.L2Deployment memory l2 = _l2Deployment(harness);

        Before memory before = Before({
            messageId: bridge.nextMessageId(),
            bridgeOwner: bridge.owner(),
            vaultOwner: vault.owner(),
            bridgedUsdt: vault.canonicalToBridged(1, L1.USDT_TOKEN)
        });
        assertTrue(before.bridgedUsdt != address(0), "no bridged USDT on this fork");

        // Deliver the two L2 actions the way governance will: as a processMessage call on the
        // bridge itself, which is what exercises the mid-call self-upgrade. The message is the one
        // BuildProposal wraps the L2 batch into.
        IBridge.Message memory message = harness.exposedBuildL2Message(l2);
        message.id = 8_250_000;
        message.from = L1.DAO_CONTROLLER;
        message.srcChainId = 1;

        // On the relayer branch the invocation receives message.gasLimit minus the message's own
        // minimum, not gasleft(). Pin that budget so the 5,000,000 in the proposal is shown to be
        // sufficient rather than assumed: 5,000,000 - (16,896 calldata cost + 800,000 GAS_RESERVE)
        // for this message's 612 bytes of data, more than twenty times what two upgrades need.
        // `Proposal0025.t.sol` pins the 612.
        if (_caller != message.destOwner) {
            assertEq(
                message.gasLimit - bridge.getMessageMinGasLimit(message.data.length),
                4_183_104,
                "relayer invocation budget moved; re-derive it before trusting this rehearsal"
            );
        }

        vm.prank(_caller);
        (IBridge.Status status, IBridge.StatusReason reason) = bridge.processMessage(message, "");

        // A passing transaction is NOT evidence the upgrade worked: a reverting invocation becomes
        // RETRIABLE without reverting processMessage. Assert the status as well as the slots.
        assertEq(uint8(status), uint8(IBridge.Status.DONE));
        assertEq(uint8(reason), uint8(IBridge.StatusReason.INVOCATION_OK));
        assertEq(_implementationOf(L2.BRIDGE), l2.bridgeImpl);
        assertEq(_implementationOf(L2.ERC20_VAULT), l2.erc20VaultImpl);

        _assertL2BridgeAfterUpgrade(before);
        _assertL2VaultAfterUpgrade(before);
        _deliverUsdtFromL1(before.bridgedUsdt);
        _deliverGovernanceMessageThroughUpgradedBridge(_caller);
    }

    /// @dev Brings the L2 fork to the state Proposal0025 executes from: the Proposal0024
    /// implementations, reading the resolver Proposal0024 populates. A fork still on the 1.10.0
    /// bridge has Proposal0024's L2 batch delivered first, through `processMessage` like the real
    /// thing.
    /// @param _caller The address that calls `processMessage`.
    function _ensureProposal0024ExecutedOnL2(address _caller) private {
        if (_implementationOf(L2.BRIDGE) == _V110_BRIDGE_IMPL_L2) {
            console2.log("L2 fork predates Proposal0024; delivering its L2 batch first");
            Proposal0024Harness p24 = new Proposal0024Harness();
            IBridge.Message memory message = p24.exposedBuildL2Message();
            message.id = 8_240_000;
            message.from = L1.DAO_CONTROLLER;
            message.srcChainId = 1;

            vm.prank(_caller);
            (IBridge.Status status, IBridge.StatusReason reason) =
                Bridge(payable(L2.BRIDGE)).processMessage(message, "");
            assertEq(uint8(status), uint8(IBridge.Status.DONE), "Proposal0024 batch not invoked");
            assertEq(
                uint8(reason),
                uint8(IBridge.StatusReason.INVOCATION_OK),
                "Proposal0024 batch failed"
            );
        }
        assertEq(
            _implementationOf(L2.BRIDGE),
            _P24_BRIDGE_IMPL_L2,
            "L2 fork does not run the Proposal0024 bridge implementation"
        );
        assertEq(
            _implementationOf(L2.ERC20_VAULT),
            _P24_ERC20_VAULT_IMPL_L2,
            "L2 fork does not run the Proposal0024 vault implementation"
        );
    }

    /// @dev The implementations the L2 leg points at: the deployed ones once the constants name
    /// them, otherwise ones built from this tree with the immutables `DeployProposal0025L2` bakes
    /// in.
    /// @param _harness The proposal.
    /// @return d_ The L2 implementations.
    function _l2Deployment(Proposal0025Harness _harness)
        private
        returns (Proposal0025.L2Deployment memory d_)
    {
        d_ = Proposal0025.L2Deployment({
            bridgeImpl: _harness.BRIDGE_NEW_IMPL_L2(),
            erc20VaultImpl: _harness.ERC20_VAULT_NEW_IMPL_L2()
        });
        if (d_.bridgeImpl == address(0) || d_.erc20VaultImpl == address(0)) {
            console2.log("Proposal0025 L2 constants are placeholders; building the implementations");
            d_.bridgeImpl = address(
                new Bridge(L2.SHARED_RESOLVER, L2.SIGNAL_SERVICE, address(0), address(0), false)
            );
            d_.erc20VaultImpl = address(new ERC20Vault(L2.SHARED_RESOLVER, address(0)));
        } else {
            assertGt(d_.bridgeImpl.code.length, 0, "L2 bridge implementation is not deployed");
            assertGt(d_.erc20VaultImpl.code.length, 0, "L2 vault implementation is not deployed");
        }
    }

    /// @dev Storage and immutables survived the swap, the resolver path still works, and the
    /// bridge can still send.
    /// @param _before The live values read before the batch.
    function _assertL2BridgeAfterUpgrade(Before memory _before) private {
        Bridge bridge = Bridge(payable(L2.BRIDGE));

        (bool enabled, address destBridge) = bridge.isDestChainEnabled(1);
        assertTrue(enabled);
        assertEq(destBridge, L1.BRIDGE);

        assertEq(bridge.nextMessageId(), _before.messageId);
        assertEq(bridge.owner(), _before.bridgeOwner);
        assertEq(bridge.resolver(), L2.SHARED_RESOLVER);
        assertEq(address(bridge.signalService()), L2.SIGNAL_SERVICE);
        assertEq(address(bridge.quotaManager()), address(0));
        assertEq(bridge.pauser(), address(0));
        assertFalse(bridge.recallEnabled());

        // gasLimit must clear getMessageMinGasLimit(0); below it sendMessage reverts
        // B_INVALID_GAS_LIMIT. Deliberately not 0, which would short-circuit that validation.
        IBridge.Message memory outbound;
        outbound.srcChainId = 167_000;
        outbound.destChainId = 1;
        outbound.srcOwner = address(this);
        outbound.destOwner = address(this);
        outbound.to = address(this);
        outbound.gasLimit = 1_000_000;
        bridge.sendMessage(outbound);

        assertEq(bridge.nextMessageId(), _before.messageId + 1);
    }

    /// @dev Storage and immutables of the vault survived the swap.
    /// @param _before The live values read before the batch.
    function _assertL2VaultAfterUpgrade(Before memory _before) private view {
        ERC20Vault vault = ERC20Vault(L2.ERC20_VAULT);
        assertEq(vault.owner(), _before.vaultOwner);
        assertEq(vault.resolver(), L2.SHARED_RESOLVER);
        assertEq(address(vault.quotaManager()), address(0));
        assertEq(vault.PERMIT2(), _PERMIT2);

        assertEq(vault.canonicalToBridged(1, L1.USDT_TOKEN), _before.bridgedUsdt);
        (uint64 ctokenChainId, address ctokenAddr,,,) =
            vault.bridgedToCanonical(_before.bridgedUsdt);
        assertEq(ctokenChainId, 1);
        assertEq(ctokenAddr, L1.USDT_TOKEN);
    }

    /// @dev Delivers `_TOKEN_AMOUNT` of USDT from L1 to a fresh recipient through the upgraded
    /// bridge and vault, minting the bridged USDT the 1.10.0 vault deployed.
    /// @param _bridgedUsdt The bridged USDT on L2.
    function _deliverUsdtFromL1(address _bridgedUsdt) private {
        address recipient = makeAddr("recipient of USDT");

        IBridge.Message memory message;
        message.id = 8_250_002;
        message.from = L1.ERC20_VAULT;
        message.srcChainId = 1;
        message.srcOwner = recipient;
        message.destChainId = 167_000;
        message.destOwner = recipient;
        message.to = L2.ERC20_VAULT;
        message.gasLimit = 3_000_000;
        message.data = abi.encodeCall(
            IMessageInvocable.onMessageInvocation,
            (abi.encode(
                    ERC20Vault.CanonicalERC20({
                        chainId: 1,
                        addr: L1.USDT_TOKEN,
                        decimals: 6,
                        symbol: "USDT",
                        name: "Tether USD"
                    }),
                    recipient,
                    recipient,
                    _TOKEN_AMOUNT
                ))
        );

        vm.prank(recipient);
        (IBridge.Status status, IBridge.StatusReason reason) =
            Bridge(payable(L2.BRIDGE)).processMessage(message, "");
        assertEq(uint8(status), uint8(IBridge.Status.DONE), "delivery was not invoked");
        assertEq(uint8(reason), uint8(IBridge.StatusReason.INVOCATION_OK), "delivery failed");
        assertEq(IERC20(_bridgedUsdt).balanceOf(recipient), _TOKEN_AMOUNT);
    }

    /// @dev Delivers a second governance message through the upgraded bridge, so the
    /// DelegateController's `context()` read is exercised against the new implementation and not
    /// only against the one that invoked the batch. The action is a no-op re-registration.
    /// @param _caller The address that calls `processMessage`.
    function _deliverGovernanceMessageThroughUpgradedBridge(address _caller) private {
        Controller.Action[] memory actions = new Controller.Action[](1);
        actions[0] = Controller.Action({
            target: L2.SHARED_RESOLVER,
            value: 0,
            data: abi.encodeCall(
                DefaultResolver.registerAddress,
                (uint256(167_000), LibNames.B_ERC20_VAULT, L2.ERC20_VAULT)
            )
        });

        IBridge.Message memory message;
        message.id = 8_250_003;
        message.from = L1.DAO_CONTROLLER;
        message.srcChainId = 1;
        message.srcOwner = L1.DAO_CONTROLLER;
        message.destChainId = 167_000;
        message.destOwner = L2.PERMISSIONLESS_EXECUTOR;
        message.to = L2.DELEGATE_CONTROLLER;
        message.gasLimit = 1_000_000;
        message.data = abi.encodeCall(
            IMessageInvocable.onMessageInvocation,
            (abi.encodePacked(uint64(0), abi.encode(actions)))
        );

        // The DelegateController only executes after `IBridge(msg.sender).context()` named the DAO
        // controller on chain 1, so this event proves the new implementation served the context.
        vm.expectEmit(true, false, false, true, L2.DELEGATE_CONTROLLER);
        emit Controller.ActionExecuted(actions[0].target, actions[0].value, actions[0].data);
        vm.prank(_caller);
        (IBridge.Status status, IBridge.StatusReason reason) =
            Bridge(payable(L2.BRIDGE)).processMessage(message, "");
        assertEq(uint8(status), uint8(IBridge.Status.DONE), "governance message was not invoked");
        assertEq(
            uint8(reason), uint8(IBridge.StatusReason.INVOCATION_OK), "governance action failed"
        );
        assertEq(
            DefaultResolver(L2.SHARED_RESOLVER).resolve(167_000, LibNames.B_ERC20_VAULT, false),
            L2.ERC20_VAULT
        );
    }

    // ---------------------------------------------------------------
    // Shared
    // ---------------------------------------------------------------

    /// @dev A valid signal proof cannot be synthesised on a fork, and the signal service is not
    /// what this rehearsal exercises.
    /// @param _signalService The chain's signal service.
    function _mockSignalProofs(address _signalService) private {
        vm.mockCall(
            _signalService,
            abi.encodeWithSelector(ISignalService.proveSignalReceived.selector),
            abi.encode(uint256(0))
        );
    }

    /// @dev Executes `_actions` one by one from `_controller`, the way `Controller._executeActions`
    /// does, aborting on the first failure.
    /// @param _controller The controller that executes the batch.
    /// @param _actions The actions.
    function _executeAs(address _controller, Controller.Action[] memory _actions) private {
        for (uint256 i; i < _actions.length; ++i) {
            vm.prank(_controller);
            (bool success,) = _actions[i].target.call{ value: _actions[i].value }(_actions[i].data);
            assertTrue(success, string.concat("action ", vm.toString(i), " reverted"));
        }
    }

    /// @dev Selects a fork from `_envVar`, or marks the test skipped when it is unset.
    /// @param _envVar Name of the environment variable holding the RPC URL.
    /// @return forked_ True when a fork was selected and the test should continue.
    function _forkOrSkip(string memory _envVar) private returns (bool forked_) {
        string memory url = vm.envOr(_envVar, string(""));
        if (bytes(url).length == 0) {
            vm.skip(true, string.concat(_envVar, " is not set"));
            return false;
        }
        vm.createSelectFork(url);
        return true;
    }

    /// @dev Reads a proxy's EIP-1967 implementation slot.
    /// @param _proxy The proxy to read.
    /// @return impl_ The implementation address it delegates to.
    function _implementationOf(address _proxy) private view returns (address impl_) {
        impl_ = address(uint160(uint256(vm.load(_proxy, _IMPL_SLOT))));
    }
}
