// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../helpers/CountingQuotaManager.sol";
import "../helpers/FreeMintERC20Token.sol";
import "./ERC20Vault.h.sol";

/// @dev Verifies that the ERC20Vault debits the token quota exactly for the tokens actually
/// released to a recipient ("debit only on actual release"). Because the vault consumes quota in
/// the same atomic call that transfers/mints the tokens, a reverted (e.g. out-of-quota) release
/// releases nothing and debits nothing, and each successful release is debited exactly once.
/// @dev Both release paths are covered, and they debit different keys: a delivery from another
/// chain debits the released token itself, a refund of a recalled message debits
/// `recallQuotaKey(token)`. A refund only returns what the same message pulled or burned, so it is
/// no net outflow and must not be able to exhaust the token's withdrawal quota -- a send-fail-
/// recall cycle is free to its sender, so a shared bucket would let anyone block that token's
/// withdrawals at no cost. It still needs a ceiling of its own, because a forged failure proof
/// turns a refund into a second payout, and on the bridged branch into a mint no vault balance
/// bounds; the separate key keeps that ceiling armable per token. See `ERC20Vault.recallQuotaKey`.
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

    /// @dev A canonical whose chain is neither this one nor the counterparty, so both release
    /// paths take the mint branch of `_transferTokens`.
    function _foreignCanonical() internal view returns (ERC20Vault.CanonicalERC20 memory) {
        return ERC20Vault.CanonicalERC20({
            chainId: 999,
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

    // A delivery whose canonical lives on a third chain is settled by *minting* the bridged
    // representation. That branch is bounded by no vault balance, so it is debited against the
    // bridged token -- what was actually released -- and not against the canonical.
    function test_quota_receive_of_a_bridged_token_debits_bridged_token() public {
        vm.chainId(taikoChainId);

        uint64 amount = 10;
        tBridge.sendReceiveERC20ToERC20Vault(
            _foreignCanonical(),
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

        address btoken = eVault.canonicalToBridged(999, address(eERC20Token1));
        assertTrue(btoken != address(0), "bridged token not deployed");
        assertEq(BridgedERC20(btoken).balanceOf(Bob), amount);
        assertEq(qm.consumed(btoken), amount);
        assertEq(qm.totalConsumed(), amount);
    }

    // And that branch is throttled, not just metered: an exhausted quota mints nothing, and the
    // bridged token deployment the delivery would have performed is unwound with it.
    function test_quota_receive_of_a_bridged_token_RevertWhen_out_of_quota() public {
        vm.chainId(taikoChainId);

        uint64 amount = 10;
        qm.setLimit(amount - 1);

        // Pre-build args so `expectRevert` targets the bridge call, not the token metadata reads.
        ERC20Vault.CanonicalERC20 memory foreign = _foreignCanonical();
        vm.expectRevert(QuotaManager.QM_OUT_OF_QUOTA.selector);
        tBridge.sendReceiveERC20ToERC20Vault(
            foreign,
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

        assertEq(qm.totalConsumed(), 0);
        assertEq(eVault.canonicalToBridged(999, address(eERC20Token1)), address(0));
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

    // A refund is debited too, but against the token's recall key, never against the token's own
    // withdrawal quota -- so a free send-fail-recall cycle cannot drain what real withdrawals need.
    function test_quota_recall_refund_debits_recall_key() public {
        vm.chainId(taikoChainId);

        uint64 amount = 10;
        uint256 aliceBefore = eERC20Token1.balanceOf(Alice);

        // Pre-build the message: it reads token metadata, which would consume the prank.
        IBridge.Message memory message = _recallMessage(amount);
        vm.prank(address(tBridge));
        eVault.onMessageRecalled(message, bytes32(0));

        assertEq(eERC20Token1.balanceOf(Alice) - aliceBefore, amount);
        assertEq(qm.consumed(eVault.recallQuotaKey(address(eERC20Token1))), amount);
        assertEq(qm.consumed(address(eERC20Token1)), 0);
        assertEq(qm.totalConsumed(), amount);
        assertEq(qm.calls(), 1);
    }

    // An armed recall key that is exhausted blocks the refund atomically: the debit runs right
    // after `_transferTokens`, so the revert unwinds the transfer and releases nothing. The
    // message stays NEW and can be recalled again once the key refills.
    function test_quota_recall_refund_insufficient_reverts_and_releases_nothing() public {
        vm.chainId(taikoChainId);

        uint64 amount = 10;
        qm.setLimit(amount - 1);

        uint256 aliceBefore = eERC20Token1.balanceOf(Alice);
        uint256 vaultBefore = eERC20Token1.balanceOf(address(eVault));

        IBridge.Message memory message = _recallMessage(amount);
        vm.prank(address(tBridge));
        vm.expectRevert(QuotaManager.QM_OUT_OF_QUOTA.selector);
        eVault.onMessageRecalled(message, bytes32(0));

        assertEq(eERC20Token1.balanceOf(Alice), aliceBefore);
        assertEq(eERC20Token1.balanceOf(address(eVault)), vaultBefore);
        assertEq(qm.totalConsumed(), 0);
    }

    // Deliveries and refunds draw on two independent buckets: the same token, released once by
    // each path, is debited under two different keys.
    function test_quota_delivery_and_refund_debit_distinct_keys() public {
        vm.chainId(taikoChainId);

        uint64 amount = 10;
        address token = address(eERC20Token1);
        address recallKey = eVault.recallQuotaKey(token);
        assertTrue(recallKey != token);

        _receive(amount);

        IBridge.Message memory message = _recallMessage(amount);
        vm.prank(address(tBridge));
        eVault.onMessageRecalled(message, bytes32(0));

        assertEq(qm.consumed(token), amount);
        assertEq(qm.consumed(recallKey), amount);
        assertEq(qm.totalConsumed(), 2 * uint256(amount));
    }

    // The recall key follows the other branch of `_transferTokens` too: a refund whose canonical
    // lives on a third chain is settled by *minting* the bridged representation, and it is keyed by
    // the bridged token -- what was actually released -- not by the canonical.
    function test_quota_recall_refund_of_a_bridged_token_debits_recall_key() public {
        vm.chainId(taikoChainId);

        uint64 amount = 10;

        // chainId 999 != block.chainid, so the refund takes the mint branch.
        IBridge.Message memory message = _recallMessage(_foreignCanonical(), amount);
        vm.prank(address(tBridge));
        eVault.onMessageRecalled(message, bytes32(0));

        address btoken = eVault.canonicalToBridged(999, address(eERC20Token1));
        assertTrue(btoken != address(0), "bridged token not deployed");
        assertEq(BridgedERC20(btoken).balanceOf(Alice), amount);
        assertEq(qm.consumed(eVault.recallQuotaKey(btoken)), amount);
        assertEq(qm.consumed(btoken), 0);
        assertEq(qm.totalConsumed(), amount);
    }

    // And the mint branch is throttled, not just metered: an exhausted quota mints nothing.
    function test_quota_recall_refund_of_a_bridged_token_is_throttled() public {
        vm.chainId(taikoChainId);

        uint64 amount = 10;
        qm.setLimit(amount - 1);

        IBridge.Message memory message = _recallMessage(_foreignCanonical(), amount);
        vm.prank(address(tBridge));
        vm.expectRevert(QuotaManager.QM_OUT_OF_QUOTA.selector);
        eVault.onMessageRecalled(message, bytes32(0));

        assertEq(qm.totalConsumed(), 0);
    }

    // The recall key is derived from the token, so it can never alias the token's own withdrawal
    // quota, another token's recall key, or the Ether key.
    function test_quota_recallQuotaKey_is_derived_and_distinct() public view {
        address token = address(eERC20Token1);
        address other = address(eVault);

        address key = eVault.recallQuotaKey(token);
        address otherKey = eVault.recallQuotaKey(other);

        assertTrue(key != otherKey);
        assertTrue(key != token);
        assertTrue(otherKey != other);
        assertTrue(key != address(0));
        assertEq(
            key, address(uint160(uint256(keccak256(abi.encode("ERC20_VAULT_RECALL_QUOTA", token)))))
        );
    }

    // Releasing zero tokens skips the quota manager call entirely.
    function test_quota_zero_amount_skips_external_call() public {
        vm.chainId(taikoChainId);

        _receive(0);

        assertEq(qm.calls(), 0);
        assertEq(qm.totalConsumed(), 0);
    }
}
