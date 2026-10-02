package rpc

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"math/big"
	"net/http"
	"net/http/httptest"
	"sync"
	"testing"

	"github.com/ethereum/go-ethereum/beacon/engine"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/common/hexutil"
	"github.com/ethereum/go-ethereum/params"
	gethrpc "github.com/ethereum/go-ethereum/rpc"
	"github.com/stretchr/testify/require"
)

// fakeRPCCall is one JSON-RPC request recorded by a fake server.
type fakeRPCCall struct {
	Method string
	Params []json.RawMessage
}

// newFakeRPCServer starts a JSON-RPC server that records each request and answers with the raw JSON
// result registered for its method (null otherwise). It returns the server URL and a call recorder.
func newFakeRPCServer(t *testing.T, results map[string]string) (string, func() []fakeRPCCall) {
	t.Helper()
	return newFakeRPCServerFunc(t, func(method string, _ []json.RawMessage) string {
		if result, ok := results[method]; ok {
			return result
		}
		return "null"
	})
}

// newFakeRPCServerFunc starts a JSON-RPC server that records each request and answers with the raw
// JSON result returned by resolve.
func newFakeRPCServerFunc(
	t *testing.T,
	resolve func(method string, params []json.RawMessage) string,
) (string, func() []fakeRPCCall) {
	t.Helper()
	var (
		mu    sync.Mutex
		calls []fakeRPCCall
	)
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		body, err := io.ReadAll(r.Body)
		require.NoError(t, err)
		var req struct {
			ID     json.RawMessage   `json:"id"`
			Method string            `json:"method"`
			Params []json.RawMessage `json:"params"`
		}
		require.NoError(t, json.Unmarshal(body, &req))

		mu.Lock()
		calls = append(calls, fakeRPCCall{Method: req.Method, Params: req.Params})
		mu.Unlock()

		fmt.Fprintf(w, `{"jsonrpc":"2.0","id":%s,"result":%s}`, req.ID, resolve(req.Method, req.Params))
	}))
	t.Cleanup(srv.Close)

	return srv.URL, func() []fakeRPCCall {
		mu.Lock()
		defer mu.Unlock()
		return append([]fakeRPCCall(nil), calls...)
	}
}

// newFakeEngineClient returns a devnet EngineClient backed by a fake JSON-RPC server.
func newFakeEngineClient(t *testing.T, results map[string]string) (*EngineClient, func() []fakeRPCCall) {
	t.Helper()
	url, calls := newFakeRPCServer(t, results)
	client, err := gethrpc.DialHTTP(url)
	require.NoError(t, err)
	t.Cleanup(client.Close)

	return &EngineClient{Client: client, rpcURL: url, chainID: params.TaikoInternalNetworkID}, calls
}

const fakeExecutionPayloadJSON = `{` +
	`"parentHash":"0x0000000000000000000000000000000000000000000000000000000000000001",` +
	`"feeRecipient":"0x0000000000000000000000000000000000000002",` +
	`"stateRoot":"0x0000000000000000000000000000000000000000000000000000000000000003",` +
	`"receiptsRoot":"0x0000000000000000000000000000000000000000000000000000000000000004",` +
	`"logsBloom":"0x` + "%0512x" + `",` +
	`"prevRandao":"0x0000000000000000000000000000000000000000000000000000000000000005",` +
	`"blockNumber":"0xa",` +
	`"gasLimit":"0x1c9c380",` +
	`"gasUsed":"0x0",` +
	`"timestamp":"0x3e8",` +
	`"extraData":"0x00000000000007",` +
	`"baseFeePerGas":"0xf4240",` +
	`"blockHash":"0x0000000000000000000000000000000000000000000000000000000000000006",` +
	`"transactions":[],` +
	`"withdrawals":[],` +
	`"blobGasUsed":"0x0",` +
	`"excessBlobGas":"0x0"` +
	`}`

func TestEngineClient_ForkchoiceUpdatedV3(t *testing.T) {
	c, calls := newFakeEngineClient(t, map[string]string{
		"engine_forkchoiceUpdatedV3": `{"payloadStatus":{"status":"VALID","latestValidHash":null,` +
			`"validationError":null},"payloadId":"0x0300000000000001"}`,
	})

	root := common.HexToHash("0xab")
	res, err := c.ForkchoiceUpdatedV3(
		context.Background(),
		&engine.ForkchoiceStateV1{HeadBlockHash: common.HexToHash("0x01")},
		&engine.PayloadAttributes{BeaconRoot: &root, BaseFeePerGas: common.Big1},
	)
	require.NoError(t, err)
	require.Equal(t, engine.VALID, res.PayloadStatus.Status)
	require.Equal(t, engine.PayloadID{0x03, 0, 0, 0, 0, 0, 0, 0x01}, *res.PayloadID)

	recorded := calls()
	require.Len(t, recorded, 1)
	require.Equal(t, "engine_forkchoiceUpdatedV3", recorded[0].Method)
	require.Len(t, recorded[0].Params, 2)
	require.Contains(t, string(recorded[0].Params[1]), `"parentBeaconBlockRoot":"`+root.Hex()+`"`)
}

func TestEngineClient_GetPayloadV5_NormalizesBlockValue(t *testing.T) {
	pinDevnetForkTimes(t, 0, 0)

	c, calls := newFakeEngineClient(t, map[string]string{
		"engine_getPayloadV5": `{"executionPayload":` + fmt.Sprintf(fakeExecutionPayloadJSON, 0) +
			`,"blockValue":"0x2a","blobsBundle":{"commitments":[],"proofs":[],"blobs":[]},` +
			`"executionRequests":[],"shouldOverrideBuilder":false}`,
	})

	payload, err := c.GetPayloadV5(context.Background(), &engine.PayloadID{0x03})
	require.NoError(t, err)
	require.Equal(t, uint64(10), payload.Number)
	require.Equal(t, big.NewInt(42), payload.HeaderDifficulty)
	require.Equal(t, "engine_getPayloadV5", calls()[0].Method)
}

func TestEngineClient_GetPayloadV5_RejectsEmptyResponse(t *testing.T) {
	c, _ := newFakeEngineClient(t, map[string]string{})

	_, err := c.GetPayloadV5(context.Background(), &engine.PayloadID{0x03})
	require.Error(t, err)
}

func TestEngineClient_NewPayloadV4_SendsFourParams(t *testing.T) {
	c, calls := newFakeEngineClient(t, map[string]string{
		"engine_newPayloadV4": `{"status":"VALID","latestValidHash":` +
			`"0x0000000000000000000000000000000000000000000000000000000000000006","validationError":null}`,
	})

	root := common.HexToHash("0xab")
	status, err := c.NewPayloadV4(context.Background(), sampleExecutableData(), root)
	require.NoError(t, err)
	require.Equal(t, engine.VALID, status.Status)

	recorded := calls()
	require.Len(t, recorded, 1)
	require.Equal(t, "engine_newPayloadV4", recorded[0].Method)
	require.Len(t, recorded[0].Params, 4)
	requireJSONKeys(t, recorded[0].Params[0], etnaPayloadKeys...)
	require.JSONEq(t, `[]`, string(recorded[0].Params[1]))
	require.JSONEq(t, `"`+root.Hex()+`"`, string(recorded[0].Params[2]))
	require.JSONEq(t, `[]`, string(recorded[0].Params[3]))
}

func TestEngineClient_NewPayloadV4_RejectsMissingDifficultyBeforeCalling(t *testing.T) {
	c, calls := newFakeEngineClient(t, map[string]string{})

	data := sampleExecutableData()
	data.HeaderDifficulty = nil
	_, err := c.NewPayloadV4(context.Background(), data, common.HexToHash("0xab"))
	require.ErrorContains(t, err, "header difficulty")
	require.Empty(t, calls())
}

func TestEngineClient_TxPoolContentWithMinTip_BlockContextOnlyWhenSet(t *testing.T) {
	c, calls := newFakeEngineClient(t, map[string]string{"taikoAuth_txPoolContentWithMinTip": `[]`})

	_, err := c.TxPoolContentWithMinTip(
		context.Background(), common.Address{}, common.Big1, 30_000_000, 1024, nil, 1, 0, nil,
	)
	require.NoError(t, err)

	blockContext := &TxPoolBlockContext{
		Timestamp:             hexutil.Uint64(100),
		ParentBeaconBlockRoot: common.HexToHash("0x01"),
		ExtraData:             []byte{0, 0, 0, 0, 0, 0, 0},
	}
	_, err = c.TxPoolContentWithMinTip(
		context.Background(), common.Address{}, common.Big1, 30_000_000, 1024, nil, 1, 0, blockContext,
	)
	require.NoError(t, err)

	recorded := calls()
	require.Len(t, recorded, 2)
	require.Len(t, recorded[0].Params, 7)
	require.Len(t, recorded[1].Params, 8)
	require.Contains(t, string(recorded[1].Params[7]), `"timestamp":"0x64"`)
}
