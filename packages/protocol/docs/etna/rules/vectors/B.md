# B — accept/reject vectors

**Non-normative.** Rule text lives in [SPEC.md](../../SPEC.md). Appendix B states a layout; a vector here takes a claimed layout or a piece of data and says whether it is the layout the text states. Where the text states a requirement but **not the consequence of violating it**, the vector says "violates STOR-B-n" and does not name an outcome. Anything undetermined has no vector; it is listed under "Not covered" and raised in [review/B.md](../review/B.md).

`accept` means the claimed layout or data is the one Appendix B states. `reject` means it contradicts the text. Appendix B names an enforcement consequence only once — "Writing a value wider than its field reverts" (STOR-B-25) — so only that vector says `reverts`; every other reject is a violation whose consequence is [Q-B-4](../review/B.md#q-b-4).

## STOR-B-1

| Vector     | Claimed layout or data                                                | Expected                                     |
| ---------- | --------------------------------------------------------------------- | -------------------------------------------- |
| 1.a accept | Inbox initialized; slot 258 reads 3                                   | matches                                      |
| 1.b reject | Inbox initialized; slot 258 reads 0 or 1                              | violates STOR-B-1 ("3 after initialization") |
| 1.c accept | anchor witness proves the Inbox slots it normally proves, and not 258 | matches "not in the anchor witness"          |
| 1.d reject | anchor witness includes a proof for slot 258                          | violates STOR-B-1                            |

## STOR-B-2

| Vector     | Claimed layout or data                                            | Expected                                 |
| ---------- | ----------------------------------------------------------------- | ---------------------------------------- |
| 2.a accept | 268 holds `recoveryGeneration`, 269 holds `committeeConfigHash`   | matches                                  |
| 2.b reject | 269 holds `recoveryGeneration`, 268 holds `committeeConfigHash`   | violates STOR-B-2                        |
| 2.c reject | `committeeConfigHash` alone at 268, `recoveryGeneration` unplaced | violates STOR-B-2 (both slots are named) |

## STOR-B-3

| Vector     | Claimed layout or data                                    | Expected                      |
| ---------- | --------------------------------------------------------- | ----------------------------- |
| 3.a accept | 270 holds the `lastCheckpoint` height, 271 holds its hash | matches                       |
| 3.b reject | 270 holds the hash, 271 holds the height                  | violates STOR-B-3             |
| 3.c reject | height and hash packed into one word at 270               | violates STOR-B-3 (two slots) |

## STOR-B-4

| Vector     | Claimed layout or data                                                                      | Expected          |
| ---------- | ------------------------------------------------------------------------------------------- | ----------------- |
| 4.a accept | 272 packs `[genesisHeight, L1_0, L]`, 273 holds the genesis hash, 274 the genesis stateRoot | matches           |
| 4.b reject | 273 holds the genesis stateRoot, 274 the genesis hash                                       | violates STOR-B-4 |
| 4.c reject | the genesis hash stored at 272 beside the packed genesis word                               | violates STOR-B-4 |

## STOR-B-5

| Vector     | Claimed layout or data                                         | Expected          |
| ---------- | -------------------------------------------------------------- | ----------------- |
| 5.a accept | 278 holds committee 0's record hash, 279 holds `genesisCutoff` | matches           |
| 5.b reject | 278 holds `genesisCutoff`, 279 the record hash                 | violates STOR-B-5 |

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

| Vector     | Claimed layout or data                                                    | Expected                           |
| ---------- | ------------------------------------------------------------------------- | ---------------------------------- |
| 8.a accept | 283 is never read, written or reused; 284 holds `activeCommitteeSnapshot` | matches                            |
| 8.b accept | immediately after Inbox initialization, 284 equals `genesisCutoff`        | matches                            |
| 8.c reject | a node reads 283 as proof input                                           | violates STOR-B-8                  |
| 8.d reject | 284 initialized to 0                                                      | violates STOR-B-8                  |
| 8.e reject | 283 reused for a later parameter                                          | violates STOR-B-8 ("no ... reuse") |

## STOR-B-9

| Vector     | Claimed layout or data                                                                                                              | Expected                                    |
| ---------- | ----------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------- |
| 9.a accept | the record for h is three words: word 1 packs actual parentHeight=c, generation and head; words 2 and 3 are the EL and Comet hashes | matches                                     |
| 9.b accept | block 0 has parent, generation and head 0, EL hash equal to the genesis hash, Comet hash 0                                          | matches                                     |
| 9.c accept | a proof with origin p reads its own retained record at p after later landings                                                       | matches ("never pruned")                    |
| 9.d reject | the record for h stores proof origin p as parentHeight when p is below c                                                            | violates STOR-B-9 ("actual parentHeight=c") |
| 9.e reject | a later landing overwrites the record at an older origin p                                                                          | violates STOR-B-9                           |
| 9.f reject | block 0's record carries the genesis hash as its Comet hash                                                                         | violates STOR-B-9 ("Comet hash=0")          |

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
| 13.a accept | per generation, three consecutive uint256 words from the mapping base: startHeight, l1BlockNumber, l1Timestamp          | matches                                                      |
| 13.b accept | generation 0 has a record, written under 8.4                                                                            | matches ("Includes generation 0")                            |
| 13.c reject | a gap between the three words (l1Timestamp not at base+2)                                                               | violates STOR-B-13                                           |
| 13.d reject | a record written without the height, block and timestamp range checks (for example startHeight past the L+1<2^48 bound) | violates STOR-B-13                                           |
| 13.e reject | a cached latest origin read instead of the per-generation record                                                        | violates STOR-B-13                                           |
| 13.f reject | the current generation's origin record added to the ordinary anchor witness                                             | violates STOR-B-13                                           |
| 13.g reject | an existing generation's record overwritten by a later recovery                                                         | violates STOR-B-13 (fixed per generation; 8.4: written once) |

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

## STOR-B-16

| Vector      | Claimed layout or data                                                                                                                               | Expected           |
| ----------- | ---------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------ |
| 16.a accept | the node verifies the latest checkpoint under 3.3/3.4, its slot-285 record under section 9, and slot 290 for startup, recovery and proving under 8.4 | matches            |
| 16.b reject | the node trusts the latest checkpoint without reading its slot-285 record                                                                            | violates STOR-B-16 |
| 16.c reject | a startup path skips the slot-290 record                                                                                                             | violates STOR-B-16 |

## STOR-B-17

| Vector      | Claimed layout or data                                    | Expected           |
| ----------- | --------------------------------------------------------- | ------------------ |
| 17.a accept | 283, 286, 287, 288, 289 and 291 are never read or written | matches            |
| 17.b reject | a replay path reads 289                                   | violates STOR-B-17 |
| 17.c reject | a write to 286                                            | violates STOR-B-17 |

## STOR-B-18

| Vector      | Claimed layout or data                                        | Expected           |
| ----------- | ------------------------------------------------------------- | ------------------ |
| 18.a accept | the only recovery-related Inbox storage is the slot-292 nonce | matches            |
| 18.b reject | the Inbox stores a recovery queue                             | violates STOR-B-18 |
| 18.c reject | the Inbox stores a scheduled recovery or a stall timer        | violates STOR-B-18 |

## STOR-B-19

| Vector      | Claimed layout or data                                           | Expected                                     |
| ----------- | ---------------------------------------------------------------- | -------------------------------------------- |
| 19.a accept | a node does not decode a layout unlike Appendix B                | matches                                      |
| 19.b reject | a node decodes an Inbox whose slots are assigned differently     | violates STOR-B-19                           |
| 19.c reject | an in-place migration rewrites an existing Inbox to a new layout | violates STOR-B-19 ("nor migrated in place") |

## STOR-B-20

| Vector      | Claimed layout or data                                                           | Expected           |
| ----------- | -------------------------------------------------------------------------------- | ------------------ |
| 20.a accept | registry storage is rooted at R, the ERC-7201 base slot of `taiko.etna.registry` | matches            |
| 20.b reject | registry storage rooted at the base slot of a different namespace id             | violates STOR-B-20 |
| 20.c reject | R set to an arbitrary constant unrelated to that namespace                       | violates STOR-B-20 |

## STOR-B-21

| Vector      | Claimed layout or data                                                                       | Expected                               |
| ----------- | -------------------------------------------------------------------------------------------- | -------------------------------------- |
| 21.a accept | checkpoint word 1 packs `l1Block` and `count`; word 2 is `entriesRoot`                       | matches                                |
| 21.b accept | entry words: `ckX`, `effStake`, then packed `ckPrefix`, `activeFromL1` and `exitEffectiveL1` | matches                                |
| 21.c reject | `entriesRoot` in checkpoint word 1                                                           | violates STOR-B-21                     |
| 21.d reject | `ckX` in the third entry word                                                                | violates STOR-B-21                     |
| 21.e reject | a node reads the top-ups or forfeitures namespace to derive a committee                      | violates STOR-B-21 ("only two things") |

## STOR-B-22

| Vector      | Claimed layout or data                                                     | Expected           |
| ----------- | -------------------------------------------------------------------------- | ------------------ |
| 22.a accept | an entry's `exitEffectiveL1` is 2^48 − 1                                   | no exit is set     |
| 22.b reject | `exitEffectiveL1` = 2^48 − 1 treated as an exit effective at that block    | violates STOR-B-22 |
| 22.c reject | an entry with `exitEffectiveL1` = 2^48 − 1 counted as exiting in selection | violates STOR-B-22 |

## STOR-B-23

| Vector      | Claimed layout or data                                                                     | Expected           |
| ----------- | ------------------------------------------------------------------------------------------ | ------------------ |
| 23.a accept | slot 272: `genesisHeight` in the least-significant 48 bits, `L1_0` next, `L` next          | matches            |
| 23.b accept | slot 285 word 1: parentHeight c in the least-significant field, then generation, then head | matches            |
| 23.c reject | slot 272 with `L` in the least-significant 48 bits                                         | violates STOR-B-23 |
| 23.d reject | slot 285 word 1 with `head` in the least-significant field                                 | violates STOR-B-23 |

## STOR-B-24

| Vector      | Claimed layout or data                                                                    | Expected           |
| ----------- | ----------------------------------------------------------------------------------------- | ------------------ |
| 24.a accept | a packed word with `ckPrefix` in 8 bits and 48-bit fields above it, unused high bits zero | matches            |
| 24.b accept | a 48-bit field holding 2^48 − 1 with no bits above it                                     | matches            |
| 24.c reject | a 16-bit `ckPrefix` field                                                                 | violates STOR-B-24 |
| 24.d reject | nonzero bits above the highest used field                                                 | violates STOR-B-24 |

## STOR-B-25

| Vector      | Claimed layout or data                                  | Expected         |
| ----------- | ------------------------------------------------------- | ---------------- |
| 25.a accept | writing 2^48 − 1 into a 48-bit field                    | succeeds         |
| 25.b reject | writing 2^48 into a 48-bit field                        | reverts (stated) |
| 25.c reject | writing a 256-bit value into the 8-bit `ckPrefix` field | reverts (stated) |

## STOR-B-26

| Vector      | Claimed layout or data                                                   | Expected                                |
| ----------- | ------------------------------------------------------------------------ | --------------------------------------- |
| 26.a accept | `exitConfirmedAtL1` is 0                                                 | not confirmed                           |
| 26.b accept | `exitConfirmedAtL1` is the L1 block of the first successful confirmation | confirmed                               |
| 26.c reject | `exitConfirmedAtL1` = 0 treated as confirmed                             | violates STOR-B-26                      |
| 26.d reject | the confirmation stored in the entry's three words                       | violates STOR-B-26 (separate namespace) |

## STOR-B-27

| Vector      | Claimed layout or data                                                | Expected           |
| ----------- | --------------------------------------------------------------------- | ------------------ |
| 27.a accept | `confirmExit` writes only into the exit-confirmations namespace       | matches            |
| 27.b accept | slot release clears the confirmation                                  | matches            |
| 27.c reject | `confirmExit` creates a committee checkpoint or changes `entriesRoot` | violates STOR-B-27 |
| 27.d reject | after slot release the confirmation remains                           | violates STOR-B-27 |
| 27.e reject | `confirmExit` writes a `regLeaf` entry                                | violates STOR-B-27 |

## STOR-B-28

| Vector      | Claimed layout or data                                                                 | Expected           |
| ----------- | -------------------------------------------------------------------------------------- | ------------------ |
| 28.a accept | the owner is written at registration to `taiko.etna.registry.owners`, keyed by bond id | matches            |
| 28.b accept | the owner entry is cleared at slot release                                             | matches            |
| 28.c reject | the owner stored in the entry's three words                                            | violates STOR-B-28 |
| 28.d reject | the owner not cleared at slot release                                                  | violates STOR-B-28 |

## STOR-B-29

| Vector      | Claimed layout or data                                 | Expected           |
| ----------- | ------------------------------------------------------ | ------------------ |
| 29.a accept | changing only the owner leaves `entriesRoot` unchanged | matches            |
| 29.b reject | an owner change alters `entriesRoot`                   | violates STOR-B-29 |
| 29.c reject | a node reads the owners mapping to derive a committee  | violates STOR-B-29 |

## STOR-B-30

| Vector      | Claimed layout or data                                                                                                                                       | Expected           |
| ----------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------ | ------------------ |
| 30.a accept | mapping at the namespace base keyed by uint256 bondId; uint256 `pendingTopUp` at the element; uint48 `topUpReadyAtL1` in the next word with unused bits zero | matches            |
| 30.b reject | `topUpReadyAtL1` packed into the same word as `pendingTopUp`                                                                                                 | violates STOR-B-30 |
| 30.c reject | nonzero unused bits in the ready word                                                                                                                        | violates STOR-B-30 |
| 30.d reject | the mapping keyed by an address or bytes32 instead of uint256 bondId                                                                                         | violates STOR-B-30 |

## STOR-B-31

| Vector      | Claimed layout or data                                | Expected           |
| ----------- | ----------------------------------------------------- | ------------------ |
| 31.a accept | withdrawal clears `pendingTopUp` and `topUpReadyAtL1` | matches            |
| 31.b reject | `pendingTopUp` nonzero after slot release             | violates STOR-B-31 |
| 31.c reject | `topUpReadyAtL1` set after slot release               | violates STOR-B-31 |

## STOR-B-32

| Vector      | Claimed layout or data                                                  | Expected                  |
| ----------- | ----------------------------------------------------------------------- | ------------------------- |
| 32.a accept | `forfeited[entryKey]` is false before any forfeiture                    | matches                   |
| 32.b accept | true after a forfeiture, and still true after withdrawal and slot reuse | matches ("never cleared") |
| 32.c reject | withdrawal or slot reuse clears the flag                                | violates STOR-B-32        |
| 32.d reject | a value other than 0 or 1 in the flag                                   | violates STOR-B-32        |

## STOR-B-33

| Vector      | Claimed layout or data                                                                           | Expected           |
| ----------- | ------------------------------------------------------------------------------------------------ | ------------------ |
| 33.a accept | a `topUp` that only sets `pendingTopUp` creates no checkpoint and leaves `entriesRoot` unchanged | matches            |
| 33.b reject | `pendingTopUp` included in `regLeaf` or `entriesRoot`                                            | violates STOR-B-33 |
| 33.c reject | a checkpoint written because of a pending change that alters no existing entry field             | violates STOR-B-33 |
| 33.d reject | a guest reads the top-ups or forfeitures namespace                                               | violates STOR-B-33 |

## STOR-B-34

| Vector      | Claimed layout or data                                                                | Expected           |
| ----------- | ------------------------------------------------------------------------------------- | ------------------ |
| 34.a accept | after the verifier-failure rollback the flags equal their pre-failure values          | matches            |
| 34.b reject | the rollback clears a flag                                                            | violates STOR-B-34 |
| 34.c reject | the rollback restores an older flag snapshot that differs from the pre-failure values | violates STOR-B-34 |

## Not covered

Everything below is a question, not a vector. Each has an entry in [review/B.md](../review/B.md).

| Rule                   | Gap                                                                                                                                                               | Question                      |
| ---------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------- |
| STOR-B-9, STOR-B-13    | the storage-key derivation for the 285 landing record and the 290 origin record (mapping element base, and whether the three words are consecutive) is not stated | [Q-B-1](../review/B.md#q-b-1) |
| all sections           | slots that the table does not list (259–267, 275–277, 293 and above) have no stated disposition                                                                   | [Q-B-2](../review/B.md#q-b-2) |
| STOR-B-24, STOR-B-25   | read-side handling of a packed word whose fields exceed their width or whose unused bits are nonzero                                                              | [Q-B-3](../review/B.md#q-b-3) |
| STOR-B-16 to STOR-B-22 | consequence of a layout violation that states no consequence                                                                                                      | [Q-B-4](../review/B.md#q-b-4) |
| STOR-B-9               | whether "never pruned" is a requirement with an enforcement path or an operational promise                                                                        | [Q-B-5](../review/B.md#q-b-5) |
| delivery sentences     | "Validate the concrete layout ... through layout checks and shared vectors" and "Validate these namespaces ... with shared layout vectors" are un-numbered        | [Q-A-5](../review/A.md#q-a-5) |
