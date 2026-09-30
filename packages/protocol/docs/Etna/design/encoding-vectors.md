# Publication covenant encoding fixture

**Normative literal schema; deterministic test data, not deployed addresses or a real signature.** All integers below are unsigned 256-bit ABI words. The Solidity/interface struct is named `PublicationClaim`, but its EIP-712 type name is exactly `EtnaPublication`.

```text
EtnaPublication(uint256 bucketId,uint256 position,uint256 revision,bytes32 baseHeadHash,uint256 issuedAt,bytes32 contextHash)
```

Use the EIP-712 domain fields in exactly this order:

```text
EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)
name = "EtnaDuty"
version = "1"
chainId = 1
verifyingContract = 0x3333333333333333333333333333333333333333
```

The fixture message is:

| Field | Value |
|---|---|
| bucketId | 1 |
| position | 2 |
| revision | 1 |
| baseHeadHash | `0x1111111111111111111111111111111111111111111111111111111111111111` |
| issuedAt | 1000 |
| contextHash | `0x2222222222222222222222222222222222222222222222222222222222222222` |

Expected Keccak-256 results:

| Result | Value |
|---|---|
| Type hash | `0x4d23451d8ae40b9d41993d4ea691972b642b2cea6ea784f21ef8e709291696fc` |
| Struct hash | `0xa41c80567337dee88ac82dc3412a7b834c671a5e325fda431cf783cbc3ef2419` |
| Domain separator | `0x9a13cb9612f90857681e558fdcf3bc698a9f6e19a1954bec63822bf76a3c6ab8` |
| Signing digest | `0x51613be945e729b3e52efb01ee7ce67514536e3a91a70d06fcf41bc9cfbeea7b` |

The struct hash is Keccak-256 of `abi.encode(typeHash, bucketId, position, revision, baseHeadHash, issuedAt, contextHash)`. The signing digest is Keccak-256 of the 66 bytes `0x1901 || domainSeparator || structHash`. Do not use NIST SHA3-256, packed variable-length fields, or the ABI struct name as a substitute type string. Changing any field, registry, chain ID, type literal or field order must produce a different digest.

**Proven/calculated:** generated with a throwaway scratch calculation checked against the published Ethereum Keccak-256 empty-string and `abc` known values. No key or signature was generated, and experiment code is not committed. **Open implementation validation:** independent Solidity/Go/Rust encoders must reproduce these values before release; this fixture does not claim those implementations already exist or passed.
