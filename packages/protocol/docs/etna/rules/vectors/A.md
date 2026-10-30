# A — accept/reject vectors

**Non-normative.** Rule text lives in [SPEC.md](../../SPEC.md). This file states only what the text states: each vector either follows directly from a numbered statement, or reports that a requirement was violated. Where the text states a requirement but **not the consequence of violating it**, the vector says "violates ENC-A-N" and does not name an outcome. Anything undetermined has no vector; it is listed under "Not covered" and raised in [review/A.md](../review/A.md).

`accept` means the described encoding satisfies the rule cited. `reject` means a stated requirement is violated. Appendix A states one consequence: ENC-A-16's "any violation makes the proposal invalid". It covers the envelope grammar (ENC-A-11–ENC-A-15) and the strict-decoding conditions (ENC-A-16–ENC-A-22), so those reject rows say "proposal invalid (ENC-A-16)". Rows elsewhere say "violates ENC-A-N" where the text states no consequence. Where a definition spans several lines, the marker and the ID sit above its first line, and the ID cites the whole definition (see [../README.md](../README.md#how-far-an-id-extends)).

**Scope note.** Appendix A's grammar — `chainDomain`, `chain_id`, `extraData`, the envelope and payload layouts, `AccountWitness`, `cutLeaf`, `cutHash`, `statement`, `committeeConfigHash`, `regLeaf`, `entriesRoot`, `setKey`/`setLeaf`/`setNode`/`record`, `voteSignBytes`, registration and the `recover` interface — sits inside four fenced blocks (SPEC.md 635–811). Under the `code-before` exception in [../README.md](../README.md), ENC-A-6–ENC-A-50 mark the definition lines (ENC-A-51–ENC-A-55 are a separate supplement); each marker is a new `// [ID]` line above an unchanged governed line. Lines in those blocks that carry no ID remain uncited. The form question (whether to restructure the blocks into prose or tables) is still [Q-A-1](../review/A.md#q-a-1).

## ENC-A-1

| Vector     | Setup                                                                                                                                | Expected                                           |
| ---------- | ------------------------------------------------------------------------------------------------------------------------------------ | -------------------------------------------------- |
| 1.a accept | envelope begins `0x06` followed by one RLP list; payload begins `0x06` followed by one zlib stream                                   | prefix is the stated one                           |
| 1.b accept | every domain tag used in a hash preimage is a V1 tag (for example `ETNA_COMET_DOMAIN_V1`, `ETNA_LAND_CUTS_V1`, `TAIKO_ETNA_LAND_V1`) | consistent with "every versioned domain tag is V1" |
| 1.c accept | the deployment exposes `APP_VERSION` 1 (CometBFT genesis, Info at height 0)                                                          | matches                                            |
| 1.d reject | envelope begins `0x07`                                                                                                               | violates ENC-A-1                                   |
| 1.e reject | payload begins `0x06` but the envelope begins `0x05`                                                                                 | violates ENC-A-1                                   |
| 1.f reject | a hash preimage uses a V2 domain tag                                                                                                 | violates ENC-A-1                                   |
| 1.g reject | the deployment reports `APP_VERSION` 2                                                                                               | violates ENC-A-1                                   |

## ENC-A-2

| Vector     | Setup                                                  | Expected         |
| ---------- | ------------------------------------------------------ | ---------------- |
| 2.a accept | config preimage is exactly seven ABI words (224 bytes) | matches          |
| 2.b reject | config preimage is six words (192 bytes)               | violates ENC-A-2 |
| 2.c reject | config preimage is eight words (256 bytes)             | violates ENC-A-2 |
| 2.d accept | a CommitteeRecord carries exactly five fields          | matches          |
| 2.e reject | a CommitteeRecord carries four fields                  | violates ENC-A-2 |
| 2.f reject | a CommitteeRecord carries six fields                   | violates ENC-A-2 |

_Which seven words, and which five fields: [Q-A-1](../review/A.md#q-a-1)._

## ENC-A-3

| Vector     | Setup                                            | Expected                         |
| ---------- | ------------------------------------------------ | -------------------------------- |
| 3.a accept | the slot-285 record at any height is three words | matches                          |
| 3.b accept | block 0's slot-285 record is three words         | matches (no exemption is stated) |
| 3.c reject | a slot-285 record of two words                   | violates ENC-A-3                 |
| 3.d reject | a slot-285 record of four words                  | violates ENC-A-3                 |

_Which fields occupy the three words: [STOR-B-9](B.md#stor-b-9)._

## ENC-A-4

| Vector     | Setup                                                                       | Expected                                          |
| ---------- | --------------------------------------------------------------------------- | ------------------------------------------------- |
| 4.a accept | a new guest image is registered in the verifier and the config is unchanged | the rules applied at each height are unchanged    |
| 4.b accept | clients are upgraded and the config is unchanged                            | the rules applied at each height are unchanged    |
| 4.c reject | a proof from an image the config does not bind is accepted as settling      | violates ENC-A-4 ("acceptance ... to the config") |
| 4.d reject | registering an image alone changes the rules applied to later blocks        | violates ENC-A-4                                  |
| 4.e reject | changing client software alone changes the rules applied to later blocks    | violates ENC-A-4                                  |

_The sentence's scope is "until the upgrade mechanism is complete" (10.1). What in the config binds acceptance: [Q-A-3](../review/A.md#q-a-3)._

## ENC-A-5

| Vector      | Setup                                                                                                             | Expected                                                                                                                  |
| ----------- | ----------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------- |
| 5.a accept  | `cutHash`, `statement` and `chainDomain` preimages are `abi.encode(...)`                                          | matches                                                                                                                   |
| 5.b accept  | a domain tag is its ASCII bytes followed by zero bytes to 32 (for example `ETNA_LAND_CUTS_V1` plus 15 zero bytes) | matches "right-zero-padded `bytes32` ASCII"                                                                               |
| 5.c accept  | an `entriesRoot` inner node is keccak256(left concatenated with right)                                            | stated exception                                                                                                          |
| 5.d accept  | the blob hash list and the cut leaf list are hashed with `abi.encodePacked`                                       | stated exceptions                                                                                                         |
| 5.e reject  | a protocol hash uses `abi.encodePacked` where the rule requires `abi.encode`                                      | violates ENC-A-5                                                                                                          |
| 5.f reject  | a domain tag is left-padded with zeros                                                                            | violates ENC-A-5 ("right-zero-padded")                                                                                    |
| 5.h reject  | the blob hash list is hashed as keccak256(abi.encode(blobHashes))                                                 | violates ENC-A-5                                                                                                          |
| 5.i reject  | the cut leaf list is hashed with `abi.encode`                                                                     | violates ENC-A-5                                                                                                          |
| 5.j pending | a disputed registry/committee hash preimage encodes its bare-literal domain tag as a dynamic string               | no conformance verdict until [Q-A-2](../review/A.md#q-a-2) is resolved: ENC-A-5 and the bare-literal definitions disagree |

_`abi.encode(left, right)` of two `bytes32` words is byte-identical to `left` followed by `right`, so it is not a separate reject case for the `entriesRoot` exception._

## ENC-A-6

| Vector     | Setup                                                                                                                               | Expected                                     |
| ---------- | ----------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------- |
| 6.a accept | preimage is the `bytes32` V1 tag, `uint256(l1ChainId)`, `uint256(l2ChainId)`, `address(inbox)`, `uint48(generation)`, in that order | 32-byte digest; matches the definition       |
| 6.b reject | tag is `ETNA_COMET_DOMAIN_V2`                                                                                                       | violates ENC-A-6 (tag is V1)                 |
| 6.c reject | `l1ChainId` and `l2ChainId` are swapped                                                                                             | violates ENC-A-6 (argument order)            |
| 6.d reject | the generation argument is omitted                                                                                                  | violates ENC-A-6 (generation is an argument) |
| 6.e reject | the tag is encoded as a dynamic string instead of `bytes32`                                                                         | violates ENC-A-6                             |

## ENC-A-7

| Vector     | Setup                                                                                          | Expected                                                     |
| ---------- | ---------------------------------------------------------------------------------------------- | ------------------------------------------------------------ |
| 7.a accept | 32-byte `chainDomain`; `chain_id` is `"etna-"` followed by `base64url_no_padding(chainDomain)` | 43-character suffix plus 5-character prefix = 48 ASCII bytes |
| 7.b reject | standard base64 is used, so `+` or `/` can appear                                              | violates ENC-A-7 (`base64url`)                               |
| 7.c reject | the encoding carries one or two `=` padding characters                                         | violates ENC-A-7 (`no_padding`)                              |
| 7.d reject | `chain_id` is 47 or 49 ASCII bytes                                                             | violates ENC-A-7 (43 + 5 = 48)                               |
| 7.e reject | `chain_id` is the hex encoding of `chainDomain`                                                | violates ENC-A-7 (base64url, not hex)                        |

## ENC-A-8

| Vector     | Setup                                                                                            | Expected                                     |
| ---------- | ------------------------------------------------------------------------------------------------ | -------------------------------------------- |
| 8.a accept | final base64url character leaves the two unused pad bits zero; no `=`, whitespace or case change | canonical RFC 4648 section 5 encoding        |
| 8.b reject | the final character's unused pad bits are nonzero                                                | violates ENC-A-8 ("canonical zero pad bits") |
| 8.c reject | one or two `=` characters are appended                                                           | violates ENC-A-8 (no "=" padding)            |
| 8.d reject | a space, tab or newline is inserted                                                              | violates ENC-A-8 ("no ... whitespace")       |
| 8.e reject | an uppercase letter is replaced by its lowercase form                                            | violates ENC-A-8 ("case-sensitive")          |
| 8.f reject | `+` or `/` appears                                                                               | violates ENC-A-8 (section 5 alphabet)        |

## ENC-A-9

| Vector     | Setup                                                                       | Expected                                 |
| ---------- | --------------------------------------------------------------------------- | ---------------------------------------- |
| 9.a accept | `inbox` is the `EtnaInbox` proxy address and `generation` is 0 at the start | matches                                  |
| 9.b reject | `inbox` is the implementation address behind the proxy                      | violates ENC-A-9 ("proxy address")       |
| 9.c accept | generations 0, 1, 2 are used in succession                                  | starts at 0 and increases                |
| 9.d reject | generation decreases (2 then 1)                                             | violates ENC-A-9 ("never ... decreases") |
| 9.e reject | generation wraps from `2^48 - 1` to 0                                       | violates ENC-A-9 ("never wraps")         |
| 9.f reject | the first generation is 1                                                   | violates ENC-A-9 ("starts at 0")         |

## ENC-A-10

| Vector      | Setup                                                                               | Expected                         |
| ----------- | ----------------------------------------------------------------------------------- | -------------------------------- |
| 10.a accept | `0x64`, then a 6-byte big-endian generation, then a 6-byte big-endian anchor number | 13 bytes                         |
| 10.b reject | `extraData` is 12 or 14 bytes                                                       | violates ENC-A-10 ("13 bytes")   |
| 10.c reject | the first byte is `0x65`                                                            | violates ENC-A-10 (`0x64`)       |
| 10.d reject | generation is little-endian                                                         | violates ENC-A-10 (`uint48_be`)  |
| 10.e reject | anchor number precedes generation                                                   | violates ENC-A-10 (field order)  |
| 10.f accept | generation 0 and anchor number 0                                                    | `0x64` followed by 12 zero bytes |

## ENC-A-11

| Vector      | Setup                                                                | Expected                                                                               |
| ----------- | -------------------------------------------------------------------- | -------------------------------------------------------------------------------------- |
| 11.a accept | `0x06` followed by one RLP list `[block, anchor, committee, forced]` | matches                                                                                |
| 11.b reject | prefix is `0x07`                                                     | violates ENC-A-11 (`0x06`); proposal invalid (ENC-A-16)                                |
| 11.c reject | `0x06` is followed by a bare RLP byte string                         | violates ENC-A-11 (RLP list); proposal invalid (ENC-A-16)                              |
| 11.d reject | list order is `[block, committee, anchor, forced]`                   | violates ENC-A-11 (named order); proposal invalid (ENC-A-16)                           |
| 11.e reject | two RLP lists follow `0x06`                                          | violates ENC-A-11 (one list); trailing bytes are ENC-A-16; proposal invalid (ENC-A-16) |

## ENC-A-12

| Vector      | Setup                                                                   | Expected                                                               |
| ----------- | ----------------------------------------------------------------------- | ---------------------------------------------------------------------- |
| 12.a accept | `block = [elHeader, [tx, ...]]`; each transaction is an RLP byte string | matches                                                                |
| 12.b accept | a legacy transaction is included as an RLP byte string                  | stated ("legacy included")                                             |
| 12.c reject | a transaction is encoded as an RLP list of its fields                   | violates ENC-A-12 (byte string); proposal invalid (ENC-A-16)           |
| 12.d reject | a typed transaction has its EIP-2718 type byte stripped                 | violates ENC-A-12 (its EIP-2718 encoding); proposal invalid (ENC-A-16) |
| 12.e reject | `block` has three items, or its second item is not a list               | violates ENC-A-12; proposal invalid (ENC-A-16)                         |

## ENC-A-13

| Vector      | Setup                                                                                               | Expected                                                                   |
| ----------- | --------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------- |
| 13.a accept | `anchor = []`                                                                                       | empty is allowed                                                           |
| 13.b accept | `anchor = [[rawL1Header, inboxWitness]]`; `rawL1Header` is a byte string of the L1 header's raw RLP | matches                                                                    |
| 13.c reject | `anchor = [rawL1Header, inboxWitness]` (one nesting level missing)                                  | violates ENC-A-13 (one item holding the pair); proposal invalid (ENC-A-16) |
| 13.d reject | `anchor` holds two entries                                                                          | violates ENC-A-13 (empty or one item); proposal invalid (ENC-A-16)         |
| 13.e reject | `rawL1Header` is a structured list rather than a byte string                                        | violates ENC-A-13; proposal invalid (ENC-A-16)                             |
| 13.f reject | `rawL1Header` is re-encoded rather than the L1 header's raw RLP                                     | violates ENC-A-13 ("raw RLP"); proposal invalid (ENC-A-16)                 |

## ENC-A-14

| Vector      | Setup                                                          | Expected                                                        |
| ----------- | -------------------------------------------------------------- | --------------------------------------------------------------- |
| 14.a accept | `committee = []`                                               | empty is allowed                                                |
| 14.b accept | `[[record, registryWitness, [entry, ...]]]`                    | matches                                                         |
| 14.c reject | `[record, registryWitness, [entry, ...]]` (outer list missing) | violates ENC-A-14; proposal invalid (ENC-A-16)                  |
| 14.d reject | two committee entries                                          | violates ENC-A-14 (empty or one); proposal invalid (ENC-A-16)   |
| 14.e reject | order is `[registryWitness, record, [entry, ...]]`             | violates ENC-A-14 (order); proposal invalid (ENC-A-16)          |
| 14.f reject | the third item is one entry rather than a list of entries      | violates ENC-A-14 (`[entry, ...]`); proposal invalid (ENC-A-16) |

## ENC-A-15

| Vector      | Setup                                                                                                                             | Expected                                                                            |
| ----------- | --------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------- |
| 15.a accept | `forced = []`                                                                                                                     | empty is allowed                                                                    |
| 15.b accept | `[[index, entryWitness, tx]]` with `tx` empty                                                                                     | "tx may be empty"                                                                   |
| 15.c accept | `tx` nonempty and its hash equals the entry's hash                                                                                | matches                                                                             |
| 15.d reject | `tx` nonempty and its hash differs from the entry's hash                                                                          | violates ENC-A-15 ("its hash must match"); proposal invalid (ENC-A-16)              |
| 15.e reject | a skip of an entry whose submission was nonempty carries an empty `tx`                                                            | violates ENC-A-15 ("required for skips") and FI-7.2-11; proposal invalid (ENC-A-16) |
| 15.h accept | a skip of an entry whose `txHash` is `keccak256("")` (an empty submission, or an entry blanked by recovery) carries an empty `tx` | conforms: the empty string is that entry's raw bytes (FI-7.2-11, FI-7.2-13)         |
| 15.f reject | two forced entries                                                                                                                | violates ENC-A-15 (empty or one); proposal invalid (ENC-A-16)                       |
| 15.g reject | order is `[index, tx, entryWitness]`                                                                                              | violates ENC-A-15 (order); proposal invalid (ENC-A-16)                              |

## ENC-A-16

| Vector      | Setup                                                                    | Expected                                     |
| ----------- | ------------------------------------------------------------------------ | -------------------------------------------- |
| 16.a accept | the envelope ends immediately after the one RLP list that follows `0x06` | matches                                      |
| 16.b reject | one or more bytes follow the RLP list                                    | violates ENC-A-16; proposal invalid (stated) |
| 16.c reject | a second envelope is concatenated after the first                        | violates ENC-A-16; proposal invalid (stated) |
| 16.d reject | `0x06` is followed by zero or two RLP lists                              | violates ENC-A-16; proposal invalid (stated) |

## ENC-A-17

| Vector      | Setup                                                                                                                 | Expected                                                               |
| ----------- | --------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------- |
| 17.a accept | every list has exactly the named items; anchor, committee and forced are empty or hold one item; integers are minimal | matches                                                                |
| 17.b reject | `block` carries three items                                                                                           | violates ENC-A-17; proposal invalid (ENC-A-16)                         |
| 17.c reject | `anchor` carries two items                                                                                            | violates ENC-A-17; proposal invalid (ENC-A-16)                         |
| 17.d reject | integer 5 is encoded as the two-byte string `0x00 0x05`                                                               | violates ENC-A-17 (leading zero); proposal invalid (ENC-A-16)          |
| 17.e reject | integer 0 is encoded as `0x00`                                                                                        | violates ENC-A-17 (0 is the empty string); proposal invalid (ENC-A-16) |
| 17.f accept | integer 0 is encoded as the empty string (`0x80`)                                                                     | matches                                                                |
| 17.g reject | a list carries an item beyond the named items                                                                         | violates ENC-A-17; proposal invalid (ENC-A-16)                         |

## ENC-A-18

| Vector      | Setup                                                                  | Expected                                       |
| ----------- | ---------------------------------------------------------------------- | ---------------------------------------------- |
| 18.a accept | hashes and stateRoots are 32 bytes, slots 32 bytes, addresses 20 bytes | matches                                        |
| 18.b reject | a hash or stateRoot is 31 or 33 bytes                                  | violates ENC-A-18; proposal invalid (ENC-A-16) |
| 18.c reject | an address is 19 or 21 bytes                                           | violates ENC-A-18; proposal invalid (ENC-A-16) |
| 18.d reject | a slot key is 33 bytes                                                 | violates ENC-A-18; proposal invalid (ENC-A-16) |
| 18.e reject | an unknown field or an extra item is appended                          | violates ENC-A-18; proposal invalid (ENC-A-16) |

## ENC-A-19

| Vector      | Setup                                                                                                                                                        | Expected                                                                  |
| ----------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------- |
| 19.a accept | hashes, stateRoots and slots are 32-byte strings; addresses 20-byte strings; `ckX` is 32 bytes with leading zeros; `ckPrefix` and other numbers are integers | matches                                                                   |
| 19.b reject | `RegistryEntry.ckX` is 31 bytes because a leading zero was stripped                                                                                          | violates ENC-A-19 ("leading zeros kept"); proposal invalid (ENC-A-16)     |
| 19.c reject | `ckPrefix` is encoded as a 32-byte string                                                                                                                    | violates ENC-A-19 (integer); proposal invalid (ENC-A-16)                  |
| 19.d reject | a slot key is encoded as an integer with leading zeros stripped                                                                                              | violates ENC-A-19 (slot is a 32-byte string); proposal invalid (ENC-A-16) |
| 19.e accept | `ckX` is 32 bytes beginning with one or more zero bytes                                                                                                      | leading zeros are kept                                                    |

## ENC-A-20

| Vector      | Setup                                                                                     | Expected                                                            |
| ----------- | ----------------------------------------------------------------------------------------- | ------------------------------------------------------------------- |
| 20.a accept | storage value 0 is the empty string; nonzero values are minimal; RLP prefixes are minimal | matches                                                             |
| 20.b reject | storage value 5 is encoded as `0x00 0x05`                                                 | violates ENC-A-20 (leading zero); proposal invalid (ENC-A-16)       |
| 20.c reject | a 2-byte string uses the long form `0xb8 0x02 ...`                                        | violates ENC-A-20 (prefix not minimal); proposal invalid (ENC-A-16) |
| 20.d reject | the single byte `0x05` is encoded as `0x81 0x05`                                          | violates ENC-A-20 (prefix not minimal); proposal invalid (ENC-A-16) |
| 20.e reject | a released slot's entry has a nonzero field                                               | violates ENC-A-20; proposal invalid (ENC-A-16)                      |
| 20.f accept | a released slot's entry has all-zero fields                                               | matches                                                             |
| 20.g accept | a slot whose value is a hash uses minimal integer encoding, stripping leading zero bytes  | stated ("including slots that hold hashes")                         |

## ENC-A-21

| Vector      | Setup                                                                                                               | Expected                                                                      |
| ----------- | ------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------- |
| 21.a accept | anchor witness address is the Inbox; forced witness address is the Inbox; committee witness address is the registry | matches                                                                       |
| 21.b reject | anchor witness address is the registry                                                                              | violates ENC-A-21; proposal invalid (ENC-A-16)                                |
| 21.c reject | committee witness address is the Inbox                                                                              | violates ENC-A-21; proposal invalid (ENC-A-16)                                |
| 21.d reject | forced witness address is an unrelated contract                                                                     | violates ENC-A-21; proposal invalid (ENC-A-16)                                |
| 21.e reject | anchor and committee witnesses share the same address                                                               | violates ENC-A-21 (different expected contracts); proposal invalid (ENC-A-16) |

## ENC-A-22

| Vector      | Setup                                                                                         | Expected                                       |
| ----------- | --------------------------------------------------------------------------------------------- | ---------------------------------------------- |
| 22.a accept | committee-witness account and storage proofs are verified under this block's anchor stateRoot | matches                                        |
| 22.b accept | the anchor was inherited rather than newly included; its stateRoot is still used              | "new or inherited"                             |
| 22.c reject | the committee witness is verified under the parent L2 block's stateRoot                       | violates ENC-A-22; proposal invalid (ENC-A-16) |
| 22.d reject | the committee witness is verified under another block's anchor stateRoot                      | violates ENC-A-22; proposal invalid (ENC-A-16) |

## ENC-A-23

| Vector      | Setup                                                                                                               | Expected                   |
| ----------- | ------------------------------------------------------------------------------------------------------------------- | -------------------------- |
| 23.a accept | `0x06`, then a zlib stream whose decompressed bytes are one RLP list of `rlp([elHeader, [tx, ...]])` items          | matches                    |
| 23.b reject | prefix is `0x07`                                                                                                    | violates ENC-A-23 (`0x06`) |
| 23.c reject | the bytes after `0x06` are raw RLP, not a zlib stream                                                               | violates ENC-A-23          |
| 23.d reject | the zlib stream decompresses to something that is not an RLP list                                                   | violates ENC-A-23          |
| 23.e reject | a block item in the decompressed list is a nested list rather than the RLP byte string `rlp([elHeader, [tx, ...]])` | violates ENC-A-23          |

## ENC-A-24

| Vector      | Setup                                                                                                              | Expected                                   |
| ----------- | ------------------------------------------------------------------------------------------------------------------ | ------------------------------------------ |
| 24.a accept | seven items in order: address, nonce, balance, storageRoot, codeHash, accountProof, list of `[slot, value, proof]` | matches                                    |
| 24.b reject | six or eight items                                                                                                 | violates ENC-A-24                          |
| 24.c reject | nonce precedes address                                                                                             | violates ENC-A-24 (order)                  |
| 24.d reject | a storage entry has two or four items                                                                              | violates ENC-A-24 (`[slot, value, proof]`) |
| 24.e reject | the seventh item is one `[slot, value, proof]` rather than a list of them                                          | violates ENC-A-24                          |

## ENC-A-25

| Vector      | Setup                                                                               | Expected                                                                            |
| ----------- | ----------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------- |
| 25.a accept | anchor witness proves slots `[268, 270, 271, 281]` in that order                    | matches                                                                             |
| 25.b reject | anchor slots are `[268, 271, 270, 281]`                                             | violates ENC-A-25 ("exactly in order"); consequence — [Q-A-4](../review/A.md#q-a-4) |
| 25.c reject | the anchor witness omits 281 or adds 269                                            | violates ENC-A-25 ("exactly")                                                       |
| 25.d accept | forced entry `i` proves `base` and `base+1`, `base = keccak256(abi.encode(i, 280))` | matches                                                                             |
| 25.e reject | `base` is computed as `keccak256(abi.encode(i, 281))` or with another index         | violates ENC-A-25                                                                   |
| 25.f reject | forced slots are `[base+1, base]`                                                   | violates ENC-A-25 (order); consequence — [Q-A-4](../review/A.md#q-a-4)              |

## ENC-A-26

| Vector      | Setup                                                                                                      | Expected                           |
| ----------- | ---------------------------------------------------------------------------------------------------------- | ---------------------------------- |
| 26.a accept | `i + 1 < length`: slots `[R, cp(i), cp(i) + 1, cp(i + 1)]` in that order, with `cp(i) = keccak256(R) + 2i` | matches                            |
| 26.b accept | `i + 1 == length`: slots `[R, cp(i), cp(i) + 1]` only                                                      | "plus cp(i + 1) if i + 1 < length" |
| 26.c reject | `cp(i) = keccak256(R) + i` (stride 1)                                                                      | violates ENC-A-26 (stride 2i)      |
| 26.d reject | `cp(i) + 1` is omitted                                                                                     | violates ENC-A-26                  |
| 26.e reject | `cp(i + 1)` is included when `i + 1 >= length`                                                             | violates ENC-A-26                  |
| 26.f reject | order is `[R, cp(i) + 1, cp(i), cp(i + 1)]`                                                                | violates ENC-A-26 (listed order)   |

## ENC-A-26a

| Vector       | Setup                                                                                                  | Expected                                           |
| ------------ | ------------------------------------------------------------------------------------------------------ | -------------------------------------------------- |
| 26a.a accept | `accountProof` and each storage proof are exactly the ordered MPT path from the root to the leaf       | matches                                            |
| 26a.b accept | a storage proof ends at the node that proves the slot is absent                                        | matches ("or to the node proving absence")         |
| 26a.c reject | a proof carries an extra node beyond that path                                                         | violates ENC-A-26a ("no extra nodes")              |
| 26a.d reject | a proven value is written with leading zero bytes, or 0 is not the empty string                        | violates ENC-A-26a ("minimal big-endian encoding") |
| 26a.e reject | the value differs from the proven value, or an account field differs from the account RLP in the proof | violates ENC-A-26a                                 |

## ENC-A-27

| Vector      | Setup                                                                                          | Expected                  |
| ----------- | ---------------------------------------------------------------------------------------------- | ------------------------- |
| 27.a accept | exactly five fields in order: targetEpoch, cutoffL1Block, checkpointIndex, setRoot, totalPower | matches                   |
| 27.b reject | four or six fields                                                                             | violates ENC-A-27         |
| 27.c reject | checkpointIndex precedes cutoffL1Block                                                         | violates ENC-A-27 (order) |
| 27.d reject | setRoot is omitted                                                                             | violates ENC-A-27         |

## ENC-A-28

| Vector      | Setup                                                                                | Expected                  |
| ----------- | ------------------------------------------------------------------------------------ | ------------------------- |
| 28.a accept | exactly five fields in order: ckPrefix, ckX, effStake, activeFromL1, exitEffectiveL1 | matches                   |
| 28.b reject | four or six fields                                                                   | violates ENC-A-28         |
| 28.c reject | ckX precedes ckPrefix                                                                | violates ENC-A-28 (order) |
| 28.d reject | exitEffectiveL1 is omitted                                                           | violates ENC-A-28         |
| 28.e accept | ckX is 32 bytes with leading zeros kept                                              | also required by ENC-A-19 |

## ENC-A-29

| Vector      | Setup                                                                                      | Expected                                             |
| ----------- | ------------------------------------------------------------------------------------------ | ---------------------------------------------------- |
| 29.a accept | `keccak256(abi.encode(uint256(x), blockHash(x), cometHash(x), forcedHead(x)))`, four words | matches                                              |
| 29.b reject | three or five words                                                                        | violates ENC-A-29                                    |
| 29.c reject | order is `(blockHash(x), uint256(x), ...)`                                                 | violates ENC-A-29                                    |
| 29.d reject | blockHash, cometHash or forcedHead is taken at a height other than `x`                     | violates ENC-A-29 (all at height x)                  |
| 29.e reject | `x` or `forcedHead(x)` is encoded in fewer than 32 bytes (for example packed as uint48)    | violates ENC-A-29 (`uint256(x)`, four 32-byte words) |

## ENC-A-30

| Vector      | Setup                                                                                                                                                             | Expected                           |
| ----------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------- |
| 30.a accept | preimage is `bytes32("ETNA_LAND_CUTS_V1")`, `uint256(generation)`, `uint256(p)`, `uint256(h)`, then `keccak256(abi.encodePacked(cut leaves))`: five 32-byte words | matches                            |
| 30.b reject | the tag is `ETNA_LAND_CUTS_V2`                                                                                                                                    | violates ENC-A-30                  |
| 30.c reject | generation, `p` or `h` is omitted or reordered                                                                                                                    | violates ENC-A-30                  |
| 30.d reject | the leaf list is hashed with `abi.encode` rather than `abi.encodePacked`                                                                                          | violates ENC-A-30                  |
| 30.e reject | generation, `p` or `h` is encoded in fewer than 32 bytes (for example packed as uint48)                                                                           | violates ENC-A-30 (`uint256(...)`) |
| 30.f reject | the fifth word is the packed cut-leaf list itself, not its `keccak256`                                                                                            | violates ENC-A-30                  |

## ENC-A-31

| Vector      | Setup                                                                                              | Expected                               |
| ----------- | -------------------------------------------------------------------------------------------------- | -------------------------------------- |
| 31.a accept | list length `(h-p)/K - 1`; leaves are cutLeaf(p+K) through cutLeaf(h-K) in increasing height order | matches                                |
| 31.b reject | the list includes cutLeaf(p) or cutLeaf(h)                                                         | violates ENC-A-31 ("strictly between") |
| 31.c reject | list length is off by one                                                                          | violates ENC-A-31                      |
| 31.d reject | leaves are out of height order                                                                     | violates ENC-A-31                      |
| 31.e accept | `h = p + 2K`: exactly one leaf, cutLeaf(p + K)                                                     | matches the formula                    |
| 31.f reject | leaves are spaced by K + 1                                                                         | violates ENC-A-31 (grid points)        |

## ENC-A-32

| Vector      | Setup                                                              | Expected          |
| ----------- | ------------------------------------------------------------------ | ----------------- |
| 32.a accept | `h = p + K`: the inner list is empty and hashed as `keccak256("")` | matches           |
| 32.b reject | `h = p + K` and the list holds one leaf                            | violates ENC-A-32 |
| 32.c reject | `h = p + K` and the empty list is hashed as `keccak256(0xc0)`      | violates ENC-A-32 |
| 32.d reject | `h = p + K` and the empty list is hashed as a zero `bytes32`       | violates ENC-A-32 |

## ENC-A-33

| Vector      | Setup                                                               | Expected                             |
| ----------- | ------------------------------------------------------------------- | ------------------------------------ |
| 33.a accept | `p % K == 0`, `h % K == 0`, `leaves.length == (h-p)/K - 1`, `c < h` | checks pass                          |
| 33.b reject | `K = 3`, `p = 1`                                                    | violates ENC-A-33 (`p % K == 0`)     |
| 33.c reject | `K = 3`, `h = 10`                                                   | violates ENC-A-33 (`h % K == 0`)     |
| 33.d reject | `leaves.length = (h-p)/K` (one too many)                            | violates ENC-A-33                    |
| 33.e reject | `c >= h`                                                            | rejected as already settled (stated) |

## ENC-A-34

| Vector      | Setup                                                                                | Expected                       |
| ----------- | ------------------------------------------------------------------------------------ | ------------------------------ |
| 34.a accept | `c > p`: `leaves[(c-p)/K - 1]` equals `cutLeaf(c)` computed from c's slot 285 record | matches                        |
| 34.b reject | `c > p` and the leaf equals `cutLeaf(c')` for another height `c'`                    | violates ENC-A-34              |
| 34.c reject | `c > p` and the leaf is computed from a record other than c's slot 285               | violates ENC-A-34              |
| 34.d accept | `c == p`: the overlap check does not apply                                           | the text conditions on `c > p` |
| 34.e reject | `c > p` and the indexed leaf is not the required one                                 | violates ENC-A-34              |

## ENC-A-35

| Vector      | Setup                                                                                  | Expected                                |
| ----------- | -------------------------------------------------------------------------------------- | --------------------------------------- |
| 35.a accept | `keccak256(abi.encode(...))` with the 21 static ABI words of the definition, 672 bytes | matches                                 |
| 35.b reject | the preimage has 20 or 22 words                                                        | violates ENC-A-35 (21 words, 672 bytes) |
| 35.c reject | `TAIKO_ETNA_LAND_V1` is replaced by a V2 tag                                           | violates ENC-A-35 (and ENC-A-1)         |
| 35.d reject | `blobHashes` are hashed with `abi.encode` instead of `abi.encodePacked`                | violates ENC-A-35                       |
| 35.e reject | `l2ChainId` precedes `l1ChainId`                                                       | violates ENC-A-35 (field order)         |

## ENC-A-36

| Vector      | Setup                                                                                                                        | Expected                    |
| ----------- | ---------------------------------------------------------------------------------------------------------------------------- | --------------------------- |
| 36.a accept | `keccak256(abi.encode(bytes32("ETNA_PARENT_ANCHOR_V1"), l2ChainId, registry, vp_unit, s_min, n_max, U))`; 7 words, 224 bytes | matches                     |
| 36.b reject | tag is `ETNA_PARENT_ANCHOR_V2`                                                                                               | violates ENC-A-36           |
| 36.c reject | six or eight fields                                                                                                          | violates ENC-A-36           |
| 36.d reject | `registry` precedes `l2ChainId`                                                                                              | violates ENC-A-36 (order)   |
| 36.e reject | 224 bytes plus a trailing word                                                                                               | violates ENC-A-36 (7 words) |

## ENC-A-37

| Vector       | Setup                                                                                                   | Expected                                                                                                                             |
| ------------ | ------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------ |
| 37.a pending | `keccak256(abi.encode("ETNA_REG_ENTRY_V1", j, ckPrefix, ckX, effStake, activeFromL1, exitEffectiveL1))` | no conformance verdict; whether the bare tag is a padded `bytes32` word or a dynamic string is pending [Q-A-2](../review/A.md#q-a-2) |
| 37.b reject  | tag is `ETNA_REG_ENTRY_V2`                                                                              | violates ENC-A-37                                                                                                                    |
| 37.c reject  | `j` or `exitEffectiveL1` is omitted                                                                     | violates ENC-A-37                                                                                                                    |
| 37.d reject  | `ckX` precedes `ckPrefix`                                                                               | violates ENC-A-37 (order)                                                                                                            |

## ENC-A-38

| Vector      | Setup                                                                                       | Expected                            |
| ----------- | ------------------------------------------------------------------------------------------- | ----------------------------------- |
| 38.a accept | leaves zero-padded to a power of two; inner nodes `keccak256(left concatenated with right)` | matches                             |
| 38.b reject | padding to a count that is not a power of two                                               | violates ENC-A-38                   |
| 38.d accept | one entry: the root is that leaf                                                            | stated ("one entry gives its leaf") |
| 38.e accept | no entries: the root is 0                                                                   | stated ("none gives 0")             |
| 38.f reject | no entries but the root is `keccak256("")`                                                  | violates ENC-A-38                   |
| 38.g reject | zero padding uses a nonzero value                                                           | violates ENC-A-38                   |

_`abi.encode(left, right)` of two `bytes32` words equals their plain concatenation, so it is not a separate reject case._

## ENC-A-39

| Vector       | Setup                                                                | Expected                                                                                                                             |
| ------------ | -------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------ |
| 39.a pending | `keccak256(abi.encode("ETNA_SET_KEY_V1", l2ChainId, ckPrefix, ckX))` | no conformance verdict; whether the bare tag is a padded `bytes32` word or a dynamic string is pending [Q-A-2](../review/A.md#q-a-2) |
| 39.b reject  | tag is `ETNA_SET_KEY_V2`                                             | violates ENC-A-39                                                                                                                    |
| 39.c reject  | `l2ChainId` or `ckX` is omitted                                      | violates ENC-A-39                                                                                                                    |
| 39.d reject  | `ckX` precedes `ckPrefix`                                            | violates ENC-A-39 (order)                                                                                                            |

## ENC-A-40

| Vector       | Setup                                                                                                | Expected                                                                                                                             |
| ------------ | ---------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------ |
| 40.a pending | `keccak256(abi.encode("ETNA_SET_LEAF_V1", l2ChainId, k, i, ckPrefix, ckX, effStake, assignedPower))` | no conformance verdict; whether the bare tag is a padded `bytes32` word or a dynamic string is pending [Q-A-2](../review/A.md#q-a-2) |
| 40.b reject  | `k`, `i` or `assignedPower` is omitted                                                               | violates ENC-A-40                                                                                                                    |
| 40.c reject  | `i` precedes `k`                                                                                     | violates ENC-A-40 (order)                                                                                                            |
| 40.d reject  | tag is `ETNA_SET_LEAF_V2`                                                                            | violates ENC-A-40                                                                                                                    |

## ENC-A-41

| Vector       | Setup                                                                | Expected                                                                                                                             |
| ------------ | -------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------ |
| 41.a pending | `keccak256(abi.encode("ETNA_SET_NODE", l2ChainId, k, left, right))`  | no conformance verdict; whether the bare tag is a padded `bytes32` word or a dynamic string is pending [Q-A-2](../review/A.md#q-a-2) |
| 41.b accept  | an odd last node is promoted unchanged (no hash with a zero sibling) | stated                                                                                                                               |
| 41.c reject  | an odd last node is hashed with a zero right child                   | violates ENC-A-41                                                                                                                    |
| 41.d reject  | `left` and `right` are swapped                                       | violates ENC-A-41 (order)                                                                                                            |
| 41.e reject  | `k` is omitted                                                       | violates ENC-A-41                                                                                                                    |
| 41.f reject  | the tag is written `ETNA_SET_NODE_V1`                                | violates ENC-A-41 (tag as written); versioning question — [Q-A-2](../review/A.md#q-a-2)                                              |

## ENC-A-42

| Vector       | Setup                                                                                                                     | Expected                                                                                                                             |
| ------------ | ------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------ |
| 42.a pending | `keccak256(abi.encode("ETNA_COMMITTEE_V1", l2ChainId, targetEpoch, cutoffL1Block, checkpointIndex, setRoot, totalPower))` | no conformance verdict; whether the bare tag is a padded `bytes32` word or a dynamic string is pending [Q-A-2](../review/A.md#q-a-2) |
| 42.b reject  | tag is `ETNA_COMMITTEE_V2`                                                                                                | violates ENC-A-42                                                                                                                    |
| 42.c reject  | `checkpointIndex` or `totalPower` is omitted                                                                              | violates ENC-A-42                                                                                                                    |
| 42.d reject  | `cutoffL1Block` precedes `targetEpoch`                                                                                    | violates ENC-A-42 (order)                                                                                                            |

## ENC-A-42a

| Vector       | Setup                                                                           | Expected           |
| ------------ | ------------------------------------------------------------------------------- | ------------------ |
| 42a.a accept | the committee for `targetEpoch = t` uses `k = t + 1` in `setLeaf` and `setNode` | matches            |
| 42a.b reject | `k = targetEpoch`                                                               | violates ENC-A-42a |

## ENC-A-43

| Vector      | Setup                                                             | Expected                       |
| ----------- | ----------------------------------------------------------------- | ------------------------------ |
| 43.a accept | `uvarint(len(cv))` followed by `cv`                               | matches CometBFT VoteSignBytes |
| 43.b reject | the length prefix is omitted                                      | violates ENC-A-43              |
| 43.c reject | the length prefix is a fixed 8-byte integer rather than a uvarint | violates ENC-A-43              |
| 43.d reject | the length prefix does not equal `len(cv)`                        | violates ENC-A-43              |

## ENC-A-44

| Vector      | Setup                                                             | Expected                         |
| ----------- | ----------------------------------------------------------------- | -------------------------------- |
| 44.a accept | fields in order: type, height, round, blockId, timestamp, chainId | matches                          |
| 44.b reject | height is big-endian rather than 8-byte little-endian             | violates ENC-A-44 (height field) |
| 44.c reject | the chainId field is omitted                                      | violates ENC-A-44                |
| 44.d reject | blockId precedes round                                            | violates ENC-A-44 (order)        |
| 44.e reject | type is 3 (not prevote 1 or precommit 2)                          | violates ENC-A-44 (type values)  |

## ENC-A-45

| Vector      | Setup                                                                          | Expected          |
| ----------- | ------------------------------------------------------------------------------ | ----------------- |
| 45.a accept | fields shown in `[]` are omitted when zero or empty; `len` is a uvarint prefix | matches           |
| 45.b reject | a zero field is written explicitly instead of omitted                          | violates ENC-A-45 |
| 45.c reject | an empty blockId is written with length 0 instead of omitted                   | violates ENC-A-45 |
| 45.d accept | timestamp is written even when zero                                            | "always written"  |
| 45.e reject | timestamp is omitted when zero                                                 | violates ENC-A-45 |
| 45.f reject | a length prefix is not a uvarint                                               | violates ENC-A-45 |

## ENC-A-46

| Vector      | Setup                                                                                                          | Expected                    |
| ----------- | -------------------------------------------------------------------------------------------------------------- | --------------------------- |
| 46.a accept | `ecrecover(keccak256(voteSignBytes), V + 27, R, S)`; signature is 65 bytes `R, S, V`; `V` in {0,1}; `S <= n/2` | matches                     |
| 46.b reject | `V = 2`                                                                                                        | violates ENC-A-46           |
| 46.c reject | `S > n/2` (high-s)                                                                                             | violates ENC-A-46           |
| 46.d reject | the signature is 64 bytes (no V byte)                                                                          | violates ENC-A-46 (65-byte) |
| 46.e reject | `ecrecover` is called with `V` instead of `V + 27`                                                             | violates ENC-A-46           |

## ENC-A-47

| Vector      | Setup                                                                  | Expected                         |
| ----------- | ---------------------------------------------------------------------- | -------------------------------- |
| 47.a accept | exactly 33 raw bytes: `ckPrefix` (0x02 or 0x03) then `uint256_be(ckX)` | matches                          |
| 47.b reject | 32 or 34 bytes                                                         | violates ENC-A-47                |
| 47.c reject | prefix is 0x04 (uncompressed)                                          | violates ENC-A-47 (0x02/0x03)    |
| 47.d reject | `ckX` is little-endian                                                 | violates ENC-A-47 (`uint256_be`) |
| 47.e reject | 33 bytes with prefix 0x00                                              | violates ENC-A-47                |

## ENC-A-48

| Vector      | Setup                                                                                                 | Expected                                                |
| ----------- | ----------------------------------------------------------------------------------------------------- | ------------------------------------------------------- |
| 48.a accept | internal decoding of a canonical public key                                                           | matches                                                 |
| 48.b reject | a noncanonical public key (for example, one whose `ckX` is not a canonical field element) is accepted | violates ENC-A-48 (noncanonical input must be rejected) |
| 48.c reject | `ckX` is reduced modulo `p` and accepted                                                              | violates ENC-A-48 ("rather than reducing coordinates")  |
| 48.d reject | noncanonical input is truncated and accepted                                                          | violates ENC-A-48                                       |

## ENC-A-49

| Vector      | Setup                                                               | Expected                         |
| ----------- | ------------------------------------------------------------------- | -------------------------------- |
| 49.a accept | `keccak256(uint256_be(ckX) concatenated with uint256_be(ckY))[12:]` | 20-byte address                  |
| 49.b reject | only `ckX` is hashed                                                | violates ENC-A-49                |
| 49.c reject | `ckY` is little-endian                                              | violates ENC-A-49 (`uint256_be`) |
| 49.d reject | bytes `[0:20]` are used instead of `[12:]`                          | violates ENC-A-49                |
| 49.e reject | `ckX` and `ckY` are concatenated in reverse order                   | violates ENC-A-49 (order)        |

## ENC-A-49a

| Vector       | Setup                                                                                                                                                                                                                                                   | Expected           |
| ------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------ |
| 49a.a accept | `registerDigest = keccak256(0x1901 ‖ domainSeparator ‖ keccak256(abi.encode(keccak256("Register(address owner)"), owner)))`; the EIP-712 domain is name "EtnaStakingRegistry", version "1", chainId = the L1 chain id, verifyingContract = the registry | matches            |
| 49a.b reject | the domain uses the L2 chain id                                                                                                                                                                                                                         | violates ENC-A-49a |
| 49a.c reject | `verifyingContract` is the Inbox                                                                                                                                                                                                                        | violates ENC-A-49a |
| 49a.d reject | the struct hash omits `owner` or uses another type string                                                                                                                                                                                               | violates ENC-A-49a |

## ENC-A-50

| Vector      | Setup                                                                 | Expected          |
| ----------- | --------------------------------------------------------------------- | ----------------- |
| 50.a accept | exactly 65 bytes `R, S, V`; `V` in {0,1}, `0 < R < n`, `0 < S <= n/2` | matches           |
| 50.b reject | 64 or 66 bytes                                                        | violates ENC-A-50 |
| 50.c reject | `R = 0`                                                               | violates ENC-A-50 |
| 50.d reject | `S = 0` or `S > n/2`                                                  | violates ENC-A-50 |
| 50.e reject | `V = 2`                                                               | violates ENC-A-50 |

## ENC-A-51

| Vector      | Setup                         | Expected                                    |
| ----------- | ----------------------------- | ------------------------------------------- |
| 51.a accept | exclusions `[bondId 1, 5, 9]` | strictly increasing; conforms               |
| 51.b reject | exclusions `[1, 9, 5]`        | violates ENC-A-51 (not sorted)              |
| 51.c reject | exclusions `[1, 5, 5]`        | violates ENC-A-51 (not strictly increasing) |

## ENC-A-52

| Vector      | Setup                                                                                                       | Expected                             |
| ----------- | ----------------------------------------------------------------------------------------------------------- | ------------------------------------ |
| 52.a accept | `invalidateRecoveryNonce` called by the Inbox owner                                                         | conforms                             |
| 52.b reject | `invalidateRecoveryNonce` called by the registry owner or the DAO, when that address is not the Inbox owner | violates ENC-A-52 (Inbox owner only) |

## ENC-A-53

| Vector      | Setup                                                                         | Expected          |
| ----------- | ----------------------------------------------------------------------------- | ----------------- |
| 53.a accept | `recoveryNonce` is a `uint256`; `validUntil` is a `uint256` L1 Unix timestamp | conforms          |
| 53.b reject | `validUntil` is compared against L2 block time rather than L1 Unix seconds    | violates ENC-A-53 |

## ENC-A-54

| Vector      | Setup                                                                                 | Expected          |
| ----------- | ------------------------------------------------------------------------------------- | ----------------- |
| 54.a accept | `forfeit(bondId, entryKey, incidentId, validUntil)` with exactly those four arguments | conforms          |
| 54.b reject | a call that omits `incidentId` or supplies a different argument list                  | violates ENC-A-54 |

## ENC-A-55

| Vector      | Setup                                                                                        | Expected                                                                                                                       |
| ----------- | -------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------ |
| 55.a accept | the registry owner forfeits a `bondId`/`entryKey` once, then never again for that `entryKey` | conforms                                                                                                                       |
| 55.b reject | the DAO's execution address calls `forfeit` while the registry owner is a different address  | violates ENC-A-55 (registry-owner-only); FORF-4.4-1 names one caller, "the registry owner, the DAO's actual execution address" |
| 55.c reject | a second `forfeit` for the same lifetime `entryKey`                                          | violates ENC-A-55 (once per lifetime entryKey)                                                                                 |
| 55.d reject | any call that attempts to revoke or reset a forfeiture via a nonce                           | violates ENC-A-55 (no forfeiture nonce or revocation)                                                                          |

## Not covered

Everything below is a question, not a vector. Each has an entry in [review/A.md](../review/A.md).

| Rule                        | Gap                                                                                                                                  | Question                      |
| --------------------------- | ------------------------------------------------------------------------------------------------------------------------------------ | ----------------------------- |
| ENC-A-6 to ENC-A-55         | whether the now-citable blocks should still be restructured into prose or tables                                                     | [Q-A-1](../review/A.md#q-a-1) |
| ENC-A-37, ENC-A-39–ENC-A-42 | whether a bare tag literal is a padded `bytes32` word or a dynamic string, and whether `ETNA_SET_NODE` is deliberately unversioned   | [Q-A-2](../review/A.md#q-a-2) |
| ENC-A-4                     | what in the seven-word config binds guest-image and verifier acceptance                                                              | [Q-A-3](../review/A.md#q-a-3) |
| ENC-A-24, ENC-A-25          | whether an out-of-order, extra or missing witness slot list makes a witness invalid; the order is now stated, the consequence is not | [Q-A-4](../review/A.md#q-a-4) |
| Shared vectors              | the obligation itself is un-numbered and has no owner                                                                                | [Q-A-5](../review/A.md#q-a-5) |
