# B — accept/reject vectors

**Non-normative.** Rule text lives in [SPEC.md](../../SPEC.md). Appendix B states a layout; a vector here takes a claimed layout or a piece of data and says whether it is the layout the text states. Where the text states a requirement but **not the consequence of violating it**, the vector says "violates STOR-B-n" and does not name an outcome. Anything undetermined has no vector; it is listed under "Not covered" and raised in [review/B.md](../review/B.md).

`accept` means the claimed layout or data is the one Appendix B states. `reject` means it contradicts the text. Appendix B names one enforcement consequence of its own — "Writing a value wider than its field reverts" (STOR-B-25) — so only those vectors say `reverts`. It also restates two from 4.3: a snapshot seat record with a nonzero unused bit (STOR-B-21a, COMM-4.3-8), and a `snapshotHeight` word with a bit set at or above bit 48 (STOR-B-21, COMM-4.3-3a), make the candidate unusable. Every other reject is a violation whose consequence is [Q-B-4](../review/B.md#q-b-4), unless the row cites the rule that states one.

## STOR-B-1

| Vector     | Claimed layout or data                                                | Expected                                     |
| ---------- | --------------------------------------------------------------------- | -------------------------------------------- |
| 1.a accept | Inbox initialized; slot 258 reads 3                                   | matches                                      |
| 1.b reject | Inbox initialized; slot 258 reads 0 or 1                              | violates STOR-B-1 ("3 after initialization") |
| 1.c accept | anchor witness proves the Inbox slots it normally proves, and not 258 | matches "not in the anchor witness"          |
| 1.d reject | anchor witness includes a proof for slot 258                          | violates STOR-B-1                            |

## STOR-B-2

| Vector     | Claimed layout or data                                   | Expected                                 |
| ---------- | -------------------------------------------------------- | ---------------------------------------- |
| 2.a accept | 268 holds `recoveryGeneration`, 269 holds `configHash`   | matches                                  |
| 2.b reject | 269 holds `recoveryGeneration`, 268 holds `configHash`   | violates STOR-B-2                        |
| 2.c reject | `configHash` alone at 268, `recoveryGeneration` unplaced | violates STOR-B-2 (both slots are named) |

## STOR-B-3

| Vector     | Claimed layout or data                                    | Expected                      |
| ---------- | --------------------------------------------------------- | ----------------------------- |
| 3.a accept | 270 holds the `lastCheckpoint` height, 271 holds its hash | matches                       |
| 3.b reject | 270 holds the hash, 271 holds the height                  | violates STOR-B-3             |
| 3.c reject | height and hash packed into one word at 270               | violates STOR-B-3 (two slots) |

## STOR-B-4

| Vector     | Claimed layout or data                                                                                  | Expected                                         |
| ---------- | ------------------------------------------------------------------------------------------------------- | ------------------------------------------------ |
| 4.a accept | 272 packs `[genesisHeight, L1_0]` with genesisHeight = S, 273 holds the start's hash, 274 its stateRoot | matches                                          |
| 4.b reject | 273 holds the start's stateRoot, 274 the start's hash                                                   | violates STOR-B-4                                |
| 4.c reject | the start's hash stored at 272 beside the packed start word                                             | violates STOR-B-4                                |
| 4.d reject | 272 packs a third nonzero field above `L1_0`                                                            | violates STOR-B-4 (and STOR-B-24)                |
| 4.e reject | 272 is nonzero after Inbox initialization and before the start write                                    | violates STOR-B-4 ("written by the start write") |

## STOR-B-5

| Vector     | Claimed layout or data                                                                                     | Expected                                                                     |
| ---------- | ---------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------- |
| 5.a accept | 278 holds `fallbackKeysHash` and 279 holds `minTotalStake`, both set at Inbox initialization               | matches                                                                      |
| 5.b reject | 278 holds `minTotalStake`, 279 the hash                                                                    | violates STOR-B-5                                                            |
| 5.c accept | an anchor witness proves 278 and 279                                                                       | matches ("part of every anchor witness")                                     |
| 5.d reject | an anchor witness omits 278 or 279                                                                         | violates STOR-B-5 and ENC-A-25a; consequence — [Q-A-4](../review/A.md#q-a-4) |
| 5.e reject | 279 changes in a call other than Inbox initialization or `setMinTotalStake`                                | violates STOR-B-5 ("changed only by")                                        |
| 5.f accept | the list `getFallbackKeys()` returns hashes under ENC-A-36a to the value of 278                            | matches                                                                      |
| 5.g reject | a guest accepts a fallback key list whose hash under ENC-A-36a differs from the 278 that its anchor proves | violates STOR-B-5 and COMM-4.3-3a                                            |

## STOR-B-6

| Vector     | Claimed layout or data                                                                                                | Expected                                    |
| ---------- | --------------------------------------------------------------------------------------------------------------------- | ------------------------------------------- |
| 6.a accept | each 280 entry is two words: word 1 `txHash`, word 2 packs timestamp and L1 block number with the remaining bits zero | matches                                     |
| 6.b accept | an entry's `txHash` is replaced with `keccak256("")` by section 8 governance recovery                                 | matches                                     |
| 6.c reject | a third word per entry holding a charge                                                                               | violates STOR-B-6 ("No charge is stored")   |
| 6.d reject | nonzero bits above the packed timestamp and L1 block number                                                           | violates STOR-B-6 ("remaining bits zero")   |
| 6.e reject | an entry's `txHash` rewritten by `land` or by any path other than section 8 recovery                                  | violates STOR-B-6 ("changes only when ...") |
| 6.f reject | 281 holds `head` and 282 holds `tail`                                                                                 | violates STOR-B-6 (282 is the delay pair)   |

## STOR-B-7

| Vector     | Claimed layout or data                                                       | Expected                        |
| ---------- | ---------------------------------------------------------------------------- | ------------------------------- |
| 7.a accept | 282 holds `forcedInclusionDelay` and `maxAnchorAge`; 1152 means 1152 seconds | matches                         |
| 7.b reject | `maxAnchorAge` stored in milliseconds (1,152,000 for 1152 s)                 | violates STOR-B-7 ("(seconds)") |
| 7.c reject | `forcedInclusionDelay` at 282 and `maxAnchorAge` at 283                      | violates STOR-B-7               |

## STOR-B-8

| Vector     | Claimed layout or data                         | Expected                           |
| ---------- | ---------------------------------------------- | ---------------------------------- |
| 8.a accept | 283 and 284 are never read, written or reused  | matches                            |
| 8.c reject | a node reads 283 as proof input                | violates STOR-B-8                  |
| 8.d reject | a value written to 284 at Inbox initialization | violates STOR-B-8                  |
| 8.e reject | 283 reused for a later parameter               | violates STOR-B-8 ("no ... reuse") |
| 8.f reject | an anchor witness or a guest reads 284         | violates STOR-B-8                  |

## STOR-B-9

| Vector     | Claimed layout or data                                                                                                              | Expected                                                                       |
| ---------- | ----------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------ |
| 9.a accept | the record for h is three words: word 1 packs actual parentHeight=c, generation and head; words 2 and 3 are the EL and Comet hashes | matches                                                                        |
| 9.b accept | the start record at S has parent S, generation 0, head 0, EL hash equal to the start's hash and Comet hash 0                        | matches                                                                        |
| 9.c accept | a proof with origin p reads its own retained record at p after later landings                                                       | matches ("never pruned")                                                       |
| 9.d reject | the record for h stores proof origin p as parentHeight when p is below c                                                            | violates STOR-B-9 ("actual parentHeight=c")                                    |
| 9.e reject | a later landing overwrites the record at an older origin p                                                                          | violates STOR-B-9                                                              |
| 9.f reject | the start record carries the start's hash as its Comet hash                                                                         | violates STOR-B-9 ("Comet hash 0")                                             |
| 9.g accept | S = 1000 with start hash H                                                                                                          | landings[1000] is (parent 1000, generation 0, head 0, EL hash H, Comet hash 0) |
| 9.i reject | the record carries a fourth word, for example a validator-state hash                                                                | violates STOR-B-9 ("three words")                                              |

## STOR-B-10

| Vector      | Claimed layout or data                        | Expected           |
| ----------- | --------------------------------------------- | ------------------ |
| 10.a accept | 286 and 287 are never read, written or reused | matches            |
| 10.b reject | a value written to 286 at initialization      | violates STOR-B-10 |
| 10.c reject | 287 reused for a later parameter              | violates STOR-B-10 |

## STOR-B-11

| Vector      | Claimed layout or data                             | Expected           |
| ----------- | -------------------------------------------------- | ------------------ |
| 11.a accept | 288 is never read, written or reused               | matches            |
| 11.b reject | a read of 288 during startup or proof verification | violates STOR-B-11 |
| 11.c reject | 288 reused for a later parameter                   | violates STOR-B-11 |

## STOR-B-12

| Vector      | Claimed layout or data                          | Expected           |
| ----------- | ----------------------------------------------- | ------------------ |
| 12.a accept | 289 is never read, written or reused            | matches            |
| 12.b reject | a read of 289 during a cold sync or proof check | violates STOR-B-12 |
| 12.c reject | 289 reused for a later parameter                | violates STOR-B-12 |

## STOR-B-13

| Vector      | Claimed layout or data                                                                                                  | Expected                                                     |
| ----------- | ----------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------ |
| 13.a accept | per generation, four consecutive words from the mapping base: startHeight, l1BlockNumber, l1Timestamp, fallbackKeysHash | matches                                                      |
| 13.b accept | generation 0 has a record, written under 8.4                                                                            | matches ("Includes generation 0")                            |
| 13.c reject | a gap between the words (l1Timestamp not at base+2, or fallbackKeysHash not at base+3)                                  | violates STOR-B-13                                           |
| 13.d reject | a record written without the height, block and timestamp range checks                                                   | violates STOR-B-13                                           |
| 13.e reject | a cached latest origin read instead of the per-generation record                                                        | violates STOR-B-13                                           |
| 13.f reject | the current generation's origin record added to the ordinary anchor witness                                             | violates STOR-B-13                                           |
| 13.g reject | an existing generation's record overwritten by a later recovery                                                         | violates STOR-B-13 (fixed per generation; 8.4: written once) |
| 13.h accept | `setFallbackKeys` stores the hash F2 in 278, then a recovery writes generation 1's record                               | the record's fourth word is F2                               |
| 13.i reject | a later `setFallbackKeys` changes the fourth word of generation 1's record                                              | violates STOR-B-13 (fixed per generation)                    |
| 13.j reject | the record has three words, without fallbackKeysHash                                                                    | violates STOR-B-13 ("four consecutive words")                |

## STOR-B-14

| Vector      | Claimed layout or data               | Expected           |
| ----------- | ------------------------------------ | ------------------ |
| 14.a accept | 291 is never read, written or reused | matches            |
| 14.b reject | a write to 291 during recovery       | violates STOR-B-14 |
| 14.c reject | 291 reused for a later parameter     | violates STOR-B-14 |

## STOR-B-15

| Vector      | Claimed layout or data                                                                                   | Expected                                       |
| ----------- | -------------------------------------------------------------------------------------------------------- | ---------------------------------------------- |
| 15.a accept | 292 holds `recoveryNonce` as a uint256, 0 at initialization                                              | matches                                        |
| 15.b accept | `recoveryNonce` is incremented by recover and preserved-and-incremented by the verifier-failure rollback | matches                                        |
| 15.c reject | the rollback restores an older `recoveryNonce`                                                           | violates STOR-B-15 ("monotonically increased") |
| 15.d reject | `recoveryNonce` stored in fewer than 256 bits                                                            | violates STOR-B-15 ("uint256")                 |
| 15.e reject | `recoveryNonce` included in an ordinary anchor witness                                                   | violates STOR-B-15                             |

## STOR-B-15a

| Vector       | Claimed layout or data                                                                           | Expected                                                      |
| ------------ | ------------------------------------------------------------------------------------------------ | ------------------------------------------------------------- |
| 15a.a accept | slot 293 packs `activeRules`, `nextRules`, `rulesTime`, `stopTime` and is 0 after initialization | matches                                                       |
| 15a.b reject | slot 293 is written by a call other than `scheduleRules`, `scheduleStop` or `recover`            | violates STOR-B-15a                                           |
| 15a.c reject | the anchor witness omits slot 293                                                                | violates STOR-B-15a and ENC-A-25a; block invalid (3.4 rule 2) |

## STOR-B-16

| Vector      | Claimed layout or data                                                                                                                               | Expected           |
| ----------- | ---------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------ |
| 16.a accept | the node verifies the latest checkpoint under 3.3/3.4, its slot-285 record under section 9, and slot 290 for startup, recovery and proving under 8.4 | matches            |
| 16.b reject | the node trusts the latest checkpoint without reading its slot-285 record                                                                            | violates STOR-B-16 |
| 16.c reject | a startup path skips the slot-290 record                                                                                                             | violates STOR-B-16 |

## STOR-B-17

| Vector      | Claimed layout or data                                         | Expected           |
| ----------- | -------------------------------------------------------------- | ------------------ |
| 17.a accept | 283, 284, 286, 287, 288, 289 and 291 are never read or written | matches            |
| 17.b reject | a replay path reads 289                                        | violates STOR-B-17 |
| 17.c reject | a write to 286                                                 | violates STOR-B-17 |
| 17.d reject | an exit or withdrawal path reads or writes 284                 | violates STOR-B-17 |

## STOR-B-18

| Vector      | Claimed layout or data                                        | Expected                                                 |
| ----------- | ------------------------------------------------------------- | -------------------------------------------------------- |
| 18.a accept | the only recovery-related Inbox storage is the slot-292 nonce | matches                                                  |
| 18.b reject | the Inbox stores a recovery queue                             | violates STOR-B-18                                       |
| 18.c reject | the Inbox stores a scheduled recovery or a stall timer        | violates STOR-B-18                                       |
| 18.d accept | the Inbox also stores the rules schedule in slot 293          | consistent with STOR-B-18 (separate from recovery, 10.1) |

## STOR-B-19

| Vector      | Claimed layout or data                                           | Expected                                     |
| ----------- | ---------------------------------------------------------------- | -------------------------------------------- |
| 19.a accept | a node does not decode a layout unlike Appendix B                | matches                                      |
| 19.b reject | a node decodes an Inbox whose slots are assigned differently     | violates STOR-B-19                           |
| 19.c reject | an in-place migration rewrites an existing Inbox to a new layout | violates STOR-B-19 ("nor migrated in place") |

## STOR-B-20

| Vector      | Claimed layout or data                                                                                                                                                                                          | Expected                                                                 |
| ----------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------ |
| 20.a accept | the staking storage that nodes and guests read is rooted at T = `keccak256(abi.encode(uint256(keccak256("taiko.etna.staking")) - 1)) & ~bytes32(uint256(0xff))`, the ERC-7201 base slot of `taiko.etna.staking` | T = `0x5cfa9ae4fa3ccb6db5189dbaff84335bb566ebd2f7442638272a1d81ccb19e00` |
| 20.b reject | that storage is rooted at the base slot of a different namespace id                                                                                                                                             | violates STOR-B-20                                                       |
| 20.c reject | T is set to an arbitrary constant unrelated to that namespace                                                                                                                                                   | violates STOR-B-20                                                       |
| 20.d reject | the namespace lives in an L1 contract                                                                                                                                                                           | violates STOR-B-20 (the L2 staking contract)                             |

## STOR-B-21

T is the base slot of 20.a.

| Vector      | Claimed layout or data                                                                      | Expected                                                                                                                                  |
| ----------- | ------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------- |
| 21.a accept | `snapshotHeight` at T with every bit at or above bit 48 zero; `snapshotTotalStake` at T + 1 | matches                                                                                                                                   |
| 21.k reject | at H, the word at T has bit 48 set and its low 48 bits equal H                              | the candidate is not usable: "a word with any of those bits set never equals H and makes the candidate unusable" (STOR-B-21, COMM-4.3-3a) |
| 21.l reject | a node or guest masks the word at T to its low 48 bits before comparing it with H           | violates STOR-B-21 ("in all 256 bits without masking") and COMM-4.3-3a                                                                    |
| 21.b accept | snapshot seat record 5                                                                      | word 1 at T + 13, word 2 at T + 14                                                                                                        |
| 21.c accept | snapshot seat record 127                                                                    | word 1 at T + 257 = `0x5cfa9ae4fa3ccb6db5189dbaff84335bb566ebd2f7442638272a1d81ccb19f01`, word 2 at T + 258                               |
| 21.d accept | n_max = 64                                                                                  | nodes and guests still read all 128 records, from T + 3 to T + 258 ("whatever n_max is")                                                  |
| 21.e reject | a node reads only the first n_max records                                                   | violates STOR-B-21 and COMM-4.3-3                                                                                                         |
| 21.f accept | the key-to-seat element for `ckAddr` = `0x7E5F4552091A69125d5DfCb7b8C2659029395Bdf`         | at `keccak256(abi.encode(ckAddr, T + 2))` = `0x5aed0c9b66e2d0fa057ebed89e910688ada65f4c543b321333450c21264ccf27`                          |
| 21.g reject | a record's word 1 is the packed word and word 2 is `ckX`                                    | violates STOR-B-21                                                                                                                        |
| 21.h reject | a node reads miss counts, forfeiture flags or bond records to decide the candidate          | violates STOR-B-21 ("only these words")                                                                                                   |
| 21.i reject | a node decides H's candidate from the records in H's parent's post-state                    | violates STOR-B-21 and COMM-4.3-3                                                                                                         |
| 21.j reject | a node sets block H's missBitmap from the key-to-seat mapping in H's own post-state         | violates STOR-B-21 and STAKE-4.2-5                                                                                                        |

## STOR-B-21a

| Vector       | Claimed layout or data                                                                                                                                    | Expected                                                                                                     |
| ------------ | --------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------ |
| 21a.a accept | both words of record s are zero                                                                                                                           | seat s is empty                                                                                              |
| 21a.b accept | record s has word 1 = `0x79be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798` and word 2 = `0x3d09002`, that is ckPrefix 2 and power 250,000 | a member with the key `(0x02, word 1)` and power 250,000                                                     |
| 21a.c reject | the record of 21a.b with bit 72 of word 2 also set, just above `power`                                                                                    | the candidate is not usable (COMM-4.3-8)                                                                     |
| 21a.d accept | word 1 is nonzero and word 2 is zero                                                                                                                      | a member with ckPrefix 0, so the candidate is not usable (COMM-4.3-4)                                        |
| 21a.e reject | the contract leaves a nonzero record at s = n_max                                                                                                         | violates STOR-B-21a ("keeps the records at or above n_max zero"); nodes and guests still read it as a member |
| 21a.f reject | a node skips a nonzero record because its seat number is at or above n_max                                                                                | violates STOR-B-21a ("any other record is a member") and COMM-4.3-3                                          |

## STOR-B-21b

| Vector       | Claimed layout or data                                                                         | Expected                                                                                                                       |
| ------------ | ---------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------ |
| 21b.a accept | a bond registers in block X and takes seat 5                                                   | in X's post-state its key maps to `0x0501` (holdsSeat 1, seat 5); T, T + 1 and the records are as X's `onBlockStart` left them |
| 21b.b reject | a `topUp` or `requestExit` transaction rewrites a snapshot seat record or `snapshotTotalStake` | violates STOR-B-21b and STAKE-4.2-7                                                                                            |
| 21b.c accept | the bond of 21b.a requests an exit in block Y                                                  | in Y's post-state its key maps to 0                                                                                            |
| 21b.d reject | the key-to-seat mapping changes only at the next `onBlockStart`                                | violates STOR-B-21b ("updates it in that call")                                                                                |
| 21b.e accept | a key no bond registered, or the key of a withdrawn bond                                       | maps to 0                                                                                                                      |
| 21b.f reject | after the bond of 21b.a releases seat 5, its key maps to `0x0500` (holdsSeat 0, seat 5 kept)   | violates STOR-B-21b ("maps to 0")                                                                                              |

## STOR-B-22

| Vector      | Claimed layout or data                                                | Expected                                   |
| ----------- | --------------------------------------------------------------------- | ------------------------------------------ |
| 22.a accept | an issued bond's `exitHeight` is 2^48 − 1                             | no exit is set                             |
| 22.b reject | `exitHeight` = 2^48 − 1 is treated as an exit set at that L2 height   | violates STOR-B-22                         |
| 22.c accept | default storage at an unissued id, with `exitHeight` 0                | neither a bond nor an exit (STAKE-4.1-13a) |
| 22.d reject | an unissued id's zero `exitHeight` is read as an exit set at height 0 | violates STOR-B-22                         |

## STOR-B-23

| Vector      | Claimed layout or data                                                                              | Expected                                                                    |
| ----------- | --------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------- |
| 23.a accept | slot 272: `genesisHeight` in the least-significant 48 bits, `L1_0` next                             | matches                                                                     |
| 23.b accept | slot 285 word 1: parentHeight c in the least-significant field, then generation, then head          | matches                                                                     |
| 23.c reject | slot 272 with `L1_0` in the least-significant 48 bits                                               | violates STOR-B-23                                                          |
| 23.d reject | slot 285 word 1 with `head` in the least-significant field                                          | violates STOR-B-23                                                          |
| 23.e accept | slot 293: `activeRules` in the least-significant 48 bits, then `nextRules`, `rulesTime`, `stopTime` | matches                                                                     |
| 23.f reject | slot 293 with `stopTime` in the least-significant 48 bits                                           | violates STOR-B-23                                                          |
| 23.g accept | a key whose bond holds seat 5                                                                       | its key-to-seat value is `0x0501`: holdsSeat in bits 0–7, seat in bits 8–15 |
| 23.h accept | record word 2 for ckPrefix 3 and power 250,000                                                      | `0x3d09003`: ckPrefix in bits 0–7, power in bits 8–71                       |
| 23.i reject | record word 2 with `power` in the least-significant bits and `ckPrefix` above it                    | violates STOR-B-23                                                          |

## STOR-B-24

| Vector      | Claimed layout or data                                                                           | Expected           |
| ----------- | ------------------------------------------------------------------------------------------------ | ------------------ |
| 24.a accept | record word 2 with `ckPrefix` in 8 bits, `power` in the 64 bits above it and the other bits zero | matches            |
| 24.b accept | a 48-bit field holding 2^48 − 1 with no bits above it                                            | matches            |
| 24.c reject | a 16-bit `ckPrefix` field                                                                        | violates STOR-B-24 |
| 24.d reject | nonzero bits above the highest used field                                                        | violates STOR-B-24 |
| 24.e accept | a key-to-seat value with holdsSeat and seat in 8 bits each and every bit from bit 16 up zero     | matches            |
| 24.f reject | `power` stored in a 48-bit field                                                                 | violates STOR-B-24 |

## STOR-B-25

| Vector      | Claimed layout or data                                       | Expected         |
| ----------- | ------------------------------------------------------------ | ---------------- |
| 25.a accept | writing 2^48 − 1 into a 48-bit field                         | succeeds         |
| 25.b reject | writing 2^48 into a 48-bit field                             | reverts (stated) |
| 25.c reject | writing a 256-bit value into the 8-bit `ckPrefix` field      | reverts (stated) |
| 25.d reject | writing a power of 2^64 into a record's 64-bit `power` field | reverts (stated) |

## Not covered

Everything below is a question, not a vector. Each has an entry in [review/B.md](../review/B.md).

| Rule                   | Gap                                                                                                                                                                                   | Question                      |
| ---------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------- |
| STOR-B-9, STOR-B-13    | the storage-key derivation for the 285 landing record and the 290 origin record (mapping element base, and whether its three (285) or four (290) words are consecutive) is not stated | [Q-B-1](../review/B.md#q-b-1) |
| all sections           | slots that the table does not list (259–267, 275–277, 294 and above) have no stated disposition                                                                                       | [Q-B-2](../review/B.md#q-b-2) |
| STOR-B-24, STOR-B-25   | read-side handling of an Inbox packed word whose fields exceed their width or whose unused bits are nonzero                                                                           | [Q-B-3](../review/B.md#q-b-3) |
| STOR-B-16 to STOR-B-22 | consequence of a layout violation that states no consequence                                                                                                                          | [Q-B-4](../review/B.md#q-b-4) |
| STOR-B-9               | whether "never pruned" is a requirement with an enforcement path or an operational promise                                                                                            | [Q-B-5](../review/B.md#q-b-5) |
