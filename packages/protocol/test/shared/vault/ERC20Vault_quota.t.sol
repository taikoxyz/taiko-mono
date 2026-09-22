// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../helpers/CountingQuotaManager.sol";
import "../helpers/FreeMintERC20Token.sol";
import "./ERC20Vault.h.sol";

/// @dev Verifies that the ERC20Vault debits the token quota exactly for the tokens actually
/// delivered to a recipient ("debit only on actual release"). Because the vault consumes quota in
/// the same atomic call that transfers/mints the tokens, a reverted (e.g. out-of-quota) delivery
/// releases nothing and debits nothing, and each successful delivery is debited exactly once.
/// @dev Both release paths are covered: delivering a message from another chain debits the quota,
/// while refunding a recalled message does not. A recall only returns what its message pulled or
/// burned in `sendToken`, so it is never a net outflow, and debiting it would let anyone exhaust a
/// token's quota at zero net cost with a send-fail-recall cycle.
contract TestERC20Vault_quota is CommonTest {
    SignalService private eSignalService;
    ERC20Vault private eVault;
    FreeMintERC20Token private eERC20Token1;
    CountingQuotaManager private qm;

    SignalService private tSignalService;
    PrankDestBridge private tBridge;

    function setUpOnEthereum() internal override {
        eSignalService = deploySignalServiceWithoutProof(
            address(this), address(uint160(uint256(keccak256("REMOTE_SIGNAL")))), deployer
        );

        qm = new CountingQuotaManager();
        eVault = ERC20Vault(
            deploy({
                name: "erc20_vault",
                impl: address(new ERC20Vault(address(resolver), address(qm))),
                data: abi.encodeCall(ERC20Vault.init, (address(0)))
            })
        );

        eERC20Token1 = new FreeMintERC20Token("ERC20", "ERC20");
        eERC20Token1.mint(address(eVault));

        register("bridged_erc20", address(new BridgedERC20(address(eVault))));
    }

    function setUpOnTaiko() internal override {
        tSignalService = deploySignalServiceWithoutProof(
            address(this), address(uint160(uint256(keccak256("REMOTE_SIGNAL_T")))), deployer
        );
        tBridge = new PrankDestBridge(eVault);
        register("bridge", address(tBridge));
        // The bridged refund branch deploys a BridgedERC20, so the impl must resolve on this chain.
        register("bridged_erc20", address(new BridgedERC20(address(eVault))));
    }

    function _canonical() internal view returns (ERC20Vault.CanonicalERC20 memory) {
        return ERC20Vault.CanonicalERC20({
            chainId: taikoChainId,
            addr: address(eERC20Token1),
            decimals: eERC20Token1.decimals(),
            symbol: eERC20Token1.symbol(),
            name: eERC20Token1.name()
        });
    }

    function _receive(uint64 _amount) internal {
        tBridge.sendReceiveERC20ToERC20Vault(
            _canonical(),
            Alice,
            Bob,
            _amount,
            0,
            bytes32(0),
            bytes32(0),
            address(eVault),
            ethereumChainId,
            0
        );
    }

    // A successful delivery debits the quota exactly by the released amount.
    function test_quota_receive_success_debits_amount() public {
        vm.chainId(taikoChainId);

        uint64 amount = 10;
        uint256 bobBefore = eERC20Token1.balanceOf(Bob);

        _receive(amount);

        assertEq(eERC20Token1.balanceOf(Bob) - bobBefore, amount);
        assertEq(qm.consumed(address(eERC20Token1)), amount);
        assertEq(qm.totalConsumed(), amount);
    }

    // When quota is insufficient the delivery reverts and releases nothing.
    function test_quota_receive_insufficient_reverts_and_releases_nothing() public {
        vm.chainId(taikoChainId);

        uint64 amount = 10;
        qm.setLimit(amount - 1);

        uint256 bobBefore = eERC20Token1.balanceOf(Bob);
        uint256 vaultBefore = eERC20Token1.balanceOf(address(eVault));

        // Pre-build args so `expectRevert` targets the bridge call, not the token metadata reads.
        ERC20Vault.CanonicalERC20 memory canonical = _canonical();
        vm.expectRevert(QuotaManager.QM_OUT_OF_QUOTA.selector);
        tBridge.sendReceiveERC20ToERC20Vault(
            canonical,
            Alice,
            Bob,
            amount,
            0,
            bytes32(0),
            bytes32(0),
            address(eVault),
            ethereumChainId,
            0
        );

        assertEq(eERC20Token1.balanceOf(Bob), bobBefore);
        assertEq(eERC20Token1.balanceOf(address(eVault)), vaultBefore);
        assertEq(qm.totalConsumed(), 0);
    }

    // Two successful deliveries each debit once; no double-counting or under-counting.
    function test_quota_two_receives_each_debit_once() public {
        vm.chainId(taikoChainId);

        uint64 amount = 10;
        _receive(amount);
        _receive(amount);

        assertEq(qm.consumed(address(eERC20Token1)), 2 * uint256(amount));
        assertEq(qm.totalConsumed(), 2 * uint256(amount));
    }

    /// @dev Builds a message shaped like one this vault would have sent, so it can be handed back
    /// through `onMessageRecalled`.
    function _recallMessage(uint64 _amount) internal view returns (IBridge.Message memory) {
        return _recallMessage(_canonical(), _amount);
    }

    function _recallMessage(
        ERC20Vault.CanonicalERC20 memory _ctoken,
        uint64 _amount
    )
        internal
        view
        returns (IBridge.Message memory)
    {
        bytes memory inner = abi.encode(_ctoken, Alice, Bob, uint256(_amount));
        return IBridge.Message({
            id: 0,
            fee: 0,
            gasLimit: 0,
            from: address(eVault),
            srcChainId: taikoChainId,
            srcOwner: Alice,
            destChainId: ethereumChainId,
            destOwner: Alice,
            to: address(0),
            value: 0,
            data: abi.encodeCall(ERC20Vault.onMessageInvocation, (inner))
        });
    }

    // A refund is exempt from the quota: it only returns what its message pulled in sendToken, so
    // nothing is debited and the quota manager is not even called.
    function test_quota_recall_refund_debits_nothing() public {
        vm.chainId(taikoChainId);

        uint64 amount = 10;
        uint256 aliceBefore = eERC20Token1.balanceOf(Alice);

        // Pre-build the message: it reads token metadata, which would consume the prank.
        IBridge.Message memory message = _recallMessage(amount);
        vm.prank(address(tBridge));
        eVault.onMessageRecalled(message, bytes32(0));

        assertEq(eERC20Token1.balanceOf(Alice) - aliceBefore, amount);
        assertEq(qm.calls(), 0);
        assertEq(qm.totalConsumed(), 0);
    }

    // An exhausted quota blocks deliveries, never refunds: users can always take their tokens
    // back on the source chain.
    function test_quota_recall_refund_succeeds_when_quota_exhausted() public {
        vm.chainId(taikoChainId);

        uint64 amount = 10;
        qm.setLimit(amount - 1);

        uint256 aliceBefore = eERC20Token1.balanceOf(Alice);
        uint256 vaultBefore = eERC20Token1.balanceOf(address(eVault));

        IBridge.Message memory message = _recallMessage(amount);
        vm.prank(address(tBridge));
        eVault.onMessageRecalled(message, bytes32(0));

        assertEq(eERC20Token1.balanceOf(Alice) - aliceBefore, amount);
        assertEq(vaultBefore - eERC20Token1.balanceOf(address(eVault)), amount);
        assertEq(qm.totalConsumed(), 0);
    }

    // The griefing vector: a send-fail-recall cycle costs the attacker nothing, so it must not
    // touch the shared quota. Deliveries still find the full quota, and it still bounds them.
    function test_quota_recall_cycle_does_not_drain_quota() public {
        vm.chainId(taikoChainId);

        uint64 quota = 100;
        qm.setLimit(quota);

        // Attacker: refund the whole quota's worth, over and over.
        for (uint256 i; i < 3; ++i) {
            IBridge.Message memory message = _recallMessage(quota);
            vm.prank(address(tBridge));
            eVault.onMessageRecalled(message, bytes32(0));
            assertEq(qm.totalConsumed(), 0);
        }

        // A delivery still finds the full quota and is debited...
        _receive(quota);
        assertEq(qm.totalConsumed(), quota);

        // ...the quota keeps bounding deliveries...
        ERC20Vault.CanonicalERC20 memory canonical = _canonical();
        vm.expectRevert(QuotaManager.QM_OUT_OF_QUOTA.selector);
        tBridge.sendReceiveERC20ToERC20Vault(
            canonical, Alice, Bob, 1, 0, bytes32(0), bytes32(0), address(eVault), ethereumChainId, 0
        );

        // ...while refunds still go through with the quota exhausted.
        IBridge.Message memory late = _recallMessage(1);
        vm.prank(address(tBridge));
        eVault.onMessageRecalled(late, bytes32(0));
        assertEq(qm.totalConsumed(), quota);
    }

    // The mint branch of `_transferTokens` is exempt as well: a refund whose canonical lives on a
    // third chain re-mints exactly what the send burned, and debits nothing even when a delivery of
    // that size would be out of quota.
    function test_quota_recall_refund_of_a_bridged_token_debits_nothing() public {
        vm.chainId(taikoChainId);

        uint64 amount = 10;
        qm.setLimit(amount - 1);

        // chainId 999 != block.chainid, so the refund takes the mint branch.
        ERC20Vault.CanonicalERC20 memory foreign = ERC20Vault.CanonicalERC20({
            chainId: 999,
            addr: address(eERC20Token1),
            decimals: eERC20Token1.decimals(),
            symbol: eERC20Token1.symbol(),
            name: eERC20Token1.name()
        });

        IBridge.Message memory message = _recallMessage(foreign, amount);
        vm.prank(address(tBridge));
        eVault.onMessageRecalled(message, bytes32(0));

        address btoken = eVault.canonicalToBridged(999, address(eERC20Token1));
        assertTrue(btoken != address(0), "bridged token not deployed");
        assertEq(BridgedERC20(btoken).balanceOf(Alice), amount);
        assertEq(qm.consumed(btoken), 0);
        assertEq(qm.calls(), 0);
    }

    // Releasing zero tokens skips the quota manager call entirely.
    function test_quota_zero_amount_skips_external_call() public {
        vm.chainId(taikoChainId);

        _receive(0);

        assertEq(qm.calls(), 0);
        assertEq(qm.totalConsumed(), 0);
    }
}
