# Public frozen design sources

These bilingual normative texts correspond to the 2026-10-27 04:07Z source edits
(12:07 Asia/Shanghai). They are public derivatives, not verbatim MCP responses:
Notion transport metadata, internal page URLs and discussion links have been removed.
Normative text and public technical references remain. `index.json` records edit
times, the public text hashes and upstream fetch hashes without internal URLs.
Earlier already-pushed commits still contain their original snapshots; this update
does not rewrite public git history.

`python3 scripts/prepare_spec.py INPUT OUTPUT` reproduces the sanitization. This
is a source-preparation tool; the output and any normative change require review.
No proof independently authenticates the Notion service or bilingual equivalence.

Clause IDs use a digest of normalized content, with an occurrence suffix for exact
duplicates. Line ranges are generated locations, not identities. Inserting unrelated
lines leaves IDs unchanged. Editing a linked clause creates a new ID and fails the
source-link check until the semantic mapping is reviewed. Run the generator to see
the complete inventory and current locations in `.scratch/generated/coverage.json`.

Canonical theorem types and reviewed source edges live only in
`manifests/design.json`; narrow claims and named boundaries are in
`spec-coverage.json`. These clauses are not atomic requirements or a coverage
percentage. A partial clause can contain many unproved obligations.
