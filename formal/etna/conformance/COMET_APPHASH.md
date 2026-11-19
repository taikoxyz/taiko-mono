# Public stock validator-state and AppHash component

This separately pinned W04 profile observes stock CometBFT v0.40.0 at
`0880b4d378f347ab16e54ec677ff50d803f37d62`. It preserves the older handover
profile, its source pins and public corpus. The three reviewed current documents
are selected independently from the executed implementation; selection alone is
not a conformance result.

The late-rescale program starts with powers A=1, B=36, H=156, replaces them at
height 1 with A=80, B=19, C=1, and runs through height 8. Its actual continuously
incremented height-5 set and a reopened sparse `LoadValidators(5)` have the same
ordered membership, powers, proposer and Merkle hash, but different priorities.
The recovery-shaped program starts at height 21, inserts H then removes B. This
is a synthetic generation constructor, not an observed governance recovery.

`run_comet_apphash.py` independently derives integer elections, stored proposer
indexes, ordered sets, complete validator/AppHash ABI, stock state and header
protobufs, raw full/sparse store rows and bootstrap continuation. The six-word
validator-state ABI commits both ordered arrays, signed int64 priorities and
stored proposers. Its three-word application ABI is separate from settlement's
four-word cut. Header at s commits post-(s-1); the post-s state commits s.

The Go profile uses only the unchanged public secp256k1eth points already in
`comet_signed/public-votes.json`. The stock update bridge forwards validation,
PB2TM conversion and `updateState`. That transition returns nil AppHash; this
reference harness assigns the newly computed application commitment. It is not
an Etna ABCI application implementation. Genesis uses stock default parameters
except the public key type and AppVersion=1; the local state version assignment
models Info without executing a handshake. The genesis results hash remains nil.
These are selected component fixtures, not the complete Etna genesis generator.

Every initial block is built by stock `MakeBlock` and tested by the public
`State.ValidateBlock` with a genuine empty commit. Seven cases per program cover
matching, current/next priority, current/next proposer, height/EL-path, and EL-only
changes. Only AppHash differs in each fresh header; exact guard diagnostics and
complete block bytes are retained. The height case changes the fixture-derived
EL hash together with the committed height. Later headers/part IDs are explicitly
synthetic inputs to the stock state transition, not authenticated blocks.

After real Save/close/reopen, full persistent State bytes and raw ValidatorsInfo
rows are compared. At s=6, a detached pre-s validator-state preimage is bound to
the frozen synthetic header and advanced once. A real fresh `Store.Bootstrap`
sets the two stock storage markers to s+2 and s+1, closes/reopens and continues
using the same full frozen header/BlockID. All other State bytes must match the
uninterrupted run. This tests local arithmetic and store semantics. It does not
authenticate a checkpoint or implement DATA-5.4 import/evidence/EL storage.

The native driver requires prepared source, SDK, module cache, an existing shared
physical build cache and lock, and a fresh output directory. All paths are CLI
arguments. Supply the independently inspected `device:inode` identities for both
the cache and lock; the driver opens the existing lock without following symlinks,
checks the open descriptor and both paths, then acquires it. The mount namespace
has no network/Git/home, readonly original source modes and inputs, a disposable
work directory and the one serialized cache. Go uses count=1, parallel=1, p=2,
mod=readonly, 90s; isolation and supervision use 100s and 110s.

Run `run_comet_apphash_native.py --help` for required arguments. First execute
`--smoke-only`, then the full original/priority-two/restored campaign. The sole
source variation changes the actual `updateState` priority increment from one
to two, without touching validation or authentication. Native generation still
must pass; the independent consumer must reject the changed observed priority
at its exact field. The same private copy is restored including modes, and all
four original/restored receipt byte streams must agree. Every source path, mode,
input hash, generated modfile, tool, command, return code and output hash is
retained. Receipts are local execution evidence, not signed attestations.

Independent verification uses a different arithmetic/Keccak/protobuf oracle and
an actual reopened sparse lookup substituted into the candidate commitment. A
wrong-source publication comparison must reject it while canonical input,
membership, powers, order, Merkle root and proposer remain unchanged. Real Etna
app/import/EL execution, noninitial signed admission, proof generation, consensus
network progress and live deployment remain WAITING.
