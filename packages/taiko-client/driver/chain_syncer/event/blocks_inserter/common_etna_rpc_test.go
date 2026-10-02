package blocksinserter

import (
	"context"
	"encoding/json"
	"fmt"
	"math/big"
	"net/http"
	"net/http/httptest"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/ethereum/go-ethereum/beacon/engine"
	"github.com/ethereum/go-ethereum/common"
	gethcore "github.com/ethereum/go-ethereum/core"
	"github.com/ethereum/go-ethereum/core/rawdb"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/crypto"
	"github.com/ethereum/go-ethereum/params"
	"github.com/ethereum/go-ethereum/trie"
	"github.com/stretchr/testify/suite"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/rpc"
)

// testEtnaTime is the devnet Etna activation time the fake-RPC tests pin; Unzen is active from genesis.
const testEtnaTime = 100

// fakePayloadID is the payload ID the fake execution engine returns for every payload it starts building.
const fakePayloadID = "0x0300000000000001"

// fakeBlockHash is the hash of the block the fake execution engine builds.
var fakeBlockHash = common.HexToHash("0x06")

// fakePayloadJSON returns the execution payload the fake execution engine builds. It carries
// headerDifficulty itself: rpc.NewJWTEngineClient leaves the engine client's chain ID unset, so
// GetPayloadV5 does not copy blockValue into it.
func fakePayloadJSON() string {
	return `{` +
		`"parentHash":"` + sampleParent().Hash().Hex() + `",` +
		`"feeRecipient":"0x0000000000000000000000000000000000000002",` +
		`"stateRoot":"` + common.HexToHash("0x04").Hex() + `",` +
		`"receiptsRoot":"` + common.HexToHash("0x05").Hex() + `",` +
		`"logsBloom":"0x` + strings.Repeat("00", types.BloomByteLength) + `",` +
		`"prevRandao":"` + common.HexToHash("0x03").Hex() + `",` +
		`"blockNumber":"0xa",` +
		`"gasLimit":"0x1c9c380",` +
		`"gasUsed":"0x0",` +
		`"timestamp":"0x64",` +
		`"extraData":"0x00000000000007",` +
		`"baseFeePerGas":"0xf4240",` +
		`"blockHash":"` + fakeBlockHash.Hex() + `",` +
		`"transactions":[],` +
		`"withdrawals":[],` +
		`"blobGasUsed":"0x0",` +
		`"excessBlobGas":"0x0",` +
		`"headerDifficulty":7` +
		`}`
}

// fakeEngineResult returns the fake execution engine's result for an Engine API method: it starts building
// on every forkchoice update with attributes, returns fakePayloadJSON, and accepts every payload.
func fakeEngineResult(method string) string {
	switch method {
	case "engine_forkchoiceUpdatedV2", "engine_forkchoiceUpdatedV3":
		return `{"payloadStatus":{"status":"VALID","latestValidHash":null,"validationError":null},` +
			`"payloadId":"` + fakePayloadID + `"}`
	case "engine_getPayloadV2", "engine_getPayloadV5":
		return `{"executionPayload":` + fakePayloadJSON() + `,"blockValue":"0x7"}`
	case "engine_newPayloadV2", "engine_newPayloadV4":
		return `{"status":"VALID","latestValidHash":"` + fakeBlockHash.Hex() + `","validationError":null}`
	}
	return "null"
}

// methodsOf returns the method of each recorded call.
func methodsOf(calls []fakeRPCCall) []string {
	methods := make([]string, 0, len(calls))
	for _, call := range calls {
		methods = append(methods, call.Method)
	}
	return methods
}

// fakeRPCCall is one JSON-RPC request received by a fake server.
type fakeRPCCall struct {
	Method string
	Params []json.RawMessage
}

// newFakeRPCServer starts a JSON-RPC server that answers each request with the raw JSON result resolve
// returns for it. It returns the server URL and a function listing the requests received so far.
func newFakeRPCServer(
	t *testing.T,
	resolve func(method string, params []json.RawMessage) string,
) (string, func() []fakeRPCCall) {
	t.Helper()
	var (
		mu    sync.Mutex
		calls []fakeRPCCall
	)
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		var req struct {
			ID     json.RawMessage   `json:"id"`
			Method string            `json:"method"`
			Params []json.RawMessage `json:"params"`
		}
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			http.Error(w, err.Error(), http.StatusBadRequest)
			return
		}

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

// sampleParent is the parent of the sample L2 block 10 that the tests build or look up.
func sampleParent() *types.Header {
	return &types.Header{Number: big.NewInt(9), Difficulty: common.Big1, GasLimit: 30_000_000}
}

// sampleBlockMeta returns the metadata of the sample L2 block 10 at the given timestamp, committing root as
// its parentBeaconBlockRoot.
func sampleBlockMeta(timestamp uint64, root *common.Hash) *createExecutionPayloadsMetaData {
	return &createExecutionPayloadsMetaData{
		BlockID:               big.NewInt(10),
		ExtraData:             []byte{0, 0, 0, 0, 0, 0, 7},
		SuggestedFeeRecipient: common.HexToAddress("0x02"),
		GasLimit:              30_000_000,
		MixHash:               common.HexToHash("0x03"),
		Timestamp:             timestamp,
		ParentHash:            sampleParent().Hash(),
		L1Origin:              &rawdb.L1Origin{BlockID: big.NewInt(10)},
		BaseFee:               big.NewInt(1_000_000),
		Withdrawals:           make([]*types.Withdrawal, 0),
		ParentBeaconBlockRoot: root,
	}
}

// EtnaRPCTestSuite covers createExecutionPayloads and isKnownCanonicalBlock across the Etna fork, against
// fake JSON-RPC servers. It needs no devnet.
type EtnaRPCTestSuite struct {
	suite.Suite
	originalUnzen uint64
	originalEtna  uint64
}

func (s *EtnaRPCTestSuite) SetupTest() {
	s.originalUnzen, s.originalEtna = gethcore.DevnetUnzenTime, gethcore.DevnetEtnaTime
	gethcore.DevnetUnzenTime, gethcore.DevnetEtnaTime = 0, testEtnaTime
}

func (s *EtnaRPCTestSuite) TearDownTest() {
	gethcore.DevnetUnzenTime, gethcore.DevnetEtnaTime = s.originalUnzen, s.originalEtna
}

func TestEtnaRPCTestSuite(t *testing.T) {
	suite.Run(t, new(EtnaRPCTestSuite))
}

// signedTx returns a signed internal devnet transaction with the given nonce.
func (s *EtnaRPCTestSuite) signedTx(nonce uint64) *types.Transaction {
	key, err := crypto.GenerateKey()
	s.Require().NoError(err)
	tx, err := types.SignTx(
		types.NewTransaction(nonce, common.Address{}, common.Big0, 21_000, big.NewInt(1), nil),
		types.LatestSignerForChainID(params.TaikoInternalNetworkID),
		key,
	)
	s.Require().NoError(err)
	return tx
}

// newFakeEngine returns an internal devnet rpc.Client whose engine client is backed by a fake execution
// engine (see fakeEngineResult), and a function listing the Engine API calls it received.
func (s *EtnaRPCTestSuite) newFakeEngine() (*rpc.Client, func() []fakeRPCCall) {
	url, calls := newFakeRPCServer(s.T(), func(method string, _ []json.RawMessage) string {
		return fakeEngineResult(method)
	})
	engineClient, err := rpc.NewJWTEngineClient(url, "fake-jwt-secret")
	s.Require().NoError(err)
	s.T().Cleanup(engineClient.Close)

	return &rpc.Client{L2: &rpc.EthClient{ChainID: params.TaikoInternalNetworkID}, L2Engine: engineClient}, calls
}

// newFakeL2 returns an rpc.Client whose L2 node serves block as every block by number, and an L1 origin
// for it that stores the payload fingerprint the driver would compute for meta and txListBytes.
func (s *EtnaRPCTestSuite) newFakeL2(
	meta *createExecutionPayloadsMetaData,
	txListBytes []byte,
	block *types.Block,
) *rpc.Client {
	headerJSON, err := json.Marshal(block.Header())
	s.Require().NoError(err)
	txsJSON, err := json.Marshal(block.Transactions())
	s.Require().NoError(err)
	blockJSON := fmt.Sprintf(
		`%s,"transactions":%s,"uncles":[],"withdrawals":[]}`,
		strings.TrimSuffix(string(headerJSON), "}"),
		txsJSON,
	)
	l1OriginJSON, err := json.Marshal(&rawdb.L1Origin{
		BlockID:            meta.BlockID,
		L2BlockHash:        block.Hash(),
		BuildPayloadArgsID: buildPayloadArgsID(meta, crypto.Keccak256Hash(txListBytes)),
	})
	s.Require().NoError(err)

	url, _ := newFakeRPCServer(s.T(), func(method string, _ []json.RawMessage) string {
		switch method {
		case "eth_chainId":
			return `"0x28c59"` // 167001, the internal devnet
		case "eth_getBlockByNumber":
			return blockJSON
		case "taiko_l1OriginByID":
			return string(l1OriginJSON)
		}
		return "null"
	})
	l2, err := rpc.NewEthClient(context.Background(), url, time.Second)
	s.Require().NoError(err)
	return &rpc.Client{L2: l2}
}

// canonicalBlock returns the canonical block 10 that matches meta in every field isKnownCanonicalBlock
// compares, committing root as its parentBeaconBlockRoot and carrying txs.
func (s *EtnaRPCTestSuite) canonicalBlock(
	meta *createExecutionPayloadsMetaData,
	root common.Hash,
	txs types.Transactions,
) *types.Block {
	var zero uint64
	return types.NewBlock(
		&types.Header{
			ParentHash: sampleParent().Hash(),
			Coinbase:   meta.SuggestedFeeRecipient,
			// Before Etna, every block uses some zk gas for its anchor transaction.
			Difficulty:       common.Big1,
			Number:           meta.BlockID,
			GasLimit:         meta.GasLimit + rpc.AnchorGasReserve(params.TaikoInternalNetworkID, meta.Timestamp),
			Time:             meta.Timestamp,
			Extra:            meta.ExtraData,
			MixDigest:        meta.MixHash,
			BaseFee:          meta.BaseFee,
			BlobGasUsed:      &zero,
			ExcessBlobGas:    &zero,
			ParentBeaconRoot: &root,
			RequestsHash:     &types.EmptyRequestsHash,
		},
		&types.Body{Transactions: txs, Withdrawals: make([]*types.Withdrawal, 0)},
		nil,
		trie.NewStackTrie(nil),
	)
}

// isKnown runs isKnownCanonicalBlock for meta, encoding its transactions list with anchorTx, against a
// fake L2 node whose canonical block 10 is block.
func (s *EtnaRPCTestSuite) isKnown(
	meta *createExecutionPayloadsMetaData,
	anchorTx *types.Transaction,
	block *types.Block,
) (*types.Header, bool) {
	txListBytes, err := encodeTxList(anchorTx, meta.Txs)
	s.Require().NoError(err)

	header, known, err := isKnownCanonicalBlock(
		context.Background(),
		s.newFakeL2(meta, txListBytes, block),
		&createPayloadAndSetHeadMetaData{createExecutionPayloadsMetaData: meta, Parent: sampleParent()},
		txListBytes,
		anchorTx,
	)
	s.Require().NoError(err)
	return header, known
}

func (s *EtnaRPCTestSuite) TestCreateExecutionPayloadsEtnaUsesV3V5V4() {
	root := common.HexToHash("0xaa")
	cli, calls := s.newFakeEngine()

	payload, err := createExecutionPayloads(
		context.Background(), cli, sampleBlockMeta(testEtnaTime, &root), []byte{0xc0},
	)
	s.Require().NoError(err)
	s.Equal(fakeBlockHash, payload.BlockHash)

	recorded := calls()
	s.Require().Equal(
		[]string{"engine_forkchoiceUpdatedV3", "engine_getPayloadV5", "engine_newPayloadV4"},
		methodsOf(recorded),
	)

	// The payload is built with the L1 anchor block hash as parentBeaconBlockRoot...
	s.Require().Len(recorded[0].Params, 2)
	var attributes engine.PayloadAttributes
	s.Require().NoError(json.Unmarshal(recorded[0].Params[1], &attributes))
	s.Require().NotNil(attributes.BeaconRoot)
	s.Equal(root, *attributes.BeaconRoot)

	// ...fetched by the payload ID the forkchoice update returned...
	s.Require().Len(recorded[1].Params, 1)
	s.JSONEq(`"`+fakePayloadID+`"`, string(recorded[1].Params[0]))

	// ...and executed with the same root: [payload, [], root, []].
	s.Require().Len(recorded[2].Params, 4)
	var executed rpc.TaikoExecutionPayloadV3
	s.Require().NoError(json.Unmarshal(recorded[2].Params[0], &executed))
	s.Equal(fakeBlockHash, executed.BlockHash)
	s.Equal(uint64(7), executed.HeaderDifficulty)
	s.JSONEq(`[]`, string(recorded[2].Params[1]))
	s.JSONEq(`"`+root.Hex()+`"`, string(recorded[2].Params[2]))
	s.JSONEq(`[]`, string(recorded[2].Params[3]))
}

func (s *EtnaRPCTestSuite) TestCreateExecutionPayloadsPreEtnaUsesV2() {
	cli, calls := s.newFakeEngine()

	payload, err := createExecutionPayloads(
		context.Background(), cli, sampleBlockMeta(testEtnaTime-1, nil), []byte{0xc0},
	)
	s.Require().NoError(err)
	s.Equal(fakeBlockHash, payload.BlockHash)

	recorded := calls()
	s.Require().Equal(
		[]string{"engine_forkchoiceUpdatedV2", "engine_getPayloadV2", "engine_newPayloadV2"},
		methodsOf(recorded),
	)
	s.Require().Len(recorded[0].Params, 2)
	var attributes engine.PayloadAttributes
	s.Require().NoError(json.Unmarshal(recorded[0].Params[1], &attributes))
	s.Nil(attributes.BeaconRoot)
	s.Len(recorded[2].Params, 1)
}

func (s *EtnaRPCTestSuite) TestCreateExecutionPayloadsEtnaRequiresRoot() {
	zero := common.Hash{}
	for _, root := range []*common.Hash{nil, &zero} {
		cli, calls := s.newFakeEngine()

		_, err := createExecutionPayloads(
			context.Background(), cli, sampleBlockMeta(testEtnaTime, root), []byte{0xc0},
		)
		s.ErrorContains(err, "missing L1 anchor block hash for Etna block 10")
		s.Empty(methodsOf(calls()))
	}
}

func (s *EtnaRPCTestSuite) TestKnownCanonicalBlockEtna() {
	root := common.HexToHash("0xaa")
	meta := sampleBlockMeta(testEtnaTime, &root)
	meta.Txs = types.Transactions{s.signedTx(1)}
	block := s.canonicalBlock(meta, root, meta.Txs)

	header, known := s.isKnown(meta, nil, block)
	s.True(known)
	s.Require().NotNil(header)
	s.Equal(block.Hash(), header.Hash())
}

func (s *EtnaRPCTestSuite) TestKnownCanonicalBlockPreEtna() {
	meta := sampleBlockMeta(testEtnaTime-1, nil)
	anchorTx := s.signedTx(0)
	block := s.canonicalBlock(meta, common.Hash{}, types.Transactions{anchorTx})

	header, known := s.isKnown(meta, anchorTx, block)
	s.True(known)
	s.Require().NotNil(header)
	s.Equal(block.Hash(), header.Hash())
}

func (s *EtnaRPCTestSuite) TestKnownCanonicalBlockRejectsEtnaMetaWithoutRoot() {
	// Before the fork was keyed on the timestamp, a missing root sent an Etna block down the pre-Etna path,
	// which dereferences the nil anchor transaction.
	meta := sampleBlockMeta(testEtnaTime, nil)
	meta.Txs = types.Transactions{s.signedTx(1)}
	block := s.canonicalBlock(meta, common.HexToHash("0xaa"), meta.Txs)

	header, known := s.isKnown(meta, nil, block)
	s.False(known)
	s.Nil(header)
}

func (s *EtnaRPCTestSuite) TestKnownCanonicalBlockRejectsEtnaMetaWithZeroRoot() {
	// The canonical block matches the metadata in every field, but an Etna block must commit its L1 anchor
	// block hash, never the zero root.
	zero := common.Hash{}
	meta := sampleBlockMeta(testEtnaTime, &zero)
	block := s.canonicalBlock(meta, zero, types.Transactions{})

	header, known := s.isKnown(meta, nil, block)
	s.False(known)
	s.Nil(header)
}

func (s *EtnaRPCTestSuite) TestKnownCanonicalBlockRejectsPreEtnaMetaWithRoot() {
	// The canonical block matches the metadata in every field, but a block before Etna commits no L1 anchor
	// block hash.
	root := common.HexToHash("0xaa")
	meta := sampleBlockMeta(testEtnaTime-1, &root)
	anchorTx := s.signedTx(0)
	block := s.canonicalBlock(meta, root, types.Transactions{anchorTx})

	header, known := s.isKnown(meta, anchorTx, block)
	s.False(known)
	s.Nil(header)
}
