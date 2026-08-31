package http

import (
	"context"
	"encoding/json"
	"errors"
	"math/big"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/ethereum/go-ethereum/core/types"
	echo "github.com/labstack/echo/v4"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/taikoxyz/taiko-mono/packages/relayer"
	"github.com/taikoxyz/taiko-mono/packages/relayer/pkg/mock"
)

// newFeeTestServer builds a server wired to mock chains, which the fee and block-info handlers
// both read through.
func newFeeTestServer() *Server {
	return &Server{
		echo:                    echo.New(),
		eventRepo:               mock.NewEventRepository(),
		srcEthClient:            &mock.EthClient{},
		destEthClient:           &mock.EthClient{},
		srcChainID:              mock.MockChainID,
		destChainID:             mock.MockChainID,
		processingFeeMultiplier: 1,
	}
}

// newRequestContext returns an echo context over a GET with the given raw query.
func newRequestContext(srv *Server, rawQuery string) (echo.Context, *httptest.ResponseRecorder) {
	req := httptest.NewRequest(http.MethodGet, "/?"+rawQuery, nil)
	rec := httptest.NewRecorder()

	return srv.echo.NewContext(req, rec), rec
}

// baseFeeErrClient fails the block lookup the base fee is derived from.
type baseFeeErrClient struct {
	mock.EthClient
}

func (c *baseFeeErrClient) BlockByNumber(_ context.Context, _ *big.Int) (*types.Block, error) {
	return nil, errors.New("dial tcp: connect: connection refused")
}

// noBaseFeeClient returns a pre-1559 block, which has no base fee to quote a fee from.
type noBaseFeeClient struct {
	mock.EthClient
}

func (c *noBaseFeeClient) BlockByNumber(_ context.Context, _ *big.Int) (*types.Block, error) {
	return types.NewBlockWithHeader(&types.Header{Number: big.NewInt(1)}), nil
}

func Test_GetRecommendedProcessingFees(t *testing.T) {
	srv := newFeeTestServer()
	c, rec := newRequestContext(srv, "")

	require.NoError(t, srv.GetRecommendedProcessingFees(c))
	require.Equal(t, http.StatusOK, rec.Code)

	var resp getRecommendedProcessingFeesResponse

	require.NoError(t, json.Unmarshal(rec.Body.Bytes(), &resp))

	// Every fee type is quoted once per direction, so the bridge UI can price a claim either way.
	assert.Len(t, resp.Fees, 2*len(feeTypes))

	for _, f := range resp.Fees {
		assert.NotEmpty(t, f.Type, "a fee published under an empty type is unusable")
		assert.NotEmpty(t, f.Amount)
		assert.NotEqual(t, "0", f.Amount, "quoting zero would have the relayer process for free")
		assert.Equal(t, mock.MockChainID.Uint64(), f.DestChainID)
	}
}

func Test_GetRecommendedProcessingFeesSurfacesChainErrors(t *testing.T) {
	srv := newFeeTestServer()
	srv.destEthClient = &baseFeeErrClient{}

	c, rec := newRequestContext(srv, "")

	// A fee quoted from an unreadable chain would be wrong rather than missing, so the handler
	// has to fail instead of guessing.
	assert.ErrorContains(t, srv.GetRecommendedProcessingFees(c), "connection refused")
	assert.Equal(t, http.StatusUnprocessableEntity, rec.Code)
}

func Test_getDestChainBaseFee(t *testing.T) {
	srv := newFeeTestServer()

	t.Run("layer 2 uses the block's own base fee", func(t *testing.T) {
		baseFee, err := srv.getDestChainBaseFee(context.Background(), Layer2, mock.MockChainID)

		require.NoError(t, err)
		assert.Equal(t, big.NewInt(1), baseFee)
	})

	t.Run("layer 1 computes the next base fee", func(t *testing.T) {
		// L1's next base fee is derived from the latest header rather than read off it, since the
		// claim will land in the block after this one.
		baseFee, err := srv.getDestChainBaseFee(context.Background(), Layer1, mock.MockChainID)

		require.NoError(t, err)
		assert.NotNil(t, baseFee)
		assert.Positive(t, baseFee.Sign())
	})

	t.Run("a block with no base fee is an error, not a zero fee", func(t *testing.T) {
		noBaseFee := newFeeTestServer()
		noBaseFee.destEthClient = &noBaseFeeClient{}

		_, err := noBaseFee.getDestChainBaseFee(context.Background(), Layer2, mock.MockChainID)

		assert.ErrorIs(t, err, relayer.ErrMissingDestBaseFee)
	})

	t.Run("the block lookup failing surfaces", func(t *testing.T) {
		failing := newFeeTestServer()
		failing.srcEthClient = &baseFeeErrClient{}

		_, err := failing.getDestChainBaseFee(context.Background(), Layer1, mock.MockChainID)

		assert.ErrorContains(t, err, "connection refused")
	})
}

func Test_GetBlockInfo(t *testing.T) {
	// These handlers render the error response and also return the error, so both are asserted:
	// the status is what the caller sees, the returned error is what echo logs.
	t.Run("chain IDs default to the connected chains", func(t *testing.T) {
		srv := newFeeTestServer()
		c, rec := newRequestContext(srv, "")

		require.NoError(t, srv.GetBlockInfo(c))
		assert.Equal(t, http.StatusOK, rec.Code)
		assert.NotEmpty(t, rec.Body.Bytes())
	})

	t.Run("explicit chain IDs are parsed and used", func(t *testing.T) {
		srv := newFeeTestServer()
		// Both directions are looked up in the indexer, so both have to be a chain it knows.
		query := "srcChainID=" + mock.MockChainID.String() + "&destChainID=" + mock.MockChainID.String()
		c, rec := newRequestContext(srv, query)

		require.NoError(t, srv.GetBlockInfo(c))
		require.Equal(t, http.StatusOK, rec.Code)

		var resp getBlockInfoResponse

		require.NoError(t, json.Unmarshal(rec.Body.Bytes(), &resp))
		require.Len(t, resp.Data, 2)

		for _, info := range resp.Data {
			assert.Equal(t, mock.MockChainID.Int64(), info.ChainID,
				"the response has to be about the chain that was asked for")
		}
	})

	t.Run("a src chain the indexer has nothing for surfaces", func(t *testing.T) {
		srv := newFeeTestServer()
		c, _ := newRequestContext(srv, "srcChainID=1")

		// The response is about a specific chain pair, so answering with another chain's numbers
		// would be worse than failing.
		assert.Error(t, srv.GetBlockInfo(c))
	})

	t.Run("a non-numeric src chain ID is rejected", func(t *testing.T) {
		srv := newFeeTestServer()
		c, rec := newRequestContext(srv, "srcChainID=not-a-number")

		// Falling back to the connected chain here would answer for a chain the caller did not
		// ask about.
		assert.ErrorContains(t, srv.GetBlockInfo(c), "invalid src chain param")
		assert.Equal(t, http.StatusUnprocessableEntity, rec.Code)
	})

	t.Run("a non-numeric dest chain ID is rejected", func(t *testing.T) {
		srv := newFeeTestServer()
		c, rec := newRequestContext(srv, "destChainID=nope")

		assert.ErrorContains(t, srv.GetBlockInfo(c), "invalid dest chain param")
		assert.Equal(t, http.StatusUnprocessableEntity, rec.Code)
	})
}
