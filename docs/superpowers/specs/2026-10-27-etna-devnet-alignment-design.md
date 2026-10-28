# Etna devnet client and deployment alignment

## Goal and approved scope

Update taiko-mono PR #22280 and k8s-configs PR #1663 to run a fresh Etna devnet against the current canonical Chinese spec, protocol PR #22286 and the lean alethia-reth PR #262. The user will deploy it. The intended local acceptance path is bootstrap → four-validator consensus → EL transaction inclusion → committee transition → dummy-proof landing and advancing L1 checkpoint → ordinary restart/catch-up.

The user explicitly excludes real proving guests and governance recovery. Mock proofs establish the devnet's integration only. No Kubernetes apply/delete, live contract deployment, secret rotation or running-chain reset is part of this work. Local isolated Anvil/Docker deployments are tests. Update and push the two existing PRs; do not merge.

## Authorities and immutable inputs

| Source                 | Revision / role                                                                                                                |
| ---------------------- | ------------------------------------------------------------------------------------------------------------------------------ |
| Canonical Chinese spec | Notion page 3fe9673143d6813da4cdeb86d5203dfd, last edited 2026-10-27T04:07:38.279Z; snapshot `/tmp/etna-client-align-spec.txt` |
| Protocol #22286        | `23963b68e43b4cbeaf83113eeb61fbc1bddb4c46`; fixed deployed interface, storage and schema-4 vectors                             |
| EL #262                | `b046734a0a47b17ca66c33ccbc7c9087cbbf9b1e`; generic bounded builds and definitive pruning error                                |
| Client starting head   | #22280 `f0036c1f80d3324563f87622688520e7705e779a`, base `1204948fbf4e4b3a238ee82a54ef72a346ccb841`                             |
| K8s starting head      | #1663 `1eb18b0d6ae9db6b8b45e0f3d3922473f1db368b`, base `36305d893a8f325fcfe5824312a73f612ccc8f53`                              |

The spec governs observable client behavior. Protocol #22286 fixes K=6, which the spec permits. Internal names and code organization are builder choices. Record any actual contradiction rather than silently change the referenced contracts or spec. The prior V15 design and unpublished V15 worktrees describe a different protocol and are not authorities for this task. Leave their worktrees and untracked documents untouched.

## Current gaps

The published client still uses Ed25519 registry entries and a numeric chain-id suffix, heartbeat eligibility, an older configuration/committee/statement, a registered proposer reward recipient, L2 fee-vault claims and Comet headers in public blobs. Its Engine requests do not carry the new byte bound. The K8s PR pins older artifacts, generates Ed25519 consensus keys, initializes local signing state in Comet home and provisions the old fee-vault/bootstrap flow. This requires a coordinated format refresh, not only a dependency bump.

## Client and host behavior

### One supported fresh-genesis format

Use APP_VERSION=1, versioned V1 domain tags, the seven-word/224-byte committee config, five-field CommitteeRecord and five-field RegistryEntry (`ckPrefix`, 32-byte `ckX`, `effStake`, `activeFromL1`, `exitEffectiveL1`). Keep envelope/payload prefix 0x06. Match protocol schema-4 vectors, ABI selectors and Appendix B storage exactly: ordinary anchor witnesses [268,270,271,281], registry R/R+1, three-word slot-285 landing records and three-word slot-290 generation origins. Do not read reserved slots as old reward/status fields.

Use generation=0 genesis from owner-initialized Inbox authentication. Bind the complete L1/L2 chain ids, Inbox proxy and generation into `chainDomain`; chain_id is `etna-` plus canonical unpadded base64url of the 32-byte digest (48 ASCII bytes). Genesis height is 1, time is the initialization L1 block time, app_hash comes from the EL genesis, and the only consensus key type is stock CometBFT v0.40.0 secp256k1eth. Keep exact default transaction-result and consensus-parameter contracts.

Reject previous app/config/journal formats explicitly. Choose a distinct internal journal schema for the new incompatible layout; its number is an implementation detail, not a spec constant. This work supports new genesis, not migration of deployed state or populated registries. Detect a different/nonzero generation and remain closed with an explicit unsupported-recovery result; do not fabricate a recovered state.

### Committee, signatures and guarded startup

Authenticate the complete registry snapshot and derive genesis and normal committees directly: eligibility, descending stake / ascending set-key tie break, top n_max, floor(stake/vp_unit), then set-key encoding order. Reject duplicate eligible keys, empty results and arithmetic/power errors. Remove heartbeat filtering, old-member priority, reward-recipient fields and d_max/margin_v derivation. U is directly authenticated and independent of epoch length L.

Use canonical H(t)=1+t\*L and epoch(h)=floor((h-1)/L) for positive heights, S(t)=H(t)-2 and D(t)=H(t)-3 for incoming epochs. The earlier H=tL design transcription is superseded by canonical §4.2. At L=900, D(1)=898, S(1)=899 and H(1)=901; the outgoing committee signs S and S+1. Snapshot uses D(t)'s committed anchor and the generation origin floor; registry proofs are under S(t)'s own anchor root. S(t) updates become active at H(t); batches may cross the transition.

Use canonical compressed secp256k1eth keys, Ethereum validator addresses, low-s 65-byte R||S||V signatures and stock VoteSignBytes. Node, host validation, genesis and Go FilePV helper must agree with cross-language vectors. Preserve complete checkpoint-trust/readiness gates for all signatures, including nil/repeated votes; transport identity need not use the consensus algorithm. Do not fork CometBFT or silently substitute generic secp256k1/SHA256 semantics.

Preserve startup/reconnect authentication and durable fatal evidence. Temporary L1/EL unavailability waits/retries; hash-canonical unsupported L1 header formats make ProcessProposal reject without a fatal latch while FinalizeBlock waits for an upgrade. Contradictory authenticated data closes trust and follows the specified safety behavior. Normal process restarts preserve HRS, WAL and private history. Real guest and recovery-domain transitions remain unsupported.

### Header, FI and Engine API ownership

Set extraData[0]=100; all basefee and tips are credited to the EL beneficiary immediately. The proposer chooses beneficiary from local configuration. Validators do not require a registry-bound reward address. Keep EIP-4396 and other EL-derived fields aligned with the pinned node. Remove Etna fee-vault claiming commands, reward receipts, registration recipients and their generated fixtures rather than keep an unused second fee path.

Every Etna FCUv3 build, including singleton skip checks and cold replay, sends maxBlockBytes=124000. Use only generic `txList` / pool modes; no forcedTransaction field. Driver-owned FI composition may take pool candidates and submit `[FI, ordinary...]`; candidate preselection is an estimate. Match FI inclusion only at transaction 0. An eligible due omission requires a completed singleton `[FI]` on the committed parent and identical attributes with full EVM/zk budgets. A failed or partial build and omission from a longer list never prove a skip.

Implement the current canonical FI eligibility predicate and protocol vectors, including field-width, chain-id, low-s, exact re-encoding and authorization-tuple boundaries. Remove the old unconditional 1-gwei fee-cap skip: a fee below the current basefee is decided by the EL singleton build. Keep preimage-hash checks before all acceptance branches. Normal EVM revert/OOG still counts as included; zk overflow rollback may yield an empty singleton.

Classify node -38100 as definitive and stop for operator repair; transient failures keep waiting/retrying in ProcessProposal/FinalizeBlock. Validate raw executionBlock length <=124000 in PrepareProposal, ProcessProposal and FinalizeBlock, in addition to the generic EL builder cap. Do not use compressed landing capacity or only a proposer guard as the consensus check.

Decode L1 headers from original canonical RLP, retaining original bytes/hash and depending only on specified fields 0/3/8/11 within the 4096-byte bound. Preserve required future-tail compatibility and the spec's liveness/safety distinction.

### Public DA, grid landing and durable submission

Publish only execution blocks as `0x06 || zlib(rlp([executionBlock,...]))` with the spec's exact canonical RLP, single-stream framing, decompression limits and Unzen blob encoding. Comet headers, envelopes, witnesses, signatures and FI skip preimages stay private host inputs. Align existing decode/reconstruction paths with this projection; no additional Comet-bootstrap product is introduced.

Use K=6 grid endpoints and the eight-field LandInput, 21-word/672-byte TAIKO_ETNA_LAND_V1 statement, four-word cutLeaf and V1 cutHash. A job covers (p,h]; current settlement frontier c may advance within it. Retain the complete original blobs, leaves, proof bytes, nonce and signed transaction across retries while p<=c<h; c>=h completes it. Preserve reference-expiry and version/generation invalidation without rewriting signed work. Persist the active committee's authenticated snapshot, not a pending committee or latest anchor snapshot.

Remove landing remuneration and reward-claim accounting. FI fees belong to the protocol treasury; proposer fees are already paid on L2. Keep the existing explicit dummy-proof mode for this devnet and check the pinned MockProofVerifier accepts its encoding. No production proof acceptance is claimed.

Regenerate ABI copies, bytecode, deploy/runtime fixtures and shared vectors from protocol `23963b6` using the existing generation workflow. Bind Rust dependencies and all integration-test EL images/source to `b046734`. Do not hand-edit generated bindings.

## K8s/bootstrap behavior

Keep changes inside internal-devnet's Etna paths and their shared conditional helpers. The non-Etna render and other environments must remain unchanged. Retain four validators, existing networking/service organization and appropriately separated RPC/Engine endpoints. Archive state is needed for historical singleton checks; do not enable permanent unwind flags. Readiness must reflect ABCI checkpoint trust and catch-up readiness, not only a successful Comet /status HTTP response.

Bootstrap order follows the new DeployEtnaDevnet script: create bootstrap Inbox proxy → registry fixed to that proxy → register fresh secp256k1eth keys with EIP-712 owner PoP → wait activation/finality and choose genesisCutoff → derive committee/config → build alloc-only EL genesis with EIP-4788/EIP-2935 and obtain its exact hash/stateRoot → initialize Inbox/SignalService → wait finality → generate authenticated Comet genesis and publish artifacts. Eliminate predicted-Inbox nonce coupling, fee-vault export/verification, reward-address registration and heartbeat transactions.

Registered consensus keys and authoritative HRS state stay outside Comet home/mount. The bootstrap creates the initial FilePV key/state exactly once for each fresh domain and persists the initial state into dedicated signer storage before runtime starts. Runtime loads that state and refuses a missing state instead of recreating height zero. Provision signer state PVCs for bootstrap and runtime explicitly; replacing a lost runtime PVC must fail closed and require restoring its authoritative state. Bootstrap guards must reject rerunning against existing artifacts/state. Keep transport node keys separately in Comet home. The guarded signer runs from the client image, uses the app's private readiness channel, and cannot fall back to local FilePV.

Codex's proposed devnet values follow the spec's reference settings where practical: K=6, U=3600, L=900, timeout_commit=4s; preserve four equally staked validators, existing FI delay/maxAnchorAge when valid, positive activation/exit/withdraw delays, and a nonzero protocol treasury. Use grid-aligned lander batching (initial proposal: min 60, max 120 blocks, six blobs, 300s maximum batch wait, contract maxBatchBlocks>=120). These are devnet operational defaults, not measured production-capacity claims. Values and CLI/config names must match authenticated contract initialization and client opening exactly.

Use immutable contract source, client and EL image pins. Build/publish the required devnet images through the existing trusted image workflow or equivalent repository tooling and verify image manifests match the tested revisions before presenting #1663 as ready for deployment. If EL b046734 lacks an image because its feature-branch trigger was removed, resolve image production without adding FI logic or changing EL behavior; record the exact image digest/provenance. No guessed or nonexistent tags.

The default operator runbook can preserve the existing compatible L1 while deploying fresh Etna contracts and a fresh L2 genesis/keys. Describe a full L1 reset separately if desired; execute neither. Provide exact manual cleanup boundaries for old L2/bootstrap/explorer artifacts and preserve retired signing-state archives. Update bootstrap guards, manifests, image pins, parameters and troubleshooting in #1663's description/runbook. Existing Kubernetes credentials and real private keys are never copied into source or tool output.

## Verification and delivery

1. Cross-language vectors: every domain/key/PoP/config/committee/statement/storage encoding and rejection of old forms. Include leading-zero ckX and Ethereum-address derivation; no SHA256/Ed25519 consensus fallback.
2. Client tests: FI eligibility/fee boundaries and singleton behavior, 124000/124001 byte boundaries in all proposal/finalize paths, -38100 versus transient errors, H+2 transitions, full proposer fee credit, startup/restart/trust refusal and new-genesis-only enforcement.
3. Lander tests: execution-only public payloads, K-grid batching, p=c and p<c<h with unchanged signed submissions, c>=h, corrupt leaves, cursor/snapshot, reference expiry, restart and immutable nonce handling.
4. Run package-mandated formatting/lints, signer race/process tests, artifact reproduction and complete Docker verification. At least one local integration scenario runs the current protocol contracts + b046734 EL + four stock Comet validators with guarded secp256k1eth signing, ordinary/FI inclusion, an epoch transition, advancing dummy-proof checkpoints, and restart/catch-up. Do not substitute mocks for that integration scenario.
5. K8s: helm lint, Etna render/schema checks, shell syntax/lint and behavior tests of changed bootstrap/signing guards. Render the actual scripts/config into the local integration setup or exercise them with controlled local endpoints. Verify non-Etna render stability. Do not run Make deploy targets or kubectl apply/delete against the user's cluster.
6. Complete independent review, fix concrete important findings, normal fast-forward push to #22280 and #1663, update both descriptions around the final behavior and exact validation, and verify image/remote revisions. Stop before deployment. Surface any remaining deployment prerequisite explicitly; do not call the devnet ready while required images or generated artifacts are missing.

## Decisions delegated to the builder

Internal module boundaries and names, exact journal schema number, local fee-recipient defaults, test fixture organization, CLI implementation details for bootstrap key/PoP generation, and equivalent trusted image-build mechanics may be settled without another product decision, provided the observable contracts above hold. Keep the implementation focused on one supported devnet format and avoid compatibility branches for discarded drafts.
