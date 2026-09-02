// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { FreeMintERC20TokenWithPermit } from "../helpers/FreeMintERC20TokenWithPermit.sol";
import { Permit2Mock } from "../helpers/Permit2Mock.sol";
import "./ERC20Vault.h.sol";
import { IERC1271 } from "@openzeppelin/contracts/interfaces/IERC1271.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { IERC20Permit } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";
import { IPermit2 } from "src/shared/vault/IPermit2.sol";

/// @notice Covers ERC20Vault's approval-free entrypoints: `sendTokenWithPermit` (EIP-2612) and
/// `sendTokenWithPermit2` (Uniswap Permit2 `SignatureTransfer`).
/// @dev Records whether `permit` was reached, so the ordering of validation vs. the external call
/// can be asserted rather than assumed.
contract PermitCallRecorder {
    uint256 public permitCalls;

    function permit(address, address, uint256, uint256, uint8, bytes32, bytes32) external {
        ++permitCalls;
    }
}

/// @notice An ERC20 whose fallback silently accepts unknown selectors, which is what WETH9 does.
/// @dev `permit` therefore neither reverts nor grants anything: the vault's `try` takes its success
/// branch with the allowance untouched. This is the shape the repo's reverting WETH9 mock cannot
/// reproduce, and the reason the allowance is checked rather than the call's outcome.
contract SilentPermitToken is ERC20 {
    constructor() ERC20("Silent", "SLNT") {
        _mint(msg.sender, 100 ether);
    }

    fallback() external payable { }
    receive() external payable { }
}

/// @notice A token whose `permit` re-enters `sendTokenWithPermit`, so `nonReentrant` is exercised.
/// @dev The reentrant call bridges the token's *own* balance against an allowance it grants itself,
/// so without the guard it would complete a second full bridge. The guard's revert is swallowed by
/// the outer `catch {}`, which is exactly why the assertion has to be on tokens moved rather than on
/// the revert reason.
contract ReenteringPermitToken is ERC20 {
    ERC20Vault public immutable vault;
    ERC20Vault.BridgeTransferOp private op;

    constructor(ERC20Vault _vault) ERC20("Reenter", "RNTR") {
        vault = _vault;
        _mint(msg.sender, 100 ether);
    }

    function arm(ERC20Vault.BridgeTransferOp calldata _op) external {
        op = _op;
        _mint(address(this), _op.amount);
        _approve(address(this), address(vault), type(uint256).max);
    }

    function permit(address, address, uint256, uint256, uint8, bytes32, bytes32) external {
        ERC20Vault.BridgeTransferOp memory reentrant = op;
        reentrant.token = address(this);
        vault.sendTokenWithPermit(reentrant, block.timestamp + 1 hours, 0, bytes32(0), bytes32(0));
    }
}

/// @notice A token whose `transferFrom` re-enters `sendTokenWithPermit2`.
/// @dev Nothing catches on that path, so the guard's revert propagates and can be asserted directly.
contract ReenteringPermit2Token is ERC20 {
    ERC20Vault public immutable vault;
    ERC20Vault.BridgeTransferOp private op;

    constructor(ERC20Vault _vault) ERC20("Reenter2", "RNTR2") {
        vault = _vault;
        _mint(msg.sender, 100 ether);
    }

    function arm(ERC20Vault.BridgeTransferOp calldata _op) external {
        op = _op;
    }

    function transferFrom(address, address, uint256) public override returns (bool) {
        vault.sendTokenWithPermit2(op, 0, block.timestamp + 1 hours, "");
        return true;
    }
}

/// @notice A smart-contract wallet that authorizes a pre-approved digest from stored state.
/// @dev Signature bytes are irrelevant to it, empty included -- the Safe `signMessage` shape. Real
/// Permit2 routes a signer with code straight to `isValidSignature`, so the vault must not impose a
/// length of its own or this wallet cannot bridge.
contract PreApprovingWallet is IERC1271 {
    mapping(bytes32 digest => bool approved) public approvedHashes;

    function approveHash(bytes32 _digest) external {
        approvedHashes[_digest] = true;
    }

    function approve(address _token, address _spender, uint256 _amount) external {
        IERC20(_token).approve(_spender, _amount);
    }

    function isValidSignature(bytes32 _hash, bytes memory) external view returns (bytes4) {
        return approvedHashes[_hash] ? IERC1271.isValidSignature.selector : bytes4(0xffffffff);
    }
}

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
        return _op(address(eToken), _amount);
    }

    function _op(
        address _token,
        uint256 _amount
    )
        private
        view
        returns (ERC20Vault.BridgeTransferOp memory)
    {
        return ERC20Vault.BridgeTransferOp({
            destChainId: taikoChainId,
            destOwner: address(0),
            to: Bob,
            fee: 0,
            token: _token,
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
        return _signPermit2(_pk, address(eToken), _amount, _nonce, _deadline, _spender);
    }

    function _signPermit2(
        uint256 _pk,
        address _token,
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
            permitted: IPermit2.TokenPermissions({ token: _token, amount: _amount }),
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
        return _signPermitFor(_pk, address(eToken), _owner, _amount, _deadline);
    }

    /// @dev Same, for any EIP-2612 token -- `BridgedERC20V2` carries its own domain separator.
    function _signPermitFor(
        uint256 _pk,
        address _token,
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
                IERC20Permit(_token).nonces(_owner),
                _deadline
            )
        );
        bytes32 digest = keccak256(
            abi.encodePacked("\x19\x01", IERC20Permit(_token).DOMAIN_SEPARATOR(), structHash)
        );
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

        // A distinct `destOwner` is the whole point: with the default `address(0)` both `srcOwner`
        // and the `destOwner` fallback resolve to `msg.sender`, so sourcing `srcOwner` from the
        // wrong field would still pass.
        ERC20Vault.BridgeTransferOp memory op = _op(amount);
        op.destOwner = Carol;

        vm.prank(Alice);
        IBridge.Message memory message = eVault.sendTokenWithPermit2(op, 7, deadline, sig);

        assertEq(message.srcOwner, Alice);
        assertEq(message.destOwner, Carol);
    }

    /// @dev The vault imposes no length on the signature; Permit2 decides. For an EOA that means
    /// Permit2's own `InvalidSignatureLength`, so a vault-side guard would add nothing here -- and
    /// would break the contract-signer case below, which is why there is none.
    function test_20Vault_permit2_leaves_an_empty_eoa_signature_to_permit2() public {
        vm.prank(Alice);
        vm.expectRevert(Permit2Mock.InvalidSignatureLength.selector);
        eVault.sendTokenWithPermit2(_op(1 ether), 0, block.timestamp + 1 hours, "");
    }

    /// @dev Real Permit2 routes a claimed signer that has code straight to
    /// `IERC1271.isValidSignature` with the signature passed through verbatim, so a wallet that
    /// authorizes from stored state (a pre-approved hash, as Safe's `signMessage` produces)
    /// validates an empty signature and transfers. A vault-side length guard would reject this
    /// documented flow before Permit2 ever saw it.
    function test_20Vault_permit2_bridges_for_a_contract_wallet_with_an_empty_signature() public {
        PreApprovingWallet wallet = new PreApprovingWallet();

        uint256 amount = 2 ether;
        uint256 deadline = block.timestamp + 1 hours;

        eToken.mint(address(wallet));
        wallet.approve(address(eToken), permit2, type(uint256).max);

        IPermit2.PermitTransferFrom memory permit = IPermit2.PermitTransferFrom({
            permitted: IPermit2.TokenPermissions({ token: address(eToken), amount: amount }),
            nonce: 0,
            deadline: deadline
        });
        wallet.approveHash(Permit2Mock(permit2).hashTypedData(permit, address(eVault)));

        uint256 walletBefore = eToken.balanceOf(address(wallet));
        uint256 vaultBefore = eToken.balanceOf(address(eVault));

        vm.prank(address(wallet));
        eVault.sendTokenWithPermit2(_op(amount), 0, deadline, "");

        assertEq(eToken.balanceOf(address(wallet)), walletBefore - amount);
        assertEq(eToken.balanceOf(address(eVault)), vaultBefore + amount);
    }

    /// @dev The same wallet without the digest approved is rejected -- the empty signature is not a
    /// bearer instrument, it is only as good as what `isValidSignature` says about it.
    function test_20Vault_permit2_reverts_for_a_contract_wallet_that_did_not_approve() public {
        PreApprovingWallet wallet = new PreApprovingWallet();

        eToken.mint(address(wallet));
        wallet.approve(address(eToken), permit2, type(uint256).max);

        vm.prank(address(wallet));
        vm.expectRevert(Permit2Mock.InvalidContractSignature.selector);
        eVault.sendTokenWithPermit2(_op(2 ether), 0, block.timestamp + 1 hours, "");
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
        vm.expectRevert(Permit2Mock.InvalidSigner.selector);
        eVault.sendTokenWithPermit2(_op(amount), 0, deadline, sig);
    }

    function test_20Vault_permit2_reverts_when_the_signature_names_another_spender() public {
        uint256 amount = 1 ether;
        uint256 deadline = block.timestamp + 1 hours;

        vm.prank(Alice);
        eToken.approve(permit2, type(uint256).max);

        // Signed for Carol as spender; the vault redeems it, so the digest will not match and
        // recovery lands on some other address.
        bytes memory sig = _signPermit2(AlicePK, amount, 0, deadline, Carol);

        vm.prank(Alice);
        vm.expectRevert(Permit2Mock.InvalidSigner.selector);
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
        vm.expectRevert(abi.encodeWithSelector(Permit2Mock.SignatureExpired.selector, deadline));
        eVault.sendTokenWithPermit2(_op(amount), 0, deadline, sig);
    }

    /// @dev Every other test in this file etches the mock at whatever `eVault.PERMIT2()` returns,
    /// so none of them would notice the constant being wrong. This pins the literal: Permit2's
    /// address is CREATE2-derived from `(factory, salt, initcode hash)`, none of which vary by
    /// chain, so it is the same on every chain the vault is deployed to.
    function test_20Vault_permit2_uses_the_canonical_permit2_address() public view {
        assertEq(eVault.PERMIT2(), 0x000000000022D473030F116dDEE9F6B43aC78BA3);
    }

    /// @dev Pins the Permit2 interface to the selector actually present in the canonical deployed
    /// Permit2. Uniswap's `PermitTransferFrom` has no `spender` member -- the spender is bound
    /// into the EIP-712 typehash as `msg.sender` -- so adding one would silently change this
    /// selector and make the vault call a function that does not exist on the real contract.
    /// 0x30f28b7a is the selector found in Permit2's dispatcher at
    /// 0x000000000022D473030F116dDEE9F6B43aC78BA3 on Ethereum mainnet and Taiko Alethia.
    function test_20Vault_permit2_interface_matches_canonical_permit2_selector() public {
        assertEq(uint32(IPermit2.permitTransferFrom.selector), uint32(0x30f28b7a));
    }

    /// @dev The selector pins the *types* tuple, but `nonce` and `deadline` are both `uint256`, so
    /// transposing them leaves the selector unchanged and a self-consistent mock would agree with
    /// the mistake. This pins the canonical wire order Permit2 decodes -- permitted.token,
    /// permitted.amount, nonce, deadline -- by inspecting the calldata our interface produces.
    /// `Permit2Fork.t.sol` proves the same property end-to-end against the deployed contract.
    function test_20Vault_permit2_encodes_nonce_before_deadline() public {
        uint256 nonce = 0x1111;
        uint256 deadline = 0x2222;
        uint256 amount = 7;
        address token = address(0xBEEF);

        IPermit2.PermitTransferFrom memory permit = IPermit2.PermitTransferFrom({
            permitted: IPermit2.TokenPermissions({ token: token, amount: amount }),
            nonce: nonce,
            deadline: deadline
        });
        IPermit2.SignatureTransferDetails memory details =
            IPermit2.SignatureTransferDetails({ to: address(0xCAFE), requestedAmount: amount });

        bytes memory cd = abi.encodeCall(
            IPermit2.permitTransferFrom, (permit, details, address(0xD00D), hex"00")
        );

        // PermitTransferFrom is fully static, so it is inlined in the calldata head.
        assertEq(_word(cd, 0), uint256(uint160(token)));
        assertEq(_word(cd, 1), amount);
        assertEq(_word(cd, 2), nonce);
        assertEq(_word(cd, 3), deadline);
    }

    /// @dev Reads the `_i`th 32-byte word of `_cd` after its 4-byte selector.
    function _word(bytes memory _cd, uint256 _i) private pure returns (uint256 w_) {
        assembly {
            w_ := mload(add(_cd, add(36, mul(_i, 32))))
        }
    }

    /// @dev A call to a codeless address cannot be allowed to look like a successful pull. Solidity
    /// emits an extcodesize check for an external call with no return value, so this reverts rather
    /// than silently transferring nothing and bridging a zero balance change.
    function test_20Vault_permit2_reverts_when_permit2_has_no_code() public {
        uint256 amount = 1 ether;
        uint256 deadline = block.timestamp + 1 hours;

        vm.prank(Alice);
        eToken.approve(permit2, type(uint256).max);

        bytes memory sig = _signPermit2(AlicePK, amount, 0, deadline, address(eVault));

        uint256 aliceBefore = eToken.balanceOf(Alice);
        uint256 vaultBefore = eToken.balanceOf(address(eVault));

        // Simulate a chain where Permit2 was never deployed.
        vm.etch(permit2, "");

        // `bytes("")` rather than a bare `expectRevert()`: it matches only the empty revert an
        // extcodesize check produces, so replacing that mechanism with anything that reverts for a
        // different reason fails here.
        vm.prank(Alice);
        vm.expectRevert(bytes(""));
        eVault.sendTokenWithPermit2(_op(amount), 0, deadline, sig);

        // Nothing moved: the call did not silently succeed.
        assertEq(eToken.balanceOf(Alice), aliceBefore);
        assertEq(eToken.balanceOf(address(eVault)), vaultBefore);
    }

    /// @dev `_pullTokens` is reached from both branches of `_handleMessage`. The canonical branch
    /// locks and measures a balance delta; this is the other one -- the bridged "transfer and
    /// burn" path, where the pull is followed by `burn(_op.amount)` and the full `_op.amount` is
    /// bridged without measuring what actually arrived. Note that `burn` takes from the vault's own
    /// balance, so a short pull of a bridged token over-credits the destination rather than
    /// reverting. That is pre-existing and reachable only for a fee-on-transfer bridged token,
    /// which is DAO-gated via `changeBridgedToken`; measuring the delta here is not the fix,
    /// because the canonical branch tolerates short pulls by design.
    function test_20Vault_permit2_bridges_a_bridged_token_via_transfer_and_burn() public {
        (address btoken,) = _registerBridgedToken();

        vm.prank(address(eVault));
        BridgedERC20(btoken).mint(Alice, 10 ether);

        uint256 amount = 3 ether;
        uint256 deadline = block.timestamp + 1 hours;

        vm.prank(Alice);
        BridgedERC20(btoken).approve(permit2, type(uint256).max);
        assertEq(BridgedERC20(btoken).allowance(Alice, address(eVault)), 0);

        bytes memory sig = _signPermit2(AlicePK, btoken, amount, 0, deadline, address(eVault));

        uint256 supplyBefore = BridgedERC20(btoken).totalSupply();

        vm.prank(Alice);
        IBridge.Message memory message =
            eVault.sendTokenWithPermit2(_op(btoken, amount), 0, deadline, sig);

        // Transfer and burn: Alice is debited, supply shrinks, and the vault keeps nothing.
        assertEq(BridgedERC20(btoken).balanceOf(Alice), 10 ether - amount);
        assertEq(BridgedERC20(btoken).totalSupply(), supplyBefore - amount);
        assertEq(BridgedERC20(btoken).balanceOf(address(eVault)), 0);
        assertEq(message.srcOwner, Alice);
    }

    /// @dev Registers a bridged token whose canonical lives on another chain, so `_handleMessage`
    /// takes its bridged branch. Mirrors the setup used by the existing ERC20Vault suite.
    function _registerBridgedToken()
        private
        returns (address btoken_, ERC20Vault.CanonicalERC20 memory canonical_)
    {
        FreeMintERC20TokenWithPermit origin = new FreeMintERC20TokenWithPermit("ORIG", "ORIG");

        ERC20Vault.CanonicalERC20 memory canonical = ERC20Vault.CanonicalERC20({
            chainId: 999, addr: address(origin), decimals: 18, symbol: "ORIG", name: "ORIG"
        });

        btoken_ = address(new BridgedERC20(address(eVault)));
        canonical_ = canonical;

        // changeBridgedToken enforces MIN_MIGRATION_DELAY against a zero baseline.
        vm.warp(block.timestamp + 91 days);
        vm.prank(deployer);
        eVault.changeBridgedToken(canonical, btoken_);
    }

    /// @dev The permit is an external call to a caller-chosen address, so an operation that cannot
    /// proceed must be rejected before the token is ever touched.
    function test_20Vault_permit_validates_before_calling_the_token() public {
        PermitCallRecorder recorder = new PermitCallRecorder();
        uint256 deadline = block.timestamp + 1 hours;

        // A state counter cannot serve here: the revert under test rolls it back, so it reads zero
        // either way. The cheatcode engine tracks calls independently of state.
        vm.expectCall(
            address(recorder),
            abi.encodeWithSelector(
                PermitCallRecorder.permit.selector,
                Alice,
                address(eVault),
                uint256(0),
                deadline,
                uint8(0),
                bytes32(0),
                bytes32(0)
            ),
            0
        );

        vm.prank(Alice);
        vm.expectRevert(ERC20Vault.VAULT_INVALID_AMOUNT.selector);
        eVault.sendTokenWithPermit(_op(address(recorder), 0), deadline, 0, bytes32(0), bytes32(0));
    }

    /// @dev Likewise for a denylisted bridged token: no call to it at all.
    function test_20Vault_permit_rejects_a_denylisted_token_before_calling_it() public {
        (address btokenOld, ERC20Vault.CanonicalERC20 memory canonical) = _registerBridgedToken();

        address btokenNew = address(new BridgedERC20(address(eVault)));
        vm.warp(block.timestamp + 91 days);
        vm.prank(deployer);
        eVault.changeBridgedToken(canonical, btokenNew);

        uint256 deadline = block.timestamp + 1 hours;

        // The denylist check must come before the permit, so the denylisted token is never called.
        vm.expectCall(
            btokenOld,
            abi.encodeWithSelector(
                PermitCallRecorder.permit.selector,
                Alice,
                address(eVault),
                uint256(1 ether),
                deadline,
                uint8(0),
                bytes32(0),
                bytes32(0)
            ),
            0
        );

        vm.prank(Alice);
        vm.expectRevert(ERC20Vault.VAULT_BTOKEN_BLACKLISTED.selector);
        eVault.sendTokenWithPermit(_op(btokenOld, 1 ether), deadline, 0, bytes32(0), bytes32(0));
    }

    /// @dev A bridged token that has been migrated away from is denylisted, and must stay
    /// unbridgeable through the permit entrypoints too -- not just through `sendToken`.
    function test_20Vault_permit2_rejects_a_denylisted_bridged_token() public {
        (address btokenOld, ERC20Vault.CanonicalERC20 memory canonical) = _registerBridgedToken();

        vm.prank(address(eVault));
        BridgedERC20(btokenOld).mint(Alice, 10 ether);

        // Migrate the canonical onto a new bridged token; the old one is denylisted.
        address btokenNew = address(new BridgedERC20(address(eVault)));
        vm.warp(block.timestamp + 91 days);
        vm.prank(deployer);
        eVault.changeBridgedToken(canonical, btokenNew);
        assertTrue(eVault.btokenDenylist(btokenOld));

        uint256 amount = 1 ether;
        uint256 deadline = block.timestamp + 1 hours;

        vm.prank(Alice);
        BridgedERC20(btokenOld).approve(permit2, type(uint256).max);

        bytes memory sig = _signPermit2(AlicePK, btokenOld, amount, 0, deadline, address(eVault));

        vm.prank(Alice);
        vm.expectRevert(ERC20Vault.VAULT_BTOKEN_BLACKLISTED.selector);
        eVault.sendTokenWithPermit2(_op(btokenOld, amount), 0, deadline, sig);
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

        // See the Permit2 counterpart: `destOwner` must differ from the caller for this to have
        // any teeth.
        ERC20Vault.BridgeTransferOp memory op = _op(amount);
        op.destOwner = Carol;

        vm.prank(Alice);
        IBridge.Message memory message = eVault.sendTokenWithPermit(op, deadline, v, r, s);

        assertEq(message.srcOwner, Alice);
        assertEq(message.destOwner, Carol);
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
        vm.expectRevert(ERC20Vault.VAULT_PERMIT_NO_ALLOWANCE.selector);
        eVault.sendTokenWithPermit(_op(amount), deadline, v, r, s);
    }

    /// @dev The case the `try/catch` alone cannot see: a token whose fallback silently accepts
    /// unknown selectors takes the *success* branch with the allowance still zero. WETH9 is exactly
    /// this shape and is one of the quota-capped vault tokens, so the failure must be decodable
    /// rather than a generic `SafeERC20` string from deep inside the pull.
    function test_20Vault_permit_reverts_when_permit_silently_grants_nothing() public {
        SilentPermitToken silent = new SilentPermitToken();
        assertTrue(silent.transfer(Alice, 10 ether));

        uint256 amount = 2 ether;
        uint256 deadline = block.timestamp + 1 hours;

        // The call succeeds and grants nothing, so only the allowance distinguishes the outcome.
        assertEq(silent.allowance(Alice, address(eVault)), 0);

        vm.prank(Alice);
        vm.expectRevert(ERC20Vault.VAULT_PERMIT_NO_ALLOWANCE.selector);
        eVault.sendTokenWithPermit(
            _op(address(silent), amount), deadline, 0, bytes32(0), bytes32(0)
        );
    }

    /// @dev The allowance check must not undo the front-run tolerance: a standing allowance is a
    /// legitimate basis to bridge on, whoever set it. Same token, same failed permit, allowance
    /// present -- and it goes through.
    function test_20Vault_permit_bridges_on_a_standing_allowance_when_permit_grants_nothing()
        public
    {
        SilentPermitToken silent = new SilentPermitToken();
        assertTrue(silent.transfer(Alice, 10 ether));

        uint256 amount = 2 ether;
        uint256 deadline = block.timestamp + 1 hours;

        vm.prank(Alice);
        silent.approve(address(eVault), amount);

        uint256 aliceBefore = silent.balanceOf(Alice);
        uint256 vaultBefore = silent.balanceOf(address(eVault));

        vm.prank(Alice);
        eVault.sendTokenWithPermit(
            _op(address(silent), amount), deadline, 0, bytes32(0), bytes32(0)
        );

        assertEq(silent.balanceOf(Alice), aliceBefore - amount);
        assertEq(silent.balanceOf(address(eVault)), vaultBefore + amount);
    }

    /// @dev EIP-2612 through the bridged "transfer and burn" branch. `BridgedERC20` has no `permit`,
    /// so this needs a `BridgedERC20V2`; without it the burn branch is covered for Permit2 only.
    function test_20Vault_permit_bridges_a_bridged_token_via_transfer_and_burn() public {
        (BridgedERC20V2 btoken,) = _registerBridgedTokenV2();

        vm.prank(address(eVault));
        btoken.mint(Alice, 10 ether);

        uint256 amount = 3 ether;
        uint256 deadline = block.timestamp + 1 hours;

        assertEq(btoken.allowance(Alice, address(eVault)), 0);

        (uint8 v, bytes32 r, bytes32 s) =
            _signPermitFor(AlicePK, address(btoken), Alice, amount, deadline);

        uint256 supplyBefore = btoken.totalSupply();

        vm.prank(Alice);
        IBridge.Message memory message =
            eVault.sendTokenWithPermit(_op(address(btoken), amount), deadline, v, r, s);

        assertEq(btoken.balanceOf(Alice), 10 ether - amount);
        assertEq(btoken.totalSupply(), supplyBefore - amount);
        assertEq(btoken.balanceOf(address(eVault)), 0);
        assertEq(message.srcOwner, Alice);
    }

    // ---------------------------------------------------------------------------------------
    // Modifiers, fee and value
    // ---------------------------------------------------------------------------------------

    function test_20Vault_permit_reverts_when_paused() public {
        vm.prank(deployer);
        eVault.pause();

        vm.prank(Alice);
        vm.expectRevert(EssentialContract.INVALID_PAUSE_STATUS.selector);
        eVault.sendTokenWithPermit(
            _op(1 ether), block.timestamp + 1 hours, 0, bytes32(0), bytes32(0)
        );
    }

    function test_20Vault_permit2_reverts_when_paused() public {
        vm.prank(deployer);
        eVault.pause();

        vm.prank(Alice);
        vm.expectRevert(EssentialContract.INVALID_PAUSE_STATUS.selector);
        eVault.sendTokenWithPermit2(_op(1 ether), 0, block.timestamp + 1 hours, "");
    }

    /// @dev `nonReentrant` is load-bearing on `sendTokenWithPermit`: `permit` hands execution to a
    /// caller-chosen address before the pull. The guard's revert is swallowed by the surrounding
    /// `catch {}`, so the observable consequence is what is asserted -- the reentrant bridge moves
    /// no tokens. Drop the modifier and the vault receives `2 * amount` instead.
    function test_20Vault_permit_blocks_a_reentrant_bridge() public {
        ReenteringPermitToken token = new ReenteringPermitToken(eVault);
        assertTrue(token.transfer(Alice, 10 ether));

        uint256 amount = 1 ether;
        token.arm(_op(address(token), amount));

        vm.prank(Alice);
        token.approve(address(eVault), amount);

        uint256 aliceBefore = token.balanceOf(Alice);
        uint256 tokenBefore = token.balanceOf(address(token));

        // The reentrant call is attempted -- the guard is what stops it, not a missing call.
        vm.expectCall(
            address(eVault), abi.encodeWithSelector(ERC20Vault.sendTokenWithPermit.selector), 2
        );

        vm.prank(Alice);
        eVault.sendTokenWithPermit(
            _op(address(token), amount), block.timestamp + 1 hours, 0, bytes32(0), bytes32(0)
        );

        // Only Alice's bridge went through; the token's own armed balance is untouched.
        assertEq(token.balanceOf(Alice), aliceBefore - amount);
        assertEq(token.balanceOf(address(token)), tokenBefore);
        assertEq(token.balanceOf(address(eVault)), amount);
    }

    /// @dev Nothing catches on the Permit2 path, so there the guard's revert is directly observable.
    function test_20Vault_permit2_reverts_on_reentrancy() public {
        ReenteringPermit2Token token = new ReenteringPermit2Token(eVault);
        assertTrue(token.transfer(Alice, 10 ether));

        uint256 amount = 1 ether;
        token.arm(_op(address(token), amount));

        vm.prank(Alice);
        token.approve(permit2, type(uint256).max);

        bytes memory sig = _signPermit2(
            AlicePK, address(token), amount, 0, block.timestamp + 1 hours, address(eVault)
        );

        vm.prank(Alice);
        vm.expectRevert(EssentialContract.REENTRANT_CALL.selector);
        eVault.sendTokenWithPermit2(_op(address(token), amount), 0, block.timestamp + 1 hours, sig);
    }

    function test_20Vault_permit_reverts_when_value_is_below_the_fee() public {
        uint256 amount = 1 ether;
        uint256 deadline = block.timestamp + 1 hours;

        ERC20Vault.BridgeTransferOp memory op = _op(amount);
        op.fee = 1000;

        (uint8 v, bytes32 r, bytes32 s) = _signPermit(AlicePK, Alice, amount, deadline);

        vm.prank(Alice);
        vm.expectRevert(BaseVault.VAULT_INSUFFICIENT_FEE.selector);
        eVault.sendTokenWithPermit{ value: 999 }(op, deadline, v, r, s);
    }

    function test_20Vault_permit2_reverts_when_value_is_below_the_fee() public {
        uint256 amount = 1 ether;
        uint256 deadline = block.timestamp + 1 hours;

        vm.prank(Alice);
        eToken.approve(permit2, type(uint256).max);

        ERC20Vault.BridgeTransferOp memory op = _op(amount);
        op.fee = 1000;

        bytes memory sig = _signPermit2(AlicePK, amount, 0, deadline, address(eVault));

        vm.prank(Alice);
        vm.expectRevert(BaseVault.VAULT_INSUFFICIENT_FEE.selector);
        eVault.sendTokenWithPermit2{ value: 999 }(op, 0, deadline, sig);
    }

    /// @dev The value path end to end: `msg.value - fee` becomes the message value and the fee is
    /// carried on the message, exactly as `sendToken` does it.
    function test_20Vault_permit2_carries_value_and_fee_onto_the_message() public {
        uint256 amount = 1 ether;
        uint256 deadline = block.timestamp + 1 hours;

        vm.prank(Alice);
        eToken.approve(permit2, type(uint256).max);

        ERC20Vault.BridgeTransferOp memory op = _op(amount);
        op.fee = 1000;

        bytes memory sig = _signPermit2(AlicePK, amount, 0, deadline, address(eVault));

        vm.prank(Alice);
        IBridge.Message memory message =
            eVault.sendTokenWithPermit2{ value: 5000 }(op, 0, deadline, sig);

        assertEq(message.fee, 1000);
        assertEq(message.value, 4000);
    }

    /// @dev Registers a `BridgedERC20V2`, which unlike `BridgedERC20` implements EIP-2612.
    function _registerBridgedTokenV2()
        private
        returns (BridgedERC20V2 btoken_, ERC20Vault.CanonicalERC20 memory canonical_)
    {
        FreeMintERC20TokenWithPermit origin = new FreeMintERC20TokenWithPermit("ORIGV2", "ORIGV2");

        canonical_ = ERC20Vault.CanonicalERC20({
            chainId: 999, addr: address(origin), decimals: 18, symbol: "ORIGV2", name: "ORIGV2"
        });

        btoken_ = BridgedERC20V2(
            deploy({
                name: "",
                impl: address(new BridgedERC20V2(address(eVault))),
                data: abi.encodeCall(
                    BridgedERC20V2.init, (deployer, address(origin), 999, 18, "ORIGV2", "ORIGV2")
                )
            })
        );

        vm.warp(block.timestamp + 91 days);
        vm.prank(deployer);
        eVault.changeBridgedToken(canonical_, address(btoken_));
    }
}
