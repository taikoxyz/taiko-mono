# Vendored event-scanner 1.1.2

Source: the exact crates.io 1.1.2 package, copied from the Cargo registry cache.
Repository: https://github.com/OpenZeppelin/Event-Scanner
Upstream commit: `0ca2ebfcf80a1d64be3a48276ae6cc1430eb1273` (also retained in `.cargo_vcs_info.json`).
Published `.crate` SHA-256: `4bb5af0a9a373eab3dbd26e447d43fdef58c23161a77423d49eb810e4e6688fd`.
License: MIT; the upstream `LICENSE` is retained unchanged.

Both upstream main manifests were checked on 2026-11-17 and still require Alloy 1.1.2.
This local production-only copy adapts the dependency to Alloy 2.4.2 so it shares
provider, network, RPC, and log types with the restored driver and execution client.

Local packaging changes:

- Normalize trailing whitespace and redundant final blank lines where present.

- Set the production Alloy dependency to 2.4.2.
- Keep production Rust source and the upstream README, license, original manifest,
  and VCS metadata. Omit examples, test modules, benchmarks, development dependencies,
  release profiles, toolchain files, lockfiles, and build/cache artifacts.
- Omit the optional test helper module and test/example/benchmark-only features and dependencies.

Scanner, retry, failover, timeout, reconnection, and reorg behavior is preserved.
