package rpc

import (
	"encoding/json"
	"math"
	"math/big"
	"testing"

	"github.com/ethereum/go-ethereum/beacon/engine"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/common/hexutil"
	consensus "github.com/ethereum/go-ethereum/consensus/taiko"
	gethcore "github.com/ethereum/go-ethereum/core"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/miner"
	"github.com/ethereum/go-ethereum/params"
	"github.com/stretchr/testify/require"
)

// pinDevnetForkTimes overrides the devnet Unzen and Etna activation times for one test.
func pinDevnetForkTimes(t *testing.T, unzen, etna uint64) {
	t.Helper()
	originalUnzen, originalEtna := gethcore.DevnetUnzenTime, gethcore.DevnetEtnaTime
	t.Cleanup(func() { gethcore.DevnetUnzenTime, gethcore.DevnetEtnaTime = originalUnzen, originalEtna })
	gethcore.DevnetUnzenTime, gethcore.DevnetEtnaTime = unzen, etna
}

func TestIsEtna_DevnetHonorsDevnetEtnaTimeOverride(t *testing.T) {
	pinDevnetForkTimes(t, 0, 100)

	devnetID := params.TaikoInternalNetworkID
	require.False(t, IsEtna(devnetID, 99), "before override timestamp")
	require.True(t, IsEtna(devnetID, 100), "at override timestamp")
	require.True(t, IsEtna(devnetID, 101), "after override timestamp")
}

func TestIsEtna_PublicNetworksUnscheduled(t *testing.T) {
	pinDevnetForkTimes(t, 0, 0)

	for _, chainID := range []*big.Int{params.TaikoMainnetNetworkID, params.TaikoHoodiNetworkID} {
		require.False(t, IsEtna(chainID, 0))
		require.False(t, IsEtna(chainID, math.MaxUint64-1))
	}
}

func TestIsEtna_NilAndUnknownChainID(t *testing.T) {
	pinDevnetForkTimes(t, 0, 0)

	require.False(t, IsEtna(nil, 0))
	require.False(t, IsEtna(big.NewInt(123456789), 0))
}

func TestForkLabel_OrdersEtnaUnzenShasta(t *testing.T) {
	pinDevnetForkTimes(t, 100, 200)

	devnetID := params.TaikoInternalNetworkID
	require.Equal(t, "Shasta", ForkLabel(devnetID, 99))
	require.Equal(t, "Unzen", ForkLabel(devnetID, 100))
	require.Equal(t, "Unzen", ForkLabel(devnetID, 199))
	require.Equal(t, "Etna", ForkLabel(devnetID, 200))
}

// etnaPayloadKeys are the only properties alethia-reth accepts in an engine_newPayloadV4 payload.
var etnaPayloadKeys = []string{
	"parentHash", "feeRecipient", "stateRoot", "receiptsRoot", "logsBloom", "prevRandao",
	"blockNumber", "gasLimit", "gasUsed", "timestamp", "extraData", "baseFeePerGas",
	"blockHash", "transactions", "withdrawals", "blobGasUsed", "excessBlobGas",
	"headerDifficulty",
}

// requireJSONKeys asserts that raw is a JSON object with exactly the given keys and returns its fields.
func requireJSONKeys(t *testing.T, raw []byte, keys ...string) map[string]json.RawMessage {
	t.Helper()
	var fields map[string]json.RawMessage
	require.NoError(t, json.Unmarshal(raw, &fields))
	got := make([]string, 0, len(fields))
	for key := range fields {
		got = append(got, key)
	}
	require.ElementsMatch(t, keys, got)
	return fields
}

func sampleExecutableData() *engine.ExecutableData {
	slot := uint64(9)
	return &engine.ExecutableData{
		ParentHash:       common.HexToHash("0x01"),
		FeeRecipient:     common.HexToAddress("0x02"),
		StateRoot:        common.HexToHash("0x03"),
		ReceiptsRoot:     common.HexToHash("0x04"),
		LogsBloom:        make([]byte, 256),
		Random:           common.HexToHash("0x05"),
		Number:           10,
		GasLimit:         30_000_000,
		GasUsed:          0,
		Timestamp:        1_000,
		ExtraData:        []byte{0, 0, 0, 0, 0, 0, 7},
		BaseFeePerGas:    big.NewInt(1_000_000),
		BlockHash:        common.HexToHash("0x06"),
		TxHash:           common.HexToHash("0x07"),
		WithdrawalsHash:  common.HexToHash("0x08"),
		SlotNumber:       &slot,
		TaikoBlock:       true,
		HeaderDifficulty: big.NewInt(0),
	}
}

func TestAnchorGasReserve(t *testing.T) {
	pinDevnetForkTimes(t, 0, 100)

	devnetID := params.TaikoInternalNetworkID
	require.Equal(t, consensus.AnchorV3V4GasLimit, AnchorGasReserve(devnetID, 99))
	require.Zero(t, AnchorGasReserve(devnetID, 100))
	require.Equal(t, consensus.AnchorV3V4GasLimit, AnchorGasReserve(params.TaikoMainnetNetworkID, 100))
}

func TestManifestGasLimit(t *testing.T) {
	pinDevnetForkTimes(t, 0, 100)

	devnetID := params.TaikoInternalNetworkID
	genesis := &types.Header{Number: big.NewInt(0), GasLimit: 30_000_000, Time: 0}
	preEtna := &types.Header{Number: big.NewInt(5), GasLimit: 31_000_000, Time: 99}
	etna := &types.Header{Number: big.NewInt(6), GasLimit: 30_000_000, Time: 100}

	require.Equal(t, uint64(30_000_000), ManifestGasLimit(devnetID, genesis))
	require.Equal(t, uint64(30_000_000), ManifestGasLimit(devnetID, preEtna))
	require.Equal(t, uint64(30_000_000), ManifestGasLimit(devnetID, etna))
}

// sampleBuildPayloadArgsID fingerprints a fixed sample block with the given parentBeaconBlockRoot.
func sampleBuildPayloadArgsID(parentBeaconBlockRoot *common.Hash) engine.PayloadID {
	return BuildPayloadArgsID(
		common.HexToHash("0x01"),
		100,
		common.HexToAddress("0x02"),
		common.HexToHash("0x03"),
		[]byte{0, 0, 0, 0, 0, 0, 7},
		common.HexToHash("0x04"),
		parentBeaconBlockRoot,
	)
}

func TestBuildPayloadArgsIDKeepsPreEtnaFingerprint(t *testing.T) {
	txListHash := common.HexToHash("0x04")
	expected := (&miner.BuildPayloadArgs{
		Parent:       common.HexToHash("0x01"),
		Timestamp:    100,
		FeeRecipient: common.HexToAddress("0x02"),
		Random:       common.HexToHash("0x03"),
		Withdrawals:  make([]*types.Withdrawal, 0),
		Version:      engine.PayloadV2,
		TxListHash:   &txListHash,
		Extra:        []byte{0, 0, 0, 0, 0, 0, 7},
	}).Id()

	require.Equal(t, expected, sampleBuildPayloadArgsID(nil))
	// Pinned, so a taiko-geth bump that changes BuildPayloadArgs.Id() fails here.
	require.Equal(t, engine.PayloadID{0x02, 0x4a, 0xd6, 0x36, 0x22, 0x68, 0x15, 0x1d}, sampleBuildPayloadArgsID(nil))
}

func TestBuildPayloadArgsIDBindsEtnaRoot(t *testing.T) {
	preEtna := sampleBuildPayloadArgsID(nil)

	root := common.HexToHash("0xaa")
	etna := sampleBuildPayloadArgsID(&root)
	require.Equal(t, byte(engine.PayloadV3), etna[0])
	require.NotEqual(t, preEtna, etna)
	// Pinned, so a taiko-geth bump that changes BuildPayloadArgs.Id() fails here.
	require.Equal(t, engine.PayloadID{0x03, 0xba, 0x33, 0xdc, 0xa7, 0xbf, 0xd2, 0x51}, etna)

	otherRoot := common.HexToHash("0xbb")
	require.NotEqual(t, etna, sampleBuildPayloadArgsID(&otherRoot))
}

func TestNewTaikoExecutionPayloadV3_JSONShape(t *testing.T) {
	payload, err := NewTaikoExecutionPayloadV3(sampleExecutableData())
	require.NoError(t, err)

	raw, err := json.Marshal(payload)
	require.NoError(t, err)
	fields := requireJSONKeys(t, raw, etnaPayloadKeys...)

	require.JSONEq(t, `0`, string(fields["headerDifficulty"]))
	require.JSONEq(t, `[]`, string(fields["transactions"]))
	require.JSONEq(t, `[]`, string(fields["withdrawals"]))
	require.JSONEq(t, `"0x0"`, string(fields["blobGasUsed"]))
	require.JSONEq(t, `"0x0"`, string(fields["excessBlobGas"]))
	require.JSONEq(t, `"0x3e8"`, string(fields["timestamp"]))
	require.JSONEq(t, `"0x00000000000007"`, string(fields["extraData"]))
}

func TestNewTaikoExecutionPayloadV3_DecimalDifficulty(t *testing.T) {
	data := sampleExecutableData()
	data.HeaderDifficulty = big.NewInt(1234)
	data.Transactions = [][]byte{{0x01, 0x02}}

	payload, err := NewTaikoExecutionPayloadV3(data)
	require.NoError(t, err)

	raw, err := json.Marshal(payload)
	require.NoError(t, err)
	fields := requireJSONKeys(t, raw, etnaPayloadKeys...)
	require.JSONEq(t, `1234`, string(fields["headerDifficulty"]))
	require.JSONEq(t, `["0x0102"]`, string(fields["transactions"]))
}

func TestNewTaikoExecutionPayloadV3_RejectsInvalidInput(t *testing.T) {
	_, err := NewTaikoExecutionPayloadV3(nil)
	require.Error(t, err)

	missingDifficulty := sampleExecutableData()
	missingDifficulty.HeaderDifficulty = nil
	_, err = NewTaikoExecutionPayloadV3(missingDifficulty)
	require.ErrorContains(t, err, "header difficulty")

	overflowingDifficulty := sampleExecutableData()
	overflowingDifficulty.HeaderDifficulty = new(big.Int).Lsh(common.Big1, 64)
	_, err = NewTaikoExecutionPayloadV3(overflowingDifficulty)
	require.ErrorContains(t, err, "header difficulty")

	missingBaseFee := sampleExecutableData()
	missingBaseFee.BaseFeePerGas = nil
	_, err = NewTaikoExecutionPayloadV3(missingBaseFee)
	require.ErrorContains(t, err, "base fee")
}

func TestTxPoolBlockContext_JSON(t *testing.T) {
	raw, err := json.Marshal(&TxPoolBlockContext{
		Timestamp:             hexutil.Uint64(100),
		ParentBeaconBlockRoot: common.HexToHash("0x01"),
		ExtraData:             []byte{0, 0, 0, 0, 0, 0, 0},
	})
	require.NoError(t, err)
	require.JSONEq(
		t,
		`{"timestamp":"0x64",`+
			`"parentBeaconBlockRoot":"0x0000000000000000000000000000000000000000000000000000000000000001",`+
			`"extraData":"0x00000000000000"}`,
		string(raw),
	)
}
