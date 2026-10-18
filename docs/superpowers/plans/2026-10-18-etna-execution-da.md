# Implementation plan

1. Protocol: V10 statement domain, payload v6/private-witness specification, recovery assumptions, independent vectors and protocol verification.
2. Client red tests: projection-only payload, original-envelope authentication, witness-free decoding/recovery, DA capacity and private-retention bounds.
3. Client implementation: canonical execution-block encoding, v6 projection codec, private envelope/data_hash checks, Prepare/Process DA accounting, prefix private budgets and journal schema 12.
4. Compatibility: V10 assertions/vectors, protocol revision pin and generated ABI/bytecode; old signed jobs remain fail-closed.
5. Focused regressions, full formatting/Clippy/unit/artifact/Docker gates, mutation checks and compression comparison; review invariant preservation.
6. Commit/push protocol then client to existing PR branches. Update final PR descriptions and assumptions. Minimally edit Notion and GitHub review item 9 and read edits back.
