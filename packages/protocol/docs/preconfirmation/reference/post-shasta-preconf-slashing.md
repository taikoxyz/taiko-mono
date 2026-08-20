# Taiko Post-Shasta Preconfirmation Slashing

> **Provenance**: This document is a faithful markdown conversion of the Notion page
> "Taiko Post-Shasta Preconfirmation Slashing" (PDF export, 9 pages, authored ~09/2025).
> Margin comments from the Notion page are preserved as quoted asides where legible;
> several were truncated in the PDF export and are marked `[truncated]`.

## Overview

- This document elaborates on a two contract slashing system containing `PreconfSlasherL2`
  on Taiko, and `PreconfSlasherL1` on Ethereum L1. Preconfers opt-into `PreconfSlasherL1`.
- Slashing condition checks are done within `PreconfSlasherL2`, which then calls the `URC`
  contract via the native Bridge. The URC then calls `PreconfSlasherL1` to slash the preconfer.
- This system would require some minimal changes in `Inbox` on L1, and `ShastaAnchor` on L2.
- **Note:**
  - Please start by reading "Changes needed in `Inbox`" and "Changes needed in
    `ShastaAnchor`" first, for a better understanding.
  - The document contains pseudo functions. The actual implementation may have a slightly
    different set of arguments.

## Preconfirmation Structure

```solidity
struct Preconfirmation {
    bool eop; // End-of-preconfirmation flag
    uint256 blockId;
    bytes32 anchorBlockId;
    bytes32 rawParentBlockHash;
    bytes32 rawTxListHash;
    uint256 submissionWindowEnd; // The timestamp of the preconf's lookahead slot
}
// Note on `submissionWindowEnd`: In the present slasher, this is called
// `proposalSlotTimestamp`, but I am leaning toward switching to
// `endOfSubmissionWindow` because the proposal timestamp might be different
// if the preconfer is proposing in an advanced-slot.
```

> 💬 **Margin comment**: Anshu Jalan (09/29/2025): "@Lin Oshitani I have removed the word
> `timestamp` for this, complying with the changes made in the …" `[truncated]` — and:
> "Edit: renamed to `submissionWindowEnd`. That is what we are using in the store."

### Special Case (EOP-only preconfirmation)

- If a fallback preconfer happens to be asked to preconf within the handover window (possible
  in multiple scenarios that are covered in the routing logic), they may issue an EOP-only
  preconfirmation to signal that they are not going to preconf and the next preconfer may take
  over.

```solidity
// Structure of EOP-only preconfirmation
Preconfirmation {
    eop: true,
    txListHash: bytes32(0),
    submissionWindowEnd: <as-computed-by-the-lookahead-store>
}
```

## Slashing checks on L2

The actual slashing happens on L1, so the L2 slasher simply forwards a `SlashingReason` to the
L1 slasher:

```solidity
enum SlashingReason {
    LivenessFault,
    SafetyFault,
    // This signifies that an additional block was proposed within the same
    // lookahead period, after issuing the EOP
    InvalidEOP,
    // This signifies that the preconfirmed block was the last block issued
    // in the preconf window, but the EOP flag was not set to `true`
    MissingEOP,
}

// Will be used as revert messages
enum SkipReason {
    // Invalid Preconfs
    EOPOnlyPreconfirmation,
    NotAFaultyPreconfirmation,
    ParentRawTxListHashMismatch,
    UnexpectedExtraBlockInPreviousWindow,
    // Invalid or Missing EOP
    InvalidEOPFlag,
    SlashableUnderInvalidPreconfirmation,
}
```

### Invalid Preconfirmation

Sequence of logic contained within the function `slashInvalidPreconfirmation(preconfirmation)`:

- Skip slashing if: `preconfirmation.eop` is true and `preconfirmation.rawTxListHash` is
  `0x0000...000`.
  (SkipReason.EOPOnlyPreconfirmation)
- **[Optional]** Skip slashing if: `preconfirmation.rawTxListHash` and
  `preconfirmation.anchorId` matches the `rawTxListHash` and `anchorId` for the stored block.
  (SkipReason.NotAFaultyPreconfirmation)
- Skip slashing if: `preconfirmation.parentRawTxListHash` does not match the `rawTxListHash`
  of `preconfirmation.blockId - 1` stored in `ShastaAnchor`.
  (SkipReason.ParentRawTxListHashMismatch)
- Skip slashing if: `preconfirmation.submissionWindowEnd` is greater than the stored
  `submissionWindowEnd` for `preconfirmation.blockId`.
  (SkipReason.UnexpectedExtraBlockInPreviousWindow)
- If: `preconfirmation.submissionWindowEnd` is less than the stored `submissionWindowEnd`
  for `preconfirmation.blockId`:
  - Slash: SlashingReason.LivenessFault
- Else:
  - Slash: SlashingReason.SafetyFault

### Invalid EOP

(Invalid EOP is a slashing condition when additional blocks are proposed by the preconfer after
issuing an EOP)

Sequence of logic contained within the function `slashInvalidEOP(preconfirmation)`:

- Skip slashing if: `preconfirmation.eop` is false.
  (SkipReason.InvalidEOPFlag)
- If `preconfirmation.rawTxListHash` is `0x0000..0000`:
  - Slash if: `preconfirmation.submissionWindowEnd` matches the stored
    `submissionWindowEnd` for `preconfirmation.blockId`
    (SlashingReason.InvalidEOP)
- Else:
  - Skip slashing if: `preconfirmation.submissionWindowEnd` does not match the stored
    `submissionWindowEnd` for `preconfirmation.blockId`
    (SkipReason.SlashableUnderInvalidPreconfirmation)
  - Slash if: `submissionWindowEnd` stored in `ShastaAnchor` is identical for blocks
    `preconfirmation.blockId` and `preconfirmation.blockId + 1`
    (SlashingReason.InvalidEOP)

> 💬 **Margin comments**: gustavo Gonzalez (09/04/2025): "not sure I follow…. isn't
> lookaheadSlotTimestamp the timestamp for the slot of the current …" `[truncated]` —
> Lin Oshitani (09/04/2025): "Yes, exactly. The edge case we are protecting against is the case
> where we have schedule of preconfer A → …" `[truncated]` —
> gustavo Gonzalez (09/04/2025): "do we really need to slash for a missing EOP? If the preconfer
> does not issue any, then we could safely …" `[truncated]` — Lin Oshitani (09/04/2025): "But
> potentially we can use fair exchange blacklisting for such liveness faults." —
> Lin Oshitani (09/14/2025): "I think we need to check for L1 missed slot here too. And in case
> there was not a missed slot, `InvalidEOP`, if there was a missed slot, it's more of a 'liveness
> fault for EOP'. Or else we slash in full if preconfer did 'ea…" `[truncated]`

### Missing EOP

(Missing EOP is a slashing condition when EOP was not issued for the last block in a preconfing
period)

Sequence of logic contained within the function `slashMissingEOP(preconfirmation, blockheader)`:

- Skip slashing if: `preconfirmation.eop` is true.
  (SkipReason.InvalidEOPFlag)
- Skip slashing if: `preconfirmation.submissionWindowEnd` does not match the stored
  `submissionWindowEnd` for `preconfirmation.blockId`.
  (SkipReason.SlashableUnderInvalidPreconfirmation)
- Slash if: `submissionWindowEnd` stored in `ShastaAnchor` are different for blocks
  `preconfirmation.blockId` and `preconfirmation.blockId + 1`
  (SlashingReason.MissingEOP)

## Slashing checks on L1

The L2 slasher forwards the `preconfirmation` commitment, and the `slashingReason` over to
the L1 Slasher's function `slash(preconfirmation, slashingReason)` containing the following
sequence of logic:

- Skip slashing if: The transaction was not initiated by L2 Slasher.
  (Explained further in "Reflecting the slashing on L1" section).
- Skip slashing if: `slashingReason` is `MissedSubmission` or `MissingEOP` and
  `preconfirmation.submissionWindowEnd` has no beacon block root.
  (Signifies the block proposed in preconfer's dedicated L1 slot was reorged out)
- Slash if: The control flow reaches this statement.

## Reflecting the slashing on L1

This is a two-contract slashing system where the slashing process begins by slashing-condition
checks on L2 within the `PreconfSlasherL2` contract, and if the conditions are satisfied, a call is
initiated to the `URC` via the bridge. The `URC` then interfaces with `PreconfSlasherL1` to
complete the slashing process.

Slashing Sequence:

- Slashing condition checks: If the slashing conditions as specified in "Slashing checks on L2"
  are satisfied in `PreconfSlasherL2`, it initiates a call to `URC`'s function
  `slashCommitment(registrationRoot, commitment, evidence)` via the Bridge.
  - `registrationRoot`: Passed in the evidence to `PreconfSlasherL2`
  - `commitment`: The preconfirmation commitment passed to `PreconfSlasherL2`
  - `evidence`: This would simply be the encoded `slashingReason` to bytes.
- The L2 Bridge's `message.data` would be an encoded call to the above specified
  `slashCommitment` function.

[Standard bridging process with the call on L1 being handled by the relayer]

- The `URC` forwards the call to `PreconfSlasherL1`'s `slash(..)` function, assuming that the
  preconfer has opted in to `PreconfSlasherL1`.
- `PreconfSlasherL1` verifies that `PreconfSlasherL2` is the sender in L1 Bridge's `ctx`
  (bridge context).
- If the remainder of the checks as specified in "Slashing checks on L1" passes, the preconfer
  is slashed.

> 💬 **Margin comments**: Lin Oshitani (09/01/2025): "Did URC have functionality to compensate
> the slash submitter with some of the slashed collateral? IIRC …" `[truncated]` —
> Anshu Jalan (09/03/2025): "That was not the only reason. The committer could also slash
> himself, say in the same transaction, thus …" `[truncated]`

## Changes needed in Inbox

- Only one change is expected in the inbox - the `Proposal` object that is hashed and stored
  should contain the `endOfSubmissionWindowTimestamp` (synonymous with
  `preconfirmation.endOfSubmissionWindowTimestamp`):

```solidity
struct Proposal {
    uint48 id;
    address proposer;
    // Timestamp of proposal slot
    uint48 timestamp;
    // Timestamp of the lookahead slot for the current preconfing period
    uint48 endOfSubmissionWindowTimestamp;
    bytes32 coreStateHash;
    bytes32 derivationHash;
}
```

It is expected that the Lookahead contract returns the current
`endOfSubmissionWindowTimestamp` when called by the inbox during proposal.

> 💬 **Margin comments**: Lin Oshitani (08/31/2025): "We might want to have a generic
> 'extraData' field to keep the core Taiko protocol agnostic of preconfs. …" `[truncated]` —
> Anshu Jalan (09/01/2025): "Agreed" — Daniel Wang (09/03/2025): "WIP, will merge soon" —
> gustavo Gonzalez (09/04/2025): "downside is it makes L1→L2 messaging (i.e. deposits) slower
> right? I wonder if there's another …" `[truncated]` — Lin Oshitani (09/05/2025): "Let me add
> some appendix section to compare so we can make a final call"

## Changes needed in ShastaAnchor

- The above specified `endOfSubmissionWindowTimestamp` is passed into the `updateState`
  function:

```solidity
function updateState(
    uint48 _proposalId,
    address _proposer,
    bytes calldata _proverAuth,
    bytes32 _bondInstructionsHash,
    LibBonds.BondInstruction[] calldata _bondInstructions,
    uint16 _blockIndex,
    uint48 _anchorBlockNumber,
    bytes32 _anchorBlockHash,
    bytes32 _anchorStateRoot,
    // Extra argument (this is deterministic)
    uint48 _endOfSubmissionWindowTimestamp
)
```

- Currently, the anchor contract only stores the historical blockhashes of the L2 blocks, but for
  preconfirmations we would need the lookahead slot timestamp for performing the slashing
  condition checks as specified in "Slashing checks on L2" section.

  We propose that `_endOfSubmissionWindowTimestamp` is stored for every L2 block:

```solidity
mapping(uint256 blockId => uint256 endOfSubmissionWindowTimestamp)
    public blockIdToLookaheadSlotTimestap;
```
