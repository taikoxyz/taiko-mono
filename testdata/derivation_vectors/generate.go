//go:build ignore

// Regenerate with: GOTOOLCHAIN=go1.26.0 go run ./testdata/derivation_vectors/generate.go
package main

import (
	"bytes"
	"compress/zlib"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"math/big"
	"os"
	"path/filepath"
	"runtime"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/crypto"
	"github.com/ethereum/go-ethereum/rlp"
	"github.com/holiman/uint256"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/manifest"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/utils"
)

type vector struct {
	Name            string `json:"name"`
	Family          string `json:"family"`
	Payload         string `json:"payload_hex"`
	Offset          int    `json:"offset"`
	Default         bool   `json:"expect_default"`
	Expected        string `json:"expected_manifest_rlp_hex"`
	Engine          string `json:"engine_tx_list_hex,omitempty"`
	EngineDecodable *bool  `json:"engine_decodable,omitempty"`
}

func encode(v any) []byte {
	b, err := rlp.EncodeToBytes(v)
	if err != nil {
		panic(err)
	}
	return b
}
func frame(compressed []byte) []byte {
	b := make([]byte, 64)
	b[31] = 1
	new(big.Int).SetUint64(uint64(len(compressed))).FillBytes(b[32:64])
	return append(b, compressed...)
}
func compress(b []byte) []byte {
	z, err := utils.Compress(b)
	if err != nil {
		panic(err)
	}
	return z
}
func power(bits uint) *big.Int   { return new(big.Int).Lsh(big.NewInt(1), bits) }
func maximum(bits uint) *big.Int { return new(big.Int).Sub(power(bits), big.NewInt(1)) }
func u(n *big.Int) *uint256.Int  { return uint256.MustFromBig(n) }

// Each input sets one field; expected acceptance is an explicit test-case decision.
func tx(kind int, field string, n *big.Int) *types.Transaction {
	chain, fee, tip, value, v, r, s := big.NewInt(167001), big.NewInt(1), big.NewInt(1), big.NewInt(0), big.NewInt(1), big.NewInt(1), big.NewInt(1)
	if kind == 0 {
		v = big.NewInt(27)
	}
	switch field {
	case "chain":
		chain = n
	case "fee":
		fee = n
	case "tip":
		tip = n
	case "value":
		value = n
	case "v":
		v = n
	case "r":
		r = n
	case "s":
		s = n
	}
	blobFee := big.NewInt(1)
	if field == "blob_fee" {
		blobFee = n
	}
	to := common.HexToAddress("0x0000000000000000000000000000000000001234")
	switch kind {
	case 0:
		return types.NewTx(&types.LegacyTx{GasPrice: fee, Gas: 21000, To: &to, Value: value, V: v, R: r, S: s})
	case 1:
		return types.NewTx(&types.AccessListTx{ChainID: chain, GasPrice: fee, Gas: 21000, To: &to, Value: value, V: v, R: r, S: s})
	case 2:
		return types.NewTx(&types.DynamicFeeTx{ChainID: chain, GasFeeCap: fee, GasTipCap: tip, Gas: 21000, To: &to, Value: value, V: v, R: r, S: s})
	case 3:
		return types.NewTx(&types.BlobTx{ChainID: u(chain), GasFeeCap: u(fee), GasTipCap: u(tip), BlobFeeCap: u(blobFee), Gas: 21000, To: to, Value: u(value), V: u(v), R: u(r), S: u(s)})
	case 4:
		a := types.SetCodeAuthorization{ChainID: *u(maximum(256)), Address: to, V: 2, R: *u(big.NewInt(0)), S: *u(big.NewInt(0))}
		if field == "auth_v" {
			a.V = uint8(n.Uint64())
		}
		return types.NewTx(&types.SetCodeTx{ChainID: u(chain), GasFeeCap: u(fee), GasTipCap: u(tip), Gas: 21000, To: to, Value: u(value), V: u(v), R: u(r), S: u(s), AuthList: []types.SetCodeAuthorization{a}})
	default:
		panic(kind)
	}
}

func main() {
	if runtime.Version() != "go1.26.0" {
		panic("regenerate with GOTOOLCHAIN=go1.26.0 for reproducible zlib bytes")
	}
	cases := []vector{}
	defaultManifest := &manifest.DerivationSourceManifest{Blocks: []*manifest.BlockManifest{{}}}
	add := func(name string, txs types.Transactions, invalid bool, blocks int) {
		m := &manifest.DerivationSourceManifest{}
		for i := 0; i < blocks; i++ {
			m.Blocks = append(m.Blocks, &manifest.BlockManifest{Timestamp: 100 + uint64(i), Coinbase: common.HexToAddress("0x1234"), AnchorBlockNumber: 5, GasLimit: 10_000_000})
		}
		m.Blocks[blocks-1].Transactions = txs
		raw := encode(m)
		expected := raw
		if invalid {
			expected = encode(defaultManifest)
		}
		engineDecodable := !invalid
		cases = append(cases, vector{Name: name, Family: "f9", Payload: hex.EncodeToString(frame(compress(raw))), Default: invalid, Expected: hex.EncodeToString(expected), Engine: hex.EncodeToString(encode(txs)), EngineDecodable: &engineDecodable})
	}
	for kind := 0; kind <= 4; kind++ {
		name := fmt.Sprintf("type%d", kind)
		add(name+"_control", types.Transactions{tx(kind, "", nil)}, false, 1)
		fields := []struct {
			name string
			bits uint
		}{{"fee", 128}, {"value", 256}, {"r", 256}, {"s", 256}}
		if kind == 3 {
			fields = append(fields, struct {
				name string
				bits uint
			}{"blob_fee", 128})
		}
		if kind > 0 {
			fields = append(fields, struct {
				name string
				bits uint
			}{"chain", 64})
		}
		if kind >= 2 {
			fields = append(fields, struct {
				name string
				bits uint
			}{"tip", 128})
		}
		for _, f := range fields {
			add(name+"_"+f.name+"_max", types.Transactions{tx(kind, f.name, maximum(f.bits))}, false, 1)
			if kind <= 2 || f.bits < 256 {
				add(name+"_"+f.name+"_overflow", types.Transactions{tx(kind, f.name, power(f.bits))}, true, 1)
			}
		}
		if kind > 0 {
			for _, parity := range []int64{0, 1, 2} {
				add(fmt.Sprintf("%s_parity_%d", name, parity), types.Transactions{tx(kind, "v", big.NewInt(parity))}, parity > 1, 1)
			}
		}
		add(name+"_unrecoverable", types.Transactions{tx(kind, "r", big.NewInt(0))}, false, 1)
	}
	for _, v := range []int64{0, 1, 26, 27, 28, 29, 34, 35, 36} {
		add(fmt.Sprintf("legacy_v_%d", v), types.Transactions{tx(0, "v", big.NewInt(v))}, v != 27 && v != 28 && v < 35, 1)
	}
	for _, parity := range []int64{0, 1} {
		v := new(big.Int).Add(new(big.Int).Lsh(maximum(64), 1), big.NewInt(35+parity))
		add(fmt.Sprintf("legacy_chain_max_parity_%d", parity), types.Transactions{tx(0, "v", v)}, false, 1)
	}
	v := new(big.Int).Add(new(big.Int).Lsh(power(64), 1), big.NewInt(35))
	add("legacy_chain_overflow", types.Transactions{tx(0, "v", v)}, true, 1)
	for _, parity := range []int64{2, 255} {
		add(fmt.Sprintf("authorization_parity_%d", parity), types.Transactions{tx(4, "auth_v", big.NewInt(parity))}, false, 1)
	}
	add("wrong_chain_control", types.Transactions{tx(2, "chain", big.NewInt(999))}, false, 1)
	for _, version := range []byte{0, 1} {
		wrapped := tx(3, "", nil).WithBlobTxSidecar(&types.BlobTxSidecar{Version: version})
		add(fmt.Sprintf("blob_sidecar_v%d", version), types.Transactions{wrapped}, true, 1)
	}
	// Public Anvil account, funded in the disposable devnet genesis. This transaction
	// proves the E2E forced-source assertion distinguishes retention from fallback.
	key, err := crypto.HexToECDSA("ac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80")
	if err != nil {
		panic(err)
	}
	to := common.HexToAddress("0x1234")
	signed, err := types.SignTx(types.NewTx(&types.DynamicFeeTx{ChainID: big.NewInt(167001),
		Gas: 21000, GasFeeCap: big.NewInt(10_000_000_000), GasTipCap: big.NewInt(1_000_000_000),
		To: &to, Value: big.NewInt(1)}), types.LatestSignerForChainID(big.NewInt(167001)), key)
	if err != nil {
		panic(err)
	}
	add("signed_control", types.Transactions{signed}, false, 1)
	add("forced_bad_with_valid", types.Transactions{signed, tx(2, "v", big.NewInt(2))}, true, 1)
	add("late_blob_sidecar", types.Transactions{tx(2, "", nil), tx(3, "", nil).WithBlobTxSidecar(&types.BlobTxSidecar{})}, true, 2)
	add("late_bad_transaction", types.Transactions{tx(2, "", nil), tx(2, "v", big.NewInt(2))}, true, 2)
	add("two_valid_blocks", types.Transactions{tx(2, "", nil)}, false, 2)
	// Build malformed wire framing directly: typed constructors only emit canonical RLP.
	addFraming := func(name string, elements ...[]byte) {
		var txs []rlp.RawValue
		for _, element := range elements {
			txs = append(txs, element)
		}
		list := encode(txs)
		block := encode([]any{uint64(100), common.HexToAddress("0x1234"), uint64(5), uint64(10_000_000), rlp.RawValue(list)})
		raw := encode([]any{[]rlp.RawValue{block}})
		cases = append(cases, vector{Name: name, Family: "framing", Payload: hex.EncodeToString(frame(compress(raw))), Default: true,
			Expected: hex.EncodeToString(encode(defaultManifest)), Engine: hex.EncodeToString(list)})
	}
	for kind := 1; kind <= 4; kind++ {
		bare, err := tx(kind, "", nil).MarshalBinary()
		if err != nil {
			panic(err)
		}
		name := fmt.Sprintf("framing_type%d", kind)
		addFraming(name+"_bare", bare)
		addFraming(name+"_short", append(encode(bare[:len(bare)-1]), bare[len(bare)-1]))
		addFraming(name+"_long", encode(append(append([]byte(nil), bare...), encode(tx(0, "", nil))...)))
		// A list element is exclusively a legacy transaction, even if a generic
		// envelope decoder could discover a typed payload inside nested wrappers.
		addFraming(name+"_payload_list", bare[1:])
		nested := append([]byte(nil), bare[1:]...)
		for n := 1; n < kind; n++ {
			nested = encode(nested)
		}
		nested = encode([]rlp.RawValue{nested})
		addFraming(name+"_nested_wrappers", encode([]rlp.RawValue{nested}))
		if kind == 2 {
			addFraming("framing_empty_before_typed", []byte{0x80}, encode(bare))
			unsupported := append([]byte(nil), bare...)
			unsupported[0] = 5
			addFraming("framing_type5", encode(unsupported))
		}
	}
	legacy := encode(tx(0, "", nil))
	addFraming("framing_type0_string", encode(append([]byte{0}, legacy...)))
	addFraming("framing_type0_bare", append([]byte{0}, legacy...))
	blockWithExtraField := encode([]any{uint64(100), common.HexToAddress("0x1234"), uint64(5), uint64(10_000_000), []rlp.RawValue{}, uint64(1)})
	cases = append(cases, vector{Name: "framing_block_extra_field", Family: "framing",
		Payload: hex.EncodeToString(frame(compress(encode([]any{[]rlp.RawValue{blockWithExtraField}})))),
		Default: true, Expected: hex.EncodeToString(encode(defaultManifest))})
	baseManifest := &manifest.DerivationSourceManifest{Blocks: []*manifest.BlockManifest{{
		Timestamp: 100, Coinbase: common.HexToAddress("0x1234"), AnchorBlockNumber: 5, GasLimit: 10_000_000,
	}}}
	baseRaw := encode(baseManifest)
	z := compress(baseRaw)
	addZlib := func(name string, compressed, expected []byte, offset int, invalid bool) {
		if invalid {
			expected = encode(defaultManifest)
		}
		payload := append(make([]byte, offset), frame(compressed)...)
		cases = append(cases, vector{Name: name, Family: "f8", Payload: hex.EncodeToString(payload),
			Offset: offset, Default: invalid, Expected: hex.EncodeToString(expected)})
	}
	addZlib("complete", z, baseRaw, 0, false)
	// FDICT with the Adler-32 of an empty dictionary is accepted by Go's NewReader.
	for _, dictionaryID := range []byte{0, 1, 2} {
		withDictionary := append([]byte{0x78, 0x20, 0, 0, 0, dictionaryID}, z[2:]...)
		addZlib(fmt.Sprintf("dictionary_id_%d", dictionaryID), withDictionary, baseRaw, 0, dictionaryID != 1)
	}
	for cut := 1; cut <= 4; cut++ {
		addZlib(fmt.Sprintf("trailer_missing_%d", cut), z[:len(z)-cut], nil, 0, true)
	}
	corrupt := append([]byte(nil), z...)
	corrupt[len(corrupt)-1] ^= 0xff
	addZlib("bad_checksum", corrupt, nil, 0, true)
	addZlib("empty_input", nil, nil, 0, true)
	addZlib("header_only", z[:2], nil, 0, true)
	addZlib("body_truncated", z[:len(z)/2], nil, 0, true)
	var buf bytes.Buffer
	writer := zlib.NewWriter(&buf)
	if _, err := writer.Write(baseRaw); err != nil {
		panic(err)
	}
	if err := writer.Flush(); err != nil {
		panic(err)
	}
	addZlib("nonfinal_stream", append([]byte(nil), buf.Bytes()...), nil, 0, true)
	if err := writer.Close(); err != nil {
		panic(err)
	}
	addZlib("trailing_bytes", append(append([]byte(nil), z...), 0xde, 0xad), baseRaw, 0, false)
	addZlib("second_stream", append(append([]byte(nil), z...), compress(encode(defaultManifest))...), baseRaw, 0, false)
	addZlib("nonzero_offset", z, baseRaw, 7, false)
	bigTx := &types.DynamicFeeTx{ChainID: big.NewInt(167001), GasFeeCap: big.NewInt(1), GasTipCap: big.NewInt(1),
		Gas: 1_000_000, Value: big.NewInt(0), Data: bytes.Repeat([]byte{0x42}, 30_000), V: big.NewInt(0), R: big.NewInt(1), S: big.NewInt(1)}
	baseManifest.Blocks[0].Transactions = types.Transactions{types.NewTx(bigTx)}
	largeRaw := encode(baseManifest)
	addZlib("large_output", compress(largeRaw), largeRaw, 0, false)
	doc := struct {
		Version int      `json:"schema_version"`
		Cases   []vector `json:"cases"`
	}{1, cases}
	b, err := json.MarshalIndent(doc, "", "  ")
	if err != nil {
		panic(err)
	}
	_, file, _, _ := runtime.Caller(0)
	if err = os.WriteFile(filepath.Join(filepath.Dir(file), "manifest_cases.json"), append(b, '\n'), 0644); err != nil {
		panic(err)
	}
	fmt.Printf("wrote %d vectors\n", len(cases))
}
