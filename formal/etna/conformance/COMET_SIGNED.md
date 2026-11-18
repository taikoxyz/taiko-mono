# N01 stock Comet signed admission

This lane consumes public vote fixtures at stock CometBFT v0.40.0 commit
`0880b4d378f347ab16e54ec677ff50d803f37d62`, tree
`083ecc3cf413b6333ffe47c2b0ce1d91ce84a259`. The existing 1,659-file Comet
manifest and reviewed SPEC correspondence remain the source authority.

## Published inputs

The versioned, strictly parsed [public projection](comet_signed/public-votes.json)
contains the selected deployment binding, one public signer, 23 signed votes,
14 named pairs, five domains and three public spectator keys. Numeric words
are canonical decimal strings, including both signed timestamp seconds and
unsigned uint64 bits. The exact origin is the published
`testdata/etna_vectors/vectors.json` at
`89f419915de4b73bb57c53bf970f6dea9e8e8c8c`, blob
`e069e2930143cbaf126d46532a96179764ec0ab6`, SHA256
`85d9df59bbc1709950be8cd8b248a3871523229afabd3d4e65b8027d6e4529de`.
The source extraction decoded only explicitly allowed value tokens. The
isolated Go test receives only the resulting public projection. A checked
hash, recursive field allowlists and exact typed identities guard these bytes.
The signer point matches the separate [public registration fixture](registry_public/registration.json).

## Expected native behavior

The [literal oracle](comet_signed/pins.json) records exact per-leaf
expectations independently of native execution. Every published row compares
`VoteSignBytes` byte-for-byte and verifies the unchanged 65-byte signature
through the native secp256k1eth key and `Vote.Verify`. `Vote.ValidateBasic`
accepts 21 rows and refuses `partial_block_id` and `hash_only_block_id`
for incomplete BlockIDs. The two partial IDs encode and verify with each
absent hash mapped individually to a nil Go slice. The zero BlockID supplies
native nil semantics. The `max_values` row only exercises wire and signature
APIs. A signed second of -1 retains the uint64 word 18446744073709551615.

| Role                                   | Stock consumer                         | Independent expected observation                                                                                                                                                          |
| -------------------------------------- | -------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Commit at exact two thirds             | Full `VerifyCommit`                    | Typed insufficient signed power 2/2. A1 power 2 of 3 at index 0.                                                                                                                          |
| Commit above threshold                 | Full `VerifyCommit`                    | Accept A1 power 3 of 4 at index 0 and one absent slot.                                                                                                                                    |
| Commit below threshold                 | Full `VerifyCommit`                    | Typed 2/3 with total 5. Separate index-1 control yields typed 1/2 with total 3.                                                                                                           |
| Genuine signed nil                     | `VoteSet.AddVote`, full `VerifyCommit` | Nil majority at power 3 of 4. An A-target commit with that nil signature refuses with typed 0/2.                                                                                          |
| Invalid nil signature and swapped slot | Full `VerifyCommit`                    | Exact signature and address mismatch branches respectively.                                                                                                                               |
| Duplicate and same-block later time    | `VoteSet.AddVote`                      | Original remains the only vote with unchanged native power. Exact duplicate is idempotent. Genuine later-time signature verifies separately and hits nondeterministic-signature handling. |
| A/B and A/nil                          | `VoteSet.AddVote`                      | Typed conflict carries both votes. No added power or competing block tracking.                                                                                                            |
| Chain, address, index and H/R/type     | `Vote.Verify`, `VoteSet.AddVote`       | Distinguish signature, address, index and step refusals. Changed H/R/type also fails signature with a matching step.                                                                      |
| Round 1 and 2                          | `HeightVoteSet.AddVote/POLInfo`        | Genuine prevotes select (1,A) then (2,B) at power 3 of 4, retaining the earlier vote. Both admit at exactly two thirds with no POL.                                                       |
| POL controls                           | `HeightVoteSet.AddVote/POLInfo`        | Wrong height refuses. Invalid type adds nothing. R2 signature rebound to R1 refuses. A genuine precommit remains in its separate bucket.                                                  |

The public receipt records actual sign bytes, signatures, key/address,
validator order and powers, vote slot bits, native power, majority BlockIDs,
POL rounds and exact diagnostic. The first smoke selects only genuine
`precommit_a`; the full campaign runs 45 leaves per phase. A unique source
fault changes the final threshold from `<=` to `<` inside
`verifyCommitSingle` on the same private copy used before and after the
fault. Only `commit-exact-two-thirds` is expected to fail under that
fault, with its exact diagnostic. All raw commands, outputs and guarded
source/build hashes are kept in the requested output directory.

## Offline invocation

The runner takes a manifest-matching source snapshot, pinned Go SDK,
existing module and build caches and the existing physical build-cache
lock. See `run_comet_signed.py --help`. The first invocation uses
`--smoke` and a fresh `--output`. The full invocation requires the reviewed
smoke directory via `--smoke-output` and a different fresh `--output`.
The existing isolation launcher and supervisor enforce offline local
Go resolution, explicit read-only bindings, two writable bindings and
descendant cleanup. Native source, runtime executable identities, adapter
and public fixtures are checked before and after each phase.

The profiles describe controlled one-signer API arithmetic outside the
Etna launch concentration constraint. The 14 pair descriptions and five
domain records are projected for downstream consumers. This lane reaches
the above stock Go API boundaries. Authenticated committees, signed proposals,
round locks, successor block validation, finalization, P2P and production
signer behavior remain open.
