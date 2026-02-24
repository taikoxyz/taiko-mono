// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../CommonTest.sol";

contract TestBridgedERC20V3 is CommonTest {
    address private vault = randAddress();
    BridgedERC20V3 private token;

    // Test accounts with known private keys for signature testing
    uint256 private constant ALICE_PRIVATE_KEY = 0xa11ce;
    uint256 private constant BOB_PRIVATE_KEY = 0xb0b;
    address private alice;
    address private bob;

    function setUp() public override {
        super.setUp();
        alice = vm.addr(ALICE_PRIVATE_KEY);
        bob = vm.addr(BOB_PRIVATE_KEY);
    }

    function setUpOnEthereum() internal override {
        register("erc20_vault", vault);
    }

    function _deployToken() internal returns (BridgedERC20V3) {
        address srcToken = randAddress();
        return BridgedERC20V3(
            deploy({
                name: "TEST_V3",
                impl: address(new BridgedERC20V3(vault)),
                data: abi.encodeCall(
                    BridgedERC20V3.init, (deployer, srcToken, taikoChainId, 18, "Test Token", "TEST")
                )
            })
        );
    }

    function _createTransferAuthorization(
        uint256 _signerKey,
        address _from,
        address _to,
        uint256 _value,
        uint256 _validAfter,
        uint256 _validBefore,
        bytes32 _nonce
    )
        internal
        view
        returns (uint8 v, bytes32 r, bytes32 s)
    {
        bytes32 structHash = keccak256(
            abi.encode(
                token.TRANSFER_WITH_AUTHORIZATION_TYPEHASH(),
                _from,
                _to,
                _value,
                _validAfter,
                _validBefore,
                _nonce
            )
        );

        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", token.DOMAIN_SEPARATOR(), structHash));

        (v, r, s) = vm.sign(_signerKey, digest);
    }

    function _createReceiveAuthorization(
        uint256 _signerKey,
        address _from,
        address _to,
        uint256 _value,
        uint256 _validAfter,
        uint256 _validBefore,
        bytes32 _nonce
    )
        internal
        view
        returns (uint8 v, bytes32 r, bytes32 s)
    {
        bytes32 structHash = keccak256(
            abi.encode(
                token.RECEIVE_WITH_AUTHORIZATION_TYPEHASH(),
                _from,
                _to,
                _value,
                _validAfter,
                _validBefore,
                _nonce
            )
        );

        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", token.DOMAIN_SEPARATOR(), structHash));

        (v, r, s) = vm.sign(_signerKey, digest);
    }

    function _createCancelAuthorization(
        uint256 _signerKey,
        address _authorizer,
        bytes32 _nonce
    )
        internal
        view
        returns (uint8 v, bytes32 r, bytes32 s)
    {
        bytes32 structHash =
            keccak256(abi.encode(token.CANCEL_AUTHORIZATION_TYPEHASH(), _authorizer, _nonce));

        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", token.DOMAIN_SEPARATOR(), structHash));

        (v, r, s) = vm.sign(_signerKey, digest);
    }

    // ---------------------------------------------------------------
    // Basic EIP-3009 Functionality Tests
    // ---------------------------------------------------------------

    function test_transferWithAuthorization_succeeds() public {
        token = _deployToken();

        // Mint tokens to alice
        vm.prank(vault);
        token.mint(alice, 1000 ether);

        // Prepare authorization
        bytes32 nonce = keccak256("unique-nonce-1");
        uint256 validAfter = block.timestamp - 1;
        uint256 validBefore = block.timestamp + 3600;
        uint256 value = 100 ether;

        (uint8 v, bytes32 r, bytes32 s) =
            _createTransferAuthorization(ALICE_PRIVATE_KEY, alice, bob, value, validAfter, validBefore, nonce);

        // Anyone can submit the transaction
        vm.prank(Carol);
        vm.expectEmit(true, true, false, false);
        emit BridgedERC20V3.AuthorizationUsed(alice, nonce);
        token.transferWithAuthorization(alice, bob, value, validAfter, validBefore, nonce, v, r, s);

        assertEq(token.balanceOf(alice), 900 ether);
        assertEq(token.balanceOf(bob), 100 ether);
        assertTrue(token.authorizationState(alice, nonce));
    }

    function test_receiveWithAuthorization_succeeds() public {
        token = _deployToken();

        vm.prank(vault);
        token.mint(alice, 1000 ether);

        bytes32 nonce = keccak256("receive-nonce-1");
        uint256 validAfter = block.timestamp - 1;
        uint256 validBefore = block.timestamp + 3600;
        uint256 value = 100 ether;

        (uint8 v, bytes32 r, bytes32 s) =
            _createReceiveAuthorization(ALICE_PRIVATE_KEY, alice, bob, value, validAfter, validBefore, nonce);

        // Only bob (the payee) can call receiveWithAuthorization
        vm.prank(bob);
        vm.expectEmit(true, true, false, false);
        emit BridgedERC20V3.AuthorizationUsed(alice, nonce);
        token.receiveWithAuthorization(alice, bob, value, validAfter, validBefore, nonce, v, r, s);

        assertEq(token.balanceOf(alice), 900 ether);
        assertEq(token.balanceOf(bob), 100 ether);
    }

    function test_cancelAuthorization_succeeds() public {
        token = _deployToken();

        bytes32 nonce = keccak256("cancel-nonce-1");

        (uint8 v, bytes32 r, bytes32 s) = _createCancelAuthorization(ALICE_PRIVATE_KEY, alice, nonce);

        vm.expectEmit(true, true, false, false);
        emit BridgedERC20V3.AuthorizationCanceled(alice, nonce);
        token.cancelAuthorization(alice, nonce, v, r, s);

        assertTrue(token.authorizationState(alice, nonce));
    }

    function test_authorizationState_returnsCorrectState() public {
        token = _deployToken();

        bytes32 nonce = keccak256("state-nonce");

        // Initially false
        assertFalse(token.authorizationState(alice, nonce));

        // After cancellation, true
        (uint8 v, bytes32 r, bytes32 s) = _createCancelAuthorization(ALICE_PRIVATE_KEY, alice, nonce);
        token.cancelAuthorization(alice, nonce, v, r, s);

        assertTrue(token.authorizationState(alice, nonce));
    }

    // ---------------------------------------------------------------
    // Error Cases
    // ---------------------------------------------------------------

    function test_transferWithAuthorization_RevertWhen_AuthorizationNotYetValid() public {
        token = _deployToken();

        vm.prank(vault);
        token.mint(alice, 1000 ether);

        bytes32 nonce = keccak256("not-yet-valid");
        uint256 validAfter = block.timestamp + 3600; // Future
        uint256 validBefore = block.timestamp + 7200;

        (uint8 v, bytes32 r, bytes32 s) = _createTransferAuthorization(
            ALICE_PRIVATE_KEY, alice, bob, 100 ether, validAfter, validBefore, nonce
        );

        vm.expectRevert(BridgedERC20V3.BTOKEN_AUTHORIZATION_NOT_YET_VALID.selector);
        token.transferWithAuthorization(alice, bob, 100 ether, validAfter, validBefore, nonce, v, r, s);
    }

    function test_transferWithAuthorization_RevertWhen_AuthorizationExpired() public {
        token = _deployToken();

        vm.prank(vault);
        token.mint(alice, 1000 ether);

        bytes32 nonce = keccak256("expired");
        uint256 validAfter = block.timestamp - 7200;
        uint256 validBefore = block.timestamp - 3600; // Past

        (uint8 v, bytes32 r, bytes32 s) = _createTransferAuthorization(
            ALICE_PRIVATE_KEY, alice, bob, 100 ether, validAfter, validBefore, nonce
        );

        vm.expectRevert(BridgedERC20V3.BTOKEN_AUTHORIZATION_EXPIRED.selector);
        token.transferWithAuthorization(alice, bob, 100 ether, validAfter, validBefore, nonce, v, r, s);
    }

    function test_transferWithAuthorization_RevertWhen_NonceAlreadyUsed() public {
        token = _deployToken();

        vm.prank(vault);
        token.mint(alice, 1000 ether);

        bytes32 nonce = keccak256("reuse-nonce");
        uint256 validAfter = block.timestamp - 1;
        uint256 validBefore = block.timestamp + 3600;

        (uint8 v, bytes32 r, bytes32 s) = _createTransferAuthorization(
            ALICE_PRIVATE_KEY, alice, bob, 100 ether, validAfter, validBefore, nonce
        );

        // First transfer succeeds
        token.transferWithAuthorization(alice, bob, 100 ether, validAfter, validBefore, nonce, v, r, s);

        // Second transfer with same nonce fails
        vm.expectRevert(BridgedERC20V3.BTOKEN_AUTHORIZATION_USED.selector);
        token.transferWithAuthorization(alice, bob, 100 ether, validAfter, validBefore, nonce, v, r, s);
    }

    function test_transferWithAuthorization_RevertWhen_InvalidSignature() public {
        token = _deployToken();

        vm.prank(vault);
        token.mint(alice, 1000 ether);

        bytes32 nonce = keccak256("invalid-sig");
        uint256 validAfter = block.timestamp - 1;
        uint256 validBefore = block.timestamp + 3600;

        // Sign with bob's key but claim it's from alice
        (uint8 v, bytes32 r, bytes32 s) = _createTransferAuthorization(
            BOB_PRIVATE_KEY, alice, bob, 100 ether, validAfter, validBefore, nonce
        );

        vm.expectRevert(BridgedERC20V2.BTOKEN_INVALID_SIG.selector);
        token.transferWithAuthorization(alice, bob, 100 ether, validAfter, validBefore, nonce, v, r, s);
    }

    function test_transferWithAuthorization_RevertWhen_Paused() public {
        token = _deployToken();

        vm.prank(vault);
        token.mint(alice, 1000 ether);

        // Pause the token
        vm.prank(deployer);
        token.pause();

        bytes32 nonce = keccak256("paused");
        uint256 validAfter = block.timestamp - 1;
        uint256 validBefore = block.timestamp + 3600;

        (uint8 v, bytes32 r, bytes32 s) = _createTransferAuthorization(
            ALICE_PRIVATE_KEY, alice, bob, 100 ether, validAfter, validBefore, nonce
        );

        vm.expectRevert("Pausable: paused");
        token.transferWithAuthorization(alice, bob, 100 ether, validAfter, validBefore, nonce, v, r, s);
    }

    function test_receiveWithAuthorization_RevertWhen_CallerNotPayee() public {
        token = _deployToken();

        vm.prank(vault);
        token.mint(alice, 1000 ether);

        bytes32 nonce = keccak256("wrong-caller");
        uint256 validAfter = block.timestamp - 1;
        uint256 validBefore = block.timestamp + 3600;

        (uint8 v, bytes32 r, bytes32 s) =
            _createReceiveAuthorization(ALICE_PRIVATE_KEY, alice, bob, 100 ether, validAfter, validBefore, nonce);

        // Carol tries to call (not the payee)
        vm.prank(Carol);
        vm.expectRevert(BridgedERC20V3.BTOKEN_CALLER_NOT_PAYEE.selector);
        token.receiveWithAuthorization(alice, bob, 100 ether, validAfter, validBefore, nonce, v, r, s);
    }

    function test_cancelAuthorization_RevertWhen_AlreadyUsed() public {
        token = _deployToken();

        vm.prank(vault);
        token.mint(alice, 1000 ether);

        bytes32 nonce = keccak256("already-used");
        uint256 validAfter = block.timestamp - 1;
        uint256 validBefore = block.timestamp + 3600;

        // Use the authorization first
        (uint8 v, bytes32 r, bytes32 s) = _createTransferAuthorization(
            ALICE_PRIVATE_KEY, alice, bob, 100 ether, validAfter, validBefore, nonce
        );
        token.transferWithAuthorization(alice, bob, 100 ether, validAfter, validBefore, nonce, v, r, s);

        // Now try to cancel
        (v, r, s) = _createCancelAuthorization(ALICE_PRIVATE_KEY, alice, nonce);
        vm.expectRevert(BridgedERC20V3.BTOKEN_AUTHORIZATION_USED.selector);
        token.cancelAuthorization(alice, nonce, v, r, s);
    }

    // ---------------------------------------------------------------
    // Edge Cases
    // ---------------------------------------------------------------

    function test_transferWithAuthorization_withZeroValue() public {
        token = _deployToken();

        vm.prank(vault);
        token.mint(alice, 1000 ether);

        bytes32 nonce = keccak256("zero-value");
        uint256 validAfter = block.timestamp - 1;
        uint256 validBefore = block.timestamp + 3600;

        (uint8 v, bytes32 r, bytes32 s) =
            _createTransferAuthorization(ALICE_PRIVATE_KEY, alice, bob, 0, validAfter, validBefore, nonce);

        token.transferWithAuthorization(alice, bob, 0, validAfter, validBefore, nonce, v, r, s);

        assertEq(token.balanceOf(alice), 1000 ether);
        assertEq(token.balanceOf(bob), 0);
        assertTrue(token.authorizationState(alice, nonce));
    }

    function test_transferWithAuthorization_toSelf() public {
        token = _deployToken();

        vm.prank(vault);
        token.mint(alice, 1000 ether);

        bytes32 nonce = keccak256("self-transfer");
        uint256 validAfter = block.timestamp - 1;
        uint256 validBefore = block.timestamp + 3600;

        (uint8 v, bytes32 r, bytes32 s) = _createTransferAuthorization(
            ALICE_PRIVATE_KEY, alice, alice, 100 ether, validAfter, validBefore, nonce
        );

        token.transferWithAuthorization(alice, alice, 100 ether, validAfter, validBefore, nonce, v, r, s);

        assertEq(token.balanceOf(alice), 1000 ether); // Balance unchanged
    }

    function test_multipleAuthorizationsFromSameUser() public {
        token = _deployToken();

        vm.prank(vault);
        token.mint(alice, 1000 ether);

        uint256 validAfter = block.timestamp - 1;
        uint256 validBefore = block.timestamp + 3600;

        // Create and execute multiple authorizations
        for (uint256 i = 0; i < 5; i++) {
            bytes32 nonce = keccak256(abi.encodePacked("multi-", i));
            (uint8 v, bytes32 r, bytes32 s) = _createTransferAuthorization(
                ALICE_PRIVATE_KEY, alice, bob, 50 ether, validAfter, validBefore, nonce
            );
            token.transferWithAuthorization(alice, bob, 50 ether, validAfter, validBefore, nonce, v, r, s);
        }

        assertEq(token.balanceOf(alice), 750 ether);
        assertEq(token.balanceOf(bob), 250 ether);
    }

    function test_cancelThenTransfer_fails() public {
        token = _deployToken();

        vm.prank(vault);
        token.mint(alice, 1000 ether);

        bytes32 nonce = keccak256("cancel-then-transfer");
        uint256 validAfter = block.timestamp - 1;
        uint256 validBefore = block.timestamp + 3600;

        // Cancel first
        (uint8 v, bytes32 r, bytes32 s) = _createCancelAuthorization(ALICE_PRIVATE_KEY, alice, nonce);
        token.cancelAuthorization(alice, nonce, v, r, s);

        // Then try to transfer
        (v, r, s) = _createTransferAuthorization(
            ALICE_PRIVATE_KEY, alice, bob, 100 ether, validAfter, validBefore, nonce
        );
        vm.expectRevert(BridgedERC20V3.BTOKEN_AUTHORIZATION_USED.selector);
        token.transferWithAuthorization(alice, bob, 100 ether, validAfter, validBefore, nonce, v, r, s);
    }

    // ---------------------------------------------------------------
    // EIP-2612 Compatibility (Inherited from V2)
    // ---------------------------------------------------------------

    function test_permit_stillWorks() public {
        token = _deployToken();

        vm.prank(vault);
        token.mint(alice, 1000 ether);

        uint256 deadline = block.timestamp + 3600;
        uint256 value = 100 ether;

        // Create permit signature
        bytes32 permitTypehash =
            keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");

        bytes32 structHash =
            keccak256(abi.encode(permitTypehash, alice, bob, value, token.nonces(alice), deadline));

        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", token.DOMAIN_SEPARATOR(), structHash));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ALICE_PRIVATE_KEY, digest);

        token.permit(alice, bob, value, deadline, v, r, s);

        assertEq(token.allowance(alice, bob), value);
    }

    function test_permit_and_transferWithAuthorization_independent() public {
        token = _deployToken();

        vm.prank(vault);
        token.mint(alice, 1000 ether);

        // Use permit
        uint256 deadline = block.timestamp + 3600;
        bytes32 permitTypehash =
            keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");
        bytes32 structHash =
            keccak256(abi.encode(permitTypehash, alice, bob, 200 ether, token.nonces(alice), deadline));
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", token.DOMAIN_SEPARATOR(), structHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ALICE_PRIVATE_KEY, digest);
        token.permit(alice, bob, 200 ether, deadline, v, r, s);

        // Use transferWithAuthorization (different nonce system)
        bytes32 authNonce = keccak256("auth-nonce");
        (v, r, s) = _createTransferAuthorization(
            ALICE_PRIVATE_KEY, alice, Carol, 100 ether, block.timestamp - 1, block.timestamp + 3600, authNonce
        );
        token.transferWithAuthorization(
            alice, Carol, 100 ether, block.timestamp - 1, block.timestamp + 3600, authNonce, v, r, s
        );

        // Verify both systems work independently
        assertEq(token.allowance(alice, bob), 200 ether);
        assertEq(token.balanceOf(Carol), 100 ether);
        assertEq(token.nonces(alice), 1); // Permit nonce incremented
        assertTrue(token.authorizationState(alice, authNonce)); // Auth nonce used
    }

    // ---------------------------------------------------------------
    // Upgrade Tests
    // ---------------------------------------------------------------

    function test_upgradeFromV2ToV3_preservesState() public {
        // Deploy V2 token first
        address srcToken = randAddress();
        BridgedERC20V2 tokenV2 = BridgedERC20V2(
            deploy({
                name: "TEST_V2",
                impl: address(new BridgedERC20V2(vault)),
                data: abi.encodeCall(
                    BridgedERC20V2.init, (deployer, srcToken, taikoChainId, 18, "Test Token", "TEST")
                )
            })
        );

        // Mint some tokens
        vm.prank(vault);
        tokenV2.mint(alice, 1000 ether);

        // Use permit on V2
        uint256 deadline = block.timestamp + 3600;
        bytes32 permitTypehash =
            keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");
        bytes32 structHash =
            keccak256(abi.encode(permitTypehash, alice, bob, 200 ether, tokenV2.nonces(alice), deadline));
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", tokenV2.DOMAIN_SEPARATOR(), structHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ALICE_PRIVATE_KEY, digest);
        tokenV2.permit(alice, bob, 200 ether, deadline, v, r, s);

        // Upgrade to V3
        BridgedERC20V3 newImpl = new BridgedERC20V3(vault);
        vm.prank(deployer);
        tokenV2.upgradeTo(address(newImpl));

        // Cast to V3
        BridgedERC20V3 tokenV3 = BridgedERC20V3(address(tokenV2));

        // Initialize V3
        tokenV3.init3();

        // Verify state preserved
        assertEq(tokenV3.balanceOf(alice), 1000 ether);
        assertEq(tokenV3.allowance(alice, bob), 200 ether);
        assertEq(tokenV3.nonces(alice), 1);

        // Use EIP-3009 on upgraded contract
        bytes32 authNonce = keccak256("post-upgrade");
        token = tokenV3; // Set for helper function
        (v, r, s) = _createTransferAuthorization(
            ALICE_PRIVATE_KEY, alice, Carol, 50 ether, block.timestamp - 1, block.timestamp + 3600, authNonce
        );
        tokenV3.transferWithAuthorization(
            alice, Carol, 50 ether, block.timestamp - 1, block.timestamp + 3600, authNonce, v, r, s
        );

        assertEq(tokenV3.balanceOf(Carol), 50 ether);
    }

    // ---------------------------------------------------------------
    // Interface Support
    // ---------------------------------------------------------------

    function test_supportsInterface() public {
        token = _deployToken();

        // IEIP3009
        assertTrue(token.supportsInterface(type(IEIP3009).interfaceId));

        // IERC20PermitUpgradeable (inherited from V2)
        assertTrue(token.supportsInterface(type(IERC20PermitUpgradeable).interfaceId));

        // IERC165
        assertTrue(token.supportsInterface(type(IERC165Upgradeable).interfaceId));
    }

    // ---------------------------------------------------------------
    // Integration Tests
    // ---------------------------------------------------------------

    function test_mintAndTransferWithAuthorization_fullFlow() public {
        token = _deployToken();

        // Vault mints to alice
        vm.prank(vault);
        token.mint(alice, 1000 ether);

        // Alice creates authorization for bob
        bytes32 nonce = keccak256("full-flow");
        uint256 validAfter = block.timestamp - 1;
        uint256 validBefore = block.timestamp + 3600;

        (uint8 v, bytes32 r, bytes32 s) = _createTransferAuthorization(
            ALICE_PRIVATE_KEY, alice, bob, 500 ether, validAfter, validBefore, nonce
        );

        // A relayer (David) submits the transaction
        vm.prank(David);
        token.transferWithAuthorization(alice, bob, 500 ether, validAfter, validBefore, nonce, v, r, s);

        // Bob transfers some to Carol via standard transfer
        vm.prank(bob);
        token.transfer(Carol, 100 ether);

        assertEq(token.balanceOf(alice), 500 ether);
        assertEq(token.balanceOf(bob), 400 ether);
        assertEq(token.balanceOf(Carol), 100 ether);
    }

    // ---------------------------------------------------------------
    // Fuzz Tests
    // ---------------------------------------------------------------

    function testFuzz_transferWithAuthorization_randomAmounts(uint256 _amount) public {
        token = _deployToken();

        // Bound amount to reasonable values
        _amount = bound(_amount, 0, 1e24);

        vm.prank(vault);
        token.mint(alice, _amount);

        bytes32 nonce = keccak256(abi.encodePacked("fuzz-amount", _amount));
        uint256 validAfter = block.timestamp - 1;
        uint256 validBefore = block.timestamp + 3600;

        (uint8 v, bytes32 r, bytes32 s) =
            _createTransferAuthorization(ALICE_PRIVATE_KEY, alice, bob, _amount, validAfter, validBefore, nonce);

        token.transferWithAuthorization(alice, bob, _amount, validAfter, validBefore, nonce, v, r, s);

        assertEq(token.balanceOf(alice), 0);
        assertEq(token.balanceOf(bob), _amount);
    }

    function testFuzz_transferWithAuthorization_randomNonces(bytes32 _nonce) public {
        token = _deployToken();

        vm.prank(vault);
        token.mint(alice, 1000 ether);

        uint256 validAfter = block.timestamp - 1;
        uint256 validBefore = block.timestamp + 3600;

        (uint8 v, bytes32 r, bytes32 s) = _createTransferAuthorization(
            ALICE_PRIVATE_KEY, alice, bob, 100 ether, validAfter, validBefore, _nonce
        );

        token.transferWithAuthorization(alice, bob, 100 ether, validAfter, validBefore, _nonce, v, r, s);

        assertTrue(token.authorizationState(alice, _nonce));
    }

    function testFuzz_validityWindow_boundaries(uint256 _validAfter, uint256 _validBefore) public {
        token = _deployToken();

        vm.prank(vault);
        token.mint(alice, 1000 ether);

        // Bound to create valid window around current timestamp
        _validAfter = bound(_validAfter, 0, block.timestamp - 1);
        _validBefore = bound(_validBefore, block.timestamp + 1, type(uint128).max);

        bytes32 nonce = keccak256(abi.encodePacked("fuzz-window", _validAfter, _validBefore));

        (uint8 v, bytes32 r, bytes32 s) = _createTransferAuthorization(
            ALICE_PRIVATE_KEY, alice, bob, 100 ether, _validAfter, _validBefore, nonce
        );

        token.transferWithAuthorization(alice, bob, 100 ether, _validAfter, _validBefore, nonce, v, r, s);

        assertEq(token.balanceOf(bob), 100 ether);
    }
}
