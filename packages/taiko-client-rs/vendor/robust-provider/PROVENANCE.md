# Vendored robust-provider 1.0.2

Source: the exact crates.io 1.0.2 package, copied from the Cargo registry cache.
Repository: https://github.com/OpenZeppelin/Robust-Provider
Upstream commit: `acb2c7387336b52afcf0fdd39be9067a5596bace` (also retained in `.cargo_vcs_info.json`).
Published `.crate` SHA-256: `c2537c0c6f84b1f2f9f3fb51cf88b79edebe2673c2795859e1d53030240339f1`.
License: MIT; the upstream `LICENSE` is retained unchanged.

Both upstream main manifests were checked on 2026-11-17 and still require Alloy 1.1.2.
This local production-only copy adapts the dependency to Alloy 2.4.2 so it shares
provider, network, RPC, and log types with the restored driver and execution client.

Local packaging changes:

- Normalize trailing whitespace and redundant final blank lines where present.

- Set the production Alloy dependency to 2.4.2.
- Remove the unused `block_not_found_doc` import; the existing macro-use scope still resolves the documentation macro.
- Keep production Rust source and the upstream README, license, original manifest,
  and VCS metadata. Omit examples, test modules, benchmarks, development dependencies,
  release profiles, toolchain files, lockfiles, and build/cache artifacts.

Scanner, retry, failover, timeout, reconnection, and reorg behavior is preserved.
