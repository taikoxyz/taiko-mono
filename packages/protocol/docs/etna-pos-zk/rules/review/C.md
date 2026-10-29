# C — review notes

**Non-normative.** Nothing here can be conformed to or failed against. This is what decomposing [SPEC.md](../../SPEC.md) Appendix C into citable statements turned up: questions the text does not settle, and sentences whose normative status was ambiguous. Each item says what would close it.

## Normativity boundary

These statements in Appendix C carry no ID, deliberately:

| Sentence | Why it has no ID | Verdict proposed |
|---|---|---|
| "This appendix states operating requirements, not validity rules." | the type declaration that makes every COST ID an `assumption`; it is a statement about the appendix, not an assumption about the world | keep un-numbered |
| the closing navigation line to Etna Acceptance and Launch Checklist | a link, not a statement | keep un-numbered |

## Q-C-1

**A prohibition inside an appendix that declares itself non-normative**

**Text.** "land binds no recipient and a public blob transaction can be copied, so DAO compensation must not be a per-landing bounty paid to the submitting address; fund named operators or attribute work off chain." The appendix opens: "This appendix states operating requirements, not validity rules."

**Why it matters.** The sentence prohibits a funding design ("must not"), but the appendix is declared non-validity and the type recorded for its IDs is `assumption`. Nothing in the protocol checks how the DAO pays landers, and no section states a consequence for paying a bounty. A DAO that pays one violates no validity rule, yet the text says it must not — so the sentence is either a rule that needs a type and an enforcement point, or advice that should read like advice.

**Would close it.** Decide which it is, and either move it to a rules section with an owner and a check, or mark it in the text as design advice.

Raised by: DeepSeek-V4.1-Flash (dantaik)

## Q-C-2

**The funded worst case is defined by targets that are not validity rules**

**Text.** "measure and fund the budget for the operating targets of approximately 4 s blocks and at most 20 min between L1 inclusions of successive successful landings (6.4)". Section 6.4: "approximately 4 s blocks and no more than 20 min between L1 inclusions of successive successful landings are operating targets, not block-validity rules", and "missing it shrinks the margin but does not pause L2".

**Why it matters.** The budget is defined against targets that may be missed indefinitely with no protocol consequence. A deployment can conform to every rule while running at half the target rate against a budget sized for the target, so the "sustained worst case" this appendix asks to fund is not a case the protocol can enforce or even detect. The choice is between funding a target and funding a bound, and the text funds the former.

**Would close it.** State the funded bound independently of the targets (for example, the worst measured rate at which the chain still pauses only by the U rule) and say who re-funds when the targets are missed.

Raised by: DeepSeek-V4.1-Flash (dantaik)

## Q-C-3

**What counts as evidence that funding is in place?**

**Text.** "cost estimates alone are not evidence that funding is in place."

**Why it matters.** The sentence excludes one kind of evidence and names no acceptable kind, no owner and no check. ACCEPTANCE §1 measures resources and latency and §4 gates launch on capital and committee concentration, but neither requires a funded operating budget, so the appendix's central claim cannot be accepted or rejected at launch. Two deployments, one with a treasury balance and one with a spreadsheet, are indistinguishable under the current text.

**Would close it.** Name the artifact that counts (a budget with currency, owner and period, a treasury balance, or a signed commitment) and add the check to ACCEPTANCE.

Raised by: DeepSeek-V4.1-Flash (dantaik)

## Q-C-4

**Which funded figure applies before K is pinned?**

**Text.** "A landing carries at most six blobs, hence six blocks, and must end at a grid point, so each covers m blocks, where m is the largest multiple of K not above 6: about 900/m landings an hour, which is about 150 when K divides 6, about 225 at K = 4 and about 180 at K = 5."

**Why it matters.** K "is not fixed yet; set from proving capacity measured during acceptance" (section 11), so the funded figure depends on a parameter pinned later. Before K is pinned there is no single number to fund, and after it is pinned the required landing rate can differ by 50% between K = 6 (150 an hour) and K = 4 (225 an hour). A budget approved now against the wrong value is a budget that does not cover the sustained worst case.

**Would close it.** Say which figure to fund before K is pinned (the maximum, or the K = 4 case) and require re-funding when K is set.

Raised by: DeepSeek-V4.1-Flash (dantaik)

## Q-C-5

**"3 blobs per L1 slot" assumes an L1 slot time the spec never states**

**Text.** "Whatever K is, that is 3 blobs per L1 slot."

**Why it matters.** The figure follows from about 150 landings an hour at six blobs each over 300 L1 slots an hour, which assumes a 12 s L1 slot. Appendix C states neither the slot duration nor the per-block blob capacity of the L1 chain it assumes, so the number cannot be checked against a future L1 schedule, and a reader cannot tell which external parameters the blob budget depends on.

**Would close it.** State the L1 slot duration and per-block blob capacity assumed, or cite where they are pinned.

Raised by: DeepSeek-V4.1-Flash (dantaik)
