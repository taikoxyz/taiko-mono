// Command fixturegen writes Go-encoded golden fixtures consumed by the Rust
// taiko-client-rs test suite. Regenerate with `just gen-fixtures` from
// packages/taiko-client-rs. Output must be deterministic: fixed keys, fixed
// field values, no clocks or randomness.
package main

import (
	"compress/zlib"
	"encoding/json"
	"flag"
	"fmt"
	"math/big"
	"os"
	"path/filepath"

	"github.com/ethereum-optimism/optimism/op-node/p2p"
	"github.com/ethereum-optimism/optimism/op-node/rollup"
	"github.com/ethereum-optimism/optimism/op-service/eth"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/common/hexutil"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/crypto"
	"github.com/golang/snappy"
	"github.com/holiman/uint256"
	pubsub_pb "github.com/libp2p/go-libp2p-pubsub/pb"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/utils"
)

const chainID = int64(167000)

// fixedKey is anvil's well-known account #3 key; never used on a real network.
const fixedKey = "7c852118294e51e653712a81e05800f419141751be58f605c371e15141b007a6"

func main() {
	out := flag.String("out", "", "taiko-client-rs package root to write fixtures under")
	flag.Parse()
	if *out == "" {
		fmt.Fprintln(os.Stderr, "usage: fixturegen -out <path-to-packages/taiko-client-rs>")
		os.Exit(1)
	}
	protocolDir := filepath.Join(*out, "crates", "protocol", "fixtures", "go")
	whitelistDir := filepath.Join(*out, "crates", "whitelist-preconfirmation-driver", "fixtures", "go")

	txs := buildTxs()
	writeTxListFixtures(filepath.Join(protocolDir, "txlist"), txs)
	writeBlobFixtures(filepath.Join(protocolDir, "blob"))
	writeEnvelopeFixtures(filepath.Join(whitelistDir, "envelope"), txs)
	writeMsgIDFixture(filepath.Join(whitelistDir, "msgid.json"))
	writeSigningHashFixture(filepath.Join(whitelistDir, "signing_hash.json"))
	fmt.Println("fixtures written under", *out)
}

// buildTxs returns one signed tx per transaction type, deterministic.
func buildTxs() map[string]*types.Transaction {
	key, err := crypto.HexToECDSA(fixedKey)
	must(err)
	signer := types.LatestSignerForChainID(big.NewInt(chainID))
	to := common.HexToAddress("0x000000000000000000000000000000000000dEaD")
	sign := func(tx types.TxData) *types.Transaction {
		return types.MustSignNewTx(key, signer, tx)
	}
	out := map[string]*types.Transaction{
		"legacy": sign(&types.LegacyTx{
			Nonce: 0, GasPrice: big.NewInt(1_000_000_000), Gas: 21_000,
			To: &to, Value: big.NewInt(1),
		}),
		"eip2930": sign(&types.AccessListTx{
			ChainID: big.NewInt(chainID), Nonce: 1, GasPrice: big.NewInt(1_000_000_000),
			Gas: 21_000, To: &to, Value: big.NewInt(2), AccessList: types.AccessList{},
		}),
		"eip1559": sign(&types.DynamicFeeTx{
			ChainID: big.NewInt(chainID), Nonce: 2, GasTipCap: big.NewInt(1_000_000_000),
			GasFeeCap: big.NewInt(2_000_000_000), Gas: 21_000, To: &to, Value: big.NewInt(3),
		}),
		"eip4844": sign(&types.BlobTx{
			ChainID: uint256.NewInt(uint64(chainID)), Nonce: 3,
			GasTipCap: uint256.NewInt(1_000_000_000), GasFeeCap: uint256.NewInt(2_000_000_000),
			Gas: 21_000, To: to, Value: uint256.NewInt(4),
			BlobFeeCap: uint256.NewInt(1_000_000_000),
			BlobHashes: []common.Hash{{0x01}},
		}),
	}
	// EIP-7702 (type-4): the pinned geth fork ships types.SetCodeTx.
	out["eip7702"] = sign(&types.SetCodeTx{
		ChainID: uint256.NewInt(uint64(chainID)), Nonce: 4,
		GasTipCap: uint256.NewInt(1_000_000_000), GasFeeCap: uint256.NewInt(2_000_000_000),
		Gas: 60_000, To: to, Value: uint256.NewInt(5),
		AuthList: []types.SetCodeAuthorization{},
	})
	return out
}

// writeTxListFixtures writes <name>.bin (zlib(rlp list)) + <name>.json (canonical tx hex).
func writeTxListFixtures(dir string, txs map[string]*types.Transaction) {
	must(os.MkdirAll(dir, 0o755))
	cases := map[string]types.Transactions{
		"empty":         {},
		"single_legacy": {txs["legacy"]},
		"single_1559":   {txs["eip1559"]},
		"single_2930":   {txs["eip2930"]},
		"single_4844":   {txs["eip4844"]},
		"mixed_all":     {txs["legacy"], txs["eip2930"], txs["eip1559"], txs["eip4844"]},
	}
	cases["single_7702"] = types.Transactions{txs["eip7702"]}
	cases["mixed_all"] = append(cases["mixed_all"], txs["eip7702"])
	// 100-tx bulk case: repeat legacy/1559 alternating (re-signing with bumped nonces).
	key, err := crypto.HexToECDSA(fixedKey)
	must(err)
	signer := types.LatestSignerForChainID(big.NewInt(chainID))
	to := common.HexToAddress("0x000000000000000000000000000000000000dEaD")
	bulk := types.Transactions{}
	for i := uint64(0); i < 100; i++ {
		if i%2 == 0 {
			bulk = append(bulk, types.MustSignNewTx(key, signer, &types.LegacyTx{
				Nonce: 100 + i, GasPrice: big.NewInt(1_000_000_000), Gas: 21_000, To: &to, Value: big.NewInt(int64(i)),
			}))
		} else {
			bulk = append(bulk, types.MustSignNewTx(key, signer, &types.DynamicFeeTx{
				ChainID: big.NewInt(chainID), Nonce: 100 + i, GasTipCap: big.NewInt(1_000_000_000),
				GasFeeCap: big.NewInt(2_000_000_000), Gas: 21_000, To: &to, Value: big.NewInt(int64(i)),
			}))
		}
	}
	cases["bulk_100"] = bulk

	for name, list := range cases {
		compressed, err := utils.EncodeAndCompressTxList(list)
		must(err)
		must(os.WriteFile(filepath.Join(dir, name+".bin"), compressed, 0o644))
		// Level-independence probe: the Rust DECODER must accept any zlib
		// level a Go peer might emit, not just the default level.
		if name == "mixed_all" {
			raw, err := utils.Decompress(compressed)
			must(err)
			var best []byte
			bw := &sliceWriter{buf: &best}
			zw, err := zlib.NewWriterLevel(bw, zlib.BestCompression)
			must(err)
			_, err = zw.Write(raw)
			must(err)
			must(zw.Close())
			must(os.WriteFile(filepath.Join(dir, "mixed_all_best_compression.bin"), best, 0o644))
		}
		hexes := make([]string, len(list))
		for i, tx := range list {
			raw, err := tx.MarshalBinary() // canonical: legacy = RLP list, typed = type||payload
			must(err)
			hexes[i] = hexutil.Encode(raw)
		}
		writeJSON(filepath.Join(dir, name+".json"), map[string]any{"txs": hexes})
	}
}

// writeBlobFixtures writes payload.bin + blob.bin pairs through the Go blob coder.
func writeBlobFixtures(dir string) {
	must(os.MkdirAll(dir, 0o755))
	// Deterministic pseudo-payloads: repeating byte patterns, NOT random.
	pattern := func(n int) []byte {
		b := make([]byte, n)
		for i := range b {
			b[i] = byte(i % 251)
		}
		return b
	}
	// 130044 = (4*31+3)*1024 - 4 = BLOB_MAX_DATA_SIZE on the Rust side.
	cases := map[string][]byte{
		"empty":    {},
		"one_byte": {0x42},
		"len_27":   pattern(27),
		"len_28":   pattern(28),
		"max":      pattern(130044),
	}
	for name, payload := range cases {
		var blob eth.Blob
		must(blob.FromData(payload))
		must(os.WriteFile(filepath.Join(dir, name+".payload.bin"), payload, 0o644))
		must(os.WriteFile(filepath.Join(dir, name+".blob.bin"), blob[:], 0o644))
	}
}

// writeEnvelopeFixtures writes SSZ + snappy-framed gossip envelopes.
func writeEnvelopeFixtures(dir string, txs map[string]*types.Transaction) {
	must(os.MkdirAll(dir, 0o755))
	compressed, err := utils.EncodeAndCompressTxList(types.Transactions{txs["legacy"], txs["eip1559"]})
	must(err)

	basePayload := func() *eth.ExecutionPayload {
		return &eth.ExecutionPayload{
			ParentHash:    common.HexToHash("0x1111111111111111111111111111111111111111111111111111111111111111"),
			FeeRecipient:  common.HexToAddress("0x2222222222222222222222222222222222222222"),
			StateRoot:     eth.Bytes32(common.HexToHash("0x33")),
			ReceiptsRoot:  eth.Bytes32(common.HexToHash("0x44")),
			PrevRandao:    eth.Bytes32{},
			BlockNumber:   eth.Uint64Quantity(7),
			GasLimit:      eth.Uint64Quantity(30_000_000),
			GasUsed:       eth.Uint64Quantity(21_000),
			Timestamp:     eth.Uint64Quantity(1_700_000_000),
			ExtraData:     eth.BytesMax32{0x01},
			BaseFeePerGas: eth.Uint256Quantity(*uint256.NewInt(1_000_000_000)),
			BlockHash:     common.HexToHash("0x5555555555555555555555555555555555555555555555555555555555555555"),
			Transactions:  []eth.Data{eth.Data(compressed)},
		}
	}
	root := common.HexToHash("0x6666666666666666666666666666666666666666666666666666666666666666")
	sig := [65]byte{}
	for i := range sig {
		sig[i] = 0x11
	}
	tru := true
	diff := big.NewInt(123456)

	cases := map[string]*eth.ExecutionPayloadEnvelope{
		// Baseline: signature present, no flags, legacy tx inside the txlist —
		// the exact PR #21906 escape shape through the full decode chain.
		"legacy_tx_signed": {
			ParentBeaconBlockRoot: &root,
			ExecutionPayload:      basePayload(),
			Signature:             &sig,
		},
		// All flag bits set: EOS + forced-inclusion + signature + non-zero
		// Uzen HeaderDifficulty (flags[0]&0x02 path).
		"all_flags_difficulty": {
			EndOfSequencing:       &tru,
			IsForcedInclusion:     &tru,
			ParentBeaconBlockRoot: &root,
			ExecutionPayload:      basePayload(),
			Signature:             &sig,
			HeaderDifficulty:      diff,
		},
		// No signature (subscriber-side shape before re-signing).
		"unsigned": {
			ParentBeaconBlockRoot: &root,
			ExecutionPayload:      basePayload(),
		},
	}
	for name, env := range cases {
		var buf []byte
		w := &sliceWriter{buf: &buf}
		_, err := env.MarshalSSZ(w)
		must(err)
		must(os.WriteFile(filepath.Join(dir, name+".ssz.bin"), buf, 0o644))
		must(os.WriteFile(filepath.Join(dir, name+".snappy.bin"), snappy.Encode(nil, buf), 0o644))
		// tx_count is the number of payload.transactions entries (each a compressed
		// txlist blob), not the count of txs inside the txlist.
		meta := map[string]any{
			"block_number":        uint64(env.ExecutionPayload.BlockNumber),
			"block_hash":          env.ExecutionPayload.BlockHash.Hex(),
			"tx_count":            len(env.ExecutionPayload.Transactions),
			"end_of_sequencing":   env.EndOfSequencing != nil && *env.EndOfSequencing,
			"is_forced_inclusion": env.IsForcedInclusion != nil && *env.IsForcedInclusion,
			"has_signature":       env.Signature != nil,
			"header_difficulty":   "0x0",
			"parent_beacon_root":  root.Hex(),
		}
		if env.HeaderDifficulty != nil {
			meta["header_difficulty"] = hexutil.EncodeBig(env.HeaderDifficulty)
		}
		writeJSON(filepath.Join(dir, name+".json"), meta)
	}
}

// writeMsgIDFixture captures BuildMsgIdFn output for valid and invalid snappy data.
func writeMsgIDFixture(path string) {
	cfg := &rollup.Config{L2ChainID: big.NewInt(chainID)}
	idFn := p2p.BuildMsgIdFn(cfg)
	topic := fmt.Sprintf("/taiko/%d/0/preconfBlocks", chainID)
	valid := snappy.Encode(nil, []byte("golden fixture payload"))
	invalid := []byte{0xff, 0x00, 0xde, 0xad, 0xbe, 0xef} // not valid snappy

	entry := func(data []byte) map[string]string {
		id := idFn(&pubsub_pb.Message{Data: data, Topic: &topic})
		return map[string]string{
			"topic":       topic,
			"data":        hexutil.Encode(data),
			"expected_id": hexutil.Encode([]byte(id)),
		}
	}
	writeJSON(path, map[string]any{
		"valid_snappy":   entry(valid),
		"invalid_snappy": entry(invalid),
	})
}

// writeSigningHashFixture captures BlockSigningHash for a fixed payload.
func writeSigningHashFixture(path string) {
	cfg := &rollup.Config{L2ChainID: big.NewInt(chainID)}
	payload := []byte("taiko preconfirmation signing-hash golden payload")
	h, err := p2p.BlockSigningHash(cfg, payload)
	must(err)
	writeJSON(path, map[string]string{
		"chain_id":      fmt.Sprintf("%d", chainID),
		"payload":       hexutil.Encode(payload),
		"expected_hash": h.Hex(),
	})
}

// sliceWriter adapts MarshalSSZ's io.Writer to an in-memory buffer.
type sliceWriter struct{ buf *[]byte }

func (w *sliceWriter) Write(p []byte) (int, error) {
	*w.buf = append(*w.buf, p...)
	return len(p), nil
}

func writeJSON(path string, v any) {
	b, err := json.MarshalIndent(v, "", "  ")
	must(err)
	must(os.WriteFile(path, append(b, '\n'), 0o644))
}

func must(err error) {
	if err != nil {
		panic(err)
	}
}
