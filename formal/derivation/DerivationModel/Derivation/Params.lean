/-!
# Protocol constants and per-chain parameters

Values match `packages/protocol/docs/Derivation.md`, the Go driver
(`bindings/manifest/manifest.go`) and the Rust `protocol` crate (`shasta/constants.rs`). Fork
times match taiko-geth (`core/taiko_genesis.go`) and alethia-reth (`chainspec/src/hardfork.rs`).

This package models Unzen only: proposals that land at or after `UNZEN_FORK_TIME` on top of an
Unzen parent. The clients' Shasta-era branches (the 192-block source limit and headers without
Cancun fields) and Etna are outside the model.
-/

namespace TaikoSpec.Derivation

/-- Bytes in one EIP-4844 blob. -/
def BLOB_BYTES : Nat := 131072

/-- The only accepted manifest payload version. -/
def SHASTA_PAYLOAD_VERSION : Nat := 1

/-- Per-source block limit for proposals landed at or after Unzen. -/
def UNZEN_DERIVATION_SOURCE_MAX_BLOCKS : Nat := 768

/-- Gas reserved in non-genesis block headers for the anchor transaction. -/
def ANCHOR_GAS_LIMIT : Nat := 1_000_000

/-- Lowest allowed block gas limit. -/
def MIN_BLOCK_GAS_LIMIT : Nat := 10_000_000

/-- Highest allowed block gas limit. -/
def MAX_BLOCK_GAS_LIMIT : Nat := 45_000_000

/-- Largest per-block gas limit change, in millionths. -/
def BLOCK_GAS_LIMIT_MAX_CHANGE : Nat := 200

/-- Denominator for `BLOCK_GAS_LIMIT_MAX_CHANGE`. -/
def GAS_LIMIT_DENOMINATOR : Nat := 1_000_000

/-- Chain-specific derivation parameters. -/
structure ChainParams where
  /-- L2 chain ID. -/
  chainId : Nat
  /-- How far (in L1 blocks) an anchor may lag the proposal's origin block. -/
  maxAnchorOffset : Nat
  /-- How far (in seconds) a block timestamp may lag the proposal timestamp. -/
  timestampMaxOffset : Nat
  /-- Shasta activation timestamp. No derived block may be earlier. -/
  shastaForkTime : Nat
  /-- Unzen activation timestamp. It only delimits the modeled proposals. -/
  unzenForkTime : Nat

/-- Taiko mainnet. -/
def mainnet : ChainParams where
  chainId := 167000
  maxAnchorOffset := 512
  timestampMaxOffset := 6144
  shastaForkTime := 1_775_135_700
  unzenForkTime := 1_786_021_200

/-- Taiko Hoodi. -/
def hoodi : ChainParams where
  chainId := 167013
  maxAnchorOffset := 128
  timestampMaxOffset := 1536
  shastaForkTime := 1_770_296_400
  unzenForkTime := 1_781_787_600

/-- The internal devnet: Shasta and Unzen active from genesis. -/
def devnet : ChainParams where
  chainId := 167001
  maxAnchorOffset := 128
  timestampMaxOffset := 1536
  shastaForkTime := 0
  unzenForkTime := 0

end TaikoSpec.Derivation
