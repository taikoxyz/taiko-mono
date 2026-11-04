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

Validation is recorded after the complete local build, audit and regression run.
Historical hosted results in the previous reports apply only to their recorded SHAs.
