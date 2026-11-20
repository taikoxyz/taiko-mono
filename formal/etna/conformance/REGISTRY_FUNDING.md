# Historical Registry funded forfeiture

The `funded-forfeiture` producer checks one historical Registry proxy with a local exact-transfer token and published registration proofs. The selected document bundle is `2e6763e21bc236cfcda6011d164b32040f9e0c8d`. The executable contract revision is `89f419915de4b73bb57c53bf970f6dea9e8e8c8c`. `reviewed_source(workspace_root)` checks the three current documents and returns the fixed claim with `execution = NOT_EVALUATED`.

| Observation | Block | Timestamp | A / B / public / Registry / sink |
| --- | ---: | ---: | --- |
| Initial allocations and approvals | 10 | 1000 | 9 / 4 / 2 / 0 / 0 |
| Register A and B with four units each | 10 | 1000 | 5 / 0 / 2 / 8 / 0 |
| Record executor and exact forfeiture calldata | 12 | 1000 | 5 / 0 / 2 / 8 / 0 |
| Owner A deposits pending principal | 12 | 1000 | 0 / 0 / 2 / 13 / 0 |
| Execute at the inclusive deadline | 15 | 1060 | 0 / 0 / 2 / 8 / 5 |
| Cover exit and confirm | 16 | 1060 | 0 / 0 / 2 / 8 / 5 |
| Withdraw four after the two-block delay | 18 | 1060 | 4 / 0 / 2 / 4 / 5 |
| Reapprove and register a fresh A key | 19 | 1060 | 0 / 0 / 2 / 8 / 5 |

Forfeiture reads the nine units present at execution. Rounding up at 5000 basis points charges five. Four units come from effective stake and one from pending stake. The remaining pending four retain readiness block 14. The sink receives five. Each Registry balance equals the sum of effective and pending principal for all three modeled bonds. After withdrawal the original key remains used and forfeited. The payout funds the fresh registration, leaving B and fresh A with four each.

The two saved-prefix branches exercise timestamp 1061 and a public top-up by an actor holding two tokens and an allowance of one. The restored clock is block 12 and timestamp 1000. Later calls exercise an uncovered exit, withdrawal at block 17, public withdrawal at block 18 and reuse of the retired key. The fixture's `setGeneration(1)` and `setSnapshot(14/15)` are synthetic Inbox inputs. Land, recovery, nonce advancement, DAO authorization, production TAIKO funding and current Registry admission are outside this observation.

## Evidence interface

`audit_journal(receipt: bytes)` accepts the native event payload. Its first eight ABI words specify the fixture schema, test driver, token, Inbox, Registry, implementation and two templates. Each following length-prefixed tuple encodes one named observation. The consumer checks the complete call schedule, calldata, return or custom error, before/after state, ordered events and access frames. Its journal buffer is bounded at 2 MiB. Each wide observation calls the same inherited digest in a fresh self-only memory frame outside the recorded call window. The selected 95 words include three bond records, two slots, tree and checkpoint state, thirteen token account pairs and the transfer counter. Where captured, the inherited digest covers all 8192 raw admission cells.

`current_receipt(workspace_root, raw, *, execution, stderr)` takes the untouched Forge JSON and a trusted same-run capture. The caller provides actual execution provenance. Matching supplied metadata cannot authenticate its origin. The closed execution JSON uses schema `etna-registry-funding-execution-1` and carries `claim`, `nativeCommit`, `forgeArgv`, `environment`, `sourceFiles`, `cwd`, integer `returncode`, boolean `timedOut`, `stdoutSha256` and `stderrSha256`. The pinned inventory covers the actual historical Solidity import closure, fixture files, public registration JSON, config, launcher, Forge and solc. The outer native event sequence must also agree with the journal.

The recorder includes code-size probes issued by the Solidity caller, template code copies during setup, and resumed delegate contexts. The journal checks their callers, depth, initialized and revert flags, zero native balances, and storage ownership. Registry proxy calls load the ERC-1967 implementation slot; delegated instructions access Registry storage. Setup observes the implementation pointer in the first actual proxy load and the inherited wide digest. Parent test-contract bookkeeping and the cheatcode that seeds that pointer execute outside the recorded child SSTOREs.

The ordinary unit suite covers arithmetic, caller identity, the deadline and token route checks. Select the explicit unittest target `test_registry_funding.native_capture_suite` to exercise genuine full-receipt and metadata changes. It requires `ETNA_REGISTRY_FUNDING_CAPTURE`. The capture directory supplies `stdout.log`, `stderr.log`, and `execution.json`. `ETNA_REGISTRY_FUNDING_WORKSPACE` locates the reviewed workspace documents.

### Ordered storage access profile

The `storageGeometry` section in `registry_funding/pins.json` records each frame’s ordered `[slot, isWrite]` pairs, including empty frames. Its 27 steps, 152 frames and 502 storage accesses came from the reviewed historical Registry, public fixture, solc and Forge build identified in its provenance. The native journal and Forge JSON hashes identify the originating capture. Each new run supplies its own actual output digest.

The profile checks the placement and order of SLOADs and SSTOREs in this compiler and recorder version. It identifies, for example, the confirmation write after the Inbox snapshot call. Account identities, previous and new values, selected state, wide digest, token movement, event data and call outcomes use the source-derived checks described above. Replacing the compiler, recorder, contract or fixture requires a separately reviewed profile. The consumer has no regeneration path.
