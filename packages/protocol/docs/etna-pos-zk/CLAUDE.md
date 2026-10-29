# CLAUDE.md

Guidance for AI agents working on the Etna PoS + ZK specification in this directory.

**Authority: [`rules/README.md`](rules/README.md) defines the convention.** This file is the operator checklist; if the two disagree, `rules/README.md` governs. Read it before your first edit.

## Non-negotiables

1. **Never hand-edit ID markers in `SPEC.md`.** IDs are attached only by a single-writer insertion pass that checks uniqueness, placement and ordering. A marker placed by hand bypasses every check.
2. **Never change rule text while adding an ID.** The binding invariant: stripping every marker from `SPEC.md` must reproduce the base revision **byte for byte**.
3. **Never renumber an ID.** Insert with a suffix letter (`FI-7.2-3a`); a retired ID is never reused.
4. **Vectors assert only what the text states.** If the text states a requirement but not the consequence of violating it, the vector says `violates <ID>` — never invent *invalid / reverted / slashed / rejected*. If you cannot state an expected result, do not write a vector: open a review question.
5. **Only the specification owner decides.** Never write a `Decision` line, never claim consensus, and never delete a question unless a rule change has landed in `SPEC.md` (or a "no change, and here is why" decision was made).
6. **Attribute every question**: `Raised by: <agent or model> (<GitHub handle>)`. Attribution names the author, not an endorsement.
7. **Code blocks are not normative by default.** Only definition blocks that state requirements - Appendix A today - may carry IDs, and only in the `code-before` form: a `// [ID]` line above the governed line, which stays unchanged. Examples and interface sketches are cited only where a `code-before` ID says so.
8. **Types matter.** `rule` binds; `limitation` (section 12) and `assumption` (Appendix C) are citable but nothing conforms to them. Never turn a limitation or assumption into a rule silently.
9. **No invented facts.** No measurements, no implementation claims, no deployment claims. If a number is not in the document or a cited measurement, do not introduce it.
10. **The Notion copy is the owner's.** Do not edit it from here.

## Before you commit

```bash
python3 rules/tools/check.py --base <revision-before-IDs>
```

It must print **ALL CHECKS PASSED**. The checks are: **purity** (stripping every marker reproduces the base revision byte for byte), **markers** (unique, contiguous per section, document order), **index** (1:1 with `INDEX.md`), **assets** (vectors and review present for every section, every `rule` has a vector heading, every cited question exists), **links and tables**.

`--base` names the revision before the IDs were attached, or the revision you are editing from. **`purity` is a migration check** - once rule text is amended on purpose the text will differ, so pass the current base or omit `--base` and let the other four checks run. [rules/README.md](rules/README.md#checking-your-work) has the full table of what each check proves.

## Where things are

| Path | What |
|---|---|
| `SPEC.md` | the specification - **the authority** |
| `rules/INDEX.md` | ID → type → title → section → vectors |
| `rules/vectors/<section>.md` | determined, checkable consequences; feeds `ACCEPTANCE.md` §3 |
| `rules/review/<section>.md` | undetermined questions; owner decides; deleted when a decision lands |
| `rules/tools/check.py` | the checks above |
| `ACCEPTANCE.md` | resource, recovery, shared-vector and launch acceptance |

## Adding a section

Follow [`rules/README.md`](rules/README.md#adding-a-section): build the anchor list outside the repository, apply the markers in one pass, add INDEX rows, write vectors, write review notes, attribute every question, then run the checks. The anchor list is scaffolding — do not commit it.
