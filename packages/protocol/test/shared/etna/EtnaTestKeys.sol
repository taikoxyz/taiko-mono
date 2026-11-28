// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { Vm } from "forge-std/src/Vm.sol";
import { LibEtnaKeys } from "src/shared/etna/LibEtnaKeys.sol";

/// @title EtnaTestKeys
/// @notice Builds Etna consensus keys and their signatures from test private keys.
/// @dev Signatures are the 65-byte `R ‖ S ‖ V` form with V in {0, 1} and a low S.
library EtnaTestKeys {
    /// @dev The forge cheatcode address.
    Vm private constant _VM = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    /// @dev Returns the 33-byte compressed public key of `_pk`: `0x02 | (y & 1)` followed by X.
    /// @param _pk The private key, in [1, n).
    /// @return The compressed key.
    function publicKey(uint256 _pk) internal returns (bytes memory) {
        (uint8 ckPrefix, bytes32 ckX) = fallbackKey(_pk);
        return abi.encodePacked(ckPrefix, ckX);
    }

    /// @dev Returns the key of `_pk` as its SEC1 prefix and X, the fields of an Inbox fallback key.
    /// @param _pk The private key, in [1, n).
    /// @return ckPrefix_ The SEC1 prefix, `0x02 | (y & 1)`.
    /// @return ckX_ The X coordinate.
    function fallbackKey(uint256 _pk) internal returns (uint8 ckPrefix_, bytes32 ckX_) {
        Vm.Wallet memory wallet = _VM.createWallet(_pk);
        ckPrefix_ = uint8(2 + (wallet.publicKeyY & 1));
        ckX_ = bytes32(wallet.publicKeyX);
    }

    /// @dev Returns the key address of `_pk`, keccak256(X ‖ Y)[12:], which is its Ethereum
    /// address.
    /// @param _pk The private key, in [1, n).
    /// @return The key address.
    function ckAddr(uint256 _pk) internal pure returns (address) {
        return _VM.addr(_pk);
    }

    /// @dev Signs `_digest` with `_pk`, normalizing S to the lower half of the order.
    /// @param _pk The private key.
    /// @param _digest The digest.
    /// @return The signature `R ‖ S ‖ V`.
    function sig65(uint256 _pk, bytes32 _digest) internal pure returns (bytes memory) {
        (uint8 v, bytes32 r, bytes32 s) = _VM.sign(_pk, _digest);
        if (uint256(s) > LibEtnaKeys.N / 2) {
            s = bytes32(LibEtnaKeys.N - uint256(s));
            v = v == 27 ? 28 : 27;
        }
        return abi.encodePacked(r, s, v - 27);
    }
}
