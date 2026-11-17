# Preparing an Unzen to Etna switch

`DeployEtnaSwitch.s.sol` prepares a switch from an existing Unzen chain. It retains the existing
L1 SignalService proxy and checkpoints. Unlike `DeployEtnaDevnet`, **it never upgrades a proxy**:
its entry points deploy a bootstrap proxy, a registry or replacement implementations. No
deployment or upgrade is performed merely by compiling these scripts.

This implements the contract preparation in [SWITCH.md](../../../docs/etna/SWITCH.md). DAO batch
construction, start correction upgrades, real guests/provers and switch rehearsal are separate work.
The existing L2 implementation deployment is
[`DeployShastaL2Contracts`](../../layer2/DeployShastaL2Contracts.s.sol), including its chain-specific
mainnet/Hoodi entry points. EIP-2935 and EIP-4788 must already be installed on L2.

## Inputs and deployment order

Use the same L1 RPC and `L1_CHAIN_ID` for every step. `PRIVATE_KEY` selects the deployer;
`CONTRACT_OWNER` selects the owner of new proxies (defaults to the deployer). Use the existing
Unzen proxy as `UNZEN_INBOX` and its existing L1 SignalService proxy as `SIGNAL_SERVICE`.
The scripts reject implementation addresses in place of these proxies and require VERSION=1.
They read the live Unzen `getConfig()` and six-word `getCoreState()` ABI.

1. Deploy the bootstrap with `DeployEtnaSwitch.deployInboxProxy()`, then export `INBOX_PROXY`.
   It creates no replacement SignalService or checkpoint store.
2. Use the inherited `deployRegistry()` with the same registry variables as
   [the new-network deployment](../../../contracts/layer1/etna/README.md#deployment).
   Export `STAKING_REGISTRY`, register validators, and select a finalized committee-0 cutoff.
3. Deploy dedicated Etna verifier instances with `DeployEtnaVerifiers.run()`, then export
   `ETNA_PROOF_VERIFIER`. The new SGX, RISC0 and SP1 instances are separate from Unzen's image-trusting
   instances. Configure the new instances and image/program trust separately before using them.
4. Set `ETNA_FORK_TIME`, `PROPOSE_MARGIN`, `FI_MARGIN`, `ORIGIN_WRITER` and `L2_CHAIN_ID` consistently
   with the planned L2 Anchor upgrade. Call `deployUnzenInboxImplementation()` and export the
   returned address as `UNZEN_INBOX_IMPLEMENTATION`.
5. Set `REMOTE_SIGNAL_SERVICE` to the existing L2 SignalService proxy; its address must match the
   chain's canonical predeploy. Call `deploySignalServiceImplementation()`. Its immutable pauser
   is read from the existing proxy, including zero for a pre-pauser implementation.
6. Set the remaining Inbox/committee/FI parameters documented for `DeployEtnaDevnet` and call
   `deployInbox()`. The prepared cutoff implementation must have the same configuration as the
   live Unzen Inbox and the same fork time as Etna. The registry must name this Etna proxy and L2
   chain. The Etna composite and every enabled image-trusting sub-verifier must be separate from
   Unzen's, with the same L2 chain id; Unzen must expose the existing ComposeVerifier getters.
   Before broadcasting, the script also compares the Etna verifier's runtime bytecode against
   this build's ZkRequiredVerifier with those exact immutable addresses. A same-shaped AnyVerifier
   or a differently built policy is refused. The comparison instance exists only in the script's
   local EVM outside startBroadcast and is never broadcast.

The `DeployEtnaSwitch` initialization data uses zero genesis hash and state root without reading
`GENESIS_BLOCK_HASH` or `GENESIS_STATE_ROOT`. The inherited `ownerInitCall(implementation)` returns
the owner installation/initialization calldata for review; no switch entry point sends it. The
actual DAO batch, including time/implementation guards and L1/L2 fork-time cross-checks, remains
outside this preparation. Install and initialize the Etna implementation atomically. Until that
point the bootstrap's `etnaStart()` reports an unwritten start, so Unzen proofs can continue.

Use Foundry's normal script simulation/review and broadcast process for each preparation entry
point. This task did not execute these scripts or broadcast transactions.

## Cutoffs and retained state

`InboxWithEtnaCutoffs` keeps Unzen's complete existing configuration and storage. It rejects
proposals at or after `ETNA_FORK_TIME - PROPOSE_MARGIN` and forced submissions at or after
`ETNA_FORK_TIME - FI_MARGIN`. Proving and bond operations remain available. Its constructor requires
`PROPOSE_MARGIN >= 12`, `FI_MARGIN > PROPOSE_MARGIN + forcedInclusionDelay`, and
`FI_MARGIN < ETNA_FORK_TIME`. All values are seconds. The strict inequality supplies a nonzero
buffer; operators must choose a buffer at least the longest expected proposal gap and satisfy
the full timestamp-lead bound for short L1 slots described in SWITCH.md.

The shared `SignalService` adds no storage and keeps VERSION=1. The switch implementation uses
`stateRootProvider = address(0)`, the Etna Inbox proxy as its primary syncer and the live Unzen
Inbox proxy as `unzenInbox`. Both Inbox proxies can save checkpoints; once a nonzero Etna start
hash is written, Unzen cannot save above S. Only the Unzen checkpoint path reads the current start
and fails closed if that read fails. It preserves existing checkpoints and proof/cache behavior
and never initializes or replaces the existing L1 proxy's storage.

The scripts do not call `setOrigin`. The originWriter must wait for the post-fork finalized L1
observation, derive the complete last Unzen proposal, verify S's hash/state root, pre-fork
timestamp and Anchor implementation, and wait for the start write to finalize before node startup.
Etna can start before the last Unzen proof; its first landing still waits for that proof and
Unzen's matching SignalService checkpoint at S. Those EtnaInbox guards already use the live Unzen ABI.

## Dedicated verifier inputs

`DeployEtnaVerifiers.run()` reads `PRIVATE_KEY`, optional `CONTRACT_OWNER`, `L1_CHAIN_ID`,
`L2_CHAIN_ID`, `DCAP_ATTESTATION`, `SGX_REGISTRAR`, `SGX_INSTANCE_VALIDITY_DELAY`,
`R0_GROTH16_VERIFIER` and `SP1_PLONK_VERIFIER`. It checks dependency code and chain identities.
An unset/empty owner defaults to the deployer; an explicit zero owner is refused. Registrar zero
allows permissionless SGX registration. The SGX validity delay is positive and at most its
90-day instance lifetime. Allow enough lead for attestation, registration and that delay.

The script creates a SecureSgxVerifier in SGX_RETH, RISC0 and SP1 instances, and a ZkRequiredVerifier
with SGX_GETH disabled. It leaves image/program trust, enclave policies and SGX instances empty.
The shared remote ZK proof systems and DCAP infrastructure can remain common; the instances
that hold guest/image/instance trust are new. This prepares contracts, not a real proving backend.
