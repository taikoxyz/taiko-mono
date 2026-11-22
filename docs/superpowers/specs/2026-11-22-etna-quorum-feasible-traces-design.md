# Etna quorum-feasible trace design

The user directly authorized continued verification after the selected L2
boundary review. This round reviews unmerged PR22425 at
`178d7a7a66b14305c2f6467ae77163f93dd677cf`, based on
`3602629758beb653423a23608fd1960810efcfac`, and adds a power/domain projection
around the immutable historical69 boundary model. Old completed stages stay
complete; this is a separately qualified extension.

The goal is to prevent an impossible parent omission or an unavailable current
quorum from being credited as a successful continuous lifecycle trace. It is
not a consensus engine, proof guest, cryptographic verifier or liveness proof.

## Inputs and sequence

`LastCommit` holds generation, height and exactly one keyed flag per parent
member: commit, nil or absent. These are abstract flags for one parent block;
round, signature, full chain domain and BlockID authentication are premises.
Keyed ordering does not model Comet wire ordering. Powers always come from the
selected authoritative set, never from a caller's claimed weights.

`Availability` holds generation, height and unique known keys eligible to vote
at that height. It is a bound on possible contribution, not an exact signed
certificate or a statement that all available members actually voted.

`advance_with_quorum` validates the immutable predecessor, requires parent=None
at the origin and a complete parent certificate otherwise, and requires
3*committed_power > 2*total_power in the predecessor's current_signers. It
requires independent >2/3 available power in next_signers for the new height,
then calls the historical `advance` once, deriving missing_keys from nil and
absent flags. Pending sets cannot rescue the current height.

An optional previous_availability binds parent flags to the availability
premise used by a trace driver at that parent's height. Commit and nil must
come from available keys; absent may be either offline or omitted. The driver
retains the last successfully admitted availability across a stalled retry.
Without that input the result is only an independent one-step power check.
This still does not prove compatible rounds, locks, signing or message delivery.

All invalid domains, malformed rows, inadequate quorums and rejected actions
raise ValueError without changing predecessor state. A failed block-start call
inside an otherwise power-feasible block advances and remains distinct from
having no block. Heights/generations use exact non-bool integers. The wrapper
must preserve all historical state, action and selection validation under -O.

## Evidence and scope

The independently frozen hand oracle is prepared before implementation.
It includes a seven-advance trace with stakes Q=10^27/4, four bonds, two misses
and a 10% rounded penalty, plus delayed fallback, same-key reseating, failed
call, weighted-set changes and retry branches. A small arithmetic bank may
enumerate all commit/nil/absent vectors for 1..4 members and powers 1..3;
its explicit finite bounds do not establish a quotient of production states.

A separate source manifest pins the new five-document identity; old source.json,
the model hash6065102a, runtime classifier, five accepted bundles, all old
claims, 911 tracked formal artifacts and TLC inputs retain their identities.
Fourteen source360 runtime rows stay WAITING and19 archived searches stay
INCONCLUSIVE. Actual staking/EL/guest, MPT, signatures, full128-member native
updates, cost and operating/history budgets remain absent evidence.

Source review separates full proof-origin witness validation from consuming
its278/279 for p+2: the exceptional root cannot authorize other Inbox values.
No-code calls and call failures have equal empty-state effects but different
execution success meanings; the symbolic flag is not an EVM implementation.
No production/SPEC/Notion/GitHub-comment changes are authorized. A confirmed
normal-path protocol defect stops for user discussion; wording clarifications
and documented limits must not be inflated into protocol defects.
