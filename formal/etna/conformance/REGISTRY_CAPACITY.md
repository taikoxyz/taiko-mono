# Current Registry capacity and stalled release

W03 consumes the W02 occupied-slot and lifetime conventions and models a
closed TAIKO supply. The reviewed SPEC, ACCEPTANCE and SWITCH bundle is
`2e6763e21bc236cfcda6011d164b32040f9e0c8d`. The recorder uses the
`registry-supply-model/bounded-recycling` source claim.

## Exact deployment inequality

For supply `S >= 0` and a positive number of slots `N`, the least integer
stake with `N * stake > S` is `floor(S / N) + 1`. With `N = 4096` and
`S = 10^27` base units, multiplication verifies each boundary independently.

| Stake in base units          | Product with 4096 | Meets strict inequality |
| ---------------------------- | ----------------- | ----------------------- |
| 244140625000000000000000 − 1 | S − 4096          | No                      |
| 244140625000000000000000     | S                 | No                      |
| 244140625000000000000001     | S + 4096          | Yes                     |

STAKE-4.1-14a, START-10-12 and PARAM-11-11 specify this deployment bound.
COMM-4.3 and LIMIT-12-11 assume fixed supply. The inequality shows that a
full registry cannot still hold every bond's original principal.

For the no-sink-return bound, let `D` be the original deposits of bonds
currently holding slots, `H` their remaining effective and pending
principal, and `K` the penalties those same bonds have paid to the sink.
When all slots are occupied, `D >= N * minStake > S`. If the maximum
bounty rate is `1 − q`, the sink share of each loss is at least `q`.
Hence `H + K >= q * D + (1 − q) * H > q * S` for `q > 0`. Top-ups add
to the principal subject to loss. With no returns, the part of the sink
balance attributable to those bonds remains present. The normalized
model checks `4 * (H + K) > 3 * S` in any full state with no sink return.
Per-bond paid totals are historical flows. Only the live sink balance
can fund a return, and the inequality's `K` excludes previously withdrawn
bonds' payments.

## Operational scope

| Source                                                        | Modeled action or accounting                                                                                                                                                                                                                                                                   |
| ------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| STAKE-4.1-13a, 14a, 27, 28                                    | On admission, debit liquid and bind the next ID and key to the lowest empty slot. Presence remains true after exit or penalty even at balance zero. Only withdrawal releases a slot. Refused calls preserve issuance, identity, escrow and accounts.                                           |
| STAKE-4.1-15–24                                               | Top-up moves available liquid to a pending balance, and an explicit activation moves ready pending principal into effective stake. An exit blocks top-up and activation.                                                                                                                       |
| STAKE-4.1-31–35, FORF-4.4-4–15                                | A slash pays the quarter bounty rounded down, with the rest to the sink. Forfeiture debits the ceiling half, effective principal first, pays the sink, and sets the lifetime flag. Both can shorten exit and preserve prior confirmation.                                                      |
| LIMIT-12-11                                                   | Reporter and sink returns are explicit transfers from their spendable balances to pooled liquid. A fresh registration spends actual available liquid.                                                                                                                                          |
| START-10-5, STOR-B-8, RECOV-8-49, LAND-6.1-9, PROOF-6.2-30–32 | Start initializes coverage from an eligible closed genesis cutoff. Authorized recovery records R and preserves that coverage. Tick freezes eligible powers at the close of R. Only a successful modeled first post-recovery landing with the frozen nonempty selection advances coverage to R. |
| STAKE-4.1-26–29                                               | Confirmation requires coverage of the bond's exit and records the first successful call's block. Withdrawal requires the full delay. The owner authorizes payment of positive principal to the chosen recipient, represented by pooled liquid. Anyone can withdraw zero.                       |

The graph has two slots, three lifetime IDs, liquid supply 7, minimum
stake 4, and one-block activation, exit and withdrawal delays. Every
balance stays nonnegative and liquid, effective stake, pending stake,
reporter and sink always sum to 7. Selection uses all eligible modeled
slots, a normalized threshold of one and a voting-power unit of one, so each eligible bond's power equals its effective stake. The caller controls an owner account,
a public representative or the forfeiture role. Each fresh key is a
canonical unused representative and issued keys stay available as
duplicate-key offers. Successful withdrawals pay to the pooled liquid
account. A recycle transfers one whole positive balance in this graph.
The positive scenarios show reporter-only saturation with A=0, B=4 and
sink=3, and sink-only saturation with A=2, B=4 and liquid=1.

Finite offer limits include one top-up of one unit per lifetime bond,
only the minimum registration amount, one recovery and its first landing,
and an L1 horizon of two to seven blocks. Start can use the most recently
closed cutoff. The graph offers lifecycle calls
for issued unwithdrawn bonds. Other key permutations, callers with
identical effects, partial recycling transfers, ordinary rotations,
recovery exclusions, and verifier rollback are out of scope. The graph
assumes lawful PoP, evidence, DAO authorization, token transfers and
successful proof validation when presenting an eligible modeled landing.
The recovery action represents the authorized transaction's R write.
It can complete with no eligible final selection, in which case the
modeled landing refuses. A nonempty normalized set establishes eligibility
for the projection. Real distribution, quorum, proof and deployment
requirements need their own checks.

## Checks

The operational action relation chooses among the offered calls at every
state. The finite offer limits and the outcomes of offered calls are
observed separately. `OffersExact` compares the actual enabled accept
and refuse transitions with an independently constructed call domain
and preconditions. `FramesExact` checks full effects and unchanged fields.
The Python observer replays each reported call and complete PRE/POST
record, then qualifies the complete named endpoint and its actual
movement or coverage history. The initial state also records the
evaluated profile for checking caller-supplied case metadata.

| Profile               | Checked outcome                                                                                                                                              |
| --------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `smoke`               | Two-block pre-start unprojected safety with the two-way offer audit.                                                                                         |
| `no-penalty`          | Unprojected bounded safety with neither penalty nor recycling.                                                                                               |
| `reporter-saturation` | Slash, reporter transfer and funded second registration while the sink balance stays 3.                                                                      |
| `sink-saturation`     | Forfeiture, sink transfer and funded second registration with a positive exiting holder.                                                                     |
| `funded-full-refusal` | Sufficient liquid and a fresh identity while both slots are occupied, followed by atomic refusal.                                                            |
| `stalled-release`     | Actual recovery and frozen R with no covering landing, elapsed L1 time, refused confirmation, public withdrawal and fresh registration.                      |
| `covered-release`     | Covering landing, first confirmation, premature withdrawal refusal, delayed public withdrawal and an unfunded registration refusal with an empty slot.       |
| `pending-withdrawal`  | Pending funds survive the effective-first penalty, a public positive withdrawal refuses, and the owner receives the remaining effective and pending amounts. |

The witness profiles use `WitnessView` for breadth-first search. It
preserves the operational state, frame check and every endpoint flag.
The previous displayed call has no effect on future transitions or
endpoint checks. TLC emits its actual representative transition with
the full raw call. A named difference establishes reachability in its
observed profile. Exhaustive safety requires a completed unprojected
search with zero states queued.

Select a case with the existing pinned checker, for example:

```sh
"$PYTHON" -B formal/etna/check.py --java "$JAVA" --tlc-jar "$TLC_JAR" \
  --config-dir formal/etna/products/registry-capacity --case reporter-saturation \
  --output-dir "$DISPOSABLE_OUTPUT"
```

Replay the untouched witness log with the reviewed three source documents
present at their normal workspace paths:

```sh
"$PYTHON" -B - "$CURRENT_SOURCE" "$TLC_LOG" <<'PYTHON'
from pathlib import Path
import sys

workspace = Path(sys.argv[1])
sys.path.insert(0, str(workspace / "formal/etna/conformance"))
from registry_capacity import audit_trace, reviewed_source

print(reviewed_source(workspace))
print(audit_trace(Path(sys.argv[2]).read_text(), "reporter-saturation"))
PYTHON
```

Actual fixed-supply token, deployment constructor acceptance, current
Registry correspondence and 4096-slot cold-state gas remain **WAITING**.
