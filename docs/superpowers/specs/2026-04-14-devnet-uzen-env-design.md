# Devnet Uzen Override Input Design

## Goal

Reduce the public surface area of the devnet Uzen timestamp override while keeping the runtime
behavior explicit and localized to the driver codepaths that submit or normalize Uzen payloads.

The setting is intended for internal deployment only. It should not appear as a public operator
flag in either client.

## Problem

The current branch introduces explicit driver flags for the override:

- Go: `--devnetUzenTime`
- Rust: `--driver.devnetUzenTime`

That works functionally, but it exposes an internal deployment knob in CLI help and creates extra
user-facing configuration surface that is not meant to be documented or supported broadly.

At the same time, moving the setting to an environment variable does not eliminate the real runtime
work. The driver, beacon sync, and execution payload submission paths still need one consistent
value at runtime.

## Approaches Considered

### 1. Env-only at the driver config boundary

Read a private environment variable once in the driver startup/config path, then store the parsed
value on driver-local runtime config and pass it through the existing driver-local execution
payload logic.

Pros:

- Removes public CLI surface
- Keeps env parsing in one place
- Preserves explicit data flow at runtime
- Minimizes cross-cutting changes

Cons:

- Still requires driver-local config plumbing

### 2. Env reads inside payload submission code

Read the environment variable ad hoc inside engine submission helpers and beacon sync code.

Pros:

- Slightly less upfront config plumbing

Cons:

- Hidden behavior
- Repeated env parsing
- Harder to test and reason about
- Easy for paths to diverge

### 3. Keep public flags

Keep the current public driver flags and accept the larger visible CLI surface.

Pros:

- Straightforward for operators

Cons:

- Not aligned with the internal-only requirement
- Unnecessary public surface

## Recommendation

Use approach 1.

Read the override from an internal environment variable once in the driver config boundary for each
client, then keep the value on driver-local config only.

This is the smallest clean design because it removes the flag surface without pushing hidden env
reads deeper into engine logic.

## Proposed Behavior

### Go client

- Remove the public driver flag definition for the override.
- Read `DEVNET_UZEN_TIME` during driver config construction.
- Parse it once into `rpc.ClientConfig.DevnetUzenTime`.
- Keep the existing runtime behavior in `rpc.IsUzen`, `rpc.ForkLabel`, and
  `rpc.NormalizeExecutableData`.

This keeps the current Go runtime design intact and changes only the input source.

### Rust client

- Remove `--driver.devnetUzenTime` from the driver CLI args.
- Read `DRIVER_DEVNET_UZEN_TIME` in the driver command builders.
- Store the parsed value on `driver::DriverConfig`.
- Keep the driver-local payload applier and beacon sync runtime logic that already uses
  `DriverConfig.devnet_uzen_time`.
- Keep `rpc::auth::engine_new_payload_v2` accepting an optional `headerDifficulty`, since that is
  the correct engine API boundary for the Uzen payload difference.

This keeps the override local to the driver runtime and avoids reintroducing shared RPC config
churn.

## Data Flow

### Go

`env -> driver/config.go -> rpc.ClientConfig.DevnetUzenTime -> driver/runtime payload paths`

### Rust

`env -> bin/client command builder -> driver::DriverConfig.devnet_uzen_time -> driver payload applier / beacon sync -> engine_new_payload_v2(headerDifficulty)`

## Error Handling

- Missing env var means the override defaults to `0`.
- Invalid env var values should fail fast during driver startup with a clear parse error.
- No payload path should perform its own env parsing.

## Verification

- Go: `make lint`
- Rust: `just fmt && just clippy`

No new tests are required for this branch.

## Scope

In scope:

- Replace public flag input with internal environment-variable input
- Preserve existing runtime override behavior
- Keep Rust override driver-local

Out of scope:

- Dynamic node-side discovery of the Uzen timestamp
- Generalizing this override beyond driver-related paths
- Adding new tests in this branch
