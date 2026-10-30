# CLAUDE.md

Guidance for AI agents working on the Etna PoS + ZK specification in this directory.

**Authority: [`rules/README.md`](rules/README.md) defines the convention.** This file is the operator checklist; if the two disagree, `rules/README.md` governs. Read it before your first edit.

## Non-negotiables

1. **Never hand-edit ID markers in `SPEC.md`.** IDs are attached only by a single-writer insertion pass that checks uniqueness, placement and ordering. A marker placed by hand bypasses every check.
2. **Never change rule text while adding an ID.** The binding invariant: stripping every marker from `SPEC.md` must reproduce the base revision's text — same words, same order, same structure. Whitespace and table padding belong to the repository's formatter, so `check.py` compares normalised text.
3. **Never renumber an ID.** Insert with a suffix letter (`FI-7.2-3a`); a retired ID is never reused.
4. **Vectors assert only what the text states.** If the text states a requirement but not the consequence of violating it, the vector says `violates <ID>` — never invent _invalid / reverted / slashed / rejected_. Before writing a bare `violates <ID>`, check whether the text states the consequence elsewhere, and write it if it does: 3.4's rules 1–9, which ProcessProposal and FinalizeBlock apply (block invalid); the `land` reference, whose checks are normative (`land` reverts); `recover` ("any failure reverts everything"); registration (STAKE-4.1-9); Appendix A's strict decoding ("any violation makes the proposal invalid"). If you cannot state an expected result, do not write a vector: open a review question.
5. **Only the specification owner decides.** Never write a `Decision` line, never claim consensus, and never delete a question unless a rule change has landed in `SPEC.md` (or a "no change, and here is why" decision was made).
6. **Attribute every question**: `Raised by: <agent or model> (<GitHub handle>)`. Attribution names the author, not an endorsement.
7. **Code blocks are not normative by default.** Only definition blocks that state requirements - Appendix A today - may carry IDs, and only in the `code-before` form: a `// [ID]` line above the governed line, which stays unchanged. Examples and interface sketches are cited only where a `code-before` ID says so.
8. **Types matter.** `rule` binds; `limitation` (section 12, and SYNC-9.1-9) and `assumption` (Appendix C, except the rule COST-C-5) are citable but nothing conforms to them. Never turn a limitation or assumption into a rule silently. An ID covers the text up to the next marker or the end of its line; see [rules/README.md](rules/README.md#how-far-an-id-extends).
9. **No invented facts.** No measurements, no implementation claims, no deployment claims. If a number is not in the document or a cited measurement, do not introduce it.
10. **The Notion copy is the owner's.** Do not edit it from here.

## Before you commit

```bash
python3 rules/tools/check.py --base <revision-before-IDs>
```

It must print **ALL CHECKS PASSED**. The checks are: **purity** (stripping every marker reproduces `--base` after normalising table padding — prettier owns whitespace, so a byte-exact comparison would fail by design), **markers** (unique, document order, contiguous per section; suffix IDs such as `FI-7.2-3a` are audited, and a gap left by a `retired` row is allowed), **index** (1:1 with `INDEX.md`), **assets** (vectors and review present for every section, every live `rule` has a vector heading, every cited question exists), **links and tables**.

`--base` names the revision before the IDs were attached, or the revision you are editing from. **`purity` only runs when you pass `--base`**; omitting it skips purity and runs the other four, which is the normal mode after the ID migration and after any deliberate rule amendment. [rules/README.md](rules/README.md#checking-your-work) has the full table of what each check proves.

## Where things are

| Path                         | What                                                                 |
| ---------------------------- | -------------------------------------------------------------------- |
| `SPEC.md`                    | the specification - **the authority**                                |
| `rules/INDEX.md`             | ID → type → title → section → vectors                                |
| `rules/vectors/<section>.md` | determined, checkable consequences; feeds `ACCEPTANCE.md` §3         |
| `rules/review/<section>.md`  | undetermined questions; owner decides; deleted when a decision lands |
| `rules/tools/check.py`       | the checks above                                                     |
| `ACCEPTANCE.md`              | resource, recovery, shared-vector and launch acceptance              |

## Adding a section

Follow [`rules/README.md`](rules/README.md#adding-a-section): build the anchor list outside the repository, apply the markers in one pass, add INDEX rows, write vectors, write review notes, attribute every question, then run the checks. The anchor list is scaffolding — do not commit it.
