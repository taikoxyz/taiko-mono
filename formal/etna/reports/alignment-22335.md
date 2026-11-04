# Alignment with merged PR #22335

Current authority: main `e84a9aaac526c15597d97ee93f8803f92b02c279` (2026-11-04).
This refresh follows formal PR head `4f38cfcc8cbcfad10ec159110f5a8f74ca3e7ea5`
and merges that main revision into the existing PR history.

## Model and evidence changes

The current registry initializer and decoded slash reject `slashBountyBps = 10000`;
zero and 9999 remain admissible. The current enabled-slash theorem chain and H1–H3
premise record require the strict bound. Generic token arithmetic/conservation lemmas
retain the weaker `≤ 10000` bound where sufficient. Historical/shared machines,
the 1,216 historical manifest objects, historical authority pins and historical JSON
vector bytes are unchanged.

The existing current payment definition already computes the floor bounty and sends
the exact remainder to the fixed sink, using the authenticated outer caller without
excluding the bond owner. Kernel regressions now exercise self-reporting, 1001 units
at 1000 bps (100 bounty / 901 sink), one unit at 9999 bps (zero bounty / one sink),
zero bounty and rejection of the exact 10000 boundary. These are decoded-model tests,
not a new whole-rule or production-token proof.

Five SPEC clauses, two ACCEPTANCE clauses and six SWITCH clauses change identity.
Only two changed SPEC clauses had existing supporting edges: STAKE-4.1-34's exact
principal/payment projections and DATA-5.4-5's candidate rejection, authenticated
conflict halt and publication boundary. Those edges retain their exact theorem lists
and supporting status. No new edge or proof credit is assigned. PARAM-11-11 remains
deferred: evidence-window sizing is still a deployment premise. Inventory totals stay
38 partial / 528 deferred current clauses and 41 partial / 35 supporting / 527 deferred
binding rules, with 32 deferred assumption/limitation rows.

The current admission JSON is regenerated separately with the new authority commit;
its eight cases and behavioral outputs are unchanged. It does not claim coverage of
bounty distribution. The offline reader embeds the refreshed model, strict premise,
reviewed exact types, authority citations and rule titles.

## Clarified boundaries

Empty proposer/FI manifest fallback is a legacy derivation metadata-stage requirement;
the new written metadata-stage cases are separate from payload decoding. This package's
current decoded Etna H3 model does not implement that legacy derivation pipeline, and
this refresh adds no derivation or driver-parity proof.

The modeled current `setOrigin` gate is already inclusive at the fork timestamp.
The origin writer's separate wait for finalized L1 and the DAO proposal's inclusive
lead-time boundary are operational/implementation obligations; this refresh does not
add a DAO proposal or L1 finality implementation model. SWITCH remains deferred.

Current candidate inspection already retries unavailable material, rejects failed
checkpoint/DataHash authentication and halts an authenticated EL hash contradiction.
A record still awaiting L1 finality must keep real synchronization incomplete and
untrusted until retry; the model's primitive authenticated candidate inputs do not
implement that finality wait. Missing downloads likewise differ from a publisher
omitting required starting material. No complete snapshot-sync or ACCEPTANCE proof
is added; all ACCEPTANCE clauses remain deferred.

## Validation

Local validation used the pinned Lean 4.35.0-rc4 toolchain. The full 196-job build
passed, as did 17 focused authority/economics/payment tests in 42.128 seconds.

The complete Python command executed **567 tests in 1489.372 seconds: 566 passed and
one failed**. The failure was the evidence-package test's obsolete literal raw SPEC
fingerprint from the preceding authority. Its SPEC and ACCEPTANCE expectations now
match the reviewed current bytes, and it additionally checks SWITCH's fingerprint.
The complete affected evidence-package module then passed **all 10 tests in 1.031
seconds**. The other 566 outcomes remain applicable because this follow-up changes
only fingerprint expectations and this report; the original full command's exit was
not green.

After the full command and the affected-module rerun, the **canonical serial audit
passed in 155.62 seconds**: all 1,821 exact contracts, types, mechanical roles,
transitive allowed axioms, fresh whole-import-closure replay and 50 Lean regression
modules passed. All 15 current premise fields (22 including historical fields) are
consumed by the headline proofs. An earlier overlapping audit was provisional; the
final audit ran alone after the suite and is the recorded final audit evidence.
The 460 mechanical property derivation chains do not count verified protocol rules.

Final serial checks passed for the eight historical vector files, separate current
admission file, deterministic Audit/971-clause inventory, offline reader freshness,
authority pins, exact rule evidence, source/import lint and reader JavaScript syntax.
Historical manifest objects, archived authority bytes and historical vectors remain
unchanged. Direct Prettier 3.2.5 and whitespace checks pass. The repository pre-commit
wrapper still fails on pnpm's rejection of the existing `p256-verifier#v0.1.0` and
`urc#main` aliases; equivalent formatting checks ran directly, with `LEFTHOOK=0` for
commits. The lockfile is unchanged.

The semantic/vector checkpoint is `a8722e8caf570ba64597f532b6945313e3182643`.
This follow-up only corrects the fingerprint test and records validation. Historical
hosted results in preceding reports apply only to their recorded SHAs; this local
validation does not claim a hosted run at the new head.
