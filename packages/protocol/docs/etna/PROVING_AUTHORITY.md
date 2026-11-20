# L1 authority for proving inputs

**Status: design discussion, not an amendment to SPEC.md.** This proposal asks
which state-derived inputs L1 should supply to proof verification, so guests do
not re-prove facts that the landing contract can establish directly. The hash
representation below is provisional. No contract, client, guest or deployed
behavior changes in this PR.

Raised by: Codex (smtmfft)

## Responsibility boundary

The host reads the required chain data and passes it to the guest. The guest
uses those values and binds them to its public statement. At landing, L1
constructs or independently checks the corresponding authoritative values and
verifies the proof against that same statement. A caller-supplied value does
not become authoritative merely because L1 includes it in a hash.

Use this boundary wherever L1 can enforce the same predicate at the required
historical context. Keep execution, signature/quorum verification, block and
data bindings in the guest. Existing execution witnesses and trie handling
remain unchanged. Reading data belongs in the host/provider; adding another
generic guest storage reader is not a prerequisite.

## What the current interfaces already establish

The inspected protocol implementation is
[PR #22286 at 7cd9606a](https://github.com/taikoxyz/taiko-mono/tree/7cd9606af6a8c9290874bd1525d58008e24ebadc/packages/protocol/contracts/layer1/etna).
This is a development source snapshot, not a deployment claim.

Its `EtnaInbox._hashLandStatement` builds a 21-word statement. L1 supplies the
deployment domain, current generation, retained origin EL/Comet hashes and FI
cursor, stored configuration digest, reference block hash and transaction blob
commitment. Guests can bind the values they use to those statement fields
without separately proving how L1 read its own storage or transaction context.
Opening a configuration digest, hashing the reference header before using its
state root, and matching actual blob payloads remain separate obligations.

`activeCommitteeSnapshot` instead comes from landing calldata and is stored
after proof verification. It is an output of the current proof relation, not
an independent L1 authorization of signing keys or voting powers. The current
statement contains no independently authenticated historical signing schedule.
The genesis committee record hash alone also does not cover later rotations.

The same source hashes initialization `sMin` into its configuration digest;
that is not evidence of the revised specification's required equality to the
registry's immutable `minStake`. Source/spec alignment remains necessary.

## Provisional interface: a signing-authority commitment

Reserve a public-statement field, provisionally `committeeAuthorityHash`, for
the context L1 authenticates. This is not a hash of QC signatures. It binds the
authorized signing sets that the guest uses to verify those signatures.

One candidate preimage binds:

- the complete deployment domain and recovery generation;
- the proof range `(p, h]` and its retained origin;
- an ordered, bounded schedule identifying each distinct activation boundary
  needed for both current and next validator commitments in the range;
- for each applicable set, a canonical keys-and-assigned-powers commitment and
  its effective height, plus the snapshot/context needed to authorize it.

The schema must cover the set governing `h + 1` where validating the header at
`h` requires its next-validator commitment. It must retain A-to-B-to-A changes,
recovery resets and the distinct outgoing/incoming activation semantics. It
must cover the full proof range when `p < c`, not just the newly settled suffix.
Exact encoding, domain tag, bounds and versioning are review questions, not
final ABI definitions in this document.

The guest opens each authorized set with its canonical public keys and powers,
matches all applicable current/next validator hashes, and verifies the required
native signatures and strict weighted quorum under the full signing domain.
The authority mechanism does not change the separate fewer-QC design question.

L1 must obtain this commitment from authoritative historical state or from a
separately authenticated derivation. Hashing a host-provided schedule is
insufficient. Neither the current committee nor the latest registry snapshot
can substitute for sets that actually governed earlier blocks.

### A smaller offload to consider first

If deriving complete signer sets on L1 is too costly, L1 can instead authenticate
the required historical registry checkpoint tuples and bind their ordered
commitment into the statement. The inspected registry interface exposes
`checkpointCount()` and `checkpointAt(index)` returning
`(l1Block, count, entriesRoot)`. A proposed lookup must check that a checkpoint
is the latest at the applicable cutoff, including its successor boundary.

In that variant the guest still opens the entry roots and uses the shared
selection/power implementation. It no longer needs MPT proofs to establish
those particular registry storage words. L1 would not itself compute the
signer-set hash, so the public field and specification must name the checkpoint
authority rather than claim L1 directly authorized the selected set.

For either variant, deciding which cutoff applies at a rotation can depend on
the committed L2 anchor history. State which part L1 establishes and which
part remains guest-proven; do not authenticate only membership while leaving
the historical checkpoint selection unconstrained. Document historical
availability, registration/top-up/exit ordering and upgrade/recovery behavior.

## Coherent specification and implementation changes

The current rules require committee derivation under authenticated historical
roots (COMM-4.3-1..17 and PROOF-6.2), and original account/storage witnesses have
their own validity and exact-path requirements (ENC-A-24..26a). Replacing their
authority with L1 inputs requires an explicit rule amendment and matching
node/guest acceptance. Authenticating equivalent checkpoint values alone does
not prove that an embedded original witness has the required encoding or path.

Review must decide whether those redundant witness items are removed, given a
new representation/version, or retain explicit validation. Keep original
proposal/DA byte binding whichever form is chosen. Do not simply delete guest
checks and call the existing protocol compatible.

The statement layout, L1 verifier input construction, native client codecs,
both guest journals, child-proof aggregation and deployment/image registration
must agree on the adopted version. An unused extra guest journal field outside
L1's recomputed statement does not supply this binding. Existing old proofs
must not silently acquire new authority semantics.

## Review questions and completion gates

- Which is the smallest useful authority: selected keys/powers, historical
  registry checkpoints, or another value L1 already records?
- How does L1 derive and retain it, at what gas/storage cost, and how is the
  selection cutoff tied to the committed L2 history?
- Which exact existing predicates become redundant, and which witness-format,
  anchor, schedule and execution predicates remain?
- What canonical preimage covers current/next sets, rotations, A-to-B-to-A,
  recovery generations and overlapping `p < c` ranges?
- What coordinated rule/ABI/version change makes node, guest and L1 acceptance
  agree, with no host-only trust or fallback?

Before adoption, cross-language vectors must show that changing any authorized
key, power, activation height, generation, cutoff, range or origin fails the
appropriate binding. Include a valid old proof landing after registry changes,
an overlap landing and recovery. Measure L1 costs and guest costs separately.
No gas, cycle, proof or implementation result is claimed here.
