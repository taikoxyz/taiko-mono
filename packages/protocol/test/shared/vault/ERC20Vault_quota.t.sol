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
}
