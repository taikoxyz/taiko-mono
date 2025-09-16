# Repository Guidelines

## Project Structure & Module Organization

Core Solidity sources sit in `contracts/{layer1,layer2,shared}`, mirroring deployment targets. Execution scripts and proposal tooling live in `script/`, while on-chain addresses and artifacts live in `deployments/` and `layout/`. Forge outputs land in `out/` and `cache/`; avoid committing them. Tests follow the same layer split under `test/`, with `genesis/` generating chain configs and `mocks/` providing fixtures. Reference docs and metrics reside in `docs/`, `gas-reports/`, and `snapshots/`.

Shasta contracts live in `contracts/layer1/shasta/impl` with interfaces in `contracts/layer1/shasta/iface`, plus the L2 anchor in `contracts/layer2/based/ShastaAnchor.sol`. Their main regression suite is `test/layer1/shasta/inbox/suite2/`; run `forge test --match-path "test/layer1/shasta/inbox/suite2/*"` during iterations before expanding to wider coverage.

## Build, Test, and Development Commands

- `pnpm compile` runs every Foundry profile (`shared`, `layer1`, `layer2`).
- `pnpm test:l1`, `pnpm test:l2`, `pnpm test:shared`, or aggregate `pnpm test` execute Forge suites with the right `FOUNDRY_PROFILE`.
- `pnpm layout` regenerates storage layouts; use `layout:<tier>` for targeted updates.
- `pnpm fmt:sol` applies `forge fmt` and `solhint`; `pnpm eslint` maintains TypeScript utilities.
- `pnpm clean` clears caches before large rebases or compiler upgrades.

## Coding Style & Naming Conventions

Adopt Forge defaults: 4-space indentation, explicit visibility, `CamelCase` contracts, and `camelCase` functions. Declare custom errors and events near the top, and favor `immutable` or `constant` modifiers for configuration. TypeScript helpers use ECMAScript modules, 2-space indentation, and camelCase exports. Run `pnpm fmt:sol` and `pnpm eslint` prior to PRs to keep diffs minimal.

## Testing Guidelines

Place new specs under the closest layer directory using `<Module>.t.sol`; shared utilities end with `.utils.sol`. Lean on Foundry cheatcodes for determinism and add regression cases for gas-sensitive logic. Use `FOUNDRY_PROFILE` to mirror chain-specific behavior locally. For coverage snapshots, run `pnpm test:coverage` and review `coverage/index.html` before merging substantive protocol changes.

## Commit & Pull Request Guidelines

Commits follow Conventional syntax (`feat(protocol): …`) paired with concise subjects. Rebase on `main`, include the protocol impact, simulations or dry-run outputs, and the exact test commands executed. Link issues or core-tracking tickets and tag reviewers early to unblock audits or deployments.

## Security & Configuration Tips

Keep secrets out of the repo; `.env` files and keys belong in the shared secrets manager. When altering deployment or proposal scripts, update `deployments/` metadata and capture a `pnpm proposal:dryrun:l1` or `:l2` log in the PR description. Document parameter or circuit changes in `docs/` so downstream networks stay synchronized.
