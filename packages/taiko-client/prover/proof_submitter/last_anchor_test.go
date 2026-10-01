package submitter

import (
	"context"
	"encoding/json"
	"fmt"
	"math/big"
	"net/http"
	"net/http/httptest"
	"sync"
	"testing"
	"time"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/common/hexutil"
	gethcore "github.com/ethereum/go-ethereum/core"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"github.com/stretchr/testify/suite"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/rpc"
)

// newFakeEthClient returns an rpc.EthClient backed by a fake JSON-RPC server, which answers each call with
// the raw JSON result resolve returns, and a function listing the methods called so far.
func newFakeEthClient(
	t *testing.T,
	resolve func(method string, params []json.RawMessage) string,
) (*rpc.EthClient, func() []string) {
	t.Helper()
	var (
		mu      sync.Mutex
		methods []string
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
		methods = append(methods, req.Method)
		mu.Unlock()

		fmt.Fprintf(w, `{"jsonrpc":"2.0","id":%s,"result":%s}`, req.ID, resolve(req.Method, req.Params))
	}))
	t.Cleanup(srv.Close)

	client, err := rpc.NewEthClient(context.Background(), srv.URL, time.Second)
	require.NoError(t, err)

	return client, func() []string {
		mu.Lock()
		defer mu.Unlock()
		return append([]string(nil), methods...)
	}
}

// newFakeL2 returns an internal devnet L2 client that serves the given header bodies by block number.
func newFakeL2(t *testing.T, byNumber map[uint64]string) *rpc.EthClient {
	t.Helper()
	client, _ := newFakeEthClient(t, func(method string, params []json.RawMessage) string {
		switch method {
		case "eth_chainId":
			return `"0x28c59"` // 167001, the internal devnet
		case "eth_getBlockByNumber":
			var number hexutil.Uint64
			if assert.NoError(t, json.Unmarshal(params[0], &number)) {
				if body, ok := byNumber[uint64(number)]; ok {
					return body
				}
			}
		}
		return "null"
	})
	return client
}

// newFakeL1 returns an L1 client that serves the given header bodies by block hash, and a function listing
// the methods it has been called with.
func newFakeL1(t *testing.T, byHash map[common.Hash]string) (*rpc.EthClient, func() []string) {
	t.Helper()
	return newFakeEthClient(t, func(method string, params []json.RawMessage) string {
		switch method {
		case "eth_chainId":
			return `"0x1"`
		case "eth_getBlockByHash":
			var hash common.Hash
			if assert.NoError(t, json.Unmarshal(params[0], &hash)) {
				if body, ok := byHash[hash]; ok {
					return body
				}
			}
		}
		return "null"
	})
}

// fakeHeaderJSON returns an eth_getBlockBy* result body with the fields go-ethereum requires to decode a
// header. The header commits root as its parentBeaconBlockRoot when root is not nil.
func fakeHeaderJSON(number, timestamp uint64, root *common.Hash) string {
	var parentBeaconBlockRoot string
	if root != nil {
		parentBeaconBlockRoot = fmt.Sprintf(`,"parentBeaconBlockRoot":"%s"`, root.Hex())
	}
	return fmt.Sprintf(`{`+
		`"number":"0x%x",`+
		`"timestamp":"0x%x",`+
		`"parentHash":"0x%064x",`+
		`"sha3Uncles":"0x%064x",`+
		`"stateRoot":"0x%064x",`+
		`"transactionsRoot":"0x%064x",`+
		`"receiptsRoot":"0x%064x",`+
		`"logsBloom":"0x%0512x",`+
		`"difficulty":"0x0",`+
		`"gasLimit":"0x0",`+
		`"gasUsed":"0x0",`+
		`"extraData":"0x"%s}`,
		number, timestamp, 0, 0, 0, 0, 0, 0, parentBeaconBlockRoot,
	)
}

// decodedHeaderHash returns the hash go-ethereum computes for a header JSON body.
func decodedHeaderHash(t *testing.T, body string) common.Hash {
	t.Helper()
	var header types.Header
	require.NoError(t, json.Unmarshal([]byte(body), &header))
	return header.Hash()
}

// LastAnchorBlockNumberTestSuite covers the anchor block number the prover sends for a proposal whose
// previous proposal ends with an Etna block. It needs no devnet. The pre-Etna branch reads the Anchor
// contract binding, which needs the devnet, so it is not tested here.
type LastAnchorBlockNumberTestSuite struct {
	suite.Suite
	originalUnzen uint64
	originalEtna  uint64
}

func (s *LastAnchorBlockNumberTestSuite) SetupTest() {
	s.originalUnzen, s.originalEtna = gethcore.DevnetUnzenTime, gethcore.DevnetEtnaTime
	gethcore.DevnetUnzenTime, gethcore.DevnetEtnaTime = 0, 0
}

func (s *LastAnchorBlockNumberTestSuite) TearDownTest() {
	gethcore.DevnetUnzenTime, gethcore.DevnetEtnaTime = s.originalUnzen, s.originalEtna
}

func TestLastAnchorBlockNumberTestSuite(t *testing.T) {
	suite.Run(t, new(LastAnchorBlockNumberTestSuite))
}

func (s *LastAnchorBlockNumberTestSuite) TestEtnaGenesisIsZero() {
	// An Etna genesis block commits the zero root, which names no L1 block.
	zero := common.Hash{}
	l1, l1Calls := newFakeL1(s.T(), nil)
	l2 := newFakeL2(s.T(), map[uint64]string{0: fakeHeaderJSON(0, 0, &zero)})
	submitter := &ProofSubmitter{rpc: &rpc.Client{L1: l1, L2: l2}}

	anchorBlockNumber, err := submitter.lastAnchorBlockNumber(context.Background(), common.Big0)
	s.Require().NoError(err)
	s.Equal(uint64(0), anchorBlockNumber.Uint64())
	s.Equal([]string{"eth_chainId"}, l1Calls())
}

func (s *LastAnchorBlockNumberTestSuite) TestEtnaBlockResolvesRootOnL1() {
	anchorBody := fakeHeaderJSON(77, 0, nil)
	root := decodedHeaderHash(s.T(), anchorBody)
	l1, _ := newFakeL1(s.T(), map[common.Hash]string{root: anchorBody})
	l2 := newFakeL2(s.T(), map[uint64]string{5: fakeHeaderJSON(5, 10, &root)})
	submitter := &ProofSubmitter{rpc: &rpc.Client{L1: l1, L2: l2}}

	anchorBlockNumber, err := submitter.lastAnchorBlockNumber(context.Background(), big.NewInt(5))
	s.Require().NoError(err)
	s.Equal(uint64(77), anchorBlockNumber.Uint64())
}

func (s *LastAnchorBlockNumberTestSuite) TestEtnaBlockWithoutRootFails() {
	l1, _ := newFakeL1(s.T(), nil)
	l2 := newFakeL2(s.T(), map[uint64]string{5: fakeHeaderJSON(5, 10, nil)})
	submitter := &ProofSubmitter{rpc: &rpc.Client{L1: l1, L2: l2}}

	_, err := submitter.lastAnchorBlockNumber(context.Background(), big.NewInt(5))
	s.ErrorContains(err, "failed to resolve the Etna anchor block of block 5")
	s.ErrorContains(err, "missing L1 anchor block hash")
}
