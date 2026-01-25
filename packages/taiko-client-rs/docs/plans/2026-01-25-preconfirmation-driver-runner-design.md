# Preconfirmation Driver Runner Refactor Design (2026-01-25)

## Goals

- Move preconfirmation driver orchestration out of `bin/client` into `crates/preconfirmation-driver`.
- Flip dependency direction: `preconfirmation-driver` depends on `driver`; `driver` has no dependency on `preconfirmation-driver` (including dev-deps).
- Treat missing L2 latest head as a hard error (fail fast) instead of a soft warning.

## Constraints

- Preserve current runtime behavior and logging where possible.
- Keep CLI thin: parse flags, build configs, delegate to runner.
- Avoid dependency cycles across crates.

## Proposed Architecture

Introduce a new `runner` module in `crates/preconfirmation-driver` that encapsulates the orchestration currently in `PreconfirmationDriverSubCommand`:

- `PreconfirmationDriverRunner` (struct): owns the `DriverConfig`, `P2pConfig`, and optional RPC config.
- `RunnerConfig` (struct): input bundle for runner construction; contains `DriverConfig`, `P2pConfig`, optional `PreconfRpcServerConfig`, and any runtime options.
- `RunnerError` (enum): runner-specific errors (event syncer exit, L2 latest head failure, driver/sync errors).

The CLI (`bin/client`) will only:

- Parse flags and build `DriverConfig` + `P2pConfig`.
- Construct `RunnerConfig` and call `PreconfirmationDriverRunner::run().await`.
- Map `RunnerError` into `CliError`.

## Data Flow (Runner)

1. Create `rpc::client::Client` from `DriverConfig`.
2. Build `driver::sync::event::EventSyncer` and spawn its run loop.
3. Await `wait_preconf_ingress_ready`; if the syncer exits first, return a runner error.
4. Build `PreconfirmationClientConfig` using the inbox address from `DriverConfig` and the L1 provider.
5. Construct `PreconfirmationDriverNode` + driver channels and spawn the state/input forwarder.
6. Run the P2P node loop; on exit, abort forwarder and syncer tasks.

## Error Handling

- `resolve_preconf_tip_from_l2` returns `Result<U256, RunnerError>`.
  - If `get_block_by_number(Latest)` returns `None` or RPC error, return a hard error.
  - `publish_proposal_state` propagates the error and stops the runner.
- Preserve existing early-exit errors: event syncer exited/failed before readiness.
- Wrap `driver`/`sync` errors via `From` in `RunnerError`.

## Testing Plan

- Move unit tests for `resolve_preconf_tip_from_l2` from CLI to `crates/preconfirmation-driver`.
- Move `crates/driver/tests/preconf_e2e.rs` and `crates/driver/tests/dual_driver_e2e.rs` into `crates/preconfirmation-driver/tests/`.
  - Update imports to use `driver` as a normal dependency of `preconfirmation-driver`.
  - Ensure tests still use `DriverConfig` and `EventSyncer` from `driver`.
- Remove `preconfirmation-driver` from `crates/driver/Cargo.toml` dev-dependencies.

## Open Questions

- Whether to expose a minimal public API (`runner::run(config)`) or a more test-friendly struct.
- Final error mapping strategy in CLI (direct mapping vs. string wrapping).
