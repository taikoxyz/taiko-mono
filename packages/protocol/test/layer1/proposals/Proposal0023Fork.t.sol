// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Test } from "forge-std/src/Test.sol";
import { Proposal0023 } from "script/layer1/proposals/Proposal0023.s.sol";
import { LibL1Addrs as L1 } from "src/layer1/mainnet/LibL1Addrs.sol";
import { LibL2Addrs as L2 } from "src/layer2/mainnet/LibL2Addrs.sol";
import { Bridge } from "src/shared/bridge/Bridge.sol";
import { IBridge, IMessageInvocable } from "src/shared/bridge/IBridge.sol";
import { DefaultResolver } from "src/shared/common/DefaultResolver.sol";
import { Controller } from "src/shared/governance/Controller.sol";
import { LibNames } from "src/shared/libs/LibNames.sol";
import { ISignalService } from "src/shared/signal/ISignalService.sol";
import { BridgedERC20 } from "src/shared/vault/BridgedERC20.sol";
import { ERC20Vault } from "src/shared/vault/ERC20Vault.sol";

/// @notice Rehearses the Proposal0023 upgrades against live mainnet state.
/// @dev Skipped unless `L1_FORK_URL` / `L2_FORK_URL` are set, because CI configures no RPC
/// endpoints. Run with:
///
///   L1_FORK_URL=<l1 rpc> L2_FORK_URL=https://rpc.mainnet.taiko.xyz \
///     FOUNDRY_PROFILE=layer1 forge test --match-contract Proposal0023ForkTest -vv
///
/// `Proposal0023.t.sol` proves the proposal encodes the right calldata. It cannot prove the
/// upgrades work, and the L2 leg is where that distinction matters: the live L2 bridge and ERC20
/// vault both run protocol 1.10.0 implementations from October 2024, the bridge must upgrade
/// *itself* from inside its own `processMessage` frame, and every resolver lookup the vault makes
/// moves to a registry that is empty until the same batch populates it. Each leg therefore also
/// bridges tokens through the upgraded contracts, on the exact actions the proposal encodes.
/// @custom:security-contact security@taiko.xyz
contract Proposal0023ForkTest is Test {
    /// @dev Live values read before the L2 batch executes, compared against afterwards.
    struct L2Before {
        uint64 messageId;
        address bridgeOwner;
        address vaultOwner;
        // A bridged token the 1.10.0 vault deployed; it resolves the vault through the legacy
        // registry and must keep working after the upgrade.
        address bridgedUsdt;
    }

    /// @dev EIP-1967 implementation slot.
    bytes32 private constant _IMPL_SLOT =
        0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    /// @dev The canonical Permit2 deployment, present on both chains.
    address private constant _PERMIT2 = 0x000000000022D473030F116dDEE9F6B43aC78BA3;

    /// @dev The amount every token movement below uses, in the token's smallest unit.
    uint256 private constant _AMOUNT = 50e6;

    /// @dev The implementations each proxy must still be running when the rehearsal starts. Both
    /// forks are taken at head, so once Proposal0023 executes these tests would otherwise rehearse
    /// current -> current and stay green while no longer covering the transition they exist for —
    /// the L2 ones silently stop exercising the 1.10.0 jump. Asserting the starting implementation
    /// fails loudly instead. It is preferred over a pinned fork block because pinning needs an
    /// archive node; the blocks the rehearsal was captured at are named in the failure messages for
    /// anyone who has one.
    address private constant _LIVE_BRIDGE_IMPL_L1 = 0x1c94D798CFA08F396E5BA9F81697289c53273381;
    address private constant _LIVE_ERC20_VAULT_IMPL_L1 = 0x024253C6FDC27d3161aFd43fb0241411A28dDc3c;
    address private constant _LIVE_BRIDGE_IMPL_L2 = 0x95ae2918dcbc6aFF8B4c1F1BCC1bf819b6e08B83;
    address private constant _LIVE_ERC20_VAULT_IMPL_L2 = 0xb96AbB41b01E3ad519D00E80355a1c3801910F62;

    function test_l1_upgradesAgainstLiveState() external {
        if (!_forkOrSkip("L1_FORK_URL")) return;

        string memory notPreUpgrade =
            "L1 fork is not pre-upgrade; pin --fork-block-number 25875170 against an archive node";
        assertEq(_implementationOf(L1.BRIDGE), _LIVE_BRIDGE_IMPL_L1, notPreUpgrade);
        assertEq(_implementationOf(L1.ERC20_VAULT), _LIVE_ERC20_VAULT_IMPL_L1, notPreUpgrade);

        uint64 messageIdBefore = Bridge(payable(L1.BRIDGE)).nextMessageId();
        address vaultOwnerBefore = ERC20Vault(L1.ERC20_VAULT).owner();

        // Deploy exactly what DeployBridgeUpgradeL1 and DeployERC20VaultUpgradeL1 deploy.
        Proposal0023.L1Deployment memory l1 = Proposal0023.L1Deployment({
            bridgeImpl: address(
                new Bridge(
                    L1.SHARED_RESOLVER,
                    L1.SIGNAL_SERVICE,
                    L1.QUOTA_MANAGER,
                    L1.MULTISIG_ADMIN_TAIKO_ETH
                )
            ),
            erc20VaultImpl: address(new ERC20Vault(L1.SHARED_RESOLVER, L1.QUOTA_MANAGER))
        });

        // The L2 addresses only shape the payload of the message the third L1 action sends; the
        // L1 bridge never reads them. The L2 leg rehearses them on the L2 fork.
        Proposal0023ForkHarness harness = new Proposal0023ForkHarness();
        Proposal0023.L2Deployment memory l2 = Proposal0023.L2Deployment({
            sharedResolver: harness.L2_SHARED_RESOLVER(),
            bridgeImpl: harness.BRIDGE_NEW_IMPL_L2(),
            erc20VaultImpl: makeAddr("ERC20_VAULT_NEW_IMPL_L2"),
            bridgedErc20Impl: makeAddr("BRIDGED_ERC20_NEW_IMPL_L2")
        });

        // Execute the whole L1 batch the way the DAO controller will: both upgrades, then the
        // sendMessage that BuildProposal appends, through the just-upgraded bridge.
        Controller.Action[] memory actions = harness.exposedBuildAllActions(l1, l2);
        assertEq(actions.length, 3);
        _executeAs(L1.DAO_CONTROLLER, actions);

        _assertL1BridgeAfterUpgrade(l1.bridgeImpl, messageIdBefore);
        _assertL1VaultAfterUpgrade(l1.erc20VaultImpl, vaultOwnerBefore, messageIdBefore);
    }

    function test_l2_selfUpgradeThroughProcessMessage() external {
        if (!_forkOrSkip("L2_FORK_URL")) return;
        _rehearseL2Upgrade(L2.PERMISSIONLESS_EXECUTOR);
    }

    /// @dev The same rehearsal driven by a relayer rather than the destination owner. When the
    /// caller is the destOwner the legacy bridge forwards `gasleft()`, so the executor case never
    /// exercises the proposal's 5,000,000 gas limit at all; any caller may process a message, and
    /// a relayer instead receives `_invocationGasLimit`, which is what this case covers.
    function test_l2_selfUpgradeThroughProcessMessage_byRelayer() external {
        if (!_forkOrSkip("L2_FORK_URL")) return;
        _rehearseL2Upgrade(makeAddr("relayer"));
    }

    /// @dev Checks the L1 bridge after the batch: immutables, resolver wiring, and that the
    /// governance message left through the new implementation.
    /// @param _newImpl The implementation the proxy must now run.
    /// @param _messageIdBefore The bridge's `nextMessageId` before the batch.
    function _assertL1BridgeAfterUpgrade(address _newImpl, uint64 _messageIdBefore) private view {
        Bridge bridge = Bridge(payable(L1.BRIDGE));
        assertEq(_implementationOf(L1.BRIDGE), _newImpl);
        assertEq(bridge.resolver(), L1.SHARED_RESOLVER);
        assertEq(address(bridge.signalService()), L1.SIGNAL_SERVICE);
        assertEq(address(bridge.quotaManager()), L1.QUOTA_MANAGER);
        assertEq(bridge.pauser(), L1.MULTISIG_ADMIN_TAIKO_ETH);

        (bool enabled, address destBridge) = bridge.isDestChainEnabled(167_000);
        assertTrue(enabled);
        assertEq(destBridge, L2.BRIDGE);

        assertEq(bridge.nextMessageId(), _messageIdBefore + 1);
    }

    /// @dev Checks the L1 vault after the batch: storage and immutables kept, Permit2 gained, and
    /// a canonical token still leaves through the upgraded bridge on the resolver entries the L1
    /// shared resolver already carries.
    /// @param _newImpl The implementation the proxy must now run.
    /// @param _ownerBefore The vault's owner before the batch.
    /// @param _messageIdBefore The bridge's `nextMessageId` before the batch.
    function _assertL1VaultAfterUpgrade(
        address _newImpl,
        address _ownerBefore,
        uint64 _messageIdBefore
    )
        private
    {
        ERC20Vault vault = ERC20Vault(L1.ERC20_VAULT);
        assertEq(_implementationOf(L1.ERC20_VAULT), _newImpl);
        assertEq(vault.owner(), _ownerBefore);
        assertEq(vault.resolver(), L1.SHARED_RESOLVER);
        assertEq(address(vault.quotaManager()), L1.QUOTA_MANAGER);
        assertEq(vault.PERMIT2(), _PERMIT2);
        assertGt(_PERMIT2.code.length, 0, "Permit2 is not deployed on this fork");

        IBridge.Message memory message = _sendToken(vault, L1.WETH_TOKEN, 167_000);
        assertEq(message.to, L2.ERC20_VAULT);
        assertEq(Bridge(payable(L1.BRIDGE)).nextMessageId(), _messageIdBefore + 2);
    }

    /// @dev Runs the L2 rehearsal with `_caller` processing the governance message.
    /// @param _caller The address that calls `processMessage`.
    function _rehearseL2Upgrade(address _caller) private {
        Bridge bridge = Bridge(payable(L2.BRIDGE));
        ERC20Vault vault = ERC20Vault(L2.ERC20_VAULT);

        string memory notPreUpgrade =
            "L2 fork is not pre-upgrade; pin --fork-block-number 10785761 against an archive node";
        assertEq(_implementationOf(L2.BRIDGE), _LIVE_BRIDGE_IMPL_L2, notPreUpgrade);
        assertEq(_implementationOf(L2.ERC20_VAULT), _LIVE_ERC20_VAULT_IMPL_L2, notPreUpgrade);

        L2Before memory before = L2Before({
            messageId: bridge.nextMessageId(),
            bridgeOwner: bridge.owner(),
            vaultOwner: vault.owner(),
            bridgedUsdt: vault.canonicalToBridged(1, L1.USDT_TOKEN)
        });
        assertTrue(before.bridgedUsdt != address(0), "no bridged USDT on this fork");

        Proposal0023.L2Deployment memory l2 = _deployL2Contracts();

        // Deliver the seven L2 actions the way governance will: as a processMessage call on the
        // bridge itself, not by pranking the DelegateController. That is what exercises the
        // mid-call self-upgrade.
        IBridge.Message memory message = _governanceMessage(l2);

        // A valid signal proof cannot be synthesised on a fork, and the signal service is not what
        // this test exercises.
        vm.mockCall(
            L2.SIGNAL_SERVICE,
            abi.encodeWithSelector(ISignalService.proveSignalReceived.selector),
            abi.encode(uint256(0))
        );

        // On the relayer branch the invocation receives message.gasLimit minus the message's own
        // minimum, not gasleft(). Pin that budget so the 5,000,000 in the proposal is shown to be
        // sufficient rather than assumed: 5,000,000 - (39,936 calldata cost + 800,000 GAS_RESERVE)
        // for this message's 2,052 bytes of data, more than ten times what the seven actions need.
        // `Proposal0023.t.sol` pins the 2,052.
        if (_caller != message.destOwner) {
            assertEq(
                message.gasLimit - bridge.getMessageMinGasLimit(message.data.length),
                4_160_064,
                "relayer invocation budget moved; re-derive it before trusting this rehearsal"
            );
        }

        vm.prank(_caller);
        (IBridge.Status status, IBridge.StatusReason reason) = bridge.processMessage(message, "");

        // A passing transaction is NOT evidence the upgrade worked. The 1.10.0 _invokeMessageCall
        // uses a raw call, so a reverting invocation becomes RETRIABLE without reverting
        // processMessage. Assert the status as well as the slots; a silent failure fails here.
        assertEq(uint8(status), uint8(IBridge.Status.DONE));
        assertEq(uint8(reason), uint8(IBridge.StatusReason.INVOCATION_OK));
        assertEq(_implementationOf(L2.BRIDGE), l2.bridgeImpl);
        assertEq(_implementationOf(L2.ERC20_VAULT), l2.erc20VaultImpl);

        _assertL2Registrations(l2);
        _assertL2BridgeAfterUpgrade(l2.sharedResolver, before);
        _assertL2VaultAfterUpgrade(l2.sharedResolver, before);
        _bridgeTokensThroughUpgradedL2(l2, before);
    }

    /// @dev Deploys exactly what DeployBridgeUpgradeL2 and DeployERC20VaultUpgradeL2 deploy.
    /// @return l2_ The four addresses the L2 leg points at.
    function _deployL2Contracts() private returns (Proposal0023.L2Deployment memory l2_) {
        l2_.sharedResolver = address(
            new ERC1967Proxy(
                address(new DefaultResolver()),
                abi.encodeCall(DefaultResolver.init, (L2.DELEGATE_CONTROLLER))
            )
        );
        l2_.bridgeImpl =
            address(new Bridge(l2_.sharedResolver, L2.SIGNAL_SERVICE, address(0), address(0)));
        l2_.erc20VaultImpl = address(new ERC20Vault(l2_.sharedResolver, address(0)));
        l2_.bridgedErc20Impl = address(new BridgedERC20(L2.ERC20_VAULT));
    }

    /// @dev The message BuildProposal wraps the L2 batch into, as the L2 bridge receives it: the
    /// L1 bridge assigns `id`, `from` and `srcChainId` at send time.
    /// @param _l2 The L2 addresses the batch points at.
    /// @return message_ The message to hand to processMessage.
    function _governanceMessage(Proposal0023.L2Deployment memory _l2)
        private
        returns (IBridge.Message memory message_)
    {
        message_ = new Proposal0023ForkHarness().exposedBuildL2Message(_l2);
        message_.id = 999_999;
        message_.from = L1.DAO_CONTROLLER;
        message_.srcChainId = 1;
    }

    /// @dev Every registration landed on the new resolver.
    /// @param _l2 The L2 addresses the batch points at.
    function _assertL2Registrations(Proposal0023.L2Deployment memory _l2) private view {
        DefaultResolver resolver = DefaultResolver(_l2.sharedResolver);
        assertEq(resolver.resolve(1, LibNames.B_BRIDGE, false), L1.BRIDGE);
        assertEq(resolver.resolve(167_000, LibNames.B_BRIDGE, false), L2.BRIDGE);
        assertEq(resolver.resolve(1, LibNames.B_ERC20_VAULT, false), L1.ERC20_VAULT);
        assertEq(resolver.resolve(167_000, LibNames.B_ERC20_VAULT, false), L2.ERC20_VAULT);
        assertEq(resolver.resolve(167_000, LibNames.B_BRIDGED_ERC20, false), _l2.bridgedErc20Impl);
    }

    /// @dev Storage survived the bridge's 1.10.0 to main jump, the new immutables read as
    /// deployed, the resolver path the legacy registry could not serve now works, and the bridge
    /// can still send.
    /// @param _resolverProxy The new resolver.
    /// @param _before The live values read before the batch.
    function _assertL2BridgeAfterUpgrade(address _resolverProxy, L2Before memory _before) private {
        Bridge bridge = Bridge(payable(L2.BRIDGE));

        // This is the call that reverts if the wiring is wrong.
        (bool enabled, address destBridge) = bridge.isDestChainEnabled(1);
        assertTrue(enabled);
        assertEq(destBridge, L1.BRIDGE);

        assertEq(bridge.nextMessageId(), _before.messageId);
        assertEq(bridge.owner(), _before.bridgeOwner);
        assertEq(bridge.resolver(), _resolverProxy);
        assertEq(address(bridge.quotaManager()), address(0));
        assertEq(bridge.pauser(), address(0));

        // gasLimit must clear getMessageMinGasLimit(0) = _messageCalldataCost(0) 6,656 +
        // GAS_RESERVE 800,000 = 806,656; below it _invocationGasLimit returns 0 and sendMessage
        // reverts B_INVALID_GAS_LIMIT. Deliberately not 0, which would short-circuit that
        // validation.
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

    /// @dev Storage survived the vault's 1.10.0 to main jump and the new immutables read as
    /// deployed.
    /// @param _resolverProxy The new resolver.
    /// @param _before The live values read before the batch.
    function _assertL2VaultAfterUpgrade(
        address _resolverProxy,
        L2Before memory _before
    )
        private
        view
    {
        ERC20Vault vault = ERC20Vault(L2.ERC20_VAULT);
        assertEq(vault.owner(), _before.vaultOwner);
        assertEq(vault.resolver(), _resolverProxy);
        assertEq(address(vault.quotaManager()), address(0));
        assertEq(vault.PERMIT2(), _PERMIT2);
        assertGt(_PERMIT2.code.length, 0, "Permit2 is not deployed on this fork");

        assertEq(vault.canonicalToBridged(1, L1.USDT_TOKEN), _before.bridgedUsdt);
        (uint64 ctokenChainId, address ctokenAddr,,,) =
            vault.bridgedToCanonical(_before.bridgedUsdt);
        assertEq(ctokenChainId, 1);
        assertEq(ctokenAddr, L1.USDT_TOKEN);
    }

    /// @dev Moves tokens through the upgraded L2 contracts in every direction the vault supports.
    /// @param _l2 The L2 addresses the batch pointed at.
    /// @param _before The live values read before the batch.
    function _bridgeTokensThroughUpgradedL2(
        Proposal0023.L2Deployment memory _l2,
        L2Before memory _before
    )
        private
    {
        Bridge bridge = Bridge(payable(L2.BRIDGE));
        ERC20Vault vault = ERC20Vault(L2.ERC20_VAULT);

        // A delivery of a token that already has a bridged representation. Every lookup the
        // upgraded vault makes on this path — its onlyFromNamed(B_BRIDGE) guard and the check that
        // the message came from the L1 vault — now goes through the new registry, while the mint
        // goes through a 1.10.0 bridged token that still resolves the vault through the legacy one.
        _deliverFromL1(L1.USDT_TOKEN, 6, "USDT", "Tether USD", _before.bridgedUsdt);

        // The first delivery of a token with no bridged representation yet deploys one from the
        // implementation registered as `bridged_erc20`, through the six-argument init the 1.10.0
        // implementation does not have. This is the path that made a new BridgedERC20 mandatory.
        address ctoken = makeAddr("canonical L1 token with no L2 representation");
        address btoken = _deliverFromL1(ctoken, 18, "NEW", "New Token", address(0));
        assertEq(_implementationOf(btoken), _l2.bridgedErc20Impl);
        assertEq(BridgedERC20(btoken).erc20Vault(), L2.ERC20_VAULT);
        assertEq(BridgedERC20(btoken).owner(), _before.vaultOwner);
        assertEq(BridgedERC20(btoken).srcToken(), ctoken);
        assertEq(BridgedERC20(btoken).srcChainId(), 1);
        assertEq(BridgedERC20(btoken).decimals(), 18);

        // Sending a bridged token back burns it and routes the message to the L1 vault, both
        // resolved through the new registry, out through the upgraded bridge.
        uint64 messageIdBefore = bridge.nextMessageId();
        uint256 supplyBefore = IERC20(_before.bridgedUsdt).totalSupply();
        IBridge.Message memory sent = _sendToken(vault, _before.bridgedUsdt, 1);
        assertEq(sent.to, L1.ERC20_VAULT);
        assertEq(IERC20(_before.bridgedUsdt).totalSupply(), supplyBefore - _AMOUNT);
        assertEq(bridge.nextMessageId(), messageIdBefore + 1);
    }

    /// @dev Delivers `_AMOUNT` of an L1 canonical token to a fresh recipient through
    /// `processMessage`, the way a relayer delivers a `sendToken` from L1, and asserts the
    /// recipient received the bridged representation.
    /// @param _ctoken The canonical token address on L1.
    /// @param _decimals The canonical token's decimals.
    /// @param _symbol The canonical token's symbol.
    /// @param _name The canonical token's name.
    /// @param _expectedBtoken The bridged token the vault must mint, or zero when the delivery is
    /// expected to deploy one.
    /// @return btoken_ The bridged token the recipient received.
    function _deliverFromL1(
        address _ctoken,
        uint8 _decimals,
        string memory _symbol,
        string memory _name,
        address _expectedBtoken
    )
        private
        returns (address btoken_)
    {
        address recipient = makeAddr(string.concat("recipient of ", _symbol));

        IBridge.Message memory message;
        message.id = uint64(uint160(_ctoken));
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
                        chainId: 1, addr: _ctoken, decimals: _decimals, symbol: _symbol, name: _name
                    }),
                    recipient,
                    recipient,
                    _AMOUNT
                ))
        );

        vm.prank(recipient);
        (IBridge.Status status, IBridge.StatusReason reason) =
            Bridge(payable(L2.BRIDGE)).processMessage(message, "");
        assertEq(uint8(status), uint8(IBridge.Status.DONE), "delivery was not invoked");
        assertEq(uint8(reason), uint8(IBridge.StatusReason.INVOCATION_OK), "delivery failed");

        btoken_ = ERC20Vault(L2.ERC20_VAULT).canonicalToBridged(1, _ctoken);
        if (_expectedBtoken != address(0)) {
            assertEq(btoken_, _expectedBtoken, "delivery deployed a new bridged token");
        } else {
            assertTrue(btoken_ != address(0), "delivery deployed no bridged token");
        }
        assertEq(IERC20(btoken_).balanceOf(recipient), _AMOUNT);
    }

    /// @dev Sends `_AMOUNT` of `_token` from a fresh holder through `sendToken`, the plain
    /// allowance path, and asserts the vault took them.
    /// @param _vault The vault to send through.
    /// @param _token The token to send; canonical on this chain, or bridged.
    /// @param _destChainId The destination chain.
    /// @return message_ The bridge message `sendToken` returned.
    function _sendToken(
        ERC20Vault _vault,
        address _token,
        uint64 _destChainId
    )
        private
        returns (IBridge.Message memory message_)
    {
        address holder = makeAddr("token holder");
        deal(_token, holder, _AMOUNT);

        vm.startPrank(holder);
        IERC20(_token).approve(address(_vault), _AMOUNT);
        message_ = _vault.sendToken(
            ERC20Vault.BridgeTransferOp({
                destChainId: _destChainId,
                destOwner: holder,
                to: holder,
                fee: 0,
                token: _token,
                gasLimit: 1_000_000,
                amount: _AMOUNT
            })
        );
        vm.stopPrank();

        assertEq(IERC20(_token).balanceOf(holder), 0);
        assertEq(message_.destChainId, _destChainId);
        assertEq(message_.srcOwner, holder);
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

/// @dev Exposes the proposal's parameterised builders so the rehearsal executes the actions the
/// proposal encodes rather than a hand-written copy of them.
contract Proposal0023ForkHarness is Proposal0023 {
    function exposedBuildAllActions(
        L1Deployment memory _l1,
        L2Deployment memory _l2
    )
        external
        pure
        returns (Controller.Action[] memory)
    {
        (uint64 l2ExecutionId, uint32 l2GasLimit, Controller.Action[] memory l2Actions) =
            buildL2Actions(_l2);
        return _buildAllActions(buildL1Actions(_l1), l2ExecutionId, l2GasLimit, l2Actions);
    }

    function exposedBuildL2Message(L2Deployment memory _l2)
        external
        pure
        returns (IBridge.Message memory)
    {
        (uint64 l2ExecutionId, uint32 l2GasLimit, Controller.Action[] memory l2Actions) =
            buildL2Actions(_l2);
        return _buildL2Message(l2ExecutionId, l2GasLimit, l2Actions);
    }
}
