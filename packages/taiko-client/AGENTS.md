# Repository Guidelines

## Project Structure & Module Organization
- `cmd/main.go` builds `taiko-client`; `driver/`, `proposer/`, and `prover/` host the runtime subcommands that align with Taiko roles.
- Shared logic belongs in `pkg/` and `internal/` (metrics, testutils, version). Keep command directories thin wrappers over these packages.
- `bindings/` stores generated contract bindings, `docs/` and `scripts/` supply reference material, and Docker-backed scenarios live in `integration_test/`.
- Build outputs land in `bin/`; clean stale binaries with `make clean` before debugging linker oddities.

## Build, Test, and Development Commands
- `pnpm install` (from the monorepo root) bootstraps shared toolchains; run it before Foundry or Go targets.
- `make build` compiles `bin/taiko-client` with embedded Git metadata; configure linker flags through env vars if needed.
- `make lint` executes `goimports -local github.com/taikoxyz/taiko-mono/packages/taiko-client` followed by `golangci-lint run --timeout 5m`.
- `make test` runs `integration_test/entrypoint.sh` (requires Docker, `pnpm install` in `packages/protocol`, and `PACAYA_FORK_TAIKO_MONO=<value>`). `make hive_tests` and `make dev_net` cover Hive and devnet workflows.

## Coding Style & Naming Conventions
- Follow idiomatic Go: tabs, short lowercase package names, grouped imports (stdlib → external → Taiko), and doc comments on anything exported.
- Keep cross-cutting helpers inside `pkg/` or `internal/*`; contract updates must regenerate bindings via `make gen_bindings` to keep Go wrappers synced with ABIs.

## Testing Guidelines
- Write unit tests alongside code (`*_test.go`) and reuse fixtures from `internal/testutils`. Test names should describe behavior (`TestDriverHandlesReorg`).
- Integration runs depend on Docker and L2 node config; respect the `L2_NODE` env (defaults to `l2_geth`) and document any overrides in PRs.
- CI targets >95% coverage, so add coverage for new branches and update `coverage.out` only after verifying deltas locally.

## Commit & Pull Request Guidelines
- Use Conventional Commits seen in history (`feat(taiko-client): …`, `fix(driver): …`) and keep messages imperative and scoped.
- Before pushing, run `make lint` and the relevant `make test` variant; summarize results plus manual checks in the PR body.
- Reference issues, list any new env vars or scripts, and include CLI output or screenshots whenever behavior changes.

## Security & Configuration Tips
- Never commit secrets or peer data (`opnode_p2p_priv.txt`, discovery DBs); store them outside the repo.
- Call out required env vars such as `PACAYA_FORK_TAIKO_MONO`, `COMPILE_PROTOCOL`, or `TAIKO_GETH_DIR` whenever your code depends on them.
- Keep Docker, pnpm, and Go versions aligned with CI images to avoid flakiness.
