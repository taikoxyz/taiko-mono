// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {
    LibSlotChainSignatures
} from "../../../../contracts/shared/slotchain/libs/LibSlotChainSignatures.sol";
import { Test } from "forge-std/src/Test.sol";

contract SlotChainSignaturesHarness {
    function recoverSigner(
        bytes32 _digest,
        bytes calldata _signature
    )
        external
        pure
        returns (address signer_)
    {
        return LibSlotChainSignatures.recoverSigner(_digest, _signature);
    }

    function recoverSignerAt(
        bytes32 _digest,
        bytes calldata _encoded,
        uint256 _offset
    )
        external
        pure
        returns (address signer_)
    {
        return LibSlotChainSignatures.recoverSignerAt(_digest, _encoded, _offset);
    }

    function recoverParts(
        bytes32 _digest,
        bytes32 _r,
        bytes32 _s,
        uint8 _v
    )
        external
        pure
        returns (address signer_)
    {
        return LibSlotChainSignatures.recoverSigner(_digest, _r, _s, _v);
    }

    function requireSigner(
        bytes32 _digest,
        bytes calldata _signature,
        address _expectedSigner
    )
        external
        pure
    {
        LibSlotChainSignatures.requireSigner(_digest, _signature, _expectedSigner);
    }
}

contract LibSlotChainSignaturesTest is Test {
    uint256 private constant _SIGNER_KEY = 0xA11CE;
    uint256 private constant _OTHER_KEY = 0xB0B;
    uint256 private constant _SECP256K1N =
        0xfffffffffffffffffffffffffffffffebaaedce6af48a03bbfd25e8cd0364141;
    uint256 private constant _SECP256K1N_HALF =
        0x7fffffffffffffffffffffffffffffff5d576e7357a4501ddfe92f46681b20a0;

    SlotChainSignaturesHarness private _harness;

    function setUp() public {
        _harness = new SlotChainSignaturesHarness();
    }

    function test_recoverSigner_AcceptsExactLowSSignature() external {
        bytes32 digest = keccak256("slot-chain-signing-digest");
        bytes memory signature = _sign(_SIGNER_KEY, digest);
        assertEq(_harness.recoverSigner(digest, signature), vm.addr(_SIGNER_KEY));
    }

    function testFuzz_recoverSigner_MatchesVmSigner(
        uint256 _key,
        bytes32 _digest
    )
        external
        view
    {
        uint256 key = bound(_key, 1, _SECP256K1N - 1);
        bytes memory signature = _sign(key, _digest);
        assertEq(_harness.recoverSigner(_digest, signature), vm.addr(key));
    }

    function test_recoverSignerAt_AcceptsExactSliceInsideCanonicalRecord() external {
        bytes32 digest = keccak256("slot-chain-signing-digest");
        bytes memory signature = _sign(_SIGNER_KEY, digest);
        bytes memory record = bytes.concat(hex"aabbcc", signature, hex"ddeeff");
        assertEq(_harness.recoverSignerAt(digest, record, 3), vm.addr(_SIGNER_KEY));
    }

    function test_recoverSigner_RevertWhen_SignatureIsShortTrailingOrEip2098() external {
        bytes32 digest = keccak256("slot-chain-signing-digest");
        bytes memory signature = _sign(_SIGNER_KEY, digest);

        vm.expectRevert(LibSlotChainSignatures.InvalidSignatureLength.selector);
        _harness.recoverSigner(digest, _slice(signature, 0, 64));
        vm.expectRevert(LibSlotChainSignatures.InvalidSignatureLength.selector);
        _harness.recoverSigner(digest, bytes.concat(signature, hex"00"));
        vm.expectRevert(LibSlotChainSignatures.InvalidSignatureLength.selector);
        _harness.recoverSigner(digest, _slice(signature, 0, 64));
    }

    function test_recoverSignerAt_RevertWhen_OffsetOrSliceIsOutOfBounds() external {
        bytes32 digest = keccak256("slot-chain-signing-digest");
        bytes memory signature = _sign(_SIGNER_KEY, digest);

        vm.expectRevert(LibSlotChainSignatures.InvalidSignatureLength.selector);
        _harness.recoverSignerAt(digest, signature, 1);
        vm.expectRevert(LibSlotChainSignatures.InvalidSignatureLength.selector);
        _harness.recoverSignerAt(digest, signature, type(uint256).max);
    }

    function test_recoverParts_RevertWhen_RorSIsZeroOrSIsHigh() external {
        bytes32 digest = keccak256("slot-chain-signing-digest");
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(_SIGNER_KEY, digest);

        vm.expectRevert(LibSlotChainSignatures.InvalidSignature.selector);
        _harness.recoverParts(digest, bytes32(0), s, v);
        vm.expectRevert(LibSlotChainSignatures.InvalidSignature.selector);
        _harness.recoverParts(digest, r, bytes32(0), v);
        vm.expectRevert(LibSlotChainSignatures.InvalidSignature.selector);
        _harness.recoverParts(digest, r, bytes32(_SECP256K1N - uint256(s)), v);
        vm.expectRevert(LibSlotChainSignatures.InvalidSignature.selector);
        _harness.recoverParts(digest, r, bytes32(_SECP256K1N_HALF + 1), v);
    }

    function test_recoverParts_AcceptsLowSMaximumWhenRecoveryIsNonzero() external view {
        bytes32 digest = keccak256("boundary-digest");
        address signer =
            _harness.recoverParts(digest, bytes32(uint256(1)), bytes32(_SECP256K1N_HALF), 27);
        assertTrue(signer != address(0));
    }

    function test_recoverParts_RevertWhen_VIsNotCanonical() external {
        bytes32 digest = keccak256("slot-chain-signing-digest");
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(_SIGNER_KEY, digest);
        assertTrue(v == 27 || v == 28);

        vm.expectRevert(LibSlotChainSignatures.InvalidSignature.selector);
        _harness.recoverParts(digest, r, s, 0);
        vm.expectRevert(LibSlotChainSignatures.InvalidSignature.selector);
        _harness.recoverParts(digest, r, s, 1);
        vm.expectRevert(LibSlotChainSignatures.InvalidSignature.selector);
        _harness.recoverParts(digest, r, s, 26);
        vm.expectRevert(LibSlotChainSignatures.InvalidSignature.selector);
        _harness.recoverParts(digest, r, s, 29);
    }

    function test_recoverParts_RevertWhen_EcrecoverReturnsZero() external {
        vm.expectRevert(LibSlotChainSignatures.InvalidSignature.selector);
        _harness.recoverParts(keccak256("digest"), bytes32(_SECP256K1N), bytes32(uint256(1)), 27);
    }

    function test_requireSigner_RevertWhen_ExpectedSignerDiffersOrIsZero() external {
        bytes32 digest = keccak256("slot-chain-signing-digest");
        bytes memory signature = _sign(_SIGNER_KEY, digest);
        _harness.requireSigner(digest, signature, vm.addr(_SIGNER_KEY));

        vm.expectRevert(LibSlotChainSignatures.SignerMismatch.selector);
        _harness.requireSigner(digest, signature, vm.addr(_OTHER_KEY));
        vm.expectRevert(LibSlotChainSignatures.SignerMismatch.selector);
        _harness.requireSigner(digest, signature, address(0));
    }

    function _sign(
        uint256 _key,
        bytes32 _digest
    )
        private
        view
        returns (bytes memory signature_)
    {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(_key, _digest);
        return abi.encodePacked(r, s, v);
    }

    function _slice(
        bytes memory _input,
        uint256 _start,
        uint256 _length
    )
        private
        pure
        returns (bytes memory output_)
    {
        output_ = new bytes(_length);
        for (uint256 i; i < _length; ++i) {
            output_[i] = _input[_start + i];
        }
    }
}
