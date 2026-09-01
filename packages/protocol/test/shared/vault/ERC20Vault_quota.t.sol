// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../helpers/CountingQuotaManager.sol";
import "../helpers/FreeMintERC20Token.sol";
import "./ERC20Vault.h.sol";

/// @dev Verifies that the ERC20Vault debits the token quota exactly for the tokens actually
/// released to a recipient ("debit only on actual release"). Because the vault consumes quota in
/// the same atomic call that transfers/mints the tokens, a reverted (e.g. out-of-quota) delivery
/// releases nothing and debits nothing, and each successful delivery is debited exactly once.
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
        bytes memory inner = abi.encode(_canonical(), Alice, Bob, uint256(_amount));
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

    // Refunding a recalled message is exempt from the quota: those tokens never left this chain,
    // so returning a user's own failed deposit must not be throttled by unrelated bridge traffic.
    function test_quota_recall_refund_is_exempt_from_quota() public {
        vm.chainId(taikoChainId);

        uint64 amount = 10;
        qm.setLimit(1); // any debit of `amount` would revert

        uint256 aliceBefore = eERC20Token1.balanceOf(Alice);

        // Pre-build the message: it reads token metadata, which would consume the prank.
        IBridge.Message memory message = _recallMessage(amount);
        vm.prank(address(tBridge));
        eVault.onMessageRecalled(message, bytes32(0));

        assertEq(eERC20Token1.balanceOf(Alice) - aliceBefore, amount);
        // The quota manager is not consulted at all on the refund path.
        assertEq(qm.calls(), 0);
        assertEq(qm.totalConsumed(), 0);
    }

    // The exemption is specific to refunds: under the very same exhausted quota, a cross-chain
    // delivery is still rejected.
    function test_quota_blocks_delivery_but_not_refund_under_the_same_limit() public {
        vm.chainId(taikoChainId);

        uint64 amount = 10;
        qm.setLimit(1);

        // A delivery from another chain is throttled ...
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

        // ... while a refund of a failed message goes through.
        uint256 aliceBefore = eERC20Token1.balanceOf(Alice);
        IBridge.Message memory message = _recallMessage(amount);
        vm.prank(address(tBridge));
        eVault.onMessageRecalled(message, bytes32(0));

        assertEq(eERC20Token1.balanceOf(Alice) - aliceBefore, amount);
        assertEq(qm.totalConsumed(), 0);
    }

    // Releasing zero tokens skips the quota manager call entirely.
    function test_quota_zero_amount_skips_external_call() public {
        vm.chainId(taikoChainId);

        _receive(0);

        assertEq(qm.calls(), 0);
        assertEq(qm.totalConsumed(), 0);
    }
}
