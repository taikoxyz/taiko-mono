// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { Vm } from "forge-std/src/Vm.sol";
import { IEtnaStakingRegistry } from "src/layer1/etna/iface/IEtnaStakingRegistry.sol";
import { LibCometVote } from "src/layer1/etna/libs/LibCometVote.sol";
import { LibEtnaKeys } from "src/layer1/etna/libs/LibEtnaKeys.sol";

/// @title EtnaTestKeys
/// @notice Builds Etna consensus keys and their signatures from test private keys.
/// @dev Signatures are the registry's 65-byte `R ‖ S ‖ V` form with V in {0, 1} and a low S.
library EtnaTestKeys {
    /// @dev The forge cheatcode address.
    Vm private constant _VM = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    /// @dev Returns the 33-byte compressed public key of `_pk`: `0x02 | (y & 1)` followed by X.
    /// @param _pk The private key, in [1, n).
    /// @return The compressed key.
    function publicKey(uint256 _pk) internal returns (bytes memory) {
        Vm.Wallet memory wallet = _VM.createWallet(_pk);
        return abi.encodePacked(uint8(2 + (wallet.publicKeyY & 1)), bytes32(wallet.publicKeyX));
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

    /// @dev Signs the registration proof of possession of `_pk` for `_owner` at `_registry`.
    /// @param _pk The consensus private key.
    /// @param _registry The registry.
    /// @param _owner The bond owner, the registration's caller.
    /// @return The proof of possession.
    function popSig(
        uint256 _pk,
        IEtnaStakingRegistry _registry,
        address _owner
    )
        internal
        view
        returns (bytes memory)
    {
        return sig65(_pk, _registry.registerDigest(_owner));
    }

    /// @dev Signs `_vote` with `_pk` over keccak256 of its CometBFT sign bytes under `_chainId`.
    /// @param _pk The consensus private key.
    /// @param _vote The vote; its signature is replaced.
    /// @param _chainId The CometBFT chain id the vote is signed under.
    /// @return The vote with its signature.
    function signVote(
        uint256 _pk,
        IEtnaStakingRegistry.Vote memory _vote,
        bytes memory _chainId
    )
        internal
        pure
        returns (IEtnaStakingRegistry.Vote memory)
    {
        _vote.signature = sig65(_pk, keccak256(LibCometVote.signBytes(_vote, _chainId)));
        return _vote;
    }
}
