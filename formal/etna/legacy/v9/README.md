# Historical V9 evidence

The previous package, including the 272 V9 theorem contracts, 21 exact Rust
refinements and old captured conformance evidence, is retained in Git at
[3988cfa1929795d1ba818e4cf0ff2f065a979e05](https://github.com/taikoxyz/taiko-mono/tree/3988cfa1929795d1ba818e4cf0ff2f065a979e05/formal/etna).
Use an isolated checkout of that revision to reproduce historical results.

The active `Etna.Design` model verifies the latest design independently of obsolete
implementation PRs.
It neither imports those models nor carries their source-extraction runtime
overlay, test harnesses, CI or reports as current verification evidence.
