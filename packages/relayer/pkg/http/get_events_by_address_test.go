package http

import (
	"context"
	"encoding/json"
	"fmt"
	"math/big"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/cyberhorsey/webutils/testutils"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/labstack/echo/v4"
	"github.com/stretchr/testify/assert"
	"github.com/taikoxyz/taiko-mono/packages/relayer"
	"github.com/taikoxyz/taiko-mono/packages/relayer/bindings/bridge"
	"github.com/taikoxyz/taiko-mono/packages/relayer/pkg/mock"
)

func Test_GetEventsByAddress(t *testing.T) {
	srv := newTestServer()

	_, err := srv.eventRepo.Save(context.Background(), &relayer.SaveEventOpts{
		Name:        "name",
		Data:        `{"Owner": "0x0000000000000000000000000000000000000123"}`,
		ChainID:     big.NewInt(167001),
		DestChainID: big.NewInt(167002),
		Status:      relayer.EventStatusNew,
	})

	assert.Equal(t, nil, err)

	tests := []struct {
		name                  string
		address               string
		chainID               string
		wantStatus            int
		wantBodyRegexpMatches []string
	}{
		{
			"successEmptyList",
			"0x456",
			"167001",
			http.StatusOK,
			[]string{`\[\]`},
		},
		{
			"success",
			"0x0000000000000000000000000000000000000123",
			"167001",
			http.StatusOK,
			[]string{`[{"id":780800018316137516,"name":"name",
			"data":{"Owner":"0x0000000000000000000000000000000000000123"},"status":0,"chainID":167001}]`},
		},
		{
			"successNoChainID",
			"0x0000000000000000000000000000000000000123",
			"",
			http.StatusOK,
			[]string{`[{"id":780800018316137516,"name":"name",
			"data":{"Owner":"0x0000000000000000000000000000000000000123"},"status":0,"chainID":167001}]`},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			req := testutils.NewUnauthenticatedRequest(
				echo.GET,
				fmt.Sprintf("/events?address=%v&chainID=%v",
					tt.address,
					tt.chainID),

				nil,
			)

			rec := httptest.NewRecorder()

			srv.ServeHTTP(rec, req)

			testutils.AssertStatusAndBody(t, rec, tt.wantStatus, tt.wantBodyRegexpMatches)
		})
	}
}

// claimSenderClient answers every sender lookup with one address, so a test can tell which
// chain's client the handler asked.
type claimSenderClient struct {
	mock.EthClient
	sender common.Address
}

func (c *claimSenderClient) TransactionSender(
	_ context.Context,
	_ *types.Transaction,
	_ common.Hash,
	_ uint,
) (common.Address, error) {
	return c.sender, nil
}

// The relayer reports who claimed a message by reading the claim transaction named in the
// message's MessageStatusChanged row. When the relayer itself claims, its processor records a
// stub row carrying only the transaction hash before the destination-chain indexer stores the
// full log, and the first row is the stub: every relayer-claimed message came back with neither
// claimer nor claim hash, while self-claims had both.
func Test_GetEventsByAddress_claimedByTheRelayer(t *testing.T) {
	const (
		srcChainID   = 167001
		destChainID  = 167002
		owner        = "0x0000000000000000000000000000000000000123"
		msgHash      = "0x789cd5dcc77d50bec34b6458af936a3bfa802f3aa8b8466c07b2c6b663c92575"
		claimTxHash  = "0x27a4811c18012da320c7a1bf4d788aeca068ac2e34a5f2ff73df33fa5f0e4b44"
		retryTxHash  = "0x1111111111111111111111111111111111111111111111111111111111111111"
		recallTxHash = "0x2222222222222222222222222222222222222222222222222222222222222222"
	)

	srcSender := common.HexToAddress("0x000000000000000000000000000000000000AAAA")
	relayerAddr := common.HexToAddress("0x00006ca990540F6e30e3ef05F085a033Ae67F214")

	newServer := func() *Server {
		srv := newTestServer()
		srv.srcChainID = big.NewInt(srcChainID)
		srv.destChainID = big.NewInt(destChainID)
		srv.srcEthClient = &claimSenderClient{sender: srcSender}
		srv.destEthClient = &claimSenderClient{sender: relayerAddr}

		// The message, sent from the source chain to the destination chain
		_, err := srv.eventRepo.Save(context.Background(), &relayer.SaveEventOpts{
			Name:         relayer.EventNameMessageSent,
			Event:        relayer.EventNameMessageSent,
			Data:         fmt.Sprintf(`{"Owner": "%s"}`, owner),
			ChainID:      big.NewInt(srcChainID),
			DestChainID:  big.NewInt(destChainID),
			Status:       relayer.EventStatusDone,
			MsgHash:      msgHash,
			MessageOwner: owner,
		})
		assert.Nil(t, err)

		return srv
	}

	// The processor's stub: written first, filed under the source chain, nothing but the hash
	saveStub := func(srv *Server) {
		_, err := srv.eventRepo.Save(context.Background(), &relayer.SaveEventOpts{
			Name:        relayer.EventNameMessageStatusChanged,
			Event:       relayer.EventNameMessageStatusChanged,
			Data:        fmt.Sprintf(`{"Raw":{"transactionHash": "%s"}}`, claimTxHash),
			ChainID:     big.NewInt(srcChainID),
			DestChainID: big.NewInt(destChainID),
			Status:      relayer.EventStatusDone,
			MsgHash:     msgHash,
		})
		assert.Nil(t, err)
	}

	// A status transition as the indexer stores it: the whole log
	saveIndexed := func(srv *Server, status relayer.EventStatus, txHash string, chainID int64) {
		_, err := srv.eventRepo.Save(context.Background(), &relayer.SaveEventOpts{
			Name:  relayer.EventNameMessageStatusChanged,
			Event: relayer.EventNameMessageStatusChanged,
			Data: fmt.Sprintf(
				`{"Raw":{"transactionHash": "%s", "transactionIndex": "0x1", "blockHash": "0x%s", "blockNumber": "0x10"}}`,
				txHash,
				strings.Repeat("ab", 32),
			),
			ChainID:     big.NewInt(chainID),
			DestChainID: big.NewInt(srcChainID),
			Status:      status,
			MsgHash:     msgHash,
		})
		assert.Nil(t, err)
	}

	get := func(srv *Server) string {
		req := testutils.NewUnauthenticatedRequest(echo.GET, fmt.Sprintf("/events?address=%v", owner), nil)
		rec := httptest.NewRecorder()
		srv.ServeHTTP(rec, req)
		assert.Equal(t, http.StatusOK, rec.Code)

		return rec.Body.String()
	}

	t.Run("reads the claimer off the indexed log, not off the stub written before it", func(t *testing.T) {
		srv := newServer()
		saveStub(srv)
		saveIndexed(srv, relayer.EventStatusDone, claimTxHash, destChainID)

		body := get(srv)

		assert.Contains(t, body, fmt.Sprintf(`"claimedBy":"%s"`, relayerAddr.Hex()))
		assert.Contains(t, body, fmt.Sprintf(`"processedTxHash":"%s"`, claimTxHash))
	})

	t.Run("still reports the claim hash when only the stub exists", func(t *testing.T) {
		// Nothing but the hash is known, and the sender cannot be recovered without the block
		srv := newServer()
		saveStub(srv)

		body := get(srv)

		assert.Contains(t, body, fmt.Sprintf(`"processedTxHash":"%s"`, claimTxHash))
		assert.Contains(t, body, `"claimedBy":""`)
	})

	t.Run("asks the destination chain for the sender whichever chain the row is filed under", func(t *testing.T) {
		// A complete row filed under the source chain, the way the processor files its own
		// claim: the transaction was mined on the destination chain all the same
		srv := newServer()
		saveIndexed(srv, relayer.EventStatusDone, claimTxHash, srcChainID)

		body := get(srv)

		assert.Contains(t, body, fmt.Sprintf(`"claimedBy":"%s"`, relayerAddr.Hex()))
		assert.NotContains(t, body, srcSender.Hex())
	})

	t.Run("reports the claim, not the earlier attempt that left the message retriable", func(t *testing.T) {
		// A retried message has two complete rows, and the older one is the failed attempt
		srv := newServer()
		saveIndexed(srv, relayer.EventStatusRetriable, retryTxHash, destChainID)
		saveIndexed(srv, relayer.EventStatusDone, claimTxHash, destChainID)

		body := get(srv)

		assert.Contains(t, body, fmt.Sprintf(`"processedTxHash":"%s"`, claimTxHash))
		assert.NotContains(t, body, retryTxHash)
	})

	t.Run("does not mistake a recall for a claim", func(t *testing.T) {
		// A recall is a status transition too, mined on the source chain, and it is not a claim
		srv := newServer()
		saveIndexed(srv, relayer.EventStatusRecalled, recallTxHash, srcChainID)

		body := get(srv)

		assert.Contains(t, body, `"processedTxHash":""`)
		assert.Contains(t, body, `"claimedBy":""`)
	})

	// A DONE that a later row superseded is not the current claim. The chain cannot go from
	// DONE to anything else, so a newer non-DONE row means the DONE was orphaned by a reorg
	// of the block it was mined in, and the message was then retried, or recalled. Reorg
	// cleanup does not remove either writer's status rows (it keys on block_id, which they
	// never set), so the orphaned row stays, and the newest row has to be the one that counts.
	t.Run("reports nothing for a claim a later retry superseded", func(t *testing.T) {
		srv := newServer()
		saveIndexed(srv, relayer.EventStatusDone, claimTxHash, destChainID)
		saveIndexed(srv, relayer.EventStatusRetriable, retryTxHash, destChainID)

		body := get(srv)

		assert.Contains(t, body, `"processedTxHash":""`)
		assert.Contains(t, body, `"claimedBy":""`)
	})

	t.Run("reports nothing for a claim a later recall superseded", func(t *testing.T) {
		srv := newServer()
		saveIndexed(srv, relayer.EventStatusDone, claimTxHash, destChainID)
		saveIndexed(srv, relayer.EventStatusRecalled, recallTxHash, srcChainID)

		body := get(srv)

		assert.Contains(t, body, `"processedTxHash":""`)
		assert.Contains(t, body, `"claimedBy":""`)
	})

	t.Run("reports nothing when a legacy stub and its orphaned log are followed by a retry", func(t *testing.T) {
		// The rows a message claimed by an older relayer carries after a reorg: the hash-only
		// stub, the indexed DONE of the orphaned block, then the canonical RETRIABLE
		srv := newServer()
		saveStub(srv)
		saveIndexed(srv, relayer.EventStatusDone, claimTxHash, destChainID)
		saveIndexed(srv, relayer.EventStatusRetriable, retryTxHash, destChainID)

		body := get(srv)

		assert.Contains(t, body, `"processedTxHash":""`)
		assert.Contains(t, body, `"claimedBy":""`)
	})
}

// The processor stores its own claim as the binding's event marshalled whole, the way the
// indexer does. That shape is a contract between geth's log codec and this package's Raw, and
// the handler tests above write their rows by hand.
func Test_claimLog_readsTheRowTheProcessorWrites(t *testing.T) {
	const msgHash = "0x789cd5dcc77d50bec34b6458af936a3bfa802f3aa8b8466c07b2c6b663c92575"

	claimTxHash := common.HexToHash("0x27a4811c18012da320c7a1bf4d788aeca068ac2e34a5f2ff73df33fa5f0e4b44")
	blockHash := common.HexToHash("0xabababababababababababababababababababababababababababababababab")

	data, err := json.Marshal(&bridge.BridgeMessageStatusChanged{
		MsgHash: common.HexToHash(msgHash),
		Status:  uint8(relayer.EventStatusDone),
		Raw: types.Log{
			Address:     common.HexToAddress("0xC4279588B8dA563D264e286E2ee7CE8c244444d6"),
			Topics:      []common.Hash{{}, common.HexToHash(msgHash)},
			Data:        []byte{},
			BlockNumber: 16,
			TxHash:      claimTxHash,
			BlockHash:   blockHash,
			Index:       3,
		},
	})
	assert.Nil(t, err)

	srv := newTestServer()
	_, err = srv.eventRepo.Save(context.Background(), &relayer.SaveEventOpts{
		Name:        relayer.EventNameMessageStatusChanged,
		Event:       relayer.EventNameMessageStatusChanged,
		Data:        string(data),
		ChainID:     big.NewInt(1),
		DestChainID: big.NewInt(2),
		Status:      relayer.EventStatusDone,
		MsgHash:     msgHash,
	})
	assert.Nil(t, err)

	claim, err := srv.claimLog(context.Background(), msgHash)
	assert.Nil(t, err)
	assert.NotNil(t, claim)
	assert.Equal(t, claimTxHash.Hex(), claim.TransactionHash)
	assert.Equal(t, blockHash.Hex(), claim.BlockHash)
	// The first transaction in a block still names its index
	assert.Equal(t, "0x0", claim.TransactionIndex)
}
