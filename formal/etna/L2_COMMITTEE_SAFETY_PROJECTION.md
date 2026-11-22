# Free safety view and first invariant failure

The original full-state Free search reached its 45-second limit at height bound 14. Its result remains **INCONCLUSIVE**. The nine finite witness profiles reached their named invariant violations with the full state. The Free safety configuration uses `SafetyView` with the same finite instance, operational choices and bounds. The Free-only identity encoding is specified below. This argument concerns the six configured safety predicates. Search completion and elapsed time require a separate TLC result.

## Equality used by the search

TLC still evaluates the model on concrete states. Before symmetry canonicalization, two Free states have equal views exactly when these four components agree:

1. The current chain record, omitting only `parentCert`, `missBitmap` and `updates`. In particular the current height, generation, origin, origin fallback, current/next/pending assignments, current certificate and its votes, ledger, snapshot and stored generation must agree.
2. The checkpoint's presence and its saved height, complete ledger, snapshot and stored generation.
3. The entire environment, including key availability, both per-generation budgets, current threshold, fallback and captured recovery authorization.
4. The actual truth values of `TypeOK`, `PipelineSafe`, `SnapshotOrderSafe`, `QuorumSafe`, `RecoverySafe` and `LedgerSafe`, in that order. These are evaluated on the concrete state and its concrete receipt.

Free's cursor is always zero. A previous receipt supplies diagnostics to the predicates but never enables an action. Each non-stuttering action writes its own receipt from the immediate concrete predecessor. Stuttering preserves the receipt. All witness configurations retain the full five model variables.

## Lifting the next input

Call a reachable state good when all six predicates hold. Consider two good states with equal views. They offer the same Free inputs. The following inspection covers each successor for the same offered input in both states.

| Operation | Enabling data and common successor data | Checks involving omitted fields |
| --- | --- | --- |
| Block, committed | Height bounds use current height and checkpoint height. The two quorum checks use the origin, current assignment and certificate, next assignment, live keys and offered omission. Call eligibility uses the ledger, input and checkpoint presence. The block-start effect, ordinary calls, election and pipeline shifts use retained values. | The action overwrites all three omitted chain fields. The old current certificate becomes the new parent certificate, its votes and the old ledger determine the bitmap, and the old pending and newly elected members determine all updates. Checks of snapshot order, ledger deltas and parent participation use each receipt's matching old retained values. The complete checkpoint stays identical to its own prior value. |
| Block, refused | The same offer fails the same quorum test. Height, ledger, environment and checkpoint do not advance. | Each successor compares its entire chain, checkpoint and environment with its own predecessor, so the three frame equalities hold in both. Unconditional typing and chain-quorum facts about omitted metadata carry over from each good predecessor. |
| Land | Permission requires the actual current certificate, an increasing height above the origin/checkpoint and an available land budget. The retained new checkpoint fields come from the retained current chain fields. | Each successor saves its own complete chain. Thus `landed.state = PriorChain` holds even if the representatives have different old parent certificates or update lists. Checkpoint typing follows from the predecessor's chain typing; the newly saved strict certificate is the retained current certificate. |
| Authorize, set threshold, lose availability, rotate fallback | Each guard reads the retained environment or retained checkpoint and generation. The entire new environment is determined by these values and the input. | Chain and checkpoint frame comparisons compare a concrete record with its own preserved value. Their unconditional typing, assignment and quorum checks carry over. Each new receipt selects the same action-specific predicate branches. |
| Recover, accepted | Authorization, generation, cap and expected checkpoint use retained data. The action restores the saved height, ledger, snapshot and stored generation. | Recovery overwrites every other checkpoint-chain field in building the new chain: generation, origin, origin fallback, current/next/pending assignments, both certificates, bitmap and updates. Restored monetary and snapshot data agree. The saved checkpoint itself stays identical to its own prior value. Both successors therefore satisfy the same origin, reset, restoration and frame tests. |
| Recover, refused | The same captured authorization mismatches the current checkpoint or generation. | The entire concrete environment and chain are preserved, including the threshold. The same mismatch and local frame equalities are observable. The checkpoint and its typing carry over. |
| Stutter | The full state is unchanged in each execution. | Each state keeps its own receipt and its same six truth values. |

Consequently, starting from good representatives, every concrete step in either execution has a step on the same input in the other, producing equal retained operational data and equal six predicate results. The proof uses the predecessor's good prefix for unconditional facts about preserved hidden fields. It does not assume that all well-typed, arbitrarily constructed records have matching successors.

## First failure

`Init` fixes a single concrete state and receipt. Its ledger is fully seated, the initial snapshot and certificates are empty, the two origin assignments point at heights 11 and 12, and the absent checkpoint carries the switching state. These values satisfy the six predicates. By induction through the good prefix before a first failure, TLC can use any reached good representative with the same view for the next input. At the first failing step the corresponding successor has the same false predicate bit. A good representative has six true bits and cannot suppress that failing view. In the other direction every expanded representative and its successor come from concrete enabled steps. First failures are terminal for this argument.

For example, changing only a new origin's parent certificate to a well-typed nonempty certificate leaves both operational projections intact, but makes `QuorumSafe` false. Its truth bit distinguishes that state immediately. The view uses the predicate values themselves, so no operational prediction of what a check should return can mask it.

The argument depends on the present operations and predicates. Changes to checkpoint restoration, discarded fields, observation or action guards require checking the lifting argument again. It establishes no temporal/fairness or witness-trace equivalence, and provides no speed guarantee.

## Four interchangeable stake identities in Free

The unpermuted height-14 search using the view alone also reached its 45-second limit. Both that result and the earlier full-state timeout remain **INCONCLUSIVE**. The safety configuration now binds four distinct TLC model values `a,b,c,d` to `SymmetricBonds` and requests their permutations. The nine witness configurations bind the unused constant to the empty set. They use the original numeric IDs, named keys, numeric miss bitmaps, input schedules and full state.

### Re-encoding the original finite instance

Fix the bijection from old seat/bond IDs 0,1,2,3 to atoms a,b,c,d in that order. Use the corresponding bijection from old stake keys A,B,C,D to the same atoms. A field's schema selects the bijection and its inverse.

| Field role | Encoding |
| --- | --- |
| Bond/seat identity | Relabel ledger function domains, occupied and forfeited sets, and call targets by the ID bijection. |
| Key identity | Relabel stake members and votes in every assignment, snapshot, certificate, update, availability set, loss and omission. All F and G keys, including their role and controller premises, stay fixed. |
| Miss bitmap | Encode a numeric mask by the set of atoms whose original seat bits are set. Every subset of the four atoms decodes to exactly one integer in 0..15. The empty set decodes to zero. |
| Scalar, tag or structure | Preserve amounts, counters, powers, thresholds, heights, generation, round, block IDs, booleans, tags, record labels and tuple positions. Apply each field rule recursively inside the checkpoint and the prior-state receipt. |

This mapping is bijective on the selected typed records and inputs. The same atom can appear in a seat field and its corresponding stake-key field because every bond has exactly one immutable key and always occupies its own seat while seated. There is no schema-free replacement of the integers 0..3. In particular a balance of one, seat 1 and a power of one have three distinct roles. No Free guard chooses a specific seat number or compares a bond identity against an amount or height.

### Preservation of actions and predicates

For each permutation of the four atoms, transform a state and an input together, with the identity on all other values. Under the schema above the following statements apply both to renaming Free atoms and to translating the original concrete model into the atom representation.

* Initialization assigns the same balance, occupancy rule, miss count, exit state and permanent key relation to all four bonds. Empty bitmap, fallback sets, origin, threshold and authorization retain their prescribed values. The initialized state is fixed under all four-atom permutations.
* Every original Free block offer has its corresponding offer. There is the empty list or an exit/forfeit for any one bond. Optional vote omissions and the persistent loss set range over every permitted key or subset. Renaming keeps cardinalities and the distinction between a stake and a fallback key. The same strict quorum inequality admits or refuses the renamed block.
* Missing seats are determined from the actual parent certificate's member/vote difference and the live occupied seats. Pointwise miss counting, reset, full penalties, release, exit and forfeiture commute with renaming because lookup at the renamed seat returns the same scalar. The ledger function at a renamed bond retains the original balance or exit height. Bitmap membership in Free means precisely that the seat's bit was set in the old numeric bitmap. The source uses no seat ordering for any other modeled decision.
* Block-start snapshot membership, total, threshold comparison and the H+2 decision depend on sets, their sizes and fixed numeric values. Both committee shifts and the generated add/delete update records commute with renaming. The new current/parent certificate and diagnostic receipt are pointwise transformations of the originals.
* Land copies its actual prior chain. Recovery restores its own saved ledger and snapshot and constructs fresh origin assignments from the same fixed fallback list. The other L1 actions update scalar settings, selected keys or captured height/generation. A refused action and stuttering preserve the appropriately renamed concrete records. These facts give both directions of transition preservation by applying the inverse permutation or inverse typed encoding.
* `TypeOK` carries numeric bitmap range into membership in the power set of four seats. `QuorumSafe` carries the empty-origin bitmap and each original bit test into empty-set and seat-membership tests. Other comparisons in those predicates preserve domains, cardinalities and scalar bounds. `PipelineSafe` checks every key and update, `SnapshotOrderSafe` and `LedgerSafe` check seats pointwise, and `RecoverySafe` checks complete typed copies or assignments. Equality is preserved in both directions for all these relations. All six concrete truth bits therefore remain unchanged.

### First bad state with symmetry and view together

Projection of the retained fields commutes with any atom permutation, and the six truth bits remain fixed. For two good states whose views agree up to permutation, rename one representative to align the views, apply the same-input lifting argument above, then apply the inverse permutation to the chosen input and successor. Free offers the required renamed input. Induction through a good prefix therefore preserves a first false predicate bit, and a failing concrete path has a corresponding path in the original labeled four-bond instance.

The pinned TLC canonicalizes the full raw state under symmetry before applying the view. Equal resulting keys imply equality of views up to a stake permutation. Hidden receipt or checkpoint details can influence the chosen canonical rename, so the search may distinguish more states than ideal canonicalization of the view alone. Refining the proved equivalence leaves first-failure preservation intact. The permutation group has 24 elements, but neither a 24-fold speedup nor search completion follows. This argument covers only Free's six finite safety checks. The named witnesses, fairness, liveness, general seat counts and unequal voting powers are outside the symmetry claim.

## Corrected stale-refusal budget and actual corruption control

The final kernel applies the two-update budget only inside an accepted recovery
branch. A stale captured checkpoint is refused and frames chain, landing and
environment even at that budget limit. The guard reads the same retained fields,
so the lifting and permutation arguments apply to the corrected domain. The
three earlier incomplete searches keep their pre-correction identities. The
corrected-kernel search also timed out; no exhaustion follows from this proof.

A separate actual TLC diagnostic added an equivariant fixed-F origin parent
certificate corruption while retaining full Free Next. It changed no other
actual variable, including receipt. The two raw states had the same operational
projection; the second violated QuorumSafe; the actual verdict vector kept the bad state
visible. Private source/config bytes were then restored exactly. This is a
fault-only diagnostic, with no claimed exhaustive Free baseline/restoration PASS.
Pinned TLC skips state-invariant checks on seen fingerprints, so these truth
bits cannot be removed on an assumption that all generated states are checked.
