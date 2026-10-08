// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../helpers/FreeMintERC20Token.sol";
import "./ERC20Vault.h.sol";

/// @dev An ERC20 that burns a 1% fee from the sender on every transfer: the shape of token the
/// vault's balance-delta accounting exists for.
contract FeeOnTransferERC20 is ERC20 {
    uint256 public constant FEE_BPS = 100;

    constructor() ERC20("Fee on transfer", "FEE") { }

    function mint(address _to, uint256 _amount) external {
        _mint(_to, _amount);
    }

    function _transfer(address _from, address _to, uint256 _amount) internal override {
        uint256 fee = _amount * FEE_BPS / 10_000;
        _burn(_from, fee);
        super._transfer(_from, _to, _amount - fee);
    }
}

/// @dev Exercises the token side of the reported griefing scenario against the real QuotaManager:
/// refunding a recalled message leaves the token's quota exactly where it was, no matter how often
/// it is repeated, while deliveries keep being bounded by it and it keeps refilling over the
/// period. The refund is exercised both directly, the way the other vault tests do, and end to end
/// through a real `Bridge.recallMessage` on the source chain.
contract TestERC20Vault_quotaRecall is CommonTest {
    uint64 private constant TOKEN_QUOTA = 100;

    SignalService private eSignalService;
    Bridge private eBridge;
    ERC20Vault private eVault;
    FreeMintERC20Token private eERC20Token1;
    QuotaManager private qm;

    SignalService private tSignalService;
    PrankDestBridge private tBridge;
    address private tVault = randAddress();

    function setUpOnEthereum() internal override {
        eSignalService = deploySignalServiceWithoutProof(
            address(this), address(uint160(uint256(keccak256("REMOTE_SIGNAL")))), deployer
        );
        // A real bridge on this chain, so a token can be sent and recalled through it. No Ether
        // quota and no pauser: only the vault's token quota is under test here.
        eBridge = deployBridge(
            address(
                new Bridge(address(resolver), address(eSignalService), address(0), address(0), true)
            )
        );

        // The vault and the quota manager reference each other through immutables, so wire them
        // up the way mainnet did: bind the quota manager to the vault proxy, then upgrade the
        // proxy to an implementation that carries the quota manager.
        eVault = ERC20Vault(
            deploy({
                name: "erc20_vault",
                impl: address(new ERC20Vault(address(resolver), address(0))),
                data: abi.encodeCall(ERC20Vault.init, (address(0)))
            })
        );
        qm = deployQuotaManager(address(0), address(eVault));
        eVault.upgradeTo(address(new ERC20Vault(address(resolver), address(qm))));
        assertEq(address(eVault.quotaManager()), address(qm));

        eERC20Token1 = new FreeMintERC20Token("ERC20", "ERC20");
        eERC20Token1.mint(address(eVault));
        qm.updateQuota(address(eERC20Token1), uint104(TOKEN_QUOTA));

        register("bridged_erc20", address(new BridgedERC20(address(eVault))));
    }

    function setUpOnTaiko() internal override {
        tSignalService = deploySignalServiceWithoutProof(
            address(this), address(uint160(uint256(keccak256("REMOTE_SIGNAL_T")))), deployer
        );
        tBridge = new PrankDestBridge(eVault);
        register("bridge", address(tBridge));
        register("bridged_erc20", address(new BridgedERC20(address(eVault))));
        // The vault a `sendToken` from Ethereum addresses on Taiko.
        register("erc20_vault", tVault);
    }

    function test_quota_recall_refund_leaves_quota_untouched() public {
        vm.chainId(taikoChainId);
        address token = address(eERC20Token1);
        assertEq(qm.availableQuota(token, 0), TOKEN_QUOTA);

        // Attacker: refund the whole quota's worth, over and over. Every refund lands and none
        // of them moves the quota.
        for (uint256 i; i < 3; ++i) {
            uint256 aliceBefore = eERC20Token1.balanceOf(Alice);
            IBridge.Message memory message = _recallMessage(TOKEN_QUOTA);
            vm.prank(address(tBridge));
            eVault.onMessageRecalled(message, bytes32(0));
            assertEq(eERC20Token1.balanceOf(Alice) - aliceBefore, TOKEN_QUOTA);
            assertEq(qm.availableQuota(token, 0), TOKEN_QUOTA);
        }

        // A delivery still finds the full quota and is debited...
        // Pre-build the args: `expectEmit` targets the next call, which must be the bridge's.
        ERC20Vault.CanonicalERC20 memory canonical = _canonical();
        vm.expectEmit();
        emit QuotaManager.QuotaConsumed(token, TOKEN_QUOTA, 0);
        _receive(canonical, TOKEN_QUOTA);
        assertEq(qm.availableQuota(token, 0), 0);

        // ...the quota keeps bounding deliveries...
        vm.expectRevert(QuotaManager.QM_OUT_OF_QUOTA.selector);
        _receive(canonical, 1);

        // ...while refunds still go through with the quota exhausted.
        uint256 aliceBeforeLate = eERC20Token1.balanceOf(Alice);
        IBridge.Message memory late = _recallMessage(1);
        vm.prank(address(tBridge));
        eVault.onMessageRecalled(late, bytes32(0));
        assertEq(eERC20Token1.balanceOf(Alice) - aliceBeforeLate, 1);
        assertEq(qm.availableQuota(token, 0), 0);

        // The quota refills over its period, for deliveries only.
        vm.warp(block.timestamp + 24 hours);
        assertEq(qm.availableQuota(token, 0), TOKEN_QUOTA);
    }

    // The same guarantee end to end: a holder sends tokens through the vault and the real bridge,
    // the delivery "fails" on the other chain, and `Bridge.recallMessage` refunds them through
    // `ERC20Vault.onMessageRecalled` without touching the token's quota.
    function test_quota_recall_through_bridge_leaves_quota_untouched() public {
        address token = address(eERC20Token1);
        address holder = Carol;
        eERC20Token1.mint(holder);
        uint256 holderBefore = eERC20Token1.balanceOf(holder);
        uint256 vaultBefore = eERC20Token1.balanceOf(address(eVault));

        vm.startPrank(holder);
        eERC20Token1.approve(address(eVault), TOKEN_QUOTA);
        IBridge.Message memory sent = eVault.sendToken(
            ERC20Vault.BridgeTransferOp({
                destChainId: taikoChainId,
                destOwner: holder,
                to: holder,
                fee: 0,
                token: token,
                gasLimit: 0,
                amount: TOKEN_QUOTA
            })
        );
        vm.stopPrank();
        assertEq(sent.from, address(eVault));
        assertEq(sent.srcOwner, holder);
        assertEq(sent.to, tVault);
        assertEq(eERC20Token1.balanceOf(holder), holderBefore - TOKEN_QUOTA);
        assertEq(eERC20Token1.balanceOf(address(eVault)), vaultBefore + TOKEN_QUOTA);

        // The failure proof is not verified by this chain's signal service (see the boundary
        // stated in `Bridge2_quotaRecall.t.sol`), so the recall goes through as if L2 had reported
        // the failure. It reaches the vault as `IRecallableSender.onMessageRecalled`.
        eBridge.recallMessage(sent, "");
        assertTrue(eBridge.messageStatus(eBridge.hashMessage(sent)) == IBridge.Status.RECALLED);
        assertEq(eERC20Token1.balanceOf(holder), holderBefore);
        assertEq(eERC20Token1.balanceOf(address(eVault)), vaultBefore);
        assertEq(qm.availableQuota(token, 0), TOKEN_QUOTA);
    }

    // The vault records the balance delta a send actually produced, not the requested amount, and
    // a refund returns exactly that delta. So a fee-on-transfer token cannot draw the vault down
    // through send-fail-recall cycles: the sender pays the fee on both legs, the vault's balance
    // ends every cycle where it started, and the token's quota is untouched.
    function test_quota_recall_of_fee_on_transfer_token_cannot_drain_vault() public {
        FeeOnTransferERC20 feeToken = new FeeOnTransferERC20();
        address holder = Carol;
        feeToken.mint(holder, 1_000_000);
        feeToken.mint(address(eVault), 1_000_000); // other users' deposits
        vm.prank(deployer);
        qm.updateQuota(address(feeToken), 1_000_000);

        uint256 vaultBefore = feeToken.balanceOf(address(eVault));
        uint256 quota = qm.availableQuota(address(feeToken), 0);

        for (uint256 i; i < 3; ++i) {
            uint256 holderBefore = feeToken.balanceOf(holder);

            vm.startPrank(holder);
            feeToken.approve(address(eVault), 10_000);
            IBridge.Message memory sent = eVault.sendToken(
                ERC20Vault.BridgeTransferOp({
                    destChainId: taikoChainId,
                    destOwner: holder,
                    to: holder,
                    fee: 0,
                    token: address(feeToken),
                    gasLimit: 0,
                    amount: 10_000
                })
            );
            vm.stopPrank();
            // The vault received 10,000 less the 1% fee, and that is what the message records.
            assertEq(feeToken.balanceOf(address(eVault)), vaultBefore + 9900);

            // The refund returns the recorded 9,900, of which the holder receives 9,801.
            eBridge.recallMessage(sent, "");
            assertEq(feeToken.balanceOf(address(eVault)), vaultBefore);
            assertEq(feeToken.balanceOf(holder), holderBefore - 199);
            assertEq(qm.availableQuota(address(feeToken), 0), quota);
        }
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

    /// @dev Delivers `_amount` of the canonical token to Bob, the way the bridge delivers a
    /// `sendToken` from the other chain.
    function _receive(
        ERC20Vault.CanonicalERC20 memory _canonicalToken,
        uint64 _amount
    )
        internal
    {
        tBridge.sendReceiveERC20ToERC20Vault(
            _canonicalToken,
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
}
