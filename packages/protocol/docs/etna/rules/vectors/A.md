# A — accept/reject vectors

**Non-normative.** Rule text lives in [SPEC.md](../../SPEC.md). This file states only what the text states: each vector either follows directly from a numbered statement, or reports that a requirement was violated. Where the text states a requirement but **not the consequence of violating it**, the vector says "violates ENC-A-N" and does not name an outcome. Anything undetermined has no vector; it is listed under "Not covered" and raised in [review/A.md](../review/A.md).

`accept` means the described encoding satisfies the rule cited. `reject` means a stated requirement is violated. Appendix A states one consequence: ENC-A-16's "any violation makes the proposal invalid". It covers the envelope grammar (ENC-A-11–ENC-A-15) and the strict-decoding conditions (ENC-A-16–ENC-A-22), so those reject rows say "proposal invalid (ENC-A-16)". Rows elsewhere say "violates ENC-A-N" where the text states no consequence. Where a definition spans several lines, the marker and the ID sit above its first line, and the ID cites the whole definition (see [../README.md](../README.md#how-far-an-id-extends)).

**Scope note.** Appendix A's grammar — `chainDomain`, `chain_id`, `extraData`, the envelope and payload layouts, `AccountWitness`, `cutLeaf`, `valStateHash`, `appHash`, `cutHash`, `statement`, `committeeConfigHash`, `regLeaf`, `entriesRoot`, `setKey`/`setHash`/`record`, `voteSignBytes`, registration and the `recover` interface — sits inside four fenced blocks in appendix A. Under the `code-before` exception in [../README.md](../README.md), ENC-A-6–ENC-A-50 mark the definition lines (ENC-A-51–ENC-A-55 are a separate supplement); each marker is a new `// [ID]` line above an unchanged governed line. Lines in those blocks that carry no ID remain uncited. The form question (whether to restructure the blocks into prose or tables) is still [Q-A-1](../review/A.md#q-a-1).

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

| Vector     | Setup                                                                    | Expected                         |
| ---------- | ------------------------------------------------------------------------ | -------------------------------- |
| 3.a accept | the slot-285 record at any height is three words                         | matches                          |
| 3.b accept | the start record at S (block 0 on a new network) is three words          | matches (no exemption is stated) |
| 3.c reject | a slot-285 record of four words, for example with a validator-state hash | violates ENC-A-3                 |
| 3.d reject | a slot-285 record of two words                                           | violates ENC-A-3                 |

_Which fields occupy the three words: [STOR-B-9](B.md#stor-b-9)._

## ENC-A-4a

| Vector      | Setup                                                                     | Expected                                       |
| ----------- | ------------------------------------------------------------------------- | ---------------------------------------------- |
| 4a.a accept | a new guest image is registered in the verifier and slot 293 is unchanged | the ruleset applied to each block is unchanged |
| 4a.b accept | clients are upgraded and slot 293 is unchanged                            | the ruleset applied to each block is unchanged |
| 4a.c reject | registering an image alone changes the rules applied to later blocks      | violates ENC-A-4a                              |
| 4a.d reject | changing client software alone changes the rules applied to later blocks  | violates ENC-A-4a                              |
| 4a.e accept | guest-image acceptance is the verifier's accepted set (6.2)               | conforms                                       |

## ENC-A-5

| Vector     | Setup                                                                                                                                      | Expected                                               |
| ---------- | ------------------------------------------------------------------------------------------------------------------------------------------ | ------------------------------------------------------ |
| 5.a accept | `cutHash`, `statement` and `chainDomain` preimages are `abi.encode(...)`                                                                   | matches                                                |
| 5.b accept | a domain tag is its ASCII bytes followed by zero bytes to 32 (for example `ETNA_LAND_CUTS_V1` plus 15 zero bytes)                          | matches "right-zero-padded `bytes32` ASCII"            |
| 5.c accept | an `entriesRoot` inner node is keccak256(left concatenated with right)                                                                     | stated exception                                       |
| 5.d accept | the blob hash list and the cut leaf list are hashed with `abi.encodePacked`                                                                | stated exceptions                                      |
| 5.e reject | a protocol hash uses `abi.encodePacked` where the rule requires `abi.encode`                                                               | violates ENC-A-5                                       |
| 5.f reject | a domain tag is left-padded with zeros                                                                                                     | violates ENC-A-5 ("right-zero-padded")                 |
| 5.h reject | the blob hash list is hashed as keccak256(abi.encode(blobHashes))                                                                          | violates ENC-A-5                                       |
| 5.i reject | the cut leaf list is hashed with `abi.encode`                                                                                              | violates ENC-A-5                                       |
| 5.j reject | a registry or committee hash preimage encodes its domain tag as a dynamic string (for `regLeaf`, a 288-byte preimage instead of 224 bytes) | violates ENC-A-5 ("never encoded as a dynamic string") |

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

## ENC-A-10a

Chain id 167000 unless a row says otherwise. The parent's gasLimit is 30,000,000 in every row, so `target` is 15,000,000. Amounts are in wei.

| Vector       | Setup                                                                                      | Expected                                                                                         |
| ------------ | ------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------ |
| 10a.a accept | parent base fee 100,000,000, gasUsed 15,000,000; parent minus grandparent timestamp is 2 s | `adjusted` = 15,000,000 = gasUsed; base fee 100,000,000                                          |
| 10a.b accept | parent base fee 100,000,000, gasUsed 30,000,000; interval 2 s                              | `delta` = 12,500,000; base fee 112,500,000                                                       |
| 10a.c accept | parent base fee 100,000,000, gasUsed 15,000,000; interval 4 s                              | `adjusted` = min(30,000,000, 28,500,000) = 28,500,000; `delta` = 11,250,000; base fee 88,750,000 |
| 10a.d accept | parent base fee 10,000,000, gasUsed 0; interval 2 s                                        | `raw` = 8,750,000, raised to the minimum 10,000,000                                              |
| 10a.e accept | the parent of 10a.d on a chain id other than 167000                                        | 8,750,000                                                                                        |
| 10a.f accept | parent base fee 10,000,000, gasUsed 15,000,001; interval 2 s                               | `delta` floors to 0 and counts as 1; base fee 10,000,001                                         |
| 10a.g accept | parent base fee 950,000,000, gasUsed 30,000,000; interval 2 s                              | `raw` = 1,068,750,000, lowered to 1,000,000,000                                                  |
| 10a.h reject | the interval is the block's own timestamp minus its parent's                               | violates ENC-A-10a (`p.timestamp - g.timestamp`); block invalid (3.4 rule 7)                     |
| 10a.i reject | a division rounds to nearest instead of flooring                                           | violates ENC-A-10a ("every division floors"); block invalid (3.4 rule 7)                         |
| 10a.j reject | the parent's gasLimit is reduced by a reserve before `target` is computed                  | violates ENC-A-10a ("the values in p's header"); block invalid (3.4 rule 7)                      |
| 10a.k accept | parent base fee 100,000,000, gasUsed 28,500,000 (95% of the gas limit); interval 4 s       | `adjusted` = 28,500,000 = gasUsed; base fee 100,000,000                                          |
| 10a.l accept | parent base fee 100,000,000, gasUsed 30,000,000 (a full block); interval 4 s               | `delta` = 1,250,000; base fee 101,250,000                                                        |

## ENC-A-10b

| Vector       | Setup                                                                  | Expected                                                                       |
| ------------ | ---------------------------------------------------------------------- | ------------------------------------------------------------------------------ |
| 10b.a accept | the parent's `difficulty` is 1,000,000 and the block's number is 12345 | `mixHash = 0x05a173eee05e0e03682acaef0ca4dea2f32b47cd3e10eed85233465b524d4507` |
| 10b.b reject | the preimage is packed without padding instead of two 32-byte words    | violates ENC-A-10b (`abi.encode`, 64 bytes); block invalid (3.4 rule 7)        |
| 10b.c reject | the first word is the parent's `mixHash` instead of its `difficulty`   | violates ENC-A-10b; block invalid (3.4 rule 7)                                 |

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
| 20.e reject | an empty slot's entry has a nonzero field                                                 | violates ENC-A-20; proposal invalid (ENC-A-16)                      |
| 20.f accept | an empty slot's entry has all-zero fields                                                 | matches                                                             |
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

| Vector      | Setup                                                                                                                                         | Expected                                  |
| ----------- | --------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------- |
| 23.a accept | `0x06`, then a zlib stream whose decompressed bytes are one RLP list whose items are the lists `[elHeader, [tx, ...]]`                        | matches                                   |
| 23.b reject | prefix is `0x07`                                                                                                                              | violates ENC-A-23 (`0x06`)                |
| 23.c reject | the bytes after `0x06` are raw RLP, not a zlib stream                                                                                         | violates ENC-A-23                         |
| 23.d reject | the zlib stream decompresses to something that is not an RLP list                                                                             | violates ENC-A-23                         |
| 23.e reject | a block item in the decompressed list is an RLP byte string that holds the encoding `rlp([elHeader, [tx, ...]])` rather than that list itself | violates ENC-A-23 ("a list encoded once") |

## ENC-A-23a

| Vector       | Setup                                                                                             | Expected                                   |
| ------------ | ------------------------------------------------------------------------------------------------- | ------------------------------------------ |
| 23a.a accept | a blob is read as 4096 field elements of 32 bytes, each one header byte followed by 31 body bytes | matches                                    |
| 23a.b reject | the header byte is read from the end of each field element                                        | violates ENC-A-23a (`hdr[i] \|\| body[i]`) |

## ENC-A-23b

| Vector       | Setup                                                                                                      | Expected                                                                                                                                               |
| ------------ | ---------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------ |
| 23b.a accept | data is 28 bytes of `0xff`, so its last byte is round 0's `x`                                              | `hdr[0] = 0x3f` and `hdr[1] = 0x30`: blob bytes 0 to 4 are `3f 00 00 00 1c`, bytes 5 to 31 are `0xff`, byte 32 is `0x30`, and every other byte is zero |
| 23b.b reject | `x` is stored whole in `hdr[4r]`                                                                           | violates ENC-A-23b (`x & 0x3f`)                                                                                                                        |
| 23b.c reject | the three single bytes are taken from the end of the round instead of after each of its first three bodies | violates ENC-A-23b (stream order)                                                                                                                      |

## ENC-A-23c

| Vector       | Setup                               | Expected                                                                |
| ------------ | ----------------------------------- | ----------------------------------------------------------------------- |
| 23c.a accept | data is the single byte `0xff`      | blob bytes 0 to 5 are `00 00 00 00 01 ff`, and every other byte is zero |
| 23c.b accept | data is 130,044 bytes               | the length bytes are `01 fb fc` and the stream has no fill              |
| 23c.c reject | the length is written little-endian | violates ENC-A-23c (`uint24_be`)                                        |
| 23c.d reject | data is 130,045 bytes in one blob   | violates ENC-A-23c (`n <= 130,044`)                                     |

## ENC-A-23d

| Vector       | Setup                                                                                                                                                                                       | Expected                                                      |
| ------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------- |
| 23d.a reject | the version byte is `0x01`                                                                                                                                                                  | violates ENC-A-23d; the blob does not decode                  |
| 23d.b reject | the length bytes give n = 130,045                                                                                                                                                           | violates ENC-A-23d; the blob does not decode                  |
| 23d.c reject | a header byte has one of its top two bits set, the first field element's included                                                                                                           | violates ENC-A-23d ("every hdr[i]"); the blob does not decode |
| 23d.d reject | a stream byte after data is nonzero                                                                                                                                                         | violates ENC-A-23d; the blob does not decode                  |
| 23d.e accept | two blobs carry D0 of 130,044 bytes and D1                                                                                                                                                  | the blob payload is D0 followed by D1                         |
| 23d.f reject | the blob of 23c.a with byte 0 changed from `0x00` to `0x40`: the first field element is still below the BLS12-381 modulus, and a decoder that masks the two bits would return the same data | violates ENC-A-23d ("every hdr[i]"); the blob does not decode |

## ENC-A-24

| Vector      | Setup                                                                                                              | Expected                                   |
| ----------- | ------------------------------------------------------------------------------------------------------------------ | ------------------------------------------ |
| 24.a accept | seven items in order: address, nonce, balance, storageRoot, codeHash, accountProof, list of `[slot, value, proof]` | matches                                    |
| 24.b reject | six or eight items                                                                                                 | violates ENC-A-24                          |
| 24.c reject | nonce precedes address                                                                                             | violates ENC-A-24 (order)                  |
| 24.d reject | a storage entry has two or four items                                                                              | violates ENC-A-24 (`[slot, value, proof]`) |
| 24.e reject | the seventh item is one `[slot, value, proof]` rather than a list of them                                          | violates ENC-A-24                          |

## ENC-A-25a

| Vector       | Setup                                                                               | Expected                                                                             |
| ------------ | ----------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------ |
| 25a.a accept | anchor witness proves slots `[268, 270, 271, 281, 293]` in that order               | matches                                                                              |
| 25a.b reject | anchor slots are `[268, 271, 270, 281, 293]`                                        | violates ENC-A-25a ("exactly in order"); consequence — [Q-A-4](../review/A.md#q-a-4) |
| 25a.c reject | the anchor witness omits 281 or 293, or adds 269                                    | violates ENC-A-25a ("exactly")                                                       |
| 25a.d accept | forced entry `i` proves `base` and `base+1`, `base = keccak256(abi.encode(i, 280))` | matches                                                                              |
| 25a.e reject | `base` is computed as `keccak256(abi.encode(i, 281))` or with another index         | violates ENC-A-25a                                                                   |
| 25a.f reject | forced slots are `[base+1, base]`                                                   | violates ENC-A-25a (order); consequence — [Q-A-4](../review/A.md#q-a-4)              |

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
| 27.a accept | exactly five fields in order: targetEpoch, cutoffL1Block, checkpointIndex, setHash, totalPower | matches                   |
| 27.b reject | four or six fields                                                                             | violates ENC-A-27         |
| 27.c reject | checkpointIndex precedes cutoffL1Block                                                         | violates ENC-A-27 (order) |
| 27.d reject | setHash is omitted                                                                             | violates ENC-A-27         |

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
| 29.b reject | three or five words, for example a leaf that appends `valStateHash(x)`                     | violates ENC-A-29                                    |
| 29.c reject | order is `(blockHash(x), uint256(x), ...)`                                                 | violates ENC-A-29                                    |
| 29.d reject | blockHash, cometHash or forcedHead is taken at a height other than `x`                     | violates ENC-A-29 (all at height x)                  |
| 29.e reject | `x` or `forcedHead(x)` is encoded in fewer than 32 bytes (for example packed as uint48)    | violates ENC-A-29 (`uint256(x)`, four 32-byte words) |

## ENC-A-29a

| Vector       | Setup                                                                                                                                                                                                                                                                                                                                                                                                                                                                       | Expected                                                                                                      |
| ------------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------- |
| 29a.a accept | `keccak256(abi.encode(bytes32("ETNA_VAL_STATE_V1"), uint256(x), current(x), uint256(currentProposer(x)), next(x), uint256(nextProposer(x))))`, each set a `ValEntry[]` of `(uint8 ckPrefix, bytes32 ckX, uint64 votingPower, int64 proposerPriority)`                                                                                                                                                                                                                       | matches                                                                                                       |
| 29a.b accept | current(x) and next(x) are CometBFT's `State.Validators` and `State.NextValidators` after committing x, each ordered by votingPower descending and then address ascending                                                                                                                                                                                                                                                                                                   | matches                                                                                                       |
| 29a.c reject | in a set whose members have unequal powers, the entries are ordered by set key (4.3) or by address                                                                                                                                                                                                                                                                                                                                                                          | violates ENC-A-29a                                                                                            |
| 29a.d reject | in a set of at least two members whose CometBFT priorities are not all zero, every `proposerPriority` is written as 0                                                                                                                                                                                                                                                                                                                                                       | violates ENC-A-29a                                                                                            |
| 29a.e reject | a negative `proposerPriority` is encoded as an unsigned value instead of sign-extended `int64`                                                                                                                                                                                                                                                                                                                                                                              | violates ENC-A-29a                                                                                            |
| 29a.f reject | current(x) is the set that signed x (`State.LastValidators`)                                                                                                                                                                                                                                                                                                                                                                                                                | violates ENC-A-29a                                                                                            |
| 29a.g reject | the tag is `ETNA_VAL_STATE_V2`                                                                                                                                                                                                                                                                                                                                                                                                                                              | violates ENC-A-29a (and ENC-A-1)                                                                              |
| 29a.h accept | x = S(t): next(x) is the committee that signs H(t), with the priorities and stored proposer CometBFT holds for it after committing S(t)                                                                                                                                                                                                                                                                                                                                     | matches (next(x) signs x + 2 = H(t))                                                                          |
| 29a.i reject | in a set whose lowest-priority (or highest-priority) member differs from the validator CometBFT stores as the set's proposer, `currentProposer(x)` names that member                                                                                                                                                                                                                                                                                                        | violates ENC-A-29a                                                                                            |
| 29a.j reject | a proposer index counts from the set-key order instead of the set's own order                                                                                                                                                                                                                                                                                                                                                                                               | violates ENC-A-29a                                                                                            |
| 29a.k accept | x = o, a generation's start height: current(o) and next(o) are the two sets CometBFT builds from that generation's genesis                                                                                                                                                                                                                                                                                                                                                  | matches                                                                                                       |
| 29a.l accept | x = 6; current = [(2, 0x0000000000000000000000000000000000000000000000000000000000000001, 10, −5), (3, 0x0000000000000000000000000000000000000000000000000000000000000002, 10, 5)] with currentProposer 1; next = [(2, 0x0000000000000000000000000000000000000000000000000000000000000001, 10, 5), (3, 0x0000000000000000000000000000000000000000000000000000000000000002, 10, −5)] with nextProposer 0; the encoding is 768 bytes (six head words, then 9 words per array) | valStateHash = `0x368f341ba9eb8b6d6cadbd5b944daed7ed417b273d1257911a7fd18320f2a81b`                           |
| 29a.m reject | a cut leaf, a slot 285 record or the statement carries `valStateHash`                                                                                                                                                                                                                                                                                                                                                                                                       | violates ENC-A-29a ("no L1 record, cut or statement holds valStateHash")                                      |
| 29a.n accept | equal power 1 for addresses A < B, priorities (−3, 2), one increment                                                                                                                                                                                                                                                                                                                                                                                                        | spread 5 exceeds 4, rescale toward zero to (−1, 1), centre to (−1, 1); B wins and final priorities are (0, 0) |
| 29a.o accept | same members with priorities (−1, 0), one increment                                                                                                                                                                                                                                                                                                                                                                                                                         | the average floors to −1, centred priorities are (0, 1), B wins and final priorities are (1, 0)               |
| 29a.p accept | an update adds a new member and removes another; power after additions and reweights but before removals is 17                                                                                                                                                                                                                                                                                                                                                              | new priority starts at −19 before rescaling and centering                                                     |

_29a.l checks only the byte encoding of the entries as given; whether that order is CometBFT's set order depends on the real addresses of the keys._

## ENC-A-29b

| Vector       | Setup                                                                                                                                                  | Expected                                                                       |
| ------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------ |
| 29b.a accept | `keccak256(abi.encode(bytes32("ETNA_APP_HASH_V1"), blockHash(x), valStateHash(x)))`, three words                                                       | matches                                                                        |
| 29b.b reject | the app returns `blockHash(x)` alone as `app_hash`                                                                                                     | violates ENC-A-29b (and CONS-3.1-8)                                            |
| 29b.c reject | `blockHash(x)` is paired with `valStateHash(x - 1)` or `valStateHash(x + 1)`                                                                           | violates ENC-A-29b (both at height x)                                          |
| 29b.d accept | header x + 1 carries appHash(x) as its AppHash                                                                                                         | matches                                                                        |
| 29b.e accept | x = o, a generation's start height: InitChain returns appHash(o), from the origin's EL hash and the genesis validator state of ENC-A-29a               | matches                                                                        |
| 29b.f reject | the tag word is omitted, or the tag is `ETNA_APP_HASH_V2`                                                                                              | violates ENC-A-29b (and ENC-A-1)                                               |
| 29b.g accept | x = 6; blockHash(6) = `0x1111111111111111111111111111111111111111111111111111111111111111`; valStateHash(6) is 29a.l's value; the encoding is 96 bytes | appHash = `0x381ceb5a317bd34b0b19b9972191a994c384b4873a3694cfd46cb155c7d8b451` |

_Reproduce 29a.l with Foundry's `cast`: `cast keccak $(cast abi-encode 'f(bytes32,uint256,(uint8,bytes32,uint64,int64)[],uint256,(uint8,bytes32,uint64,int64)[],uint256)' $(cast format-bytes32-string ETNA_VAL_STATE_V1) 6 '[(2,K1,10,-5),(3,K2,10,5)]' 1 '[(2,K1,10,5),(3,K2,10,-5)]' 0)`, with K1 and K2 the two 32-byte values in the row._

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

| Vector      | Setup                                                                                        | Expected                                                  |
| ----------- | -------------------------------------------------------------------------------------------- | --------------------------------------------------------- |
| 31.a accept | list length `h-p-1`; leaves are cutLeaf(p+1) through cutLeaf(h-1) in increasing height order | matches                                                   |
| 31.b reject | the list includes cutLeaf(p) or cutLeaf(h)                                                   | violates ENC-A-31 ("strictly between")                    |
| 31.c reject | list length is off by one                                                                    | violates ENC-A-31                                         |
| 31.d reject | leaves are out of height order                                                               | violates ENC-A-31                                         |
| 31.e accept | `h = p + 2`: exactly one leaf, cutLeaf(p + 1)                                                | matches the formula                                       |
| 31.f reject | leaves are spaced by 2, skipping every other height                                          | violates ENC-A-31 (every height strictly between p and h) |

## ENC-A-32

| Vector      | Setup                                                              | Expected          |
| ----------- | ------------------------------------------------------------------ | ----------------- |
| 32.a accept | `h = p + 1`: the inner list is empty and hashed as `keccak256("")` | matches           |
| 32.b reject | `h = p + 1` and the list holds one leaf                            | violates ENC-A-32 |
| 32.c reject | `h = p + 1` and the empty list is hashed as `keccak256(0xc0)`      | violates ENC-A-32 |
| 32.d reject | `h = p + 1` and the empty list is hashed as a zero `bytes32`       | violates ENC-A-32 |

## ENC-A-33

| Vector      | Setup                                          | Expected                             |
| ----------- | ---------------------------------------------- | ------------------------------------ |
| 33.a accept | `leaves.length == h-p-1`, `c < h`              | checks pass                          |
| 33.d reject | `leaves.length = h-p` (one too many)           | violates ENC-A-33                    |
| 33.e reject | `c >= h`                                       | rejected as already settled (stated) |
| 33.f accept | `S = 1000`, `p = 1000`, `h = 1003`, two leaves | checks pass                          |
| 33.g reject | `p = 1000`, `h = 1003`, one leaf               | violates ENC-A-33                    |

## ENC-A-34

| Vector      | Setup                                                                          | Expected                       |
| ----------- | ------------------------------------------------------------------------------ | ------------------------------ |
| 34.a accept | `c > p`: `leaves[c-p-1]` equals `cutLeaf(c)` computed from c's slot 285 record | matches                        |
| 34.b reject | `c > p` and the leaf equals `cutLeaf(c')` for another height `c'`              | violates ENC-A-34              |
| 34.c reject | `c > p` and the leaf is computed from a record other than c's slot 285         | violates ENC-A-34              |
| 34.d accept | `c == p`: the overlap check does not apply                                     | the text conditions on `c > p` |
| 34.e reject | `c > p` and the indexed leaf is not the required one                           | violates ENC-A-34              |

## ENC-A-35

| Vector      | Setup                                                                                               | Expected                                |
| ----------- | --------------------------------------------------------------------------------------------------- | --------------------------------------- |
| 35.a accept | `keccak256(abi.encode(...))` with the 21 static ABI words of the definition, 672 bytes              | matches                                 |
| 35.b reject | the preimage has 22 or 23 words, for example with a `parentValStateHash` or `lastValStateHash` word | violates ENC-A-35 (21 words, 672 bytes) |
| 35.c reject | `TAIKO_ETNA_LAND_V1` is replaced by a V2 tag                                                        | violates ENC-A-35 (and ENC-A-1)         |
| 35.d reject | `blobHashes` are hashed with `abi.encode` instead of `abi.encodePacked`                             | violates ENC-A-35                       |
| 35.e reject | `l2ChainId` precedes `l1ChainId`                                                                    | violates ENC-A-35 (field order)         |
| 35.f reject | `lastStateRoot` precedes `lastCometHash`                                                            | violates ENC-A-35 (field order)         |

## ENC-A-36

| Vector      | Setup                                                                                                                           | Expected                          |
| ----------- | ------------------------------------------------------------------------------------------------------------------------------- | --------------------------------- |
| 36.a accept | `keccak256(abi.encode(bytes32("ETNA_PARENT_ANCHOR_V1"), l2ChainId, registry, vp_unit, minStake, n_max, U))`; 7 words, 224 bytes | matches                           |
| 36.b reject | tag is `ETNA_PARENT_ANCHOR_V2`                                                                                                  | violates ENC-A-36                 |
| 36.c reject | six or eight fields                                                                                                             | violates ENC-A-36                 |
| 36.d reject | `registry` precedes `l2ChainId`                                                                                                 | violates ENC-A-36 (order)         |
| 36.e reject | 224 bytes plus a trailing word                                                                                                  | violates ENC-A-36 (7 words)       |
| 36.e reject | the fifth word is an independently chosen threshold that differs from the registry's minStake                                   | violates ENC-A-36 and START-10-14 |

## ENC-A-37

| Vector      | Setup                                                                                                                                                                                                                                            | Expected                                                                       |
| ----------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------ |
| 37.a accept | `keccak256(abi.encode(bytes32("ETNA_REG_ENTRY_V1"), j, ckPrefix, ckX, effStake, activeFromL1, exitEffectiveL1))` for slot j = 1 with all-zero entry fields: a 224-byte preimage whose first word is the tag's ASCII bytes followed by zero bytes | `0x21d961646cf730220ee47cda213ec296eba41d18fc39f8f6cb1e1350f77c907d`           |
| 37.b reject | tag is `ETNA_REG_ENTRY_V2`                                                                                                                                                                                                                       | violates ENC-A-37                                                              |
| 37.c reject | `j` or `exitEffectiveL1` is omitted                                                                                                                                                                                                              | violates ENC-A-37                                                              |
| 37.d reject | `ckX` precedes `ckPrefix`                                                                                                                                                                                                                        | violates ENC-A-37 (order)                                                      |
| 37.e accept | slots 0 to 6 are held and the bond in slot 7 has been withdrawn; the next registration creates bond 4096 in slot 7; its entry is hashed into `entriesRoot`                                                                                       | `j = 7`; the other entry fields come from bond 4096 (STAKE-4.1-13a, STOR-B-21) |
| 37.f reject | the same entry is hashed with `j = 4096`                                                                                                                                                                                                         | violates STAKE-4.1-13a and ENC-A-37; `j` is the slot number, not the bond id   |
| 37.g accept | bonds 0 and 1 hold slots 0 and 1; bond 0 is withdrawn; the next registration creates bond 2 in slot 0                                                                                                                                            | the new entry uses `j = 0` even before any bond id reaches 4096                |
| 37.h reject | the new entry for bond 2 in slot 0 uses `j = 2`                                                                                                                                                                                                  | violates STAKE-4.1-13a and ENC-A-37                                            |
| 37.i accept | slot j = 0, ckPrefix = 2, ckX = `0x79be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798`, effStake = 250,000 × 10^18, activeFromL1 = 100, exitEffectiveL1 = 2^48 − 1                                                                 | `0xe7283e6153912ee69d614724bff4c2c09b9d20287fa4e0840db13c883df21387`           |
| 37.j reject | the entry of 37.a is hashed with the tag encoded as a dynamic string: a 288-byte preimage with hash `0x6be6938b2da71c3451f504f138ac0f40a3402012cec0d51f5eb7d37d1fd574e7`                                                                         | violates ENC-A-37 and ENC-A-5                                                  |

## ENC-A-38

| Vector      | Setup                                                                                                                                                                             | Expected                   |
| ----------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------- |
| 38.a accept | leaves right-padded with zero words to the smallest sufficient power of two; inner nodes `keccak256(left concatenated with right)`                                                | matches                    |
| 38.b reject | padding to any length other than the smallest sufficient power of two                                                                                                             | violates ENC-A-38          |
| 38.d accept | one entry: the root is that leaf                                                                                                                                                  | equals regLeaf(0)          |
| 38.e accept | no entries: the root is 0                                                                                                                                                         | equals bytes32(0)          |
| 38.f reject | no entries but the root is `keccak256("")`                                                                                                                                        | violates ENC-A-38          |
| 38.g reject | zero padding uses a nonzero value                                                                                                                                                 | violates ENC-A-38          |
| 38.h accept | count = 3 with slots 0 and 2 occupied. Let L0 and L2 be their indexed leaves, Z1 = regLeaf(1) over all-zero fields, P = bytes32(0), and K(a,b) = keccak256 of their concatenation | root = K(K(L0,Z1),K(L2,P)) |
| 38.i reject | use a zero word instead of Z1, hash a zero-field entry at slot 3 instead of P, or compact slot 2 to slot 1                                                                        | violates ENC-A-38          |

_`abi.encode(left, right)` of two `bytes32` words equals their plain concatenation, so it is not a separate reject case._

## ENC-A-39

| Vector      | Setup                                                                                                                                                       | Expected                                                             |
| ----------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------- |
| 39.a accept | `keccak256(abi.encode(bytes32("ETNA_SET_KEY_V1"), l2ChainId, ckPrefix, ckX))` for l2ChainId = 167000, ckPrefix = 2 and the ckX of 37.i: a 128-byte preimage | `0x7529ec50109faf073e202f03d7b4804a32a3571765e9749536cc42cc37acb437` |
| 39.b reject | tag is `ETNA_SET_KEY_V2`                                                                                                                                    | violates ENC-A-39                                                    |
| 39.c reject | `l2ChainId` or `ckX` is omitted                                                                                                                             | violates ENC-A-39                                                    |
| 39.d reject | `ckX` precedes `ckPrefix`                                                                                                                                   | violates ENC-A-39 (order)                                            |

## ENC-A-39a

| Vector       | Setup                                                                                                                                                                                                                                                                                                   | Expected                                                             |
| ------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------- |
| 39a.a accept | `keccak256(abi.encode(bytes32("ETNA_SET_V1"), l2ChainId, k, members))` for l2ChainId = 167000, k = 1 and one member (ckPrefix = 2, the ckX of 37.i, effStake = 250,000 × 10^18, assignedPower = 250,000 × 10^9): a 288-byte preimage of four head words, the array length and four words for the member | `0x0c09cd574e795c943cf299b730422425455959f85c169641a97030f4d287566d` |
| 39a.b accept | several members listed in ascending set-key order                                                                                                                                                                                                                                                       | matches                                                              |
| 39a.c reject | the same members listed in another order, such as descending effStake                                                                                                                                                                                                                                   | violates ENC-A-39a                                                   |
| 39a.d reject | `l2ChainId` or `k` is omitted, or a member omits `effStake` or `assignedPower`                                                                                                                                                                                                                          | violates ENC-A-39a                                                   |
| 39a.e reject | the set is committed as a Merkle root over one leaf per member                                                                                                                                                                                                                                          | violates ENC-A-39a ("one hash commits the whole set")                |
| 39a.f reject | the tag is encoded as a dynamic string                                                                                                                                                                                                                                                                  | violates ENC-A-39a and ENC-A-5                                       |

## ENC-A-42

| Vector      | Setup                                                                                                                                                                                                                                                                                           | Expected                                                             |
| ----------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------- |
| 42.a accept | `keccak256(abi.encode(bytes32("ETNA_COMMITTEE_V1"), l2ChainId, targetEpoch, cutoffL1Block, checkpointIndex, setHash, totalPower))` for l2ChainId = 167000, targetEpoch = 0, cutoffL1Block = 100, checkpointIndex = 0, the setHash of 39a.a and totalPower = 250,000 × 10^9: a 224-byte preimage | `0x6fa2491c7f7f68e27ae6e55fa1a5cbcc0dfb095bef60d4a69ed7498417368634` |
| 42.b reject | tag is `ETNA_COMMITTEE_V2`                                                                                                                                                                                                                                                                      | violates ENC-A-42                                                    |
| 42.c reject | `checkpointIndex` or `totalPower` is omitted                                                                                                                                                                                                                                                    | violates ENC-A-42                                                    |
| 42.d reject | `cutoffL1Block` precedes `targetEpoch`                                                                                                                                                                                                                                                          | violates ENC-A-42 (order)                                            |

## ENC-A-42a

| Vector       | Setup                                                             | Expected           |
| ------------ | ----------------------------------------------------------------- | ------------------ |
| 42a.a accept | the committee for `targetEpoch = t` uses `k = t + 1` in `setHash` | matches            |
| 42a.b reject | `k = targetEpoch`                                                 | violates ENC-A-42a |

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

| Vector      | Setup                                                                          | Expected                                                                                                                                      |
| ----------- | ------------------------------------------------------------------------------ | --------------------------------------------------------------------------------------------------------------------------------------------- |
| 45.a accept | fields shown in `[]` are omitted when zero or empty; `len` is a uvarint prefix | matches                                                                                                                                       |
| 45.b reject | a zero field is written explicitly instead of omitted                          | violates ENC-A-45                                                                                                                             |
| 45.c reject | an empty blockId is written with length 0 instead of omitted                   | violates ENC-A-45                                                                                                                             |
| 45.d accept | timestamp is written even when zero                                            | "always written"                                                                                                                              |
| 45.e reject | timestamp is omitted when zero                                                 | violates ENC-A-45                                                                                                                             |
| 45.f reject | a length prefix is not a uvarint                                               | violates ENC-A-45                                                                                                                             |
| 45.g accept | a vote timestamp of seconds = −1 and nanos = 0                                 | the seconds field is `08 ff ff ff ff ff ff ff ff ff 01` (ten varint bytes), and the timestamp field is `2a 0b` followed by those eleven bytes |
| 45.h reject | seconds = −1 is written as a varint shorter than ten bytes                     | violates ENC-A-45                                                                                                                             |

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

| Vector      | Setup                                                             | Expected                                    |
| ----------- | ----------------------------------------------------------------- | ------------------------------------------- |
| 51.a accept | exclusions `[bondId 1, 5, 9]`                                     | strictly increasing; conforms               |
| 51.b reject | exclusions `[1, 9, 5]`                                            | violates ENC-A-51 (not sorted)              |
| 51.c reject | exclusions `[1, 5, 5]`                                            | violates ENC-A-51 (not strictly increasing) |
| 51.d reject | exclusions use two ABI words per element for bond id and key hash | violates ENC-A-51                           |

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

| Vector      | Setup                                                                        | Expected          |
| ----------- | ---------------------------------------------------------------------------- | ----------------- |
| 54.a accept | `forfeit(bondId, incidentId, validUntil)` with exactly those three arguments | conforms          |
| 54.b reject | a call that omits `incidentId` or supplies a different argument list         | violates ENC-A-54 |

## ENC-A-55

| Vector      | Setup                                                                                                 | Expected                                                                                                                       |
| ----------- | ----------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------ |
| 55.a accept | the registry owner forfeits an issued `bondId` once                                                   | conforms                                                                                                                       |
| 55.b reject | the DAO's execution address calls `forfeit` while the registry owner is a different address           | violates ENC-A-55 (registry-owner-only); FORF-4.4-1 names one caller, "the registry owner, the DAO's actual execution address" |
| 55.c reject | a second `forfeit` for the same lifetime `bondId`                                                     | violates ENC-A-55 (once per issued bondId)                                                                                     |
| 55.d reject | any call that attempts to revoke or reset a forfeiture via a nonce                                    | violates ENC-A-55 (no forfeiture nonce or revocation)                                                                          |
| 55.h accept | key K belongs to bond 0 in slot 0; query `bondForKey(ckAddr(K))`, `bondInSlot(0)` and `slotOfBond(0)` | each returns `(true, 0)` under the specified external-view ABI                                                                 |
| 55.i accept | query an unused key, an empty slot or an unissued bond id through its corresponding lookup            | returns `(false, 0)`; the read does not allocate or confirm a bond                                                             |
| 55.j accept | withdraw bond 0, then query its key and `slotOfBond(0)`                                               | key lookup returns `(true, 0)`; slot lookup returns `(false, 0)`                                                               |
| 55.k reject | `bondInSlot(4096)` or a higher slot is queried                                                        | the lookup reverts (ENC-A-55)                                                                                                  |

## Not covered

Everything below is a question, not a vector. Each has an entry in [review/A.md](../review/A.md).

| Rule                | Gap                                                                                                                                  | Question                      |
| ------------------- | ------------------------------------------------------------------------------------------------------------------------------------ | ----------------------------- |
| ENC-A-6 to ENC-A-55 | whether the now-citable blocks should still be restructured into prose or tables                                                     | [Q-A-1](../review/A.md#q-a-1) |
| ENC-A-24, ENC-A-25a | whether an out-of-order, extra or missing witness slot list makes a witness invalid; the order is now stated, the consequence is not | [Q-A-4](../review/A.md#q-a-4) |
| Shared vectors      | the obligation itself is un-numbered and has no owner                                                                                | [Q-A-5](../review/A.md#q-a-5) |
