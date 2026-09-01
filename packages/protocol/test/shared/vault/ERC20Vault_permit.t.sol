// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { FreeMintERC20TokenWithPermit } from "../helpers/FreeMintERC20TokenWithPermit.sol";
import { Permit2Mock } from "../helpers/Permit2Mock.sol";
import "./ERC20Vault.h.sol";
import { IPermit2 } from "src/shared/vault/IPermit2.sol";

/// @notice Covers ERC20Vault's approval-free entrypoints: `sendTokenWithPermit` (EIP-2612) and
/// `sendTokenWithPermit2` (Uniswap Permit2 `SignatureTransfer`).
contract TestERC20VaultPermit is CommonTest {
    uint256 private constant AlicePK = 0x1;
    uint256 private constant BobPK = 0x2;

    SignalService private eSignalService;
    Bridge private eBridge;
    ERC20Vault private eVault;
    FreeMintERC20TokenWithPermit private eToken;

    // Cached because reading `eVault.PERMIT2()` inline would consume a pending `vm.prank`.
    address private permit2;

    function setUpOnEthereum() internal override {
        eSignalService = deploySignalServiceWithoutProof(
            address(this),
            address(
                uint160(uint256(keccak256(abi.encodePacked(bytes32("ETH"), "_REMOTE_SIGNAL"))))
            ),
            deployer
        );
        eBridge = deployBridge(
            address(new Bridge(address(resolver), address(eSignalService), address(0), address(0)))
        );
        eVault = deployERC20Vault();

        eToken = new FreeMintERC20TokenWithPermit("ERC20Permit", "E20P");
        eToken.mint(Alice);

        register("bridged_erc20", address(new BridgedERC20(address(eVault))));

        // Place the mock's runtime code at Permit2's canonical address, which is what the vault
        // calls. The mock derives its domain separator from `address(this)`, so it stays valid.
        permit2 = eVault.PERMIT2();
        vm.etch(permit2, address(new Permit2Mock()).code);

        vm.deal(Alice, 1 ether);
    }

    function setUpOnTaiko() internal override {
        // `sendToken*` needs a destination-chain vault to address the message to, and Bridge
        // rejects a destination chain that has no registered bridge.
        deployERC20Vault();
        register("bridge", address(new PrankDestBridge(eVault)));
    }

    function _op(uint256 _amount) private view returns (ERC20Vault.BridgeTransferOp memory) {
        return ERC20Vault.BridgeTransferOp({
            destChainId: taikoChainId,
            destOwner: address(0),
            to: Bob,
            fee: 0,
            token: address(eToken),
            gasLimit: 1_000_000,
            amount: _amount
        });
    }

    function _signPermit2(
        uint256 _pk,
        uint256 _amount,
        uint256 _nonce,
        uint256 _deadline,
        address _spender
    )
        private
        view
        returns (bytes memory)
    {
        IPermit2.PermitTransferFrom memory permit = IPermit2.PermitTransferFrom({
            permitted: IPermit2.TokenPermissions({ token: address(eToken), amount: _amount }),
            nonce: _nonce,
            deadline: _deadline
        });
        bytes32 digest = Permit2Mock(permit2).hashTypedData(permit, _spender);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(_pk, digest);
        return abi.encodePacked(r, s, v);
    }

    function _signPermit(
        uint256 _pk,
        address _owner,
        uint256 _amount,
        uint256 _deadline
    )
        private
        view
        returns (uint8 v, bytes32 r, bytes32 s)
    {
        bytes32 structHash = keccak256(
            abi.encode(
                keccak256(
                    "Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"
                ),
                _owner,
                address(eVault),
                _amount,
                eToken.nonces(_owner),
                _deadline
            )
        );
        bytes32 digest =
            keccak256(abi.encodePacked("\x19\x01", eToken.DOMAIN_SEPARATOR(), structHash));
        return vm.sign(_pk, digest);
    }

    // ---------------------------------------------------------------------------------------
    // Permit2
    // ---------------------------------------------------------------------------------------

    function test_20Vault_permit2_bridges_without_a_prior_vault_approval() public {
        uint256 amount = 3 ether;
        uint256 deadline = block.timestamp + 1 hours;

        // Alice approves Permit2 once, and never approves the vault itself.
        vm.prank(Alice);
        eToken.approve(permit2, type(uint256).max);
        assertEq(eToken.allowance(Alice, address(eVault)), 0);

        uint256 aliceBefore = eToken.balanceOf(Alice);
        uint256 vaultBefore = eToken.balanceOf(address(eVault));

        bytes memory sig = _signPermit2(AlicePK, amount, 0, deadline, address(eVault));

        vm.prank(Alice);
        eVault.sendTokenWithPermit2(_op(amount), 0, deadline, sig);

        assertEq(eToken.balanceOf(Alice), aliceBefore - amount);
        assertEq(eToken.balanceOf(address(eVault)), vaultBefore + amount);
        // The vault still holds no standing allowance from Alice.
        assertEq(eToken.allowance(Alice, address(eVault)), 0);
    }

    /// @dev The signer must remain the message's `srcOwner`, because `onMessageRecalled` refunds
    /// tokens to `srcOwner`. If this ever drifts to a non-signer, a failed bridge would refund the
    /// wrong address.
    function test_20Vault_permit2_keeps_the_signer_as_the_recall_refund_owner() public {
        uint256 amount = 1 ether;
        uint256 deadline = block.timestamp + 1 hours;

        vm.prank(Alice);
        eToken.approve(permit2, type(uint256).max);

        bytes memory sig = _signPermit2(AlicePK, amount, 7, deadline, address(eVault));

        vm.prank(Alice);
        IBridge.Message memory message = eVault.sendTokenWithPermit2(_op(amount), 7, deadline, sig);

        assertEq(message.srcOwner, Alice);
        assertEq(message.destOwner, Alice);
    }

    function test_20Vault_permit2_reverts_on_an_empty_signature() public {
        vm.prank(Alice);
        vm.expectRevert(ERC20Vault.VAULT_INVALID_PERMIT2_SIG.selector);
        eVault.sendTokenWithPermit2(_op(1 ether), 0, block.timestamp + 1 hours, "");
    }

    function test_20Vault_permit2_reverts_when_the_nonce_is_replayed() public {
        uint256 amount = 1 ether;
        uint256 deadline = block.timestamp + 1 hours;

        vm.prank(Alice);
        eToken.approve(permit2, type(uint256).max);

        bytes memory sig = _signPermit2(AlicePK, amount, 42, deadline, address(eVault));

        vm.prank(Alice);
        eVault.sendTokenWithPermit2(_op(amount), 42, deadline, sig);

        vm.prank(Alice);
        vm.expectRevert(Permit2Mock.InvalidNonce.selector);
        eVault.sendTokenWithPermit2(_op(amount), 42, deadline, sig);
    }

    function test_20Vault_permit2_reverts_when_the_signature_is_not_the_callers() public {
        uint256 amount = 1 ether;
        uint256 deadline = block.timestamp + 1 hours;

        vm.prank(Alice);
        eToken.approve(permit2, type(uint256).max);

        // Bob signs, Alice submits: Permit2 recovers Bob but is told the owner is Alice.
        bytes memory sig = _signPermit2(BobPK, amount, 0, deadline, address(eVault));

        vm.prank(Alice);
        vm.expectRevert(Permit2Mock.InvalidSignature.selector);
        eVault.sendTokenWithPermit2(_op(amount), 0, deadline, sig);
    }

    function test_20Vault_permit2_reverts_when_the_signature_names_another_spender() public {
        uint256 amount = 1 ether;
        uint256 deadline = block.timestamp + 1 hours;

        vm.prank(Alice);
        eToken.approve(permit2, type(uint256).max);

        // Signed for Carol as spender; the vault redeems it, so the digest will not match.
        bytes memory sig = _signPermit2(AlicePK, amount, 0, deadline, Carol);

        vm.prank(Alice);
        vm.expectRevert(Permit2Mock.InvalidSignature.selector);
        eVault.sendTokenWithPermit2(_op(amount), 0, deadline, sig);
    }

    function test_20Vault_permit2_reverts_after_the_deadline() public {
        uint256 amount = 1 ether;
        uint256 deadline = block.timestamp + 1 hours;

        vm.prank(Alice);
        eToken.approve(permit2, type(uint256).max);

        bytes memory sig = _signPermit2(AlicePK, amount, 0, deadline, address(eVault));

        vm.warp(deadline + 1);

        vm.prank(Alice);
        vm.expectRevert(Permit2Mock.SignatureExpired.selector);
        eVault.sendTokenWithPermit2(_op(amount), 0, deadline, sig);
    }

    // ---------------------------------------------------------------------------------------
    // EIP-2612
    // ---------------------------------------------------------------------------------------

    function test_20Vault_permit_bridges_without_a_prior_vault_approval() public {
        uint256 amount = 4 ether;
        uint256 deadline = block.timestamp + 1 hours;

        assertEq(eToken.allowance(Alice, address(eVault)), 0);

        uint256 aliceBefore = eToken.balanceOf(Alice);
        uint256 vaultBefore = eToken.balanceOf(address(eVault));

        (uint8 v, bytes32 r, bytes32 s) = _signPermit(AlicePK, Alice, amount, deadline);

        vm.prank(Alice);
        eVault.sendTokenWithPermit(_op(amount), deadline, v, r, s);

        assertEq(eToken.balanceOf(Alice), aliceBefore - amount);
        assertEq(eToken.balanceOf(address(eVault)), vaultBefore + amount);
    }

    function test_20Vault_permit_keeps_the_signer_as_the_recall_refund_owner() public {
        uint256 amount = 1 ether;
        uint256 deadline = block.timestamp + 1 hours;

        (uint8 v, bytes32 r, bytes32 s) = _signPermit(AlicePK, Alice, amount, deadline);

        vm.prank(Alice);
        IBridge.Message memory message = eVault.sendTokenWithPermit(_op(amount), deadline, v, r, s);

        assertEq(message.srcOwner, Alice);
        assertEq(message.destOwner, Alice);
    }

    /// @dev A griefer can replay the permit straight at the token to burn the nonce. The vault must
    /// still bridge, because the allowance the permit granted is already in place.
    function test_20Vault_permit_tolerates_a_front_run_permit() public {
        uint256 amount = 2 ether;
        uint256 deadline = block.timestamp + 1 hours;

        (uint8 v, bytes32 r, bytes32 s) = _signPermit(AlicePK, Alice, amount, deadline);

        // Carol front-runs, consuming Alice's permit nonce and setting the allowance.
        vm.prank(Carol);
        eToken.permit(Alice, address(eVault), amount, deadline, v, r, s);
        assertEq(eToken.allowance(Alice, address(eVault)), amount);

        uint256 aliceBefore = eToken.balanceOf(Alice);

        vm.prank(Alice);
        eVault.sendTokenWithPermit(_op(amount), deadline, v, r, s);

        assertEq(eToken.balanceOf(Alice), aliceBefore - amount);
    }

    /// @dev A swallowed permit failure must not mask a genuinely missing allowance.
    function test_20Vault_permit_reverts_when_the_permit_is_invalid_and_no_allowance_exists()
        public
    {
        uint256 amount = 2 ether;
        uint256 deadline = block.timestamp + 1 hours;

        // Bob's signature is not valid for Alice, and Alice never approved the vault.
        (uint8 v, bytes32 r, bytes32 s) = _signPermit(BobPK, Alice, amount, deadline);

        vm.prank(Alice);
        vm.expectRevert("ERC20: insufficient allowance");
        eVault.sendTokenWithPermit(_op(amount), deadline, v, r, s);
    }
}
