// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { EtnaVectorReader, LibEtnaVectors } from "./LibEtnaVectors.sol";
import { Vm } from "forge-std/src/Vm.sol";
import { IEtnaStakingRegistry } from "src/layer1/etna/iface/IEtnaStakingRegistry.sol";
import { LibEtnaKeys } from "src/layer1/etna/libs/LibEtnaKeys.sol";
import { CommonTest } from "test/shared/CommonTest.sol";

/// @dev Exposes the library through external calls with calldata parameters.
contract LibEtnaKeysHarness {
    function parsePublicKey(bytes calldata _publicKey)
        external
        view
        returns (uint8, bytes32, bytes32)
    {
        return LibEtnaKeys.parsePublicKey(_publicKey);
    }

    function decompress(uint8 _prefix, bytes32 _x) external view returns (bytes32) {
        return LibEtnaKeys.decompress(_prefix, _x);
    }

    function ckAddr(bytes32 _x, bytes32 _y) external pure returns (address) {
        return LibEtnaKeys.ckAddr(_x, _y);
    }

    function entryKey(uint8 _prefix, bytes32 _x) external pure returns (bytes32) {
        return LibEtnaKeys.entryKey(_prefix, _x);
    }

    function recoverSigner(bytes32 _digest, bytes calldata _sig) external pure returns (address) {
        return LibEtnaKeys.recoverSigner(_digest, _sig);
    }

    function parseSignature(bytes calldata _sig) external pure returns (uint8, bytes32, bytes32) {
        return LibEtnaKeys.parseSignature(_sig);
    }
}

contract LibEtnaKeysTest is CommonTest, EtnaVectorReader {
    /// @dev The secp256k1 field prime.
    uint256 private constant _P = LibEtnaKeys.P;

    /// @dev The secp256k1 group order.
    uint256 private constant _N = LibEtnaKeys.N;

    /// @dev The largest low s, floor(n / 2).
    uint256 private constant _HALF_N = LibEtnaKeys.N / 2;

    /// @dev An X with x^3 + 7 = 1 (mod p), the cube root of -6: the points (x, 1) and (x, p - 1)
    /// are on the curve.
    bytes32 private constant _X_OF_Y_ONE =
        0x1fe1e5ef3fceb5c135ab7741333ce5a6e80d68167653f6b2b24bcbcfaaaff507;

    LibEtnaKeysHarness internal keys;

    function setUp() public virtual override {
        super.setUp();
        keys = new LibEtnaKeysHarness();
    }

    // ---------------------------------------------------------------
    // Constants
    // ---------------------------------------------------------------

    function test_constants_AreTheSecp256k1FieldPrimeAndOrder() external pure {
        assertEq(_P, type(uint256).max - (1 << 32) - 976, "p = 2^256 - 2^32 - 977");
        // The square root is a^((p + 1) / 4) only because p = 3 (mod 4).
        assertEq(_P % 4, 3, "p mod 4");
        assertEq(_N, 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141, "n");
    }

    // ---------------------------------------------------------------
    // parsePublicKey and decompress
    // ---------------------------------------------------------------

    /// @dev Every valid `key_decompression` case, each key under its own prefix and the other
    /// one, decodes to the vector's Y and `ckAddr` and recompresses to the input.
    function test_parsePublicKey_AcceptsEveryVectorKey() external view {
        string memory j = LibEtnaVectors.load();
        uint256 n = LibEtnaVectors.lengthAt(j, ".key_decompression");
        uint256 accepted;
        for (uint256 i; i < n; ++i) {
            string memory p = _at(".key_decompression", i);
            if (!vm.parseJsonBool(j, string.concat(p, "valid"))) continue;
            string memory name = _string(j, p, "name");
            bytes memory publicKey = _bytes(j, p, "public_key");

            (uint8 prefix, bytes32 x, bytes32 y) = keys.parsePublicKey(publicKey);
            assertEq(abi.encodePacked(prefix, x), publicKey, name);
            assertEq(y, _bytes32(j, p, "ck_y"), name);
            assertEq(keys.ckAddr(x, y), _address(j, p, "ck_addr"), name);
            ++accepted;
        }
        assertEq(accepted, 12, "six keys under both prefixes");
    }

    /// @dev Every invalid `key_decompression` case reverts with `InvalidPublicKey`.
    function test_parsePublicKey_RejectsEveryVectorRejection() external view {
        string memory j = LibEtnaVectors.load();
        uint256 n = LibEtnaVectors.lengthAt(j, ".key_decompression");
        uint256 rejected;
        for (uint256 i; i < n; ++i) {
            string memory p = _at(".key_decompression", i);
            if (vm.parseJsonBool(j, string.concat(p, "valid"))) continue;
            string memory label =
                string.concat(_string(j, p, "name"), " (", _string(j, p, "reason"), ")");
            _assertInvalidPublicKey(_bytes(j, p, "public_key"), label);
            ++rejected;
        }
        assertEq(rejected, 15, "rejection count");
    }

    /// @dev A key whose X has a zero top byte keeps it: the 33-byte encoding decodes, and the
    /// 32-byte form without the zero byte is rejected.
    function test_decompress_LeadingZeroX() external view {
        string memory j = LibEtnaVectors.load();
        string memory p = _keyNamed(j, "leading_zero_x");
        uint8 prefix = uint8(_uint(j, p, "ck_prefix"));
        bytes32 x = _bytes32(j, p, "ck_x");
        bytes32 y = _bytes32(j, p, "ck_y");
        assertLt(uint256(x), 1 << 248, "X has a zero top byte");

        assertEq(keys.decompress(prefix, x), y, "decompress");
        address addr = keys.ckAddr(x, y);
        assertEq(addr, _address(j, p, "ck_addr"), "ckAddr");
        assertEq(addr, vm.addr(_uint(j, p, "private_key")), "signer address");

        bytes memory publicKey = _bytes(j, p, "public_key");
        assertEq(publicKey.length, 33);
        assertEq(uint8(publicKey[1]), 0);
        (uint8 parsedPrefix, bytes32 parsedX, bytes32 parsedY) = keys.parsePublicKey(publicKey);
        assertEq(parsedPrefix, prefix);
        assertEq(parsedX, x);
        assertEq(parsedY, y);

        _assertInvalidPublicKey(
            abi.encodePacked(prefix, bytes31(uint248(uint256(x)))), "leading zero dropped"
        );
    }

    /// @dev The other prefix decodes to the negated point (y' = p - y, opposite parity), which
    /// has a different `ckAddr` and `entryKey`.
    function test_decompress_ParityFlipGivesNegatedPoint() external view {
        string memory j = LibEtnaVectors.load();
        uint256 n = LibEtnaVectors.lengthAt(j, ".keys");
        assertEq(n, 6);
        for (uint256 i; i < n; ++i) {
            string memory p = _at(".keys", i);
            string memory name = _string(j, p, "name");
            uint8 prefix = uint8(_uint(j, p, "ck_prefix"));
            bytes32 x = _bytes32(j, p, "ck_x");

            bytes32 y = keys.decompress(prefix, x);
            assertEq(y, _bytes32(j, p, "ck_y"), name);
            uint8 flippedPrefix = prefix ^ 1;
            bytes32 flipped = keys.decompress(flippedPrefix, x);
            assertEq(uint256(flipped), _P - uint256(y), name);
            assertEq(uint256(flipped) & 1, flippedPrefix - 2, name);
            assertNotEq(keys.ckAddr(x, flipped), keys.ckAddr(x, y), name);
            assertNotEq(keys.entryKey(flippedPrefix, x), keys.entryKey(prefix, x), name);
        }
    }

    function test_decompress_RevertWhen_PrefixIsNotTwoOrThree() external view {
        bytes32 x = _a1X();
        for (uint256 prefix; prefix < 256; ++prefix) {
            if (prefix == 2 || prefix == 3) continue;
            _assertDecompressReverts(uint8(prefix), x, vm.toString(prefix));
        }
    }

    function test_decompress_RevertWhen_XIsNotBelowP() external view {
        _assertDecompressReverts(2, bytes32(_P), "x = p");
        _assertDecompressReverts(3, bytes32(_P + 1), "x = p + 1");
        _assertDecompressReverts(2, bytes32(type(uint256).max), "x = 2^256 - 1");
    }

    /// @dev X is never reduced mod p: `x + p` is rejected although `x` is on the curve.
    function test_decompress_RevertWhen_XIsAnUnreducedAlias() external view {
        uint256 x = 1;
        while (!_onCurve(x)) {
            ++x;
        }
        assertLt(x, type(uint256).max - _P, "x + p fits in 256 bits");
        keys.decompress(2, bytes32(x));
        keys.decompress(3, bytes32(x));
        _assertDecompressReverts(2, bytes32(x + _P), "alias, prefix 2");
        _assertDecompressReverts(3, bytes32(x + _P), "alias, prefix 3");
    }

    function test_decompress_RevertWhen_XIsNotOnTheCurve() external view {
        assertFalse(_onCurve(5));
        _assertDecompressReverts(2, bytes32(uint256(5)), "x = 5, prefix 2");
        _assertDecompressReverts(3, bytes32(uint256(5)), "x = 5, prefix 3");
    }

    function test_decompress_RevertWhen_ModexpCallFails() external {
        bytes32 x = _a1X();
        bytes32 root = keys.decompress(3, x);
        // A failed call is rejected even when its 32 bytes of output hold a root.
        vm.mockCallRevert(address(0x05), bytes(""), abi.encode(root));
        _assertDecompressReverts(3, x, "modexp fails with a root");
        vm.mockCallRevert(address(0x05), bytes(""), bytes(""));
        _assertDecompressReverts(3, x, "modexp fails");
    }

    function test_decompress_RevertWhen_ModexpReturnsFewerThan32Bytes() external {
        vm.mockCall(address(0x05), bytes(""), abi.encodePacked(bytes31(0)));
        _assertDecompressReverts(3, _a1X(), "31-byte output");
    }

    function test_decompress_RevertWhen_ModexpReturnsMoreThan32Bytes() external {
        bytes32 x = _a1X();
        bytes32 root = keys.decompress(3, x);
        // Right root, but the precompile must return exactly the modulus length.
        vm.mockCall(address(0x05), bytes(""), abi.encodePacked(root, uint8(0)));
        _assertDecompressReverts(3, x, "33-byte output");
    }

    function test_decompress_RevertWhen_ModexpReturnsANonRoot() external {
        bytes32 x = _a1X();
        vm.mockCall(address(0x05), bytes(""), abi.encode(uint256(1)));
        _assertDecompressReverts(3, x, "1");
        vm.mockCall(address(0x05), bytes(""), abi.encode(_P));
        _assertDecompressReverts(3, x, "p");
    }

    /// @dev The points (x, 1) and (x, p - 1) decode at both ends of the field.
    function test_decompress_YAtTheFieldBounds() external view {
        assertEq(_rhs(uint256(_X_OF_Y_ONE)), 1, "x^3 + 7 = 1");
        assertEq(uint256(keys.decompress(3, _X_OF_Y_ONE)), 1);
        assertEq(uint256(keys.decompress(2, _X_OF_Y_ONE)), _P - 1);
    }

    /// @dev A root returned unreduced (1 + p squares to the same value as 1) is rejected, not
    /// reduced or wrapped.
    function test_decompress_RevertWhen_ModexpReturnsAnUnreducedRoot() external {
        vm.mockCall(address(0x05), bytes(""), abi.encode(_P + 1));
        _assertDecompressReverts(2, _X_OF_Y_ONE, "1 + p, prefix 2");
        _assertDecompressReverts(3, _X_OF_Y_ONE, "1 + p, prefix 3");
    }

    /// @dev Decompression accepts exactly the X below p with x^3 + 7 a square mod p (Euler's
    /// criterion), and returns the root of the requested parity.
    function testFuzz_decompress_AcceptsExactlyTheCurvePoints(bool _odd, bytes32 _x) external view {
        uint8 prefix = _odd ? 3 : 2;
        uint256 x = uint256(_x);
        bool expected = x < _P && _onCurve(x);
        try keys.decompress(prefix, _x) returns (bytes32 y_) {
            assertTrue(expected, "accepted an X off the curve");
            uint256 y = uint256(y_);
            assertLt(y, _P);
            assertEq(mulmod(y, y, _P), _rhs(x), "y^2 = x^3 + 7");
            assertEq(y & 1, prefix - 2, "parity");
        } catch (bytes memory err) {
            assertFalse(expected, "rejected a curve point");
            assertEq(err, abi.encodeWithSelector(IEtnaStakingRegistry.InvalidPublicKey.selector));
        }
    }

    /// @dev The compressed public key of any private key decodes to its full public key, whose
    /// `ckAddr` is the key's Ethereum address.
    function testFuzz_parsePublicKey_RoundTripsCreatedWallets(uint256 _privateKey) external {
        _privateKey = bound(_privateKey, 1, _N - 1);
        Vm.Wallet memory wallet = vm.createWallet(_privateKey);
        uint8 prefix = uint8(2 + (wallet.publicKeyY & 1));
        bytes memory publicKey = abi.encodePacked(prefix, bytes32(wallet.publicKeyX));

        (uint8 parsedPrefix, bytes32 x, bytes32 y) = keys.parsePublicKey(publicKey);
        assertEq(parsedPrefix, prefix);
        assertEq(uint256(x), wallet.publicKeyX);
        assertEq(uint256(y), wallet.publicKeyY);
        assertEq(keys.ckAddr(x, y), vm.addr(_privateKey));
        assertEq(keys.ckAddr(x, y), wallet.addr);
    }

    // ---------------------------------------------------------------
    // ckAddr and entryKey
    // ---------------------------------------------------------------

    /// @dev `ckAddr` hashes the two 32-byte coordinates, not the compressed encoding.
    function test_ckAddr_MatchesVectors() external view {
        string memory j = LibEtnaVectors.load();
        uint256 n = LibEtnaVectors.lengthAt(j, ".keys");
        for (uint256 i; i < n; ++i) {
            string memory p = _at(".keys", i);
            bytes32 x = _bytes32(j, p, "ck_x");
            bytes32 y = _bytes32(j, p, "ck_y");
            address addr = keys.ckAddr(x, y);
            assertEq(addr, _address(j, p, "ck_addr"));
            assertEq(addr, address(uint160(uint256(keccak256(abi.encodePacked(x, y))))));
            assertEq(addr, vm.addr(_uint(j, p, "private_key")));
        }
    }

    function test_entryKey_MatchesVectors() external view {
        string memory j = LibEtnaVectors.load();
        uint256 n = LibEtnaVectors.lengthAt(j, ".keys");
        for (uint256 i; i < n; ++i) {
            string memory p = _at(".keys", i);
            uint8 prefix = uint8(_uint(j, p, "ck_prefix"));
            bytes32 x = _bytes32(j, p, "ck_x");
            bytes32 key = keys.entryKey(prefix, x);
            assertEq(key, _bytes32(j, p, "entry_key"), _string(j, p, "name"));
            assertEq(key, keccak256(abi.encode(uint256(prefix), x)));
        }
    }

    // ---------------------------------------------------------------
    // recoverSigner
    // ---------------------------------------------------------------

    /// @dev Every vector proof of possession recovers to its key's `ckAddr`.
    function test_recoverSigner_AcceptsVectorPops() external view {
        string memory j = LibEtnaVectors.load();
        uint256 n = LibEtnaVectors.lengthAt(j, ".register_digests");
        assertEq(n, 12);
        for (uint256 i; i < n; ++i) {
            string memory p = _at(".register_digests", i);
            string memory name = _string(j, p, "name");
            bytes memory publicKey = _bytes(j, p, "key");
            (, bytes32 x, bytes32 y) = keys.parsePublicKey(publicKey);
            address signer = keys.recoverSigner(_bytes32(j, p, "digest"), _bytes(j, p, "pop_sig"));
            assertEq(signer, _address(j, _keyWithPublicKey(j, publicKey), "ck_addr"), name);
            assertEq(signer, keys.ckAddr(x, y), name);
        }
    }

    /// @dev Every `pop_rejections` case fails registration's PoP check: a signature that is
    /// malformed, out of range or unrecoverable reverts with `InvalidSignature`; a well-formed
    /// one bound to another owner, key, chain, registry or parity recovers to a nonzero address
    /// other than the key's `ckAddr`.
    function test_recoverSigner_RejectsEveryPopRejection() external view {
        string memory j = LibEtnaVectors.load();
        // Every case is checked at the deployment's registry on L1 chain 1, the domain of the
        // `register_digests` cases.
        bytes32 domainSeparator = _bytes32(j, ".register_digests[0].", "domain_separator");
        uint256 n = LibEtnaVectors.lengthAt(j, ".pop_rejections");
        uint256 reverted;
        uint256 mismatched;
        for (uint256 i; i < n; ++i) {
            string memory p = _at(".pop_rejections", i);
            string memory reason = _string(j, p, "reason");
            string memory label = string.concat(_string(j, p, "name"), " (", reason, ")");
            bytes32 digest = _registerDigest(domainSeparator, _address(j, p, "owner"));
            bytes memory sig = _bytes(j, p, "pop_sig");
            (, bytes32 x, bytes32 y) = keys.parsePublicKey(_bytes(j, p, "public_key"));

            if (_isMalformedPopReason(reason)) {
                _assertInvalidSignature(digest, sig, label);
                ++reverted;
            } else if (_isMisboundPopReason(reason)) {
                address signer = keys.recoverSigner(digest, sig);
                assertNotEq(signer, address(0), label);
                assertNotEq(signer, keys.ckAddr(x, y), label);
                ++mismatched;
            } else {
                assertTrue(false, string.concat("unclassified reason: ", label));
            }
        }
        assertEq(reverted, 9, "malformed cases");
        assertEq(mismatched, 5, "misbound cases");
    }

    // ---------------------------------------------------------------
    // parseSignature: the encoding and range checks
    // ---------------------------------------------------------------

    function test_parseSignature_AcceptsTheRangeBoundaries() external view {
        uint256[2] memory rs = [uint256(1), _N - 1];
        uint256[2] memory ss = [uint256(1), _HALF_N];
        for (uint8 v; v < 2; ++v) {
            for (uint256 i; i < 2; ++i) {
                for (uint256 k; k < 2; ++k) {
                    (uint8 v_, bytes32 r_, bytes32 s_) =
                        keys.parseSignature(_signature(rs[i], ss[k], v));
                    assertEq(v_, v);
                    assertEq(uint256(r_), rs[i]);
                    assertEq(uint256(s_), ss[k]);
                }
            }
        }
    }

    function test_parseSignature_RevertWhen_VIsNotZeroOrOne() external view {
        uint8[5] memory vs = [2, 27, 28, 128, 255];
        for (uint256 i; i < vs.length; ++i) {
            _assertSignatureRejected(
                _signature(1, 1, vs[i]), string.concat("v = ", vm.toString(vs[i]))
            );
        }
    }

    function test_parseSignature_RevertWhen_RIsZero() external view {
        _assertSignatureRejected(_signature(0, 1, 0), "r = 0");
    }

    function test_parseSignature_RevertWhen_RIsNotBelowN() external view {
        _assertSignatureRejected(_signature(_N, 1, 0), "r = n");
        _assertSignatureRejected(_signature(_N + 1, 1, 0), "r = n + 1");
        _assertSignatureRejected(_signature(type(uint256).max, 1, 0), "r = 2^256 - 1");
    }

    function test_parseSignature_RevertWhen_SIsZero() external view {
        _assertSignatureRejected(_signature(1, 0, 0), "s = 0");
    }

    function test_parseSignature_RevertWhen_SIsAboveHalfN() external view {
        _assertSignatureRejected(_signature(1, _HALF_N + 1, 0), "s = n/2 + 1");
        _assertSignatureRejected(_signature(1, _N - 1, 0), "s = n - 1");
        _assertSignatureRejected(_signature(1, _N, 0), "s = n");
        _assertSignatureRejected(_signature(1, type(uint256).max, 1), "s = 2^256 - 1");
    }

    function test_parseSignature_RevertWhen_LengthIsNot65() external view {
        bytes memory sig = _signature(1, 1, 0);
        _assertSignatureRejected("", "0 bytes");
        _assertSignatureRejected(abi.encodePacked(bytes32(uint256(1)), bytes32(uint256(1))), "64");
        _assertSignatureRejected(abi.encodePacked(sig, uint8(0)), "66 bytes");
        _assertSignatureRejected(abi.encodePacked(sig, sig), "130 bytes");
    }

    function testFuzz_parseSignature_AcceptsExactlyTheCanonicalRange(
        uint8 _v,
        uint256 _r,
        uint256 _s
    )
        external
        view
    {
        bool expected = _v <= 1 && _r != 0 && _r < _N && _s != 0 && _s <= _HALF_N;
        try keys.parseSignature(_signature(_r, _s, _v)) returns (uint8 v_, bytes32 r_, bytes32 s_) {
            assertTrue(expected, "accepted a noncanonical signature");
            assertEq(v_, _v);
            assertEq(uint256(r_), _r);
            assertEq(uint256(s_), _s);
        } catch (bytes memory err) {
            assertFalse(expected, "rejected a canonical signature");
            assertEq(err, abi.encodeWithSelector(IEtnaStakingRegistry.InvalidSignature.selector));
        }
    }

    // ---------------------------------------------------------------
    // Helpers
    // ---------------------------------------------------------------

    function _assertInvalidPublicKey(bytes memory _publicKey, string memory _label) private view {
        try keys.parsePublicKey(_publicKey) returns (uint8, bytes32, bytes32) {
            assertTrue(false, string.concat(_label, ": accepted"));
        } catch (bytes memory err) {
            assertEq(
                err, abi.encodeWithSelector(IEtnaStakingRegistry.InvalidPublicKey.selector), _label
            );
        }
    }

    function _assertDecompressReverts(
        uint8 _prefix,
        bytes32 _x,
        string memory _label
    )
        private
        view
    {
        try keys.decompress(_prefix, _x) returns (bytes32) {
            assertTrue(false, string.concat(_label, ": accepted"));
        } catch (bytes memory err) {
            assertEq(
                err, abi.encodeWithSelector(IEtnaStakingRegistry.InvalidPublicKey.selector), _label
            );
        }
    }

    function _assertInvalidSignature(
        bytes32 _digest,
        bytes memory _sig,
        string memory _label
    )
        private
        view
    {
        try keys.recoverSigner(_digest, _sig) returns (address signer) {
            assertTrue(false, string.concat(_label, ": recovered ", vm.toString(signer)));
        } catch (bytes memory err) {
            assertEq(
                err, abi.encodeWithSelector(IEtnaStakingRegistry.InvalidSignature.selector), _label
            );
        }
    }

    function _assertSignatureRejected(bytes memory _sig, string memory _label) private view {
        try keys.parseSignature(_sig) returns (uint8, bytes32, bytes32) {
            assertTrue(false, string.concat(_label, ": accepted"));
        } catch (bytes memory err) {
            assertEq(
                err, abi.encodeWithSelector(IEtnaStakingRegistry.InvalidSignature.selector), _label
            );
        }
    }

    /// @dev The `pop_rejections` reasons whose signature `recoverSigner` rejects by itself.
    function _isMalformedPopReason(string memory _reason) private pure returns (bool) {
        string[9] memory reasons = [
            "v_27",
            "v_2",
            "high_s",
            "r_zero",
            "s_zero",
            "r_eq_n",
            "unrecoverable_r",
            "length_64",
            "length_66"
        ];
        for (uint256 i; i < reasons.length; ++i) {
            if (keccak256(bytes(_reason)) == keccak256(bytes(reasons[i]))) return true;
        }
        return false;
    }

    /// @dev The `pop_rejections` reasons of well-formed signatures over another message or by
    /// another key; registration rejects them by comparing the signer with `ckAddr`.
    function _isMisboundPopReason(string memory _reason) private pure returns (bool) {
        string[5] memory reasons =
            ["wrong_owner", "wrong_key", "wrong_chain", "wrong_registry", "parity_flip"];
        for (uint256 i; i < reasons.length; ++i) {
            if (keccak256(bytes(_reason)) == keccak256(bytes(reasons[i]))) return true;
        }
        return false;
    }

    /// @dev The EIP-712 `Register(address owner)` digest (appendix A).
    function _registerDigest(
        bytes32 _domainSeparator,
        address _owner
    )
        private
        pure
        returns (bytes32)
    {
        bytes32 structHash = keccak256(abi.encode(keccak256("Register(address owner)"), _owner));
        return keccak256(abi.encodePacked(hex"1901", _domainSeparator, structHash));
    }

    /// @dev A 65-byte `R ‖ S ‖ V` signature.
    function _signature(uint256 _r, uint256 _s, uint8 _v) private pure returns (bytes memory) {
        return abi.encodePacked(bytes32(_r), bytes32(_s), _v);
    }

    /// @dev `x^3 + 7 mod p`.
    function _rhs(uint256 _x) private pure returns (uint256) {
        return addmod(mulmod(mulmod(_x, _x, _P), _x, _P), 7, _P);
    }

    /// @dev Whether `x^3 + 7` is a square mod p (Euler's criterion; zero is a square).
    function _onCurve(uint256 _x) private view returns (bool) {
        uint256 a = _rhs(_x);
        return a == 0 || _powmod(a, (_P - 1) / 2) == 1;
    }

    /// @dev `_base ^ _exponent mod p` through the modexp precompile.
    function _powmod(uint256 _base, uint256 _exponent) private view returns (uint256) {
        (bool ok, bytes memory out) =
            address(0x05).staticcall(abi.encode(32, 32, 32, _base, _exponent, _P));
        require(ok && out.length == 32, "modexp");
        return abi.decode(out, (uint256));
    }

    /// @dev The X coordinate of vector key a1.
    function _a1X() private view returns (bytes32) {
        return LibEtnaVectors.bytes32At(LibEtnaVectors.load(), ".keys[0].ck_x");
    }

    /// @dev The JSON path prefix of the `keys` entry named `_name`.
    function _keyNamed(string memory _j, string memory _name) private view returns (string memory) {
        uint256 n = LibEtnaVectors.lengthAt(_j, ".keys");
        for (uint256 i; i < n; ++i) {
            string memory p = _at(".keys", i);
            if (keccak256(bytes(_string(_j, p, "name"))) == keccak256(bytes(_name))) return p;
        }
        revert(string.concat("no key named ", _name));
    }

    /// @dev The JSON path prefix of the `keys` entry whose compressed key is `_publicKey`.
    function _keyWithPublicKey(
        string memory _j,
        bytes memory _publicKey
    )
        private
        view
        returns (string memory)
    {
        uint256 n = LibEtnaVectors.lengthAt(_j, ".keys");
        for (uint256 i; i < n; ++i) {
            string memory p = _at(".keys", i);
            if (keccak256(_bytes(_j, p, "public_key")) == keccak256(_publicKey)) return p;
        }
        revert("no key with that public key");
    }
}
