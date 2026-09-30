# Canonical body and manifest fixtures

Normative formulas: [execution codec](codec.html#manifests). These are **encoding/hash component fixtures**, not a valid segment, signature, execution proof or launch benchmark. The deliberately tiny header and transaction below must fail full Ethereum/profile validation. Their purpose is to make byte nesting, ABI offsets, tags and manifest order independently reproducible without a key or production implementation.

## Outer RLP and commitment fixture

```text
Body = [1, [[headerBytes=0x0102, [rawTransactionBytes=0x03]]], []]
canonicalBody = 0xc901c6c5820102c103c0          # 10 bytes
BlockRecord  = 0xc5820102c103                # 6 bytes

l1ChainId = uint256(1)
l2ChainId = uint256(167000)
inbox     = 0x3333333333333333333333333333333333333333
anchor    = 0x4444444444444444444444444444444444444444
revision  = uint64(1)
number    = uint48(42)
s.domain  = 0x1111111111111111111111111111111111111111111111111111111111111111
oldHead   = 0x2222222222222222222222222222222222222222222222222222222222222222
first = end = uint48(42)
```

`s.domain` is a synthetic input to this isolated hash fixture, not the configured Etna domain for those addresses. `blockHash=keccak256(0x0102)` is likewise only a byte hash, not an authenticated Ethereum block.

| Output | Keccak-256 value |
|---|---|
| bodyHash | `0x17b442b35e60d37cc66e6556497657dd41265da87e633d020962c68d1d2cb9d6` |
| blockHash | `0x22ae6da6b482f9b1b19b0b897c3fd43884180a1c5ee361e1107a1bc635649dda` |
| recordHash / sole fragment digest | `0x309c84295f5b9b1e2b5c092e04ad263ae0e079a26851109cdad741017d30558f` |
| fragment domain FD | `0x493755219268f6479978e9686dd691c334ee54022a2232ca0910204f97b0db35` |
| block fragment root FR | `0x52feb368dd888be74497406a77bc54e010bf998b5eae95af81efe56dc85111fd` |
| segment manifestRoot | `0x062c3d1bcf584f7e9f92455b28348fb553a3c19dfe1ce93b64df481b5ad136e1` |

The fragment lengths array is `uint32[]([6])`; the digest array has one element, `recordHash`. The fragment-root ABI head is six words. Its dynamic-array offsets are **192 and 256 bytes**, with 320 total encoded bytes. The segment-root head is also six words; its rows offset is **192 bytes**, followed by length 1 and five static row words, for 384 encoded bytes. The row is `(uint48(42), blockHash, recordHash, uint32(6), FR)`. Both tags are Keccak hashes of their exact UTF-8 literals, as specified in the codec; neither is an unencoded concatenated string.

## Fragment boundary fixture

For the isolated split function, take 32,768 zero bytes followed by byte `0x01`. This is **not** a valid BlockRecord. Its only correct split is lengths `[32768,1]`:

- First digest: `0x8cd8aa91369996e33a91695c8fcec3c5597c2fd76edc9f9d4d604fe2624cf914`.
- Second digest: `0x5fe7f977e71dba2ea1a68e21057beebb9be2ac30c6410aa38d4f3fbe41dcffd2`.

Changing the order, omitting the last byte, padding the final fragment, or choosing `[32767,2]` is not the specified manifest even if concatenation or a differently computed root appears plausible. For an exact 32,768-byte record there is one fragment, never a second empty fragment.

## Required negative cases

| Input or change | Required result |
|---|---|
| `0xc301c0c0`, version 1 with no blocks | Reject: minimum one block |
| The toy body above | Outer RLP decodes as shown; full segment rejects invalid header/type-3 transaction and missing correct anchor |
| Encode integer 1 as `0x8101` | Reject nonminimal RLP |
| Encode integer zero as a single `0x00` integer byte | Reject integer encoding; zero is empty RLP string `0x80` (a raw byte-string field may contain `0x00`) |
| Append `0x00` after a complete body | Reject trailing bytes |
| Put a transaction's RLP list directly in the `txRawBytes` array | Reject: entries are byte strings containing complete signed envelopes |
| Omit rejected forced raw bytes or reorder force indices | Reject count/prefix/raw-hash/outcome binding |
| Change a fragment, header, coinbase or transaction after staging | Body/manifest/context changes; original stage and proof cannot authorize it |
| Use segment manifestRoot as DutyClaim.manifestRoot | Reject local complete-block claim validation: different domain and object |
| Put a future stage ID, context hash or proof receipt in the block record | Reject schema; such a self-dependent execution field is absent |

**Validation performed:** scratchpad-only Keccak/ABI byte calculations, checked against the known Keccak empty-input and `abc` answers. No key, signature, production code or deployed state was used. **Open implementation conformance:** independent Solidity, Go and Rust encoders must reproduce these values and negative cases; full valid block/proof vectors belong to the later implementation work. SHA3-256 is not Ethereum Keccak-256.
