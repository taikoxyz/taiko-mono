# Etna normal-recovery signing composition

## Intent and approved scope

Extend PR #22292 so a confirmed exited lifetime key cannot regain current-chain signing authority after ordinary rotation, withdrawal, slot reuse or normal governance recovery. The user approved this scope in chat on 2026-11-01 and requested implementation and an update of the existing PR.

Use the existing Lean 4.35.0-rc4 model. Keep the seven headline premises and H1-H3 claim types unchanged. No production contract, client, signer gate or protocol validity rule changes.

## Required result

Connect successful exit confirmation to authenticated registry history and the committee of the actual next-height signing request on a trusted current prefix. Derive the selected-cutoff bound from accepted landing provenance and recovery origin/time ordering; do not assume that bound, the desired committee exclusion, a live bond or positive collateral.

Same-generation replay inclusion stays supported. Across recovery the old confirmation checkpoint can be below the new fixed origin. Carry its authentic provenance through ordinary protocol history instead of requiring that old header to occur in the new generation's replay. Preserve the original transitions and cover ordinary registrations, edits, FI operations, fee sweeps, nonce invalidations, certified landings and normal recovery.

The result remains conditional on authentic L1/EL/registry inputs, correct request production and immutable key/signature adapters. The node view must cover the relevant confirmation. No global freshness bound is added. Historical signatures, lagging signatures below a newer global checkpoint, verifier-failure rollback, cross-round locking internals, continuous collateral and production implementation certification remain outside this result.

## Architecture and builder decisions

Reuse lifetime-key/history exclusion, accepted-batch endpoint/snapshot results and SigningBridge's actual successful Signer.sign binding. Introduce the smallest typed source/provenance certificate required to connect ordinary history to a later trusted prefix. It must project to the original machine, preserve every ordinary operation and contain no desired exclusion or cutoff conclusion as a field.

Separate confirmation coverage transport from confirmation-source transport into the current consensus history. A recovery floor must be derived from a successful normal recovery and its time ordering, not an arbitrary assumed floor. Exact names and representation are builder decisions after reading the current definitions. All additional interface obligations must be explicit in theorem statements.

The initialized positive witness performs ordinary rotation, confirmation, withdrawal, normal recovery and actual fresh signing with a replacement key in the new generation. Include a post-recovery ordinary handover when practical. Show that the old checkpoint is below the new origin and the old key remains excluded. Preserve existing same-generation positive and stale-view witnesses.

## Premise classification

Document each Premises field without changing its type. For mixed fields distinguish external primitive/dependency trust from Etna-owned interface obligations: backend soundness versus guest/image/statement binding; hash separation versus canonical encodings and authenticated anchor interpretation; signature security versus consensus/registry sign-byte agreement; initial-state assumptions versus deployment checks. Also classify trusted-prefix, request-producer, immutable-key, persistence and confirmation-view obligations. A documented assumption is not a completed production acceptance check.

## Completion and validation

Kernel-check the general composition and a genuine initialized positive witness. Add exact manifest contracts, roles and imports for every new public theorem. Add positive and negative regressions, including mutations that retain valid Lean syntax but break actual provenance/request bindings, plus a silent unmodified baseline.

Run source lint, import checks, clean build, vector freshness, deterministic artifacts, clause/rule coverage, the strict proof audit with fresh kernel replay, and the full Python suite. Update README/reports and the existing PR description with measured results and precise limits. Obtain a fresh independent review before pushing; resolve confirmed Critical/Important findings.

Do not weaken bindings, use custom axioms or native evaluation, replace the original machine with an unconnected smaller one, or promote partial traceability to whole-spec verification. If a general result fails, expose the smallest genuine missing provenance condition or provide a reachable counterexample rather than silently changing the promise.
