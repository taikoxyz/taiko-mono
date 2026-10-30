package http

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/morkid/paginate"
	"github.com/stretchr/testify/require"
	"github.com/taikoxyz/taiko-mono/packages/eventindexer"
	"github.com/taikoxyz/taiko-mono/packages/eventindexer/pkg/mock"
)

func TestRetiredRoutesReturn404(t *testing.T) {
	srv := newTestServer()

	for _, path := range []string{
		"/uniqueProvers", "/uniqueProposers", "/eventByAddress", "/events", "/erc20ByAddress",
		"/proposalProposedBy", "/proposalProvedBy", "/api/user-bridged", "/chart/chartByTask",
	} {
		t.Run(path, func(t *testing.T) {
			rec := httptest.NewRecorder()
			srv.ServeHTTP(rec, httptest.NewRequest(http.MethodGet, path, nil))
			require.Equal(t, http.StatusNotFound, rec.Code)
		})
	}
}

type queryNFTRepository struct {
	*mock.NFTBalanceRepository
	t   *testing.T
	err error
}

func (r *queryNFTRepository) FindByAddress(ctx context.Context, req *http.Request, address, chainID string) (paginate.Page, error) {
	require.Equal(r.t, "0x123", address)
	require.Equal(r.t, "167000", chainID)
	require.Equal(r.t, "2", req.URL.Query().Get("page"))
	require.Equal(r.t, "10", req.URL.Query().Get("size"))

	return paginate.Page{
		Items: []eventindexer.NFTBalance{{
			ID: 1, ChainID: 167000, Address: address, Amount: 3, TokenID: 42,
			ContractAddress: "0x456", ContractType: "ERC1155",
		}},
		Page: 2, Size: 10, Total: 21, TotalPages: 3, MaxPage: 2, Last: true, Visible: 1,
	}, r.err
}
func TestNFTQueryReturnsPaginatedJSON(t *testing.T) {
	srv := newTestServer()
	srv.nftBalanceRepo = &queryNFTRepository{NFTBalanceRepository: mock.NewNFTBalanceRepository(), t: t}
	rec := httptest.NewRecorder()
	srv.ServeHTTP(rec, httptest.NewRequest(http.MethodGet, "/nftsByAddress?address=0x123&chainID=167000&page=2&size=10", nil))
	require.Equal(t, http.StatusOK, rec.Code)

	var page map[string]interface{}

	require.NoError(t, json.Unmarshal(rec.Body.Bytes(), &page))
	require.Equal(t, float64(2), page["page"])
	require.Equal(t, float64(10), page["size"])
	require.Equal(t, float64(21), page["total"])
	items := page["items"].([]interface{})
	require.Equal(t, map[string]interface{}{
		"id": float64(1), "chainID": float64(167000), "address": "0x123", "amount": float64(3),
		"tokenID": float64(42), "contractAddress": "0x456", "contractType": "ERC1155",
	}, items[0])

	for _, key := range []string{"items", "page", "size", "total", "total_pages", "max_page", "first", "last", "visible"} {
		require.Contains(t, page, key)
	}
}

func TestNFTQueryRepositoryError(t *testing.T) {
	srv := newTestServer()
	srv.nftBalanceRepo = &queryNFTRepository{NFTBalanceRepository: mock.NewNFTBalanceRepository(), t: t, err: errors.New("database unavailable")}
	rec := httptest.NewRecorder()
	srv.ServeHTTP(rec, httptest.NewRequest(http.MethodGet, "/nftsByAddress?address=0x123&chainID=167000&page=2&size=10", nil))
	require.Equal(t, http.StatusUnprocessableEntity, rec.Code)
}
