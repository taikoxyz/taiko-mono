# A — accept/reject vectors

**Non-normative.** Rule text lives in [SPEC.md](../../SPEC.md). This file states only what the text states: each vector either follows directly from a numbered statement, or reports that a requirement was violated. Where the text states a requirement but **not the consequence of violating it**, the vector says "violates ENC-A-N" and does not name an outcome. Anything undetermined has no vector; it is listed under "Not covered" and raised in [review/A.md](../review/A.md).

`accept` means the described encoding satisfies the rule cited. `reject` means a stated requirement is violated. Appendix A states one consequence: ENC-A-16's "any violation makes the proposal invalid". It covers the envelope grammar (ENC-A-11–ENC-A-15) and the strict-decoding conditions (ENC-A-16–ENC-A-21), so those reject rows say "proposal invalid (ENC-A-16)". Rows elsewhere say "violates ENC-A-N" where the text states no consequence. Where a definition spans several lines, the marker and the ID sit above its first line, and the ID cites the whole definition (see [../README.md](../README.md#how-far-an-id-extends)).

**Scope note.** Appendix A's grammar — `chainDomain`, `chain_id`, `extraData`, the `missBitmap` bit order, the `onBlockStart` calldata, the envelope and payload layouts, `AccountWitness`, `cutLeaf`, `valStateHash`, `appHash`, `cutHash`, `statement`, `configHash`, `FallbackKey`/`fallbackKeysHash`, the fallback keys' voting power, `SeatMember`, `voteSignBytes`, registration and the `recover` and staking-contract interfaces — sits inside four fenced blocks in appendix A. Under the `code-before` exception in [../README.md](../README.md), ENC-A-6–ENC-A-50 mark the definition lines (ENC-A-52–ENC-A-55 are a separate supplement); each marker is a new `// [ID]` line above an unchanged governed line. Lines in those blocks that carry no ID remain uncited. The form question (whether to restructure the blocks into prose or tables) is still [Q-A-1](../review/A.md#q-a-1).

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

| Vector     | Setup                                                 | Expected         |
| ---------- | ----------------------------------------------------- | ---------------- |
| 2.a accept | config preimage is exactly four ABI words (128 bytes) | matches          |
| 2.b reject | config preimage is three words (96 bytes)             | violates ENC-A-2 |
| 2.c reject | config preimage is five words (160 bytes)             | violates ENC-A-2 |

_Which four words: [ENC-A-36](#enc-a-36)._

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

| Vector     | Setup                                                                                                             | Expected                                                                    |
| ---------- | ----------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------- |
| 5.a accept | `cutHash`, `statement` and `chainDomain` preimages are `abi.encode(...)`                                          | matches                                                                     |
| 5.b accept | a domain tag is its ASCII bytes followed by zero bytes to 32 (for example `ETNA_LAND_CUTS_V1` plus 15 zero bytes) | matches "right-zero-padded `bytes32` ASCII"                                 |
| 5.d accept | the blob hash list and the cut leaf list are hashed with `abi.encodePacked`                                       | stated exceptions                                                           |
| 5.e reject | a protocol hash uses `abi.encodePacked` where the rule requires `abi.encode`                                      | violates ENC-A-5                                                            |
| 5.f reject | a domain tag is left-padded with zeros                                                                            | violates ENC-A-5 ("right-zero-padded")                                      |
| 5.h reject | the blob hash list is hashed as keccak256(abi.encode(blobHashes))                                                 | violates ENC-A-5                                                            |
| 5.i reject | the cut leaf list is hashed with `abi.encode`                                                                     | violates ENC-A-5                                                            |
| 5.j reject | the `configHash` preimage encodes its domain tag as a dynamic string: 192 bytes instead of 128                    | violates ENC-A-5 ("never encoded as a dynamic string")                      |
| 5.k reject | the `fallbackKeysHash` keys are hashed with `abi.encodePacked`, 33 bytes per key                                  | violates ENC-A-5 (only the blob hash list and the cut leaf list are packed) |

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

| Vector      | Setup                                                                                                                     | Expected                                                                    |
| ----------- | ------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------- |
| 10.a accept | `0x64`, then a 6-byte big-endian generation, then a 6-byte big-endian anchor number, then a 16-byte big-endian missBitmap | 29 bytes                                                                    |
| 10.b reject | `extraData` is 13 bytes, with no missBitmap, or 30 bytes                                                                  | violates ENC-A-10 ("29 bytes")                                              |
| 10.c reject | the first byte is `0x65`                                                                                                  | violates ENC-A-10 (`0x64`)                                                  |
| 10.d reject | generation is little-endian                                                                                               | violates ENC-A-10 (`uint48_be`)                                             |
| 10.e reject | anchor number precedes generation                                                                                         | violates ENC-A-10 (field order)                                             |
| 10.f accept | generation 0, anchor number 0 and missBitmap 0                                                                            | `0x64` followed by 28 zero bytes                                            |
| 10.g reject | missBitmap is little-endian, or placed before the anchor number                                                           | violates ENC-A-10 (`uint128_be`, field order)                               |
| 10.h accept | generation 1, anchor number 258, missBitmap 2^127 + 1                                                                     | `0x64 000000000001 000000000102 80000000000000000000000000000001`, 29 bytes |

## ENC-A-10a

Chain id 167000 unless a row says otherwise. The parent's gasLimit is 30,000,000 in every row, so `target` is 15,000,000. Amounts are in wei.

| Vector       | Setup                                                                                      | Expected                                                                                         |
| ------------ | ------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------ |
| 10a.a accept | parent base fee 100,000,000, gasUsed 15,000,000; parent minus grandparent timestamp is 4 s | `adjusted` = 15,000,000 = gasUsed; base fee 100,000,000                                          |
| 10a.b accept | parent base fee 100,000,000, gasUsed 30,000,000; interval 4 s                              | `delta` = 12,500,000; base fee 112,500,000                                                       |
| 10a.c accept | parent base fee 100,000,000, gasUsed 15,000,000; interval 8 s                              | `adjusted` = min(30,000,000, 28,500,000) = 28,500,000; `delta` = 11,250,000; base fee 88,750,000 |
| 10a.d accept | parent base fee 10,000,000, gasUsed 0; interval 4 s                                        | `raw` = 8,750,000, raised to the minimum 10,000,000                                              |
| 10a.e accept | the parent of 10a.d on a chain id other than 167000                                        | 8,750,000                                                                                        |
| 10a.f accept | parent base fee 10,000,000, gasUsed 15,000,001; interval 4 s                               | `delta` floors to 0 and counts as 1; base fee 10,000,001                                         |
| 10a.g accept | parent base fee 950,000,000, gasUsed 30,000,000; interval 4 s                              | `raw` = 1,068,750,000, lowered to 1,000,000,000                                                  |
| 10a.h reject | the interval is the block's own timestamp minus its parent's                               | violates ENC-A-10a (`p.timestamp - g.timestamp`); block invalid (3.4 rule 7)                     |
| 10a.i reject | a division rounds to nearest instead of flooring                                           | violates ENC-A-10a ("every division floors"); block invalid (3.4 rule 7)                         |
| 10a.j reject | the parent's gasLimit is reduced by a reserve before `target` is computed                  | violates ENC-A-10a ("the values in p's header"); block invalid (3.4 rule 7)                      |
| 10a.k accept | parent base fee 100,000,000, gasUsed 7,500,000; interval 2 s                               | `adjusted` = 7,500,000 = gasUsed; base fee 100,000,000                                           |
| 10a.l accept | parent base fee 100,000,000, gasUsed 15,000,000; interval 2 s                              | `adjusted` = 7,500,000; `delta` = 6,250,000; base fee 106,250,000                                |
| 10a.m reject | the interval is divided by 2 s, Unzen's target, for an Etna block                          | violates ENC-A-10a (`BLOCK_TIME_TARGET = 4 s`); block invalid (3.4 rule 7)                       |

## ENC-A-10b

| Vector       | Setup                                                                  | Expected                                                                       |
| ------------ | ---------------------------------------------------------------------- | ------------------------------------------------------------------------------ |
| 10b.a accept | the parent's `difficulty` is 1,000,000 and the block's number is 12345 | `mixHash = 0x05a173eee05e0e03682acaef0ca4dea2f32b47cd3e10eed85233465b524d4507` |
| 10b.b reject | the preimage is packed without padding instead of two 32-byte words    | violates ENC-A-10b (`abi.encode`, 64 bytes); block invalid (3.4 rule 7)        |
| 10b.c reject | the first word is the parent's `mixHash` instead of its `difficulty`   | violates ENC-A-10b; block invalid (3.4 rule 7)                                 |

## ENC-A-10c

| Vector       | Setup                                                                 | Expected                                                               |
| ------------ | --------------------------------------------------------------------- | ---------------------------------------------------------------------- |
| 10c.a accept | missBitmap = 5                                                        | seats 0 and 2 have bit 1, every other seat 0; `extraData[28]` = `0x05` |
| 10c.b accept | missBitmap = 2^127                                                    | only seat 127 has bit 1; `extraData[13]` = `0x80`                      |
| 10c.c reject | seat s is read as bit 127 − s, so missBitmap = 1 is taken as seat 127 | violates ENC-A-10c                                                     |
| 10c.d reject | seat 0 is read from the low bit of `extraData[13]`                    | violates ENC-A-10c                                                     |

## ENC-A-10d

| Vector       | Setup                                                                                 | Expected                                                                                      |
| ------------ | ------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------- |
| 10d.a accept | a block with generation 1 and missBitmap 5                                            | calldata `0xea987592`, then 31 zero bytes and `0x01`, then 31 zero bytes and `0x05`: 68 bytes |
| 10d.b accept | the selector is computed as `bytes4(keccak256("onBlockStart(uint48,uint128)"))`       | `0xea987592`                                                                                  |
| 10d.c reject | the arguments follow the selector packed as 6 + 16 bytes, 26 bytes of calldata in all | violates ENC-A-10d (two 32-byte words, 68 bytes)                                              |
| 10d.d reject | missBitmap is the first argument word and generation the second                       | violates ENC-A-10d (argument order)                                                           |
| 10d.e reject | the arguments are taken from the parent's `extraData`                                 | violates ENC-A-10d ("the block's own extraData fields") and STAKE-4.2-4                       |
| 10d.f reject | the calldata carries a third word after missBitmap                                    | violates ENC-A-10d ("no other bytes follow")                                                  |

## ENC-A-11

| Vector      | Setup                                                                   | Expected                                                                               |
| ----------- | ----------------------------------------------------------------------- | -------------------------------------------------------------------------------------- |
| 11.a accept | `0x06` followed by one RLP list `[block, anchor, forced]`               | matches                                                                                |
| 11.b reject | prefix is `0x07`                                                        | violates ENC-A-11 (`0x06`); proposal invalid (ENC-A-16)                                |
| 11.c reject | `0x06` is followed by a bare RLP byte string                            | violates ENC-A-11 (RLP list); proposal invalid (ENC-A-16)                              |
| 11.d reject | list order is `[block, forced, anchor]`                                 | violates ENC-A-11 (named order); proposal invalid (ENC-A-16)                           |
| 11.e reject | two RLP lists follow `0x06`                                             | violates ENC-A-11 (one list); trailing bytes are ENC-A-16; proposal invalid (ENC-A-16) |
| 11.f reject | the list has a fourth item, an empty list between `anchor` and `forced` | violates ENC-A-11 and ENC-A-17 (exactly the items above); proposal invalid (ENC-A-16)  |

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

| Vector      | Setup                                                                                                      | Expected                                                               |
| ----------- | ---------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------- |
| 17.a accept | every list has exactly the named items; anchor and forced are empty or hold one item; integers are minimal | matches                                                                |
| 17.b reject | `block` carries three items                                                                                | violates ENC-A-17; proposal invalid (ENC-A-16)                         |
| 17.c reject | `anchor` carries two items                                                                                 | violates ENC-A-17; proposal invalid (ENC-A-16)                         |
| 17.d reject | integer 5 is encoded as the two-byte string `0x00 0x05`                                                    | violates ENC-A-17 (leading zero); proposal invalid (ENC-A-16)          |
| 17.e reject | integer 0 is encoded as `0x00`                                                                             | violates ENC-A-17 (0 is the empty string); proposal invalid (ENC-A-16) |
| 17.f accept | integer 0 is encoded as the empty string (`0x80`)                                                          | matches                                                                |
| 17.g reject | a list carries an item beyond the named items                                                              | violates ENC-A-17; proposal invalid (ENC-A-16)                         |
| 17.h reject | `forced` holds two items                                                                                   | violates ENC-A-17 (empty or one item); proposal invalid (ENC-A-16)     |

## ENC-A-18

| Vector      | Setup                                                                  | Expected                                       |
| ----------- | ---------------------------------------------------------------------- | ---------------------------------------------- |
| 18.a accept | hashes and stateRoots are 32 bytes, slots 32 bytes, addresses 20 bytes | matches                                        |
| 18.b reject | a hash or stateRoot is 31 or 33 bytes                                  | violates ENC-A-18; proposal invalid (ENC-A-16) |
| 18.c reject | an address is 19 or 21 bytes                                           | violates ENC-A-18; proposal invalid (ENC-A-16) |
| 18.d reject | a slot key is 33 bytes                                                 | violates ENC-A-18; proposal invalid (ENC-A-16) |
| 18.e reject | an unknown field or an extra item is appended                          | violates ENC-A-18; proposal invalid (ENC-A-16) |

## ENC-A-19

| Vector      | Setup                                                                                                       | Expected                                                                  |
| ----------- | ----------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------- |
| 19.a accept | hashes, stateRoots and slots are 32-byte strings; addresses 20-byte strings; all other numbers are integers | matches                                                                   |
| 19.d reject | a slot key is encoded as an integer with leading zeros stripped                                             | violates ENC-A-19 (slot is a 32-byte string); proposal invalid (ENC-A-16) |
| 19.f reject | the forced item's `index` is encoded as a 32-byte string                                                    | violates ENC-A-19 (integer); proposal invalid (ENC-A-16)                  |
| 19.g reject | an `AccountWitness` nonce or balance is encoded as a fixed 32-byte string                                   | violates ENC-A-19 (integer); proposal invalid (ENC-A-16)                  |
| 19.h accept | a slot key beginning with zero bytes is a 32-byte string that keeps them                                    | matches                                                                   |

## ENC-A-20

| Vector      | Setup                                                                                     | Expected                                                            |
| ----------- | ----------------------------------------------------------------------------------------- | ------------------------------------------------------------------- |
| 20.a accept | storage value 0 is the empty string; nonzero values are minimal; RLP prefixes are minimal | matches                                                             |
| 20.b reject | storage value 5 is encoded as `0x00 0x05`                                                 | violates ENC-A-20 (leading zero); proposal invalid (ENC-A-16)       |
| 20.c reject | a 2-byte string uses the long form `0xb8 0x02 ...`                                        | violates ENC-A-20 (prefix not minimal); proposal invalid (ENC-A-16) |
| 20.d reject | the single byte `0x05` is encoded as `0x81 0x05`                                          | violates ENC-A-20 (prefix not minimal); proposal invalid (ENC-A-16) |
| 20.g accept | a slot whose value is a hash uses minimal integer encoding, stripping leading zero bytes  | stated ("including slots that hold hashes")                         |

## ENC-A-21

| Vector      | Setup                                                                    | Expected                                       |
| ----------- | ------------------------------------------------------------------------ | ---------------------------------------------- |
| 21.a accept | anchor witness address is the Inbox; forced witness address is the Inbox | matches                                        |
| 21.b reject | anchor witness address is the L1 SignalService or another contract       | violates ENC-A-21; proposal invalid (ENC-A-16) |
| 21.d reject | forced witness address is an unrelated contract                          | violates ENC-A-21; proposal invalid (ENC-A-16) |
| 21.f reject | anchor witness address is the L2 staking contract's address              | violates ENC-A-21; proposal invalid (ENC-A-16) |

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
| 25a.a accept | anchor witness proves slots `[268, 270, 271, 278, 279, 281, 293]` in that order     | matches                                                                              |
| 25a.b reject | anchor slots are `[268, 271, 270, 278, 279, 281, 293]`                              | violates ENC-A-25a ("exactly in order"); consequence — [Q-A-4](../review/A.md#q-a-4) |
| 25a.c reject | the anchor witness omits 278, 279, 281 or 293, or adds 269                          | violates ENC-A-25a ("exactly")                                                       |
| 25a.g reject | anchor slots are `[268, 270, 271, 279, 278, 281, 293]`                              | violates ENC-A-25a ("exactly in order"); consequence — [Q-A-4](../review/A.md#q-a-4) |
| 25a.d accept | forced entry `i` proves `base` and `base+1`, `base = keccak256(abi.encode(i, 280))` | matches                                                                              |
| 25a.e reject | `base` is computed as `keccak256(abi.encode(i, 281))` or with another index         | violates ENC-A-25a                                                                   |
| 25a.f reject | forced slots are `[base+1, base]`                                                   | violates ENC-A-25a (order); consequence — [Q-A-4](../review/A.md#q-a-4)              |

## ENC-A-26a

| Vector       | Setup                                                                                                  | Expected                                           |
| ------------ | ------------------------------------------------------------------------------------------------------ | -------------------------------------------------- |
| 26a.a accept | `accountProof` and each storage proof are exactly the ordered MPT path from the root to the leaf       | matches                                            |
| 26a.b accept | a storage proof ends at the node that proves the slot is absent                                        | matches ("or to the node proving absence")         |
| 26a.c reject | a proof carries an extra node beyond that path                                                         | violates ENC-A-26a ("no extra nodes")              |
| 26a.d reject | a proven value is written with leading zero bytes, or 0 is not the empty string                        | violates ENC-A-26a ("minimal big-endian encoding") |
| 26a.e reject | the value differs from the proven value, or an account field differs from the account RLP in the proof | violates ENC-A-26a                                 |

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
| 29a.c reject | in a set whose members have unequal powers, the entries are ordered by seat number or by address                                                                                                                                                                                                                                                                                                                                                                            | violates ENC-A-29a                                                                                            |
| 29a.d reject | in a set of at least two members whose CometBFT priorities are not all zero, every `proposerPriority` is written as 0                                                                                                                                                                                                                                                                                                                                                       | violates ENC-A-29a                                                                                            |
| 29a.e reject | a negative `proposerPriority` is encoded as an unsigned value instead of sign-extended `int64`                                                                                                                                                                                                                                                                                                                                                                              | violates ENC-A-29a                                                                                            |
| 29a.f reject | current(x) is the set that signed x (`State.LastValidators`)                                                                                                                                                                                                                                                                                                                                                                                                                | violates ENC-A-29a                                                                                            |
| 29a.g reject | the tag is `ETNA_VAL_STATE_V2`                                                                                                                                                                                                                                                                                                                                                                                                                                              | violates ENC-A-29a (and ENC-A-1)                                                                              |
| 29a.h accept | x = H, at or after o + 1: next(x) is the set that signs H + 2, decided at H (4.3), with the priorities and stored proposer CometBFT holds for it after committing H                                                                                                                                                                                                                                                                                                         | matches (next(x) signs x + 2)                                                                                 |
| 29a.i reject | in a set whose lowest-priority (or highest-priority) member differs from the validator CometBFT stores as the set's proposer, `currentProposer(x)` names that member                                                                                                                                                                                                                                                                                                        | violates ENC-A-29a                                                                                            |
| 29a.j reject | a proposer index counts from seat order instead of the set's own order                                                                                                                                                                                                                                                                                                                                                                                                      | violates ENC-A-29a                                                                                            |
| 29a.k accept | x = o, a generation's start height: current(o) and next(o) are the two sets CometBFT builds from that generation's genesis                                                                                                                                                                                                                                                                                                                                                  | matches                                                                                                       |
| 29a.l accept | x = 6; current = [(2, 0x0000000000000000000000000000000000000000000000000000000000000001, 10, −5), (3, 0x0000000000000000000000000000000000000000000000000000000000000002, 10, 5)] with currentProposer 1; next = [(2, 0x0000000000000000000000000000000000000000000000000000000000000001, 10, 5), (3, 0x0000000000000000000000000000000000000000000000000000000000000002, 10, −5)] with nextProposer 0; the encoding is 768 bytes (six head words, then 9 words per array) | valStateHash = `0x368f341ba9eb8b6d6cadbd5b944daed7ed417b273d1257911a7fd18320f2a81b`                           |
| 29a.m reject | a cut leaf, a slot 285 record or the statement carries `valStateHash`                                                                                                                                                                                                                                                                                                                                                                                                       | violates ENC-A-29a ("no L1 record, cut or statement holds valStateHash")                                      |
| 29a.n accept | equal power 1 for addresses A < B, priorities (−3, 2), one increment                                                                                                                                                                                                                                                                                                                                                                                                        | spread 5 exceeds 4, rescale toward zero to (−1, 1), centre to (−1, 1); B wins and final priorities are (0, 0) |
| 29a.o accept | same members with priorities (−1, 0), no update, spread below the rescale threshold, one increment                                                                                                                                                                                                                                                                                                                                                                          | the average floors to −1, centred priorities are (0, 1), B wins and final priorities are (1, 0)               |
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
| 35.a accept | `keccak256(abi.encode(...))` with the 19 static ABI words of the definition, 608 bytes              | matches                                 |
| 35.b reject | the preimage has 20 or 21 words, for example with a `parentValStateHash` or `lastValStateHash` word | violates ENC-A-35 (19 words, 608 bytes) |
| 35.g reject | the preimage carries the staking contract's address after `inbox`, 20 words                         | violates ENC-A-35 (19 words, 608 bytes) |
| 35.h reject | `configHash` precedes `parentCometHash`                                                             | violates ENC-A-35 (field order)         |
| 35.c reject | `TAIKO_ETNA_LAND_V1` is replaced by a V2 tag                                                        | violates ENC-A-35 (and ENC-A-1)         |
| 35.d reject | `blobHashes` are hashed with `abi.encode` instead of `abi.encodePacked`                             | violates ENC-A-35                       |
| 35.e reject | `l2ChainId` precedes `l1ChainId`                                                                    | violates ENC-A-35 (field order)         |
| 35.f reject | `lastStateRoot` precedes `lastCometHash`                                                            | violates ENC-A-35 (field order)         |

## ENC-A-36

| Vector      | Setup                                                                                                                                                                                         | Expected                                                             |
| ----------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------- |
| 36.a accept | `keccak256(abi.encode(bytes32("ETNA_CONFIG_V1"), l2ChainId, staking, U))` for l2ChainId = 167000, staking = `0x1111111111111111111111111111111111111111` and U = 151,200: a 128-byte preimage | `0x78f4b267763e0c4b58a0606e29530287b1761bf4155630c82e79d3e1215fe3b6` |
| 36.b reject | tag is `ETNA_CONFIG_V2`                                                                                                                                                                       | violates ENC-A-36 (and ENC-A-1)                                      |
| 36.c reject | three or five words, for example with `vp_unit` or `minStake` added                                                                                                                           | violates ENC-A-36 (4 words, 128 bytes)                               |
| 36.d reject | `staking` precedes `l2ChainId`, or `U` precedes `staking`                                                                                                                                     | violates ENC-A-36 (order)                                            |
| 36.e reject | `staking` is the Inbox address, or the staking contract's implementation address rather than its proxy                                                                                        | violates ENC-A-36 ("the address of the EtnaStaking proxy on L2")     |
| 36.f reject | the preimage of 36.a with the tag encoded as a dynamic string: 192 bytes, hash `0x4a305a25878a5ab6f2d7bd36fcdd3d7a5549d0b55471d812df821723caa6383c`                                           | violates ENC-A-36 and ENC-A-5                                        |

## ENC-A-36a

K1 is `(0x02, 0x79be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798)` and K2 is `(0x02, 0xc6047f9441ed7d6d3045406e95c07cd85c778e4b8cef3ca7abac09b95c709ee5)`, the compressed public keys of the private keys 1 and 2.

| Vector       | Setup                                                                                                             | Expected                                                                                  |
| ------------ | ----------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------- |
| 36a.a accept | `keys` = [K1]: a 160-byte preimage of the tag, the offset, the length 1, then `ckPrefix` and `ckX`                | `fallbackKeysHash` = `0x9dd1f7298a08cbe8d9579af09f0c713fc35137e6c534a74f8c439b63252f046f` |
| 36a.b accept | `keys` = [K1, K2], ascending because both prefixes are `0x02` and K1's X is smaller: a 224-byte preimage          | `0x2bc20cdc8e87ed785fc8f8012165afba944fd223ecf8973e165e41f4cddf0cea`                      |
| 36a.c reject | `keys` = [K2, K1]                                                                                                 | violates ENC-A-36a (strictly ascending); `setFallbackKeys` reverts (COMM-4.3-18)          |
| 36a.d reject | `keys` = [K1, K1]                                                                                                 | violates ENC-A-36a (strictly ascending); `setFallbackKeys` reverts (COMM-4.3-18)          |
| 36a.e reject | `keys` is empty, or holds 129 entries                                                                             | violates ENC-A-36a (1 to 128 entries); `setFallbackKeys` reverts (COMM-4.3-18)            |
| 36a.f reject | a key with prefix `0x03` precedes a key with prefix `0x02` and a larger X, as if the list were ordered by X alone | violates ENC-A-36a (order of `ckPrefix ‖ ckX`); `setFallbackKeys` reverts (COMM-4.3-18)   |
| 36a.g reject | the preimage of 36a.a with the tag encoded as a dynamic string: 224 bytes instead of 160                          | violates ENC-A-36a and ENC-A-5                                                            |
| 36a.h accept | 128 keys                                                                                                          | 3 + 2 × 128 = 259 words, 8,288 bytes                                                      |
| 36a.i reject | each key is encoded as one 33-byte value, or the keys are hashed with `abi.encodePacked`                          | violates ENC-A-36a and ENC-A-5                                                            |

_Reproduce 36a.b with Foundry's `cast`: `cast keccak $(cast abi-encode 'f(bytes32,(uint8,bytes32)[])' $(cast format-bytes32-string ETNA_FALLBACK_KEYS_V1) '[(2,X1),(2,X2)]')`, with X1 and X2 the two 32-byte values above._

## ENC-A-36b

| Vector       | Setup                                                                               | Expected                                                               |
| ------------ | ----------------------------------------------------------------------------------- | ---------------------------------------------------------------------- |
| 36b.a accept | the fallback key set of 36a.b signs H + 2                                           | two validators, K1 and K2, each with voting power 1; total power 2     |
| 36b.b accept | o + 1 and o + 2 of a generation whose origin record holds the hash of 36a.a         | K1 alone signs, with voting power 1 (COMM-4.3-9)                       |
| 36b.c reject | a fallback key signs with the power of a bond registered to the same key            | violates ENC-A-36b and COMM-4.3-8b                                     |
| 36b.d accept | K1's validator address                                                              | `0x7E5F4552091A69125d5DfCb7b8C2659029395Bdf`, its secp256k1eth address |
| 36b.e reject | a fallback key's validator address is computed from its 33-byte compressed encoding | violates ENC-A-36b and CONS-3.1-3                                      |

## ENC-A-36c

| Vector       | Setup                                                                                                | Expected                                                                                                |
| ------------ | ---------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------- |
| 36c.a accept | seat 0 holds K1 with power 100,000 and seat 2 holds K2 with power 250,000; every other seat is empty | `snapshot()` returns the members (0, 0x02, K1's X, 100000) and (2, 0x02, K2's X, 250000), in that order |
| 36c.b reject | `snapshot()` lists the members of 36c.a by descending power, seat 2 first                            | violates ENC-A-36c and STAKE-4.2-7 (ascending seat order)                                               |
| 36c.c reject | `snapshot()` lists seat 1 of 36c.a as an all-zero entry                                              | violates ENC-A-36c and STAKE-4.2-7 (occupied records only)                                              |
| 36c.d reject | a node or guest takes the candidate from `snapshot()` instead of the snapshot seat records           | violates ENC-A-36c and COMM-4.3-3                                                                       |
| 36c.e reject | `seat` or `power` is returned as a uint256                                                           | violates ENC-A-36c                                                                                      |

## ENC-A-36d

| Vector       | Setup                                                                                                                                  | Expected                                                                                                                                                                                              |
| ------------ | -------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 36d.a accept | `setFallbackKeys` stores a list of one key (prefix 0x02, X)                                                                            | one log with topic0 `0xad67b35e197f2041d061711ea23ef099f669424769b341298aaa52161dd9f88c`, topic1 the list's `fallbackKeysHash` and 128 bytes of data: `0x20`, the length 1, the word 2 and the word X |
| 36d.b accept | Inbox initialization stores a list of 128 keys                                                                                         | the same event with that list's hash as topic1 and 2 + 2 × 128 = 258 data words, the keys in their stored order                                                                                       |
| 36d.c reject | `fallbackKeysHash` is written to the data instead of to topic1                                                                         | violates ENC-A-36d (`indexed`)                                                                                                                                                                        |
| 36d.d reject | topic0 is computed over another signature, such as `FallbackKeysUpdated(bytes32,bytes)` or one that lists the key fields as two arrays | violates ENC-A-36d                                                                                                                                                                                    |
| 36d.e accept | a node holds only `fallbackKeysHash` H                                                                                                 | it finds the list as the data of the `FallbackKeysUpdated` log whose topic1 is H (SYNC-9-16)                                                                                                          |

## ENC-A-36e

| Vector       | Setup                                                         | Expected                                                                                                                                          |
| ------------ | ------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------- |
| 36e.a accept | `setMinTotalStake(2^256 − 1)`                                 | one log with the single topic `0xfd570c3cd5a2dd2e25a4647876d87fd36c533b77efb87ca66499f6cec64a25a1` and one data word `0xff…ff` (32 bytes of 0xff) |
| 36e.b accept | Inbox initialization with `minTotalStake` = M                 | the same event with M as its data word                                                                                                            |
| 36e.c reject | `value` is indexed, so the log has a second topic and no data | violates ENC-A-36e                                                                                                                                |

## ENC-A-43

| Vector      | Setup                                                             | Expected                       |
| ----------- | ----------------------------------------------------------------- | ------------------------------ |
| 43.a accept | `uvarint(len(cv))` followed by `cv`                               | matches CometBFT VoteSignBytes |
| 43.b reject | the length prefix is omitted                                      | violates ENC-A-43              |
| 43.c reject | the length prefix is a fixed 8-byte integer rather than a uvarint | violates ENC-A-43              |
| 43.d reject | the length prefix does not equal `len(cv)`                        | violates ENC-A-43              |

## ENC-A-44

| Vector      | Setup                                                             | Expected                                                                                       |
| ----------- | ----------------------------------------------------------------- | ---------------------------------------------------------------------------------------------- |
| 44.a accept | fields in order: type, height, round, blockId, timestamp, chainId | matches                                                                                        |
| 44.b reject | height is big-endian rather than 8-byte little-endian             | violates ENC-A-44 (height field)                                                               |
| 44.c reject | the chainId field is omitted                                      | violates ENC-A-44                                                                              |
| 44.d reject | blockId precedes round                                            | violates ENC-A-44 (order)                                                                      |
| 44.e reject | type is 3 (not prevote 1 or precommit 2)                          | violates ENC-A-44 (type values)                                                                |
| 44.f accept | a nil vote: both hashes empty and total 0                         | the blockId field is omitted; `cv` holds the type, height, round, timestamp and chainId fields |

## ENC-A-45

| Vector      | Setup                                                                                                      | Expected                                                                                                                                      |
| ----------- | ---------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------- |
| 45.a accept | numeric fields shown in `[]` are omitted when zero, hash fields only when empty; `len` is a uvarint prefix | matches                                                                                                                                       |
| 45.b reject | a zero numeric field is written explicitly instead of omitted                                              | violates ENC-A-45                                                                                                                             |
| 45.c reject | the blockId of a nil vote is written with length 0 instead of omitted                                      | violates ENC-A-44 ("omitted for a nil vote")                                                                                                  |
| 45.d accept | timestamp is written even when zero                                                                        | "always written"                                                                                                                              |
| 45.e reject | timestamp is omitted when zero                                                                             | violates ENC-A-45                                                                                                                             |
| 45.f reject | a length prefix is not a uvarint                                                                           | violates ENC-A-45                                                                                                                             |
| 45.g accept | a vote timestamp of seconds = −1 and nanos = 0                                                             | the seconds field is `08 ff ff ff ff ff ff ff ff ff 01` (ten varint bytes), and the timestamp field is `2a 0b` followed by those eleven bytes |
| 45.h reject | seconds = −1 is written as a varint shorter than ten bytes                                                 | violates ENC-A-45                                                                                                                             |
| 45.i accept | a hash or partsHash field contains 32 zero bytes                                                           | the field is present with its tag, length 32 and all 32 zero bytes                                                                            |
| 45.j reject | a present 32-byte zero hash is omitted as if empty                                                         | violates ENC-A-45                                                                                                                             |
| 45.k accept | both hash fields contain 32 zero bytes and total = 0                                                       | the non-nil blockId is present; only the zero total is omitted                                                                                |

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

| Vector       | Setup                                                                                                                                                                                                                                                      | Expected           |
| ------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------ |
| 49a.a accept | `registerDigest = keccak256(0x1901 ‖ domainSeparator ‖ keccak256(abi.encode(keccak256("Register(address owner)"), owner)))`; the EIP-712 domain is name "EtnaStaking", version "1", chainId = the L2 chain id, verifyingContract = the L2 staking contract | matches            |
| 49a.b reject | the domain uses the L1 chain id                                                                                                                                                                                                                            | violates ENC-A-49a |
| 49a.c reject | `verifyingContract` is the Inbox                                                                                                                                                                                                                           | violates ENC-A-49a |
| 49a.d reject | the struct hash omits `owner` or uses another type string                                                                                                                                                                                                  | violates ENC-A-49a |
| 49a.e reject | the domain name is not "EtnaStaking", or the version is not "1"                                                                                                                                                                                            | violates ENC-A-49a |

## ENC-A-50

| Vector      | Setup                                                                 | Expected          |
| ----------- | --------------------------------------------------------------------- | ----------------- |
| 50.a accept | exactly 65 bytes `R, S, V`; `V` in {0,1}, `0 < R < n`, `0 < S <= n/2` | matches           |
| 50.b reject | 64 or 66 bytes                                                        | violates ENC-A-50 |
| 50.c reject | `R = 0`                                                               | violates ENC-A-50 |
| 50.d reject | `S = 0` or `S > n/2`                                                  | violates ENC-A-50 |
| 50.e reject | `V = 2`                                                               | violates ENC-A-50 |

## ENC-A-52

| Vector      | Setup                                                                                                                 | Expected                                                                                  |
| ----------- | --------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------- |
| 52.a accept | `invalidateRecoveryNonce` called by the Inbox owner                                                                   | conforms                                                                                  |
| 52.b reject | `invalidateRecoveryNonce` called by the staking contract's owner or the DAO, when that address is not the Inbox owner | violates ENC-A-52 (Inbox owner only)                                                      |
| 52.c accept | the Inbox owner calls `invalidateRecoveryNonce(n)` while the nonce is n                                               | the Inbox emits `RecoveryNonceInvalidated(n, n + 1)`, both values `uint256` (RECOV-8.3-9) |
| 52.d reject | the staking contract emits `RecoveryNonceInvalidated`                                                                 | violates ENC-A-52 (an Inbox event)                                                        |

## ENC-A-53

| Vector      | Setup                                                                                     | Expected          |
| ----------- | ----------------------------------------------------------------------------------------- | ----------------- |
| 53.a accept | `recoveryNonce` is a `uint256`; `recover`'s `validUntil` is a `uint256` L1 Unix timestamp | conforms          |
| 53.b reject | `recover`'s `validUntil` is compared against L2 block time rather than L1 Unix seconds    | violates ENC-A-53 |

## ENC-A-54

| Vector      | Setup                                                                                                           | Expected                         |
| ----------- | --------------------------------------------------------------------------------------------------------------- | -------------------------------- |
| 54.a accept | `forfeit(bondId, incidentId, validUntil)` with exactly those three arguments, called on the L2 staking contract | conforms                         |
| 54.b reject | a call that omits `incidentId` or supplies a different argument list                                            | violates ENC-A-54                |
| 54.c accept | `topUp(bondId, amount)` with a `uint256` bond id and a `uint256` amount                                         | conforms                         |
| 54.d reject | `topUp` takes the amount before the bond id                                                                     | violates ENC-A-54                |
| 54.e reject | `forfeit`'s `validUntil` is compared with an L1 timestamp rather than the L2 `block.timestamp`                  | violates ENC-A-54 and FORF-4.4-6 |

## ENC-A-55

| Vector      | Setup                                                                                                 | Expected                                                               |
| ----------- | ----------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------- |
| 55.a accept | the staking contract's owner forfeits an issued `bondId` once                                         | conforms                                                               |
| 55.b reject | the Inbox owner, or any address other than the staking contract's owner, calls `forfeit`              | violates ENC-A-55 (owner only) and FORF-4.4-1                          |
| 55.c reject | a second `forfeit` for the same lifetime `bondId`                                                     | violates ENC-A-55 (once per issued bondId)                             |
| 55.d reject | any call that attempts to revoke or reset a forfeiture via a nonce                                    | violates ENC-A-55 (no forfeiture nonce or revocation)                  |
| 55.h accept | key K belongs to bond 0 in seat 0; query `bondForKey(ckAddr(K))`, `bondInSeat(0)` and `seatOfBond(0)` | each returns `(true, 0)` under the specified external-view ABI         |
| 55.i accept | query an unused key, an empty seat or an unissued bond id through its corresponding lookup            | returns `(false, 0)`; the read does not issue a bond                   |
| 55.j accept | withdraw bond 0, then query its key and `seatOfBond(0)`                                               | key lookup returns `(true, 0)`; seat lookup returns `(false, 0)`       |
| 55.k accept | `bondInSeat(n_max)` or a higher seat number is queried                                                | returns `(false, 0)` (ENC-A-55, STAKE-4.1-14d)                         |
| 55.l reject | `bondInSeat(n_max)` reverts, or returns a bond                                                        | violates ENC-A-55 and STAKE-4.1-14d                                    |
| 55.m accept | a top-up emits `TopUpDeposited(bondId, amount)` with two `uint256` values                             | conforms                                                               |
| 55.n accept | `snapshot()` is called                                                                                | returns `(uint256 height, uint256 totalStake, SeatMember[] members)`   |
| 55.o accept | the word at T has a bit at or above bit 48 set                                                        | `snapshot()` returns that whole word as `height`, unmasked (STOR-B-21) |
| 55.p reject | `snapshot()` returns `height` as a `uint48`, or masks the word at T                                   | violates ENC-A-55 ("height is the whole word at T")                    |

## Not covered

Everything below is a question, not a vector. Each has an entry in [review/A.md](../review/A.md).

| Rule                | Gap                                                                                                                                  | Question                      |
| ------------------- | ------------------------------------------------------------------------------------------------------------------------------------ | ----------------------------- |
| ENC-A-6 to ENC-A-55 | whether the now-citable blocks should still be restructured into prose or tables                                                     | [Q-A-1](../review/A.md#q-a-1) |
| ENC-A-24, ENC-A-25a | whether an out-of-order, extra or missing witness slot list makes a witness invalid; the order is now stated, the consequence is not | [Q-A-4](../review/A.md#q-a-4) |
| Shared vectors      | the obligation itself is un-numbered and has no owner                                                                                | [Q-A-5](../review/A.md#q-a-5) |
