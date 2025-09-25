# agents.md — Root (Monorepo Guide for Coding Agents)

> **Canonical brief for this repository.** Agents should also read `/packages/protocol/agents.md` when editing smart contracts. Keep responses terse, deterministic, and actionable. Always include exact file paths and runnable commands.

## Project Snapshot

- **Domain**: Based rollup on Ethereum (Type‑1 ZK‑EVM)
- **Key traits**: L1‑sequenced; SGX + ZK multi‑proofs; contestable validity proofs with bonding; Ethereum‑equivalent semantics
- **Workspace**: `pnpm` monorepo

```
packages/
├─ protocol/          # Solidity + Foundry (core contracts)
├─ taiko-client/      # Go (driver, proposer, prover)
├─ bridge-ui/         # TS/SvelteKit
├─ relayer/           # Go bridge relayer
├─ eventindexer/      # Go indexer
└─ ...
```

## Top‑Level Commands (run at repo root)

```bash
pnpm install                     # install all deps
pnpm build                       # build all packages
pnpm --filter @taiko/protocol test
pnpm --filter @taiko/bridge-ui dev
pnpm --filter @taiko/taiko-client build
pnpm clean && pnpm install       # fix dependency state
```

## Global Policies

- Use **GitHub CLI `gh`** for PR management and checks.
- Prefer package‑scoped commands for single‑package work; use root for cross‑package.
- Use real debuggers (Foundry `-vvvv`, Go `dlv`, browser DevTools) rather than print‑only debugging.
- Never commit secrets. Validate inputs and add DoS/rate‑limit guards for services.

## Agent Decision Flow (Root)

1. **Identify scope**: {protocol | taiko-client | relayer | eventindexer | bridge-ui}.
2. **Route**: if scope is **protocol**, switch to `/packages/protocol/agents.md` rules and runbooks.
3. **Plan a minimal diff**: smallest change that solves the problem; respect package conventions.
4. **Prepare validation**: include exact commands to compile/test/verify for the affected packages.
5. **For multi‑package edits**: run `pnpm build` and targeted `--filter` tests for each impacted package.

## CI/Test Expectations

- All tests must pass; maintain high coverage (target >95% where measured).
- Code review focuses on: security, error handling, L1 gas (when applicable), style consistency, concurrency risks (Go/TS), and test quality.
- Keep READMEs and CHANGELOGs current when adding significant features.

## PR Checklist (Root)

- Clear title + concise summary of intent.
- Exact commands to reproduce build/test/validation.
- If smart contracts are touched: link to evidence of **storage layout** checks and **gas snapshots** (see nested file).
- Security considerations (auth, invariants, failure modes).
