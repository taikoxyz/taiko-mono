# Trust assumptions and implementation contracts

This inventory classifies the existing seven fields of `Etna.Statements.Premises` and the
supplemental signing hypotheses. It changes no field, H1-H3 statement or protocol rule.
A conditional theorem can use an implementation contract before a production refinement is
available; that contract is still an outstanding implementation-verification obligation.
None of the classifications below certify a backend, guest, client, signer or contract.

## External trust versus Etna-owned contracts

| Existing field        | External trust retained                                                                                                                           | Contract that an implementation/deployment must establish                                                                                                                                                                                                                                                                                                                                                                               |
| --------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `genesis`             | The selected L1 deployment/initialization data and genesis execution are authentic.                                                               | The actual initialized Inbox/registry equal `Deployment.Genesis`: correct genesis hashes/root, committee/config openings, fixed origin, snapshot, nonce, queue, fee state, immutable bounds and address/chain bindings. `Genesis` does not itself derive initial lifetime-key uniqueness, exit-history visibility or absence of confirmations; the initialized signing corollary names those additional initial-state facts explicitly. |
| `verifierSound`       | Every accepted backend combination contains a sound backend. Its proof-system/cryptographic/attestation assumptions are external.                 | The sound backend's **guest** proves `Certifies` for the correct image and complete statement, opening the deployment commitments and binding real execution and blobs to the modeled batch. Proof-system soundness alone does not establish correct guest semantics. The contract is restricted to submitted accepted landings, as its definition states.                                                                              |
| `authenticatedInputs` | L1 finality and the underlying header/hash/MPT authentication primitives are sound.                                                               | An FI witness that `forcedAuthenticated` accepts under an accepted anchor, for an index below that anchor's tail, from the current generation's origin L1 block up to, not including, the landing's block, shows the World's actual queue entry at that index. Authenticating a proof under an unrelated root is insufficient. The field constrains no anchor field; see the next section.                                              |
| `hashSeparation`      | Idealized collision/preimage separation: the stored config hash has a unique **representable uint256** opening.                                   | The real seven-word canonical encoding, complete chain/deployment identity and Keccak adapter match the stored commitment and ghost configuration. The field is not an injectivity theorem for unbounded natural numbers.                                                                                                                                                                                                               |
| `headerHashes`        | Correct execution/header hashing can be delegated to the pinned EL and hash primitive.                                                            | `executionValid` accepts only when both parent/child hashes equal the hashes of their actual decoded headers; genesis has the same binding. Etna-specific execution and header changes, including zk gas, FI singleton execution and EIP-4788 processing, need conformance evidence.                                                                                                                                                    |
| `headerSeparation`    | Idealized header-hash collision resistance.                                                                                                       | The full decoded anchor is authenticated consistently from the L1 block bound by the header. The actual EL header carries the anchor number and state root, not every decoded anchor field, so this field contains an authentication/refinement duty as well as hash trust.                                                                                                                                                             |
| `signatureAgreement`  | Signature unforgeability and correct primitive implementations are external dependencies; this field itself states agreement, not unforgeability. | Every consensus-accepted vote in this deployment is accepted by the registry's signature verifier with the same key and evidence bytes: canonical encoding, secp256k1eth format, full domain, generation, height, round, phase and block id must agree. A real cross-implementation obligation, not an arbitrary trust boolean.                                                                                                         |

## Environment relations no premise constrains

`verifierSound` asks only that a landing be `Certifies`: valid under the rules `Deployment.build`
derives from the environment's relations. Of those relations, a premise constrains
`executionValid` (`headerHashes`), `forcedAuthenticated` for indices below an accepted anchor's
tail (`authenticatedInputs`) and `signature` (`signatureAgreement`). The others are free: H1-H3
hold for whatever they accept, and that they accept exactly what the spec requires is an
implementation obligation of the guest, and of the node for the same checks.

| Relation                             | What an implementation must establish                                                                                                                                                                                                                                                                                                                                                                                                                                     |
| ------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `anchorAuthenticated`                | An accepted anchor shows the Inbox at its L1 block: recovery generation, lastCheckpoint height and hash, FI head and tail, and that block's timestamp and stateRoot (3.3; 6.2 item 8). H3's queue service is relative to the tail and timestamp an accepted anchor reports (`AnchorTail.understated_tail_passes_due_entry`); `honest_anchor_queue_service` and `honest_anchor_chain_sees_due` take honest anchors as explicit hypotheses (`AnchorHonesty`), not premises. |
| Forced witness flags and `singleton` | `storageAuthenticated`, `canonical`, the raw hash and length and the transaction-0 fields of a witness are computed from the actual bytes, and a block's `singleton` result is its actual single-transaction build (7.2). `forcedAuthenticated` binds only the index and stored entry.                                                                                                                                                                                    |
| `committeeAuthenticated`             | Switch-block registry proofs verify under the S(t) state root (3.4 rule 6; 4.3).                                                                                                                                                                                                                                                                                                                                                                                          |
| `payloadValid`, `batchPayloadValid`  | The envelope, data hash, FI transaction 0 and singleton build decode as sections 5 and 7.2 require, and the blobs carry exactly the batch's payload (6.2 item 9).                                                                                                                                                                                                                                                                                                         |
| `historyAuthenticated`               | The fixed origin, genesis schedule, historical registry and anchor lookups (6.2 items 1-2).                                                                                                                                                                                                                                                                                                                                                                               |

The less-than-one-third Byzantine-power hypothesis is H2's explicit antecedent rather than an
eighth `Premises` field. It concerns each relevant actual committee, including punished members
whose fixed voting power persists. Capital thresholds do not establish that antecedent.

Stock CometBFT's cross-round locking correctness may be adopted as a pinned dependency
assumption, represented by `CrossRoundAccountable` in the supplemental height-agreement result.
The separate `Locking.commit_agreement` derives design-level cross-round safety from
pinned lower-level prevote/PoLC/lock rules; `shared_history_commitValid_agreement` also
derives equal active committees from raw shared prefixes. Actual Comet implementation
refinement, truthful event attribution and engine integration remain external. The fixed
coupled markdown/paper proof reading is not a deployment option.

## Normal-run and recovery composition contracts

`NormalSigning.Run` is a provenance refinement, not a new production machine. "Normal" means
only "without verifier-failure rollback": its recovery is any accepted `recover` call,
including one whose reselection a late registration captured (`RecoveryCapture`). Its projection
uses every original ordinary transaction kind. It leaves out verifier-failure rollback and
requires each landing to carry:

- its actual accepted call and L1 time order;
- `Deployment.build` with the World's stored configuration and an authenticated decoded archive;
- the valid batch and exact certificate/statement equality;
- `SnapshotSource` for the **prior** stored snapshot in the same consensus history;
- the existing reference contract `activeCommitteeSnapshot <= l1ReferenceBlockNumber`.

These witnesses must come from actual producer/guest/history behavior. `Built`, an accepting
proof pair or a trusted boolean alone do not manufacture them. No theorem lifts a headline `Run` to it: under `Premises` a submitted landing supplies the
batch, construction and statement equality (`submitted_landing_certified`), but the prior-snapshot
source, the reference bound and the absence of rollback require stronger raw history inputs.
`CanonicalHistory.run_normal` now derives normal provenance from initialized accepted calls,
append-only decoded archive/header bindings and raw origin/reference bounds. Its
`submitted_history_landing` bridge uses the original submitted-batch theorem, and its witness
actually lands and signs after recovery. The old free `historyAuthenticated` predicate alone
does not establish these inputs. No selected
cutoff bound, final confirmation coverage or key exclusion is an edge premise: the new
proofs derive them from these provenance contracts and explicit initial conditions.

`SnapshotSource.normalRecovery` additionally supports recovery before the first landing. It
names an actual successful recovery, its L1 ordering and preserved checkpoint/snapshot, and
binds the current context's generation and origin to that call. The bound it yields reads only
the clock, time order, kept snapshot, generation and origin, that is `s.snapshot <
ctx.originBlock` one generation above `before`; the recovery call and kept checkpoint name the
provenance but no bound reads them, and `before` is not tied to a trace. Its pre-recovery snapshot/clock
fact is derived by `NormalSigning.recovery_snapshot_source` from the preceding normal run and
initialization, rather than being assumed as a committee cutoff inequality.

`ConfirmationSource` has two paths. The replay path supplies the exact `IncludedCheckpoint`
and actual ordinary causality. The recovery path supplies original ordinary paths before and
after a real successful recovery, together with its unchanged current generation and origin.
The old complete checkpoint record remains retained. Thus an old confirmation checkpoint below
a new fixed origin need not be replayed as a new-generation block. Multiple recoveries can use
the last one, with earlier recoveries on its preceding ordinary path. Availability and real
authentication of these records are still archive/producer obligations.

## Signing contracts and boundaries

| Supplemental input                                                  | Responsibility                                                                                                                                                                                                                                         |
| ------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `TrustedPrefix`                                                     | Authenticate the correct deployment/configuration, fixed origin, registry history and anchors; replay valid blocks matching **both** checkpoint hashes and the FI cursor; enforce the node checkpoint fences, reference finality and archive coverage. |
| `ConfirmationSource`                                                | The view causally covers this particular confirmation through exact replay or retained ordinary-recovery history. Own-finalized truth alone does not imply knowledge of a newer global confirmation.                                                   |
| `EngineRequest`                                                     | The real Comet/app request uses this prefix's domain/generation, actual local tip + 1 and a selected member, for proposals, prevotes, precommits and nil votes alike.                                                                                  |
| `ObservedCall`                                                      | The exact decoded message/bytes and immutable key bind to the actual successful `Signer.sign` result and returned signature. Crypto/encoding correctness remains a refinement obligation.                                                              |
| `persisted`, authoritative log/session and generation switch inputs | Establish linearizable durable writes, retained HRS state, correct device identity, fencing and authenticated session/generation decisions through crash, restart and failover. A supplied `true` is not production evidence.                          |
| Initial `KeysWellFormed`, `ExitVisible` and no confirmations        | Establish the registry's initial lifetime identities and history. These are explicit deployment-state contracts, not additional claims secretly inferred from the current `Genesis` definition.                                                        |

The result guarantees current next-height committee exclusion and the exact fresh signature/log
binding under these contracts. It does not prohibit historical or stale-view signatures below a
newer global checkpoint, guarantee continuous positive collateral, timely evidence delivery or
DAO action, or certify production rollback/session implementations. The separate TrustState
trace proves revalidation and durable-log behavior in an ideal session machine; its
authenticated-generation watermark must be authoritatively restored independently of HRS.
Cross-generation rollback needs a truly certified CanonicalHistory source/reference bound,
stronger than the older same-generation source hypothesis. Target/headerMatches and replay
prove decoded metadata properties, not physical EL-state availability or snapshot fetch
success. Reconstruction separately assumes a complete authenticated starting state. See
[design safety composition](design-safety-composition.md). Real two-proof resource
acceptance and bridge/token execution remain independent implementation/launch obligations in
`ACCEPTANCE.md`.
