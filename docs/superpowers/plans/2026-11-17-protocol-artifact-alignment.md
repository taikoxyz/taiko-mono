# Align client protocol artifacts with the switch contracts

Client base: 0262c503bbf9f75388d9f653f081278eac1615dc (PR22280).
Protocol target: ce4a50feee4f4134c1a094cb6da1f66f235fe9b4 (published PR22286).

The user authorized publishing the contract stage, then aligning protocol artifacts, ABI and pin.
DAO, tests and real proving backends remain excluded. Shared vectors are copied exactly as generated
artifacts; no behavioral tests or test adapters are authored or run.

## Work

- Update the single protocol pin and regenerate the Etna artifacts/shared vectors, including the
  two new switching implementations.
- Regenerate legacy Inbox/Anchor/PreconfWhitelist bindings from the same checkout. Remove the
  absent and unused LookaheadStore module. Read Alloy from the workspace and preserve its manifest
  through the generator; never hand-edit generated crate files.
- Record binding ABI/source hashes and include bindings in artifact reproduction checks.
- Generate twice and compare exact bytes; compile and strictly lint production targets.
- Update current documentation, independently review, then publish the client alignment.

## Audit decisions

- Landing LandInput/land ABI and switch getters are unchanged, so production Rust API rewrites
  are unnecessary. Solidity GenesisRecord field names change, without changing storage layout.
- Registry Vote hashes now carry empty or 32-byte bytes; the imported ABI selector is 0xd61617a4.
- Shared vectors become schema 7, with unchanged original sign bytes and nonvote sections.
  Existing schema-6/count-specific test assertions remain outside this request.
- App/journal/trust schemas and persisted state do not change; no migration is performed.

## Progress

- Contract commit ce4a50fee pushed and PR22286 head verified.
- Two read-only audits confirmed production consumers, generator issues and absent legacy modules.
- Generators are being updated to use the one published protocol revision and workspace Alloy.
- Generated nine Etna artifacts and three legacy bindings. The linked cutoff implementation is
  explicitly ABI-only, with source library references retained in its manifest rather than exporting
  unlinked deployment bytecode. Deployable fixtures retain the strict no-unresolved-links check.
- Full generated output reproduced byte-for-byte across repeated generation: 30 files, including
  all exact shared-vector copies. Binding Cargo.toml and Cargo.lock remain unchanged.
- Production workspace check and strict all-feature Clippy/docs passed. Canonical landing ABI is
  unchanged; the refreshed registry selector is independently computed as 0xd61617a4.
- No production ABI rewrite or persisted-format migration was needed. The known schema/count-specific
  tests and their adapters remain intentionally untouched under the user's exclusion.
- Independent review found no actionable defect in pin/provenance, ABI-only linking policy or
  production consumer compatibility. Native binding files and upstream vectors were not hand-edited.
- Publishing the client alignment follows a commit and the expanded repository reproduction gate;
  the existing broken repo formatter wrapper is replaced by the directly executed same-version formatter.
