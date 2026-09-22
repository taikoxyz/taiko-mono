// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../helpers/FreeMintERC20Token.sol";
import "./ERC20Vault.h.sol";

/// @dev Exercises `onMessageRecalled`'s quota accounting against the real `QuotaManager` behind
/// the real vault proxy rather than a counting stub, so the refill curve, the unlimited default
/// and the owner-armed cap are the production ones.
contract TestERC20Vault_quotaRecall is CommonTest {
    uint64 internal constant TOKEN_QUOTA = 100;
    uint64 internal constant RECALL_CAP = 200;

    ERC20Vault private eVault;
    FreeMintERC20Token private eERC20Token1;
    QuotaManager private qm;
    address private recallKey;

    /// @dev The canonical descriptor of `eERC20Token1`, built once during setup. The helpers below
    /// read it from storage so they make no external calls of their own: an `expectRevert` or
    /// `expectEmit` placed before them would otherwise bind to a token metadata read.
    ERC20Vault.CanonicalERC20 private ctoken;

    PrankDestBridge private tBridge;

    function setUpOnEthereum() internal override {
        // The quota manager only accepts its configured vault, and the vault's quota manager is
        // immutable, so the two are wired together by upgrading the already-deployed proxy.
        eVault = deployERC20Vault();
        qm = deployQuotaManager(address(0), address(eVault));
        eVault.upgradeTo(address(new ERC20Vault(address(resolver), address(qm))));
        assertEq(address(eVault.quotaManager()), address(qm));

        eERC20Token1 = new FreeMintERC20Token("ERC20", "ERC20");
        eERC20Token1.mint(address(eVault));

        ctoken = ERC20Vault.CanonicalERC20({
            chainId: taikoChainId,
            addr: address(eERC20Token1),
            decimals: eERC20Token1.decimals(),
            symbol: eERC20Token1.symbol(),
            name: eERC20Token1.name()
        });

        qm.updateQuota(address(eERC20Token1), uint104(TOKEN_QUOTA));
        recallKey = eVault.recallQuotaKey(address(eERC20Token1));
    }

    function setUpOnTaiko() internal override {
        tBridge = new PrankDestBridge(eVault);
        register("bridge", address(tBridge));
    }

    /// @dev Delivers `_amount` of the canonical token to Bob, as a message from Ethereum would.
    function _receive(uint64 _amount) internal {
        tBridge.sendReceiveERC20ToERC20Vault(
            ctoken,
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

    /// @dev Builds a message shaped like one this vault would have sent, so it can be handed back
    /// through `onMessageRecalled`.
    function _recallMsg(uint64 _amount) internal view returns (IBridge.Message memory) {
        bytes memory inner = abi.encode(ctoken, Alice, Bob, uint256(_amount));
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

    /// @dev Refunds a pre-built recalled message to Alice.
    function _recall(IBridge.Message memory _message) internal {
        vm.prank(address(tBridge));
        eVault.onMessageRecalled(_message, bytes32(0));
    }

    // The recall key is unconfigured out of the box, which the quota manager reads as unlimited:
    // the split costs operators nothing until they choose to arm it.
    function test_quota_recall_key_is_unlimited_by_default() public view {
        assertEq(qm.availableQuota(recallKey, 0), qm.UNLIMITED_QUOTA());
        assertTrue(recallKey != address(eERC20Token1));
    }

    // The griefing vector this change closes: repeated send-fail-recall cycles are free to their
    // sender and used to drain the token's shared withdrawal quota. They now leave it fully
    // intact -- and, symmetrically, a spent withdrawal quota never blocks a refund.
    function test_quota_recall_refund_leaves_withdrawal_quota_untouched() public {
        vm.chainId(taikoChainId);

        address token = address(eERC20Token1);

        for (uint256 i; i < 3; ++i) {
            uint256 aliceBefore = eERC20Token1.balanceOf(Alice);
            _recall(_recallMsg(TOKEN_QUOTA));
            assertEq(eERC20Token1.balanceOf(Alice) - aliceBefore, TOKEN_QUOTA);
            assertEq(qm.availableQuota(token, 0), TOKEN_QUOTA);
        }

        // The full withdrawal quota is still there for a real delivery ...
        vm.expectEmit();
        emit QuotaManager.QuotaConsumed(token, TOKEN_QUOTA, 0);
        _receive(TOKEN_QUOTA);
        assertEq(eERC20Token1.balanceOf(Bob), TOKEN_QUOTA);
        assertEq(qm.availableQuota(token, 0), 0);

        // ... which is what exhausts it, not the refunds.
        vm.expectRevert(QuotaManager.QM_OUT_OF_QUOTA.selector);
        _receive(1);

        // And an exhausted withdrawal quota does not block a refund.
        uint256 aliceBalance = eERC20Token1.balanceOf(Alice);
        _recall(_recallMsg(1));
        assertEq(eERC20Token1.balanceOf(Alice) - aliceBalance, 1);

        vm.warp(block.timestamp + 24 hours);
        assertEq(qm.availableQuota(token, 0), TOKEN_QUOTA);
    }

    // Arming the recall key gives refunds their own ceiling: it throttles them exactly like the
    // withdrawal quota throttles deliveries, and the two buckets stay independent.
    function test_quota_armed_recall_key_bounds_refunds_without_touching_deliveries() public {
        vm.chainId(taikoChainId);

        address token = address(eERC20Token1);
        vm.prank(deployer);
        qm.updateQuota(recallKey, uint104(RECALL_CAP));

        _recall(_recallMsg(TOKEN_QUOTA));
        _recall(_recallMsg(TOKEN_QUOTA));
        assertEq(qm.availableQuota(recallKey, 0), 0);
        assertEq(qm.availableQuota(token, 0), TOKEN_QUOTA);

        // The next refund has to wait for the recall key to refill, and releases nothing.
        uint256 aliceBalance = eERC20Token1.balanceOf(Alice);
        IBridge.Message memory pending = _recallMsg(1);
        vm.expectRevert(QuotaManager.QM_OUT_OF_QUOTA.selector);
        _recall(pending);
        assertEq(eERC20Token1.balanceOf(Alice), aliceBalance);

        // Deliveries are untouched by the exhausted recall key.
        _receive(TOKEN_QUOTA);
        assertEq(eERC20Token1.balanceOf(Bob), TOKEN_QUOTA);
        assertEq(qm.availableQuota(token, 0), 0);

        vm.warp(block.timestamp + 24 hours);
        assertEq(qm.availableQuota(recallKey, 0), RECALL_CAP);

        _recall(pending);
        assertEq(eERC20Token1.balanceOf(Alice) - aliceBalance, 1);
    }

    // The caveat documented on `recallQuotaKey`: the quota manager caps a key's refill at its
    // configured quota, so while the key is armed a refund above the cap never clears on its own.
    // Only the owner raising the cap unblocks it, so the cap must exceed any plausible deposit.
    function test_quota_armed_recall_above_cap_RevertWhen_not_raised() public {
        vm.chainId(taikoChainId);

        vm.prank(deployer);
        qm.updateQuota(recallKey, uint104(RECALL_CAP));

        uint256 aliceBalance = eERC20Token1.balanceOf(Alice);
        IBridge.Message memory stuck = _recallMsg(RECALL_CAP + 1);

        vm.expectRevert(QuotaManager.QM_OUT_OF_QUOTA.selector);
        _recall(stuck);

        // Waiting does not help: the refill is capped at the configured quota.
        vm.warp(block.timestamp + 365 days);
        vm.expectRevert(QuotaManager.QM_OUT_OF_QUOTA.selector);
        _recall(stuck);
        assertEq(eERC20Token1.balanceOf(Alice), aliceBalance);

        // Raising the cap is the only way out, and it needs no upgrade.
        vm.prank(deployer);
        qm.updateQuota(recallKey, uint104(2 * RECALL_CAP));

        _recall(stuck);
        assertEq(eERC20Token1.balanceOf(Alice) - aliceBalance, RECALL_CAP + 1);
    }
}
