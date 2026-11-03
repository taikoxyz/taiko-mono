# Historical V9 evidence

The previous package, including the 272 V9 theorem contracts, 21 exact Rust
refinements and old captured conformance evidence, is retained in Git at
[3988cfa1929795d1ba818e4cf0ff2f065a979e05](https://github.com/taikoxyz/taiko-mono/tree/3988cfa1929795d1ba818e4cf0ff2f065a979e05/formal/etna).
Use an isolated checkout of that revision to reproduce historical results.

The `Etna.Design` model outside `Current` is itself the separately pinned
2026-10-30 historical design. Current conditional decoded claims live in
`Etna.Design.Current`; see the package README for their exact authority and scope.
It neither imports those models nor carries their source-extraction runtime
overlay, test harnesses, CI or reports as current verification evidence.
