// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @notice Creating the TypedDataV4 hash
// NOTE: This contract implements the version of the encoding known as "v4", as implemented by the
// JSON RPC method
// https://docs.metamask.io/guide/signing-data.html[`eth_signTypedDataV4` in MetaMask].
/// @dev IMPORTANT!! This is for testing, but we need this in the UI for recreating the same hash
/// (to be signed by the user).
// A good resource on how-to:
// link:
// https://medium.com/@javaidea/how-to-sign-and-verify-eip-712-signatures-with-solidity-and-typescript-part-1-5118fdda1fe7

library LibDelegationSigUtil {
    // EIP712 TYPES_HASH.
    bytes32 private constant _TYPE_HASH = keccak256(
        "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
    );

    // For delegation - this TYPES_HASH is fixed.
    bytes32 private constant _DELEGATION_TYPEHASH =
        keccak256("Delegation(address delegatee,uint256 nonce,uint256 expiry)");

    function getDomainSeparator(address verifierContract) public view returns (bytes32) {
        // This is how we create a contract level domain separator!
        // todo (@KorbinianK , @2manslkh): Do it off-chain, in the UI
        return keccak256(
            abi.encode(
                _TYPE_HASH,
                keccak256(bytes("Taiko Token")),
                keccak256(bytes("1")),
                block.chainid,
                verifierContract
            )
        );
    }

    struct Delegate {
        address delegatee;
        uint256 nonce;
        uint256 expiry;
    }

    // computes the hash of a delegation
    function getStructHash(Delegate memory _delegate) internal pure returns (bytes32) {
        return keccak256(
            abi.encode(_DELEGATION_TYPEHASH, _delegate.delegatee, _delegate.nonce, _delegate.expiry)
        );
    }

    // computes the hash of the fully encoded EIP-712 message for the domain, which can be used to
    // recover the signer
    function getTypedDataHash(
        Delegate memory _permit,
        address verifierContract
    )
        public
        view
        returns (bytes32)
    {
        return keccak256(
            abi.encodePacked(
                "\x19\x01", getDomainSeparator(verifierContract), getStructHash(_permit)
            )
        );
    }
}
