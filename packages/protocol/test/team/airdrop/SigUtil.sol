// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

// Creating the hashTypedDataV4 hash type signing
contract SigUtil {
    bytes32 private constant _TYPE_HASH = keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
    bytes32 internal DOMAIN_SEPARATOR;

    constructor(address verifierContract) {
        DOMAIN_SEPARATOR = keccak256(abi.encode(_TYPE_HASH, keccak256(bytes("TKO")), keccak256(bytes("1")), block.chainid, verifierContract));
    }

    // For delegation - this TYPES_HASH is fixed.
    bytes32 private constant _DELEGATION_TYPEHASH =
        keccak256("Delegation(address delegatee,uint256 nonce,uint256 expiry)");

    struct Delegate {
        address delegatee;
        uint256 nonce;
        uint256 expiry;
    }

    // computes the hash of a delegation
    function getStructHash(Delegate memory _delegate)
        internal
        pure
        returns (bytes32)
    {
        return
            keccak256(
                abi.encode(
                    _DELEGATION_TYPEHASH,
                    _delegate.delegatee,
                    _delegate.nonce,
                    _delegate.expiry
                )
            );
    }

    // computes the hash of the fully encoded EIP-712 message for the domain, which can be used to recover the signer
    function getTypedDataHash(Delegate memory _permit)
        public
        view
        returns (bytes32)
    {
        return
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    DOMAIN_SEPARATOR,
                    getStructHash(_permit)
                )
            );
    }
}
