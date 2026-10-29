# Rule references: conventions

> **AI agents working in this directory: read [`../CLAUDE.md`](../CLAUDE.md) first, and run `python3 rules/tools/check.py --base <rev>` before committing.** `AGENTS.md` is a symlink to the same file. This README is the convention; `CLAUDE.md` is the operator checklist; where they disagree, this file governs.

This directory adds **stable rule references** to [SPEC.md](../SPEC.md) so that review, discussion and verification can cite a rule instead of a paragraph. It changes no rule. Where this directory and SPEC.md disagree, **SPEC.md governs**.

## Why

A review comment like "section 7.2 has a problem" cannot be resolved, tested or closed. One like "FI-7.2-10 contradicts FI-7.2-8" can. Stable IDs are the cheapest upgrade to a specification that is meant to be argued about.

## ID format

`<FAMILY>-<section>-<n>` — for example `FI-7.2-1`.

- **FAMILY** groups statements by subject so they can be cited across sections:
  `MODEL` positioning and security model · `COMP` components · `CONS` consensus and blocks ·
  `STAKE` registry and epochs · `COMM` committee derivation · `FORF` DAO forfeiture ·
  `DATA` data formats and DA · `LAND` landing · `PROOF` proofs · `BATCH` batches · `BACKP` back-pressure ·
  `FI` forced inclusion · `RECOV` halts and recovery · `SYNC` sync and weak subjectivity ·
  `START` startup and deployment · `PARAM` parameters · `LIMIT` limitations ·
  `ENC` Appendix A encodings · `STOR` Appendix B storage layout · `COST` Appendix C assumptions.
- **section** is the section the rule lives in. It locates the reader; it is not the primary key.
- **n** is a counter within the section.

### Insertions, deletions, moves

- **Never renumber to make room.** Insert a suffix letter on the preceding ID: `FI-7.2-3a` sits between `FI-7.2-3` and `FI-7.2-4`.
- A deleted rule's ID is **retired, never reused**; `INDEX.md` keeps the row marked `retired`, so a stale external reference fails visibly instead of pointing at a different rule.
- If a rule moves to another section its ID stays intact and `INDEX.md` records the move. **An ID is a citation, not a coordinate.**

## What an ID means: a citation handle, plus a type

**An ID means "this statement is precise and citable". Whether it binds is recorded separately**, in the `Type` column of `INDEX.md`. Not everything worth citing is a rule: section 12 lists limitations and Appendix C lists assumptions, and both deserve a stable reference even though nothing conforms to them.

| Type         | Binds   | Where                                              | Vectors                                                                        |
| ------------ | ------- | -------------------------------------------------- | ------------------------------------------------------------------------------ |
| `rule`       | **yes** | numbered sections, Appendices A and B              | required                                                                       |
| `limitation` | no      | 12. Known limitations and open items               | none — nothing conforms to a limit                                             |
| `assumption` | no      | Appendix C. Operating funding and cost assumptions | none — an assumption is falsified by measurement, not by an implementation     |
| `retired`    | n/a     | a deleted rule's row, kept in `INDEX.md`           | none — nothing to conform to; the row exists so a stale citation fails visibly |

A statement with **no** ID is explanatory, contextual, or guidance. The un-numbered guidance in 7.2 ("an FI transaction should set `maxFeePerGas` to at least 1 gwei") is advice; nothing conforms or fails against it.

**Scope.** This distinction applies to sections that have been annotated. Text that is un-numbered because its section has not been converted yet keeps its original normative status — do not read an un-annotated requirement as guidance. Annotate the section before relying on the ID/guidance split, and list the sentences you deliberately leave without an ID in that section's _Normativity boundary_ note.

Why a type column and not an RFC-2119 keyword convention: repeating MUST/MUST NOT through prose written to be read would hurt readability without adding precision. The real problem was never a missing "must" — it was that **binding and non-binding statements are indistinguishable**. A citation handle plus a declared type fixes that, is greppable (`[FI-7.2-`), and leaves the prose alone.

## Normative content inside definition blocks

By default a fenced code block is illustrative and carries no IDs. **The exception is Appendix A's definition blocks.** Those blocks carry the byte-level layout rules - domain tags, `chain_id` derivation, `extraData`, envelope strictness, witness slot order - which are normative and must be citable. Leaving them uncitable would gut the exercise in exactly the appendix where precision matters most.

For such a line the ID goes on a **preceding comment line**, never by editing the governed line:

```txt
// [ENC-A-8]
// Strict decoding (identical for nodes and guests; any violation makes the proposal invalid): ...
```

The governed line is unchanged. Rules for this mode (`code-before`):

- The statement carrying the ID is the **full line, including its original indentation**, and that exact line must occur once in the file. A partial match puts the marker in the wrong place.
- The marker is inserted as a new line `<indent>// [ID]` immediately above it, using the target line's indentation.
- One ID per line. Do not place IDs in example or illustrative blocks - only in definition blocks whose lines state requirements.
- A fenced block that carries no IDs remains non-normative.

Why not restructure the blocks into tables now: that is a change to the specification's form, not its content, and belongs to the owner as a separate decision. It is recorded as a question in [review/A.md](review/A.md).

## Two files per section, two different jobs

`rules/vectors/<section>.md` and `rules/review/<section>.md` are deliberately separate. They have different authors, different lifetimes, and different normative standing, and mixing them is how an open question gets mistaken for a settled rule.

|                        | `vectors/<section>.md`                                                          | `review/<section>.md`                                                |
| ---------------------- | ------------------------------------------------------------------------------- | -------------------------------------------------------------------- |
| **Holds**              | Observable consequences of rules: given this block or landing, accept or reject | Questions the text does not settle                                   |
| **Nature**             | Determined. Derived from a rule; checkable by anyone                            | Undetermined. No answer yet                                          |
| **Normative standing** | Conforms to a rule — a failure is a real failure                                | **None.** Nothing can be conformed to or failed against              |
| **Lifetime**           | Durable. Feeds `ACCEPTANCE.md` section 3 and the guests' shared vectors         | Transient. A closed question is deleted                              |
| **Primary owner**      | Spec author; consumed by implementers, prover/guest authors, test authors       | Raised by reviewers/implementers/auditors; decided by the spec owner |
| **When it changes**    | Whenever the rule it encodes changes                                            | Whenever someone finds an ambiguity, or a decision is made           |

### `vectors/<section>.md` — how to write it

- **One entry per rule ID.** Every ID needs at least one **accept** vector and, where meaningful, one **reject** vector. If a rule has no observable reject case, say why in the file rather than leaving it blank.
- **Assert only what the text states.** This is the hard rule. If the text states a _requirement_ but not the _consequence of violating it_, the vector says **"violates FI-7.2-X"** — it does **not** invent "block invalid", "reverted", "slashed" or any other outcome. Inventing the consequence is a guess, and a guess in a vector becomes a test that locks in an interpretation nobody decided.
- **Unclear ⇒ `review/`.** If you cannot tell what the expected result is, you do not write a vector for it. You open a question in `review/<section>.md` and leave a pointer in the vectors file's "Not covered" table. This is why the vectors file has that table.
- **Sub-labels.** Sub-claims of one rule use `.a`, `.b`, … (`FI-7.2-1.a`). The rule ID stays the citation; the sub-label names the case.
- **Ownership on change.** The spec author is the content authority; whoever changes a rule must update its vectors in the same change. A vector that changes is a signal that dependent code and the guests' shared vectors must change too — that coupling is the point, not overhead.

### `review/<section>.md` — how to write it, and who does what

- **Anyone may raise a question.** The reviewer, an implementer, a prover author, an auditor, or the spec author. Being able to raise is intentionally open: the person who wrote the text is the least likely to see what it leaves unsaid.
- **Only the spec owner decides.** A reviewer documents the question and, if useful, a proposed resolution — but **must not fill in the decision**, because only the author can say what was meant. A reviewer's reading recorded as a decision is exactly the failure this file exists to prevent.
- **A question closes only by landing a change.** The decision must appear in `SPEC.md` as an added or amended rule with an ID (or as an explicit "no change, and here is why"), with vectors updated, and **then the entry is deleted**. Deleting it is the closure signal; leaving it forever turns this directory into a second specification.
- **Never normative.** If a question's answer is only ever written here, it is not part of the protocol. `review/` is where questions are born, not where they live.

## Checking your work

`rules/tools/check.py` is the executable form of this convention. Run it before every commit:

```bash
python3 rules/tools/check.py --base <revision-before-IDs>
```

Five checks, and what each one actually proves:

| Check     | What it proves                                                                                                                                                       | When it applies                                                                                                                                                                                                                             |
| --------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `purity`  | stripping every marker from `SPEC.md` reproduces `--base` after normalising line ends and markdown table padding                                                     | **Only when you pass `--base`**: it is a migration check, not an invariant. The repository's prettier hook owns whitespace, so a byte-exact comparison would fail by design; the normalisation tolerates re-padding but not a changed word. |
| `markers` | IDs are unique, in document order, and contiguous per section; a suffix ID (`FI-7.2-3a`) attaches to its parent number, and a gap left by a `retired` row is allowed | always                                                                                                                                                                                                                                      |
| `index`   | every marker has exactly one `INDEX.md` row and every live row has a marker; a `retired` row must not still carry a marker                                           | always                                                                                                                                                                                                                                      |
| `assets`  | every section has a vectors and a review file; every live `rule` has a vector heading; no heading names an unknown ID                                                | always                                                                                                                                                                                                                                      |
| `links`   | relative links and `#fragments` resolve; tables have consistent columns (pipes inside code spans and escaped pipes are not separators)                               | always                                                                                                                                                                                                                                      |

Exit code is non-zero if any check fails, one line per problem. **Omitting `--base` skips `purity` and runs the other four** — the normal mode after the ID migration and after any intentional rule amendment.

**A `purity` failure is not automatically a defect.** It means the stripped text differs from the revision you named. If you changed a rule on purpose, name the revision you edited from, or omit `--base`; if you changed nothing but markers, the markers moved — fix that before committing.

## Responsibility matrix

| Activity                                       | Reviewer / implementer / auditor | Spec author |
| ---------------------------------------------- | -------------------------------- | ----------- |
| Insert or amend rule IDs                       | —                                | **owns**    |
| Write or update vectors                        | may propose                      | **owns**    |
| Raise a review question                        | **owns**                         | may raise   |
| Fill in a decision on a review question        | **must not**                     | **owns**    |
| Delete a closed review question                | may, after the rule change lands | **owns**    |
| Decide whether a question is worth blocking on | proposes                         | **decides** |

## Attribution of a review question

Every question ends with an attribution line:

`Raised by: <agent or person> (<GitHub handle>)`

- It names **who raised it**, not who endorses it. An AI-raised question names the model and the account it was raised under — for example `Raised by: DeepSeek-V4.1-Flash (dantaik)`; a person names themselves and their handle.
- **Attribution confers no authority.** The `Decision` line is still owner-only, and a reviewer must never fill it (see the matrix above). An attributed question is still only a question.
- Do not leave it as a bare `reviewer`. A question with no known author cannot be followed up, and an anonymous question is easy to discount.
- If a question is re-raised or materially amended after discussion, add a second attribution line rather than replacing the first.

## Lifecycle

```text
rule in SPEC.md
      │ add ID
      ▼
   FI-7.2-N ──────► INDEX.md row
      │
      ├────► vectors/7.2.md   (determined; durable; feeds ACCEPTANCE §3)
      │
      └────► (if unclear) review/7.2.md question
                    │
                    ▼  decision by spec author
             SPEC.md rule amended (or "no change" justified)
                    │
                    ▼  vectors updated
             question deleted
```

## Adding a section

1. For each statement, record the verbatim text it starts with. It must occur **exactly once** in `SPEC.md` — check that before using it, because an ambiguous anchor puts a marker in the wrong place.
2. Attach the markers in **one** scripted pass that re-checks uniqueness, block placement, ordering and ID format, and refuses the whole batch if any entry fails. That anchor list is build scaffolding: generate it outside the repository and do not commit it. `SPEC.md`, `INDEX.md`, `vectors/` and `review/` are the reviewable artifacts.
3. Add a row per ID to `INDEX.md`, with its `Type`.
4. Write `vectors/<section>.md`, asserting only what the text states; list gaps in "Not covered" and point each at its review question.
5. Write `review/<section>.md` for everything you could not determine, and for any sentence you could not classify as normative; attribute every question.
6. Run `python3 rules/tools/check.py --base <rev>`; it must print `ALL CHECKS PASSED`.
