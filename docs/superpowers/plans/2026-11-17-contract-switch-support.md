# Contract-side Unzen to Etna switch support

Base: PR22286, ca54352f600dd57b6e81fb0da1848214fedbdede.

The user authorized implementing the remaining contract-side switch support after publishing
the nonzero-S lander. DAO proposal/recovery tooling, tests and real proving backends are excluded.
No deployment, proxy upgrade or governance transaction will be executed by this work.

## Scope

- Upgrade-compatible Unzen Inbox implementation with immutable proposal/FI cutoffs, preserving
  the current configuration, storage, proof and bond behavior.
- Storage-free L1 SignalService implementation accepting both Inboxes, preserving VERSION=1
  and rejecting Unzen checkpoints above the written Etna start S.
- Switching deployment preparation: bootstrap proxy and registry, implementations with live
  identity checks, and a dedicated Etna verifier configuration. Keep new-network deployment working.
- Documentation, production compilation, formatting, storage-layout checks and independent review.

## Decisions

- Existing EtnaInbox first-landing checks already use the real six-word Unzen CoreState ABI;
  no adapter or statement ABI change is required.
- setOrigin already provides one-time initialization and observable fork-time guards. Finality,
  S timestamp and Anchor implementation verification remain the originWriter/client duties.
- Existing Anchor and SignalServiceL2 deployment already support future fork activation.
- EIP-2935/4788 deployment is an operational prerequisite; no new custom system contract is added.
- Start corrections/rewrite upgrades and atomic governance batch construction remain excluded DAO work.

## Progress

- Lander commit 0262c503bbf9f75388d9f653f081278eac1615dc pushed and PR22280 head verified.
- Reused the managed worktree on codex/etna-contract-switch; client commits remain on their branch.
- Independent non-DAO inventory completed. Cutoff and SignalService implementations delegated on disjoint files.
- Current pnpm rejects unchanged legacy lock aliases. Installing with cached pnpm 9, without changing the lockfile.
- pnpm 9.15.9 installed the locked protocol dependencies offline; pnpm-lock.yaml is unchanged.
- Cutoff and SignalService implementations integrated, with their generated layout documentation.
- DeployEtnaSwitch reuses new-network configuration helpers but only deploys; live Unzen config,
  SignalService VERSION, candidate cutoff fork/config, registry bindings and verifier chains are checked.
- DeployEtnaVerifiers creates separate SGX/RISC0/SP1 instances and ZkRequiredVerifier, retaining empty trust.
- Optional review finding addressed: a same-topology AnyVerifier could pass identity checks, so the
  script authenticates the exact ZkRequiredVerifier runtime using identical constructor arguments
  in the local script EVM before broadcasting. Focused re-review found no defect.

## Verification and current status

- FOUNDRY_PROFILE=layer1 forge build --skip test: passed, including deployment scripts.
- FOUNDRY_PROFILE=layer2 forge build --skip test --skip script: passed.
- Changed Solidity forge fmt --check and Solhint --disc: passed.
- Etna rule/link checker: all checks passed. New runbook local links resolve.
- gen-layouts.sh layer1/shared: passed; existing layout files remain byte-identical. New layout
  files retain the generator's exact padding, as the protocol CI requires.
- Actual forge-inspect layouts compare identical slots, offsets and recursive storage types:
  Inbox/cutoffs 17 fields, SignalService/dual-syncer 15 fields.
- New runtime/initcode sizes satisfy EIP-170/EIP-3860: cutoffs 23,528/25,847 bytes;
  SignalServiceL1 14,227/15,082 bytes. A broad forge --sizes check returns nonzero because existing
  cached test handlers exceed EIP-170; ordinary production builds and targeted size checks pass.
- Independent full review and focused policy re-review found no remaining actionable bug.
- Final remote audit found PR22286 advanced from 1ef5aa82c to ca54352f6 during implementation
  (terminology/NatSpec alignment). The exact local patch was stashed, the branch fast-forwarded,
  and the patch restored without conflict; remote tests/gas updates remain untouched.
- Production L1/L2 builds, Solhint, formatting and rule checks passed again on ca54352f6.
  Focused upstream-compatibility review confirmed the renamed GenesisRecord fields do not affect
  the patch and the registry preparation override preserves the existing parameter flow.
- Existing Foundry formatter-config, unrelated NatSpec/mutability/timestamp warnings remain.
- No tests authored/run, no scripts executed, and no deployment, upgrade or governance broadcast.

PR22280 lander is published at 0262c503b, and its description now reflects switching support.
The PR22286 contract patch remains uncommitted locally on codex/etna-contract-switch for review.

The subsequent user request authorizes publishing this patch to PR22286, then updating the client
protocol artifacts/ABI/pin. Fresh production builds, formatting and Solhint passed before publication.
The protocol_sol hook refers to a nonexistent lint:sol script; its equivalent checks ran directly.
The repo formatter hook also fails on unchanged legacy lock aliases with the current pnpm wrapper;
the same Prettier version formats staged Markdown directly, and only these two wrappers are excluded.
