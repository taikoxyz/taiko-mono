# A — review notes

**Non-normative.** Nothing here can be conformed to or failed against. This is what decomposing [SPEC.md](../../SPEC.md) Appendix A into citable statements turned up: questions the text does not settle, and sentences whose normative status was ambiguous. Each item says what would close it.

## Normativity boundary

Under the convention in [../README.md](../README.md), a statement with an ID is precise and citable, and its type is recorded in `INDEX.md`. These statements in Appendix A were the ones without an ID when the appendix was first reviewed — confirming each was a judgement call worth an explicit decision. The four block rows record the later `code-before` supplement:

| Sentence                                                                                                                                                                                                                                     | Why it has no ID                                                                                                                                        | Verdict proposed                                                                                                                                                                                                                 |
| -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| "`**Shared vectors**`: every encoding, interface, storage layout and boundary condition needs accept/reject vectors shared by nodes, contracts and both guests; the list is in [Etna Acceptance and Launch Checklist](../../ACCEPTANCE.md)." | a delivery obligation on artifacts, not a property of any block; no type (rule, limitation, assumption) fits and nothing can conform or fail against it | keep un-numbered — but see [Q-A-5](#q-a-5)                                                                                                                                                                                       |
| SPEC.md 635–688: `chainDomain`, `chain_id`, `extraData`, envelope, payload, `AccountWitness`, and the strict-decoding comment block                                                                                                          | originally inside a fenced `txt` block with no ID                                                                                                       | now marked by ENC-A-6–ENC-A-28 in `code-before` mode; restructuring question remains — [Q-A-1](#q-a-1)                                                                                                                           |
| SPEC.md 690–723: `cutLeaf`, `K`, `cutHash`, the `land` checks, `statement`                                                                                                                                                                   | originally inside a fenced `txt` block with no ID                                                                                                       | now marked by ENC-A-29–ENC-A-35 in `code-before` mode; `K`'s lines stay uncited; restructuring question remains — [Q-A-1](#q-a-1)                                                                                                |
| SPEC.md 725–746: `committeeConfigHash`, `regLeaf`, `entriesRoot`, `setKey`/`setLeaf`/`setNode`/`record`, `k`                                                                                                                                 | originally inside a fenced `txt` block with no ID                                                                                                       | now marked by ENC-A-36–ENC-A-42 in `code-before` mode; `k`'s line is ENC-A-42a; restructuring question remains — [Q-A-1](#q-a-1)                                                                                                 |
| SPEC.md 748–811: `voteSignBytes`, `register` and decompression, `registerDigest`, the `recover` interface                                                                                                                                    | originally inside a fenced `txt` block with no ID                                                                                                       | now marked by ENC-A-43–ENC-A-50 in `code-before` mode; `registerDigest` is ENC-A-49a, the event lines stay uncited, parts of the `recover` interface are now ENC-A-51–ENC-A-55; restructuring question remains — [Q-A-1](#q-a-1) |

## Q-A-1

**Appendix A's rules live inside fenced blocks and cannot be cited**

**Text.** "`envelope = 0x06 || rlp([block, anchor, committee, forced])`" and "`// Strict decoding (identical for nodes and guests; any violation makes the proposal invalid): the envelope is exactly 0x06 plus one RLP list, with no trailing bytes;`" and "`chain_id = "etna-" + base64url_no_padding(chainDomain)`".

**Why it matters.** The appendix's rule content — the chain id derivation, `extraData`, the envelope layout, the strict-decoding conditions (trailing bytes, minimal integers, fixed lengths, per-field types), `AccountWitness` slot order, `cutLeaf`, `cutHash`, `statement`, `committeeConfigHash`, `regLeaf`, `entriesRoot`, `setKey`/`setLeaf`/`setNode`/`record`, `voteSignBytes`, registration and the `recover` interface — is written inside four fenced `txt` blocks (SPEC.md 635–688, 690–723, 725–746, 748–811). Under the convention then applied, a fenced block carried no ID, and an ID is what makes a statement citable; the needle rule also forbade placing an ID inside a fence. So the only place the appendix states a consequence — "any violation makes the proposal invalid" — was not normative under the directory's own rule, and ACCEPTANCE §3's shared-vector requirement for exactly these encodings had nothing to cite. [vectors/A.md](../vectors/A.md) could therefore cover only the five statements outside the fences.

**Would close it.** Convert the four blocks to normative tables (the form Appendix B uses) or lift the rule comments into prose paragraphs, then number them. Alternatively, declare definition blocks normative and give each block a citable ID placed outside the fence, in a lead-in sentence. Whichever is chosen, the strict-decoding list should become numbered prose, because it is the only statement that an encoding violation makes a proposal invalid.

**Status.** The exception was adopted: [../README.md](../README.md) now permits `code-before` for Appendix A definition blocks, and ENC-A-6–ENC-A-50 (with the separate ENC-A-51–ENC-A-55 supplement) mark the definition and strict-decoding lines inside these four blocks with a `// [ID]` line above each unchanged governed line. The rules are citable now, including the strict-decoding sentence that names the consequence. The underlying question is still the owner's: whether to restructure the blocks into prose or tables anyway. That would change the form, not the content; this note records the convention change, not a decision on the restructuring.

Raised by: DeepSeek-V4.1-Flash (dantaik)

## Q-A-2

**Domain tags: padded `bytes32` or string literal, and an unversioned `ETNA_SET_NODE`**

**Text.** ENC-A-5: "Protocol hashes are keccak256 over `abi.encode`, with domain tags as right-zero-padded `bytes32` ASCII". The fenced preimages include "`regLeaf(j)  = keccak256(abi.encode("ETNA_REG_ENTRY_V1", j, ckPrefix, ckX, effStake, activeFromL1,`", "`setNode     = keccak256(abi.encode("ETNA_SET_NODE", l2ChainId, k, left, right))`" and "`record      = keccak256(abi.encode("ETNA_COMMITTEE_V1", l2ChainId, targetEpoch, cutoffL1Block,`", while `chainDomain`, `cutHash`, `statement` and `committeeConfigHash` write `bytes32("...")`.

**Why it matters.** The two preimages are different byte strings: a right-zero-padded 32-byte word versus a dynamic string encoding (offset, length, data). A client that follows the code literally and a client that follows ENC-A-5 compute different registry, set and committee hashes, so they disagree on `regLeaf`, `entriesRoot`, `setRoot` and the committee record — a split in the very values the appendix exists to fix. Separately, `ETNA_SET_NODE` is the only tag with no `_V1` suffix, while ENC-A-1 says every versioned domain tag is V1; a reader cannot tell whether the missing suffix is deliberate.

**Would close it.** State that a bare literal in a preimage denotes a right-zero-padded `bytes32` (and make the code consistent), or add the casts. Separately, state whether `ETNA_SET_NODE` is intentionally unversioned.

Raised by: DeepSeek-V4.1-Flash (dantaik)

## Q-A-3

**Nothing in the seven-word config binds guest-image acceptance**

**Text.** ENC-A-4: "Bind real guest-image/verifier acceptance to the config; until the upgrade mechanism is complete, changing clients or registering an image does not activate new rules." ENC-A-2: "Config has seven words/224 bytes". The seven-word preimage is "`committeeConfigHash = keccak256(abi.encode(bytes32("ETNA_PARENT_ANCHOR_V1"), l2ChainId, registry,` / `vp_unit, s_min, n_max, U))  // 7 words, 224 bytes`".

**Why it matters.** The config carries no image, verifier or code-hash field, so there is nothing for acceptance to bind to. 6.2 pins "the verifier address, code hash and accepted image set ... in the deployment manifest", and 10.1 says the activation mechanism "is not fully designed yet". Two clients can therefore both conform while disagreeing about whether a newly registered image may settle, which is exactly what the sentence is trying to settle.

**Would close it.** Name the mechanism that ties image acceptance to the config — for example image hashes in a manifest authenticated at the boundary height, or an extension of the config — or say explicitly that acceptance is manifest-bound until the upgrade mechanism lands.

Raised by: DeepSeek-V4.1-Flash (dantaik)

## Q-A-4

**`AccountWitness` order is "exactly" — rejected, or merely described?**

**Text.** "`Prove exactly in order: anchor [268, 270, 271, 281]; forced entry [base,base+1], base=keccak256(abi.encode(i,280));`" and "`// accountProof and each storage proof are exactly the ordered MPT path from the root to the leaf (or to the node proving absence), with no extra nodes;`".

**Why it matters.** "exactly in order" can be read as a property of the witness — an out-of-order, short or extra slot list is invalid — or as a description of how a prover builds it. The strict-decoding rules make the envelope's item list exact, but they do not mention the witness slot list, and 3.4 rule 2 only requires that "the witness verifies". Two guests can therefore differ on whether a complete but reordered proof set is accepted, and the difference is visible only on a crafted proposal.

**Would close it.** State that the account and slot list must be exactly the listed slots in the listed order, and that any other order, an extra slot or a missing slot makes the witness invalid; or state that order is not checked.

Raised by: DeepSeek-V4.1-Flash (dantaik)

## Q-A-5

**The shared-vector obligation has no owner and no type**

**Text.** "`**Shared vectors**`: every encoding, interface, storage layout and boundary condition needs accept/reject vectors shared by nodes, contracts and both guests; the list is in [Etna Acceptance and Launch Checklist](../../ACCEPTANCE.md)."

**Why it matters.** This is the only place the spec requires shared vectors, and it is the sentence that justifies this directory. It is a delivery obligation on artifacts, not a property of any block, so none of the three types (rule, limitation, assumption) fits and nothing can conform or fail against it. It also names no owner, no minimum set and no check, while the actual list lives in ACCEPTANCE §3, so the two can drift apart without anyone noticing.

**Would close it.** Type it explicitly — either a delivery requirement with an owner and a check, or guidance — and say that ACCEPTANCE §3 is the authoritative list, so the two cannot diverge silently.

Raised by: DeepSeek-V4.1-Flash (dantaik)
