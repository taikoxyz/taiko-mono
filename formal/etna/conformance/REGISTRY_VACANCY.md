# Current Registry vacancy and bond reuse

W02 models current Registry admission and bond lifetime behavior. Its source is
the SPEC, ACCEPTANCE and SWITCH bundle at
`2e6763e21bc236cfcda6011d164b32040f9e0c8d`. The observer calls W01's
`classify_workspace_documents` for the exact three document byte streams and
`select_claim` for `registry-vacancy-model/lowest-empty-slot`. Selection gives
the reviewed scope. Execution receipts record the actual model, profile and trace.

## Rule mapping

| Source                                                   | Represented transition or observation                                                                                                                                                                                                                                                                                                                                                          |
| -------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| STAKE-4.1-1–4, 13a, 14a, 30 and ACCEPTANCE §3            | A funded registration takes the lowest unoccupied slot, issues the next bond ID and binds the submitting owner and unused lifetime key. Full and duplicate-key refusals are actual attempts with unchanged Registry and cash state. Occupancy, held-slot and lifetime key lookups each keep a presence flag independent of numeric zero.                                                       |
| STAKE-4.1-15–22 and COMM-4.3-3, 7, 17                    | Owner top-up adds pending principal and a ready block. Explicit activation moves it into effective stake. Pending principal stays out of checkpoint entries and power. Exit prevents top-up and activation.                                                                                                                                                                                    |
| STAKE-4.1-23–29                                          | The owner's request schedules exit. Confirmation requires an external covering landing, records its first call's L1 block and is idempotent. Withdrawal requires one more block. The owner may withdraw positive balance and anyone may withdraw zero balance. Withdrawal clears owner, slot and temporary funds/clock fields while preserving ID, key, exit and any lifetime forfeiture flag. |
| STAKE-4.1-31–38 and FORF-4.4-1–16                        | Valid double-sign evidence debits all principal and splits it between reporter and sink. An authorized forfeiture debits the ceiling half of remaining principal, effective funds first, and sets the permanent flag. Both shorten an exit if applicable and retain slot occupancy and confirmation.                                                                                           |
| STAKE-4.1-36, COMM-4.3-1–8, ENC-A-37–38 and STOR-B-20–34 | Block closing makes one symbolic checkpoint if any slotted entry changed. Checkpoint entries are indexed by slot. Free capture retains one closed checkpoint and its candidate powers permanently. Owner, pending funds, forfeiture and confirmation fields do not enter this projection.                                                                                                      |
| PROOF-6.2-30–31 and RECOV-8-49                           | The Registry consumes a successful covering landing. Local observation of a sample cannot advance coverage.                                                                                                                                                                                                                                                                                    |

`EtnaRegistryVacancy.tla` models the represented state and inputs. `Next` chooses
the next offered call freely at each state. `FramesExact` compares the resulting
record with separate literal equations over all fields, including the unchanged
ones. `AdmissionEnabled` derives the finite registration input domain from the
literal prestate, then checks actual offered success and refusal in both directions.
The Python observer independently validates recorded inputs and replays the complete
Registry PRE/POST frames of each selected native TLC trace. Witness marks are
checked on matching frames; the final divergent source-fault frame is classified
by its exact Registry difference and input, without asserting its marks.
Witness predicates and metadata
classify actual transitions and do not constrain call order.

## Finite state and premises

- Two slots, four lifetime bond identities, two owner identities and an independent
  public representative. The DAO forfeiture caller is a separate role.
  Unused keys are symmetric under renaming. A fresh funded call offers the
  canonical next unused key, and every issued key remains a candidate duplicate
  through withdrawal. There may be at most two slot reuse events per execution.
  Fresh calls beyond the ID/reuse limits are outside the finite input domain.
- Minimum stake 3, funded registration amounts 3 and 4, one accepted top-up of 1
  per lifetime bond, and activation, exit and withdrawal delays of one block each.
  The top-up limit is an experiment bound. Permissionless caller variants with
  identical projected effects share a representative. The cash fields record
  aggregate deposited, held, bounty, sink and paid principal. Transfer success and
  available funds for each offered deposit are premises. W03 closes the supply
  ledger and analyzes global capacity and recirculation.
- Block time is bounded by 8. A tick closes its previous block, so blocks 1–7
  close in the widest profile. Block 8 remains open to transactions.
  The no-exit sentinel 11 stands for the uint48 storage sentinel. The latest
  possible activation block is 9 and exit request can set at most 10.
- Checkpoint count is observed as the number of represented occupied slots.
  This is a symbolic occupancy observation, not the authenticated prefix width
  called `count` in STOR-B-21. It cannot justify compacting holes in ABI entries.
  The separate [Y05 positional component](REGISTRY_SNAPSHOT.md) checks that width
  and its literal encoding; these older symbolic model/config/raw bytes remain
  unchanged.
  The symbolic checkpoint carries the separate bond/occupancy identity for
  tracing, and its entries are a projection of the slotted fields. Hashes,
  packed layouts and concrete Merkle encodings require native correspondence.
  Free capture samples one closed block. The existing checkpoint is retained,
  including when that block changed no entries. Candidate powers use unit voting
  weight and include all eligible tracked slots. The sample may be empty.
  The ordinary unsampled profiles check block closure but do not explore history
  capture. The historical witness checks one captured pending-but-unactivated
  entry, later activation, withdrawal and reuse across its actual trace.
- The Inbox is initialized. Registration PoP, double-sign evidence, DAO
  authorization, matching evidence key, deadline, transfer success and
  token/chain bindings are assumed for the offered calls. Recovery exclusions,
  rollback, deployment conditions and full committee selection are separate.
  Forfeiture uses half-rate and slashing pays one-quarter bounty rounded down.
  The parameters permit a positive pending liability to remain after partial
  forfeiture. They do not exercise forfeiture debiting into pending principal.
- A `Land(snapshot)` input stands for an actual successful authenticated landing
  with monotone coverage of a closed block. W02 assumes the external settlement
  and any ambient committee required for such an input. The two tracked slots may
  have no eligible signer, so the two-hole trace does not establish a globally
  reachable covering landing in an isolated two-slot deployment.

## Opt-in checks

The configs are under `formal/etna/products/registry-vacancy`. Pass this directory
with `--config-dir` to the existing `formal/etna/check.py` launcher and select one
profile with `--case`. Use already pinned Java and TLC tools and a disposable
output directory. Ordinary `smoke`, `safety-3` and `safety` configure horizons 2,
3 and 8. All retain the two-way admission audit. Only the two-block smoke
exhausted. Both bounded safety-3 attempts were inconclusive, and safety at
horizon 8 remains open. Witness configs expect their specific `*NotReached`
invariant and retain raw actions for independent replay. Short witness profiles
use horizons 2 or 3. The historical search keeps the eight-block bound to
allow time for snapshots, activation, covering landing and delayed reuse.
The focused long witness profiles keep full frame checks and omit the separate, expensive all-offer diagnostic.
Their traces establish reachability for the displayed actions.

The `full-refusal` and `public-withdraw` breadth-first profiles use
`EtnaRegistryVacancyWitness.tla`, which extends the same operational module and
defines a TLC `VIEW`. It retains the exact Registry
record, frame result, witness marks and every endpoint truth value that reads
the previous raw call. The one future-use discriminator for that previous call
is whether it was a refusal of a withdrawn lifetime key. Other details of that
call cannot affect the next operation or any witness target. TLC still emits
the complete actual representative trace. The ordinary safety profiles use
the unprojected state. The same view is valid for the selected structural source
faults whose altered actions depend only on the Registry record and call. It
retains the first failed frame and the changed state for full trace replay. A
future observer that reads more previous-call fields, or a mutation that requires
additional hidden history, must update this argument and the view together.

| Profile                   | Raw witness                                                                                                                                                                                                                                                                                                                                      |
| ------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `held-zero`               | A fresh registration skips the lower held-zero slot and takes the higher vacancy.                                                                                                                                                                                                                                                                |
| `full-refusal`            | An offered fresh registration finds both slots held, including a zero-balance holder and a pending-positive exiting holder.                                                                                                                                                                                                                      |
| `two-holes`, `two-reuses` | The two-reuse trace must show IDs 0 and 1 holding distinct slots simultaneously, an actual withdrawal from each, both slots vacant, and fresh IDs 2 and 3 taking slots 0 and 1 in order. The final use count is two per slot. The standalone empty-topology target also requires raw history qualification, especially if the horizon is raised. |
| `public-withdraw`         | A public caller withdraws a confirmed zero-balance bond from slot 0 after the delay. A fresh ID and key subsequently reuse slot 0.                                                                                                                                                                                                               |
| `duplicate-key`           | A key remains registered after withdrawal. Its rejected call leaves the exact prestate available for an immediately following fresh admission.                                                                                                                                                                                                   |
| `forfeit-pending`         | Partial forfeiture leaves a slotted bond with positive effective and pending principal.                                                                                                                                                                                                                                                          |
| `historical`              | Capture sees effective stake with an already pending increase. Actual activation changes live stake, and later reuse leaves the old checkpoint and identity unchanged.                                                                                                                                                                           |

The deeper profiles can use a finite stock TLC simulation of the same unviewed
`Next`. The fixed seed selects a search, with no action or outcome scripted by
the oracle. From the isolated read-only source snapshot, for example, run the
historical case with pinned Java and TLC tools.

```sh
cd "$CURRENT_SOURCE/formal/etna"
"$JAVA" -Xmx768m -XX:+UseParallelGC -cp "$TLC_JAR" tlc2.TLC \
  -simulate num=8192 -depth 96 -seed 1 -workers 1 -deadlock \
  -metadir "$SCRATCH/states" -config products/registry-vacancy/historical.cfg \
  EtnaRegistryVacancy.tla
```

Retain the complete native output and status. For a simulation hit verify its
native seed, worker count and generated-state summary as well as the selected
invariant and every full frame. A finite no-hit or timeout is inconclusive.
Simulation carries no distinct-state or queue statistics.

Verify the source and replay the untouched log from the exact `historical`
configuration as follows. The snapshot contains the current documents at the
three W01 paths. The caller supplies the reviewed Python executable.
`capture_history`, `max_time` and `simulation_seed` match this invocation.

```sh
"$PYTHON" -B - "$CURRENT_SOURCE" "$TLC_LOG" <<'PYTHON'
import json
from pathlib import Path
import sys

workspace = Path(sys.argv[1])
sys.path.insert(0, str(workspace / "formal/etna/conformance"))
from registry_vacancy_observer import audit_trace, reviewed_source

authority = reviewed_source(workspace)
audit = audit_trace(Path(sys.argv[2]).read_text(), "FrozenSelectionNotReached",
                    max_time=8, capture_history=True, simulation_seed=1)
print(json.dumps({"source": authority, "audit": audit}))
PYTHON
```

A named counterexample establishes reachability for its trace. Exhaustion requires
a completed ordinary run with zero queued states. Native current-rule Registry
correspondence remains **WAITING**.
