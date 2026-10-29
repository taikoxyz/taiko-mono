# B — review notes

**Non-normative.** Nothing here can be conformed to or failed against. This is what decomposing [SPEC.md](../../SPEC.md) Appendix B into citable statements turned up: questions the text does not settle, and sentences whose normative status was ambiguous. Each item says what would close it.

## Normativity boundary

Under the convention in [../README.md](../README.md), a statement with an ID is precise and citable, and its type is recorded in `INDEX.md`. These statements in Appendix B carry no ID, deliberately:

| Sentence | Why it has no ID | Verdict proposed |
|---|---|---|
| "Slot 284 serves exit confirmation; 285 retains the history needed for overlapping proofs and reconstruction." | rationale for why 284 and 285 are special; the requirements themselves are the table rows (STOR-B-8, STOR-B-9) | keep un-numbered |
| "Validate the concrete layout, including slot 290, through layout checks and shared vectors." | a delivery obligation on the artifact set, not a layout property; no type fits and nothing conforms to it | keep un-numbered — see [Q-A-5](A.md#q-a-5) |
| "Validate these namespaces and Inbox slot 292 with shared layout vectors." | same | keep un-numbered — see [Q-A-5](A.md#q-a-5) |
| the table header row "EtnaInbox slot / Content" | column headings, not a statement | keep un-numbered |

## Q-B-1

**Where exactly do the 285 and 290 records live?**

**Text.** "285 | landing mapping, lastHeight → three words: word 1 packs actual parentHeight=c, generation and head; words 2/3 are EL/Comet hashes." "290 | Fixed per-generation origin mapping: (startHeight,l1BlockNumber,l1Timestamp), each a uint256 word with height/block/timestamp range checks; store three consecutive words from the mapping base keyed by generation." Appendix A gives the registry formula "`cp(i) = keccak256(R) + 2i`".

**Why it matters.** Nodes must read both records — 285 for a checkpoint's EL/Comet hashes and FI head (section 9), 290 for startup, recovery and proving (8.4) — but Appendix B never states the element-slot derivation or the key encoding. A Solidity mapping element is `keccak256(abi.encode(key, slot))`; an array element is `keccak256(slot) + i·size`; the two are different slots. Appendix A's registry formula uses the array form for checkpoints, while 285 and 290 are described as mappings, so the file mixes both forms without saying which applies where. Two implementations can read different slots and both claim to implement this appendix, and no layout check would catch it.

**Would close it.** State the derivation once — the element base is `keccak256(abi.encode(key, slot))` and the value is three consecutive words from that base — and say which of the structures at 285 and 290 are mappings and which are arrays.

Raised by: DeepSeek-V4.1-Flash (dantaik)

## Q-B-2

**Unlisted slots have no disposition**

**Text.** The table assigns 258, 268–274, 278–284, 285, 286–292. "Reserved slots 283, 286–289 and 291 are neither read nor written."

**Why it matters.** Slots 259–267, 275–277 and 293 and above are neither assigned nor declared reserved. A node or a future Inbox version may use them, and the appendix does not say whether that is the "other layouts are neither decoded nor migrated in place" case or free space. An upgrade can therefore silently place a value in a slot that a reader assumed was unused, and the two rules that would forbid it point in different directions.

**Would close it.** Add a rule — any slot not listed is reserved and is neither read nor written — or enumerate the free ranges explicitly.

Raised by: DeepSeek-V4.1-Flash (dantaik)

## Q-B-3

**Read-side validation of packed words**

**Text.** "ckPrefix takes 8 bits and every other field 48 bits; unused high bits are zero. Writing a value wider than its field reverts."

**Why it matters.** The rule governs writes and states that unused high bits are zero, but the reader is not told what to do with a word whose high bits are nonzero or whose field exceeds its width: reject it, mask it, or assume it cannot happen. The write-side revert makes the state unreachable through this Inbox, but not through an upgraded or replaced one, and a guest reading a witness has to choose. The choices differ observably on a crafted witness, and the appendix states a layout that a reader must be able to validate.

**Would close it.** State the reader's obligation — for example, that a packed word with nonzero unused bits, or a field wider than its declared width, makes the witness invalid.

Raised by: DeepSeek-V4.1-Flash (dantaik)

## Q-B-4

**Consequence of a layout violation**

**Text.** STOR-B-16 to STOR-B-22 state requirements — "Nodes verify the latest checkpoint ...", "Reserved slots 283, 286–289 and 291 are neither read nor written", "other layouts are neither decoded nor migrated in place" — while only STOR-B-25 names a consequence: "Writing a value wider than its field reverts."

**Why it matters.** It is not stated whether reading a different layout, reading a reserved slot, or decoding a foreign layout is a block-validity failure, a proof-side rejection, or a safety halt. Implementers must decide where to enforce, and the answers differ observably: under the first a block can be voted down at consensus time; under the second it can be committed and only fail to settle. Until this is decided, [vectors/B.md](../vectors/B.md) says "violates STOR-B-n" rather than naming an outcome.

**Would close it.** State the consequence once for Appendix B (for example, "a witness read under any layout other than this appendix is invalid") and say whether that invalidity is a proposal rejection or a safety halt.

Raised by: DeepSeek-V4.1-Flash (dantaik)

## Q-B-5

**"Never pruned" — requirement or promise?**

**Text.** "Retain original recovery-origin records; proof origin p never replaces actual parent. Historical parent links and old-p records serve overlapping proofs and public reconstruction and are never pruned."

**Why it matters.** Retaining old records is what makes overlapping proofs work (6.2 item 10, 6.3), but the sentence states no consequence if a record is missing and no retention bound. If an implementation, a state-replacement upgrade or a rebuild loses an old-p record, it is not stated whether the proof is invalid, whether the node halts, or whether this is only an operational promise about expected operation.

**Would close it.** State that a proof whose origin record or parent link is missing is invalid, and say whether any landing record may ever be deleted.

Raised by: DeepSeek-V4.1-Flash (dantaik)
