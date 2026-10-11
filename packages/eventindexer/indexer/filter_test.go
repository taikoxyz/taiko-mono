package indexer

import (
	"context"
	"database/sql"
	"database/sql/driver"
	"errors"
	"fmt"
	"io"
	"math/big"
	"sync"
	"testing"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/common/hexutil"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/ethclient"
	"github.com/ethereum/go-ethereum/rpc"
	"github.com/stretchr/testify/require"
)

// lockTestDriver supplies only the session ownership probe. Real MySQL lock
// acquisition, pinned transactions and KILL are covered by TestIntegration_WriterLock.
type lockTestDriver struct{}
type lockTestConn struct{}
type lockTestRows struct{ done bool }

func (lockTestDriver) Open(string) (driver.Conn, error) { return lockTestConn{}, nil }
func (lockTestConn) Prepare(string) (driver.Stmt, error) {
	return nil, errors.New("unexpected prepare")
}
func (lockTestConn) Close() error              { return nil }
func (lockTestConn) Begin() (driver.Tx, error) { return nil, errors.New("unexpected transaction") }
func (lockTestConn) QueryContext(_ context.Context, q string, _ []driver.NamedValue) (driver.Rows, error) {
	if q != "SELECT IS_USED_LOCK(?) = CONNECTION_ID()" {
		return nil, errors.New("unexpected SQL")
	}

	return &lockTestRows{}, nil
}
func (*lockTestRows) Columns() []string { return []string{"owned"} }
func (*lockTestRows) Close() error      { return nil }
func (r *lockTestRows) Next(v []driver.Value) error {
	if r.done {
		return io.EOF
	}

	r.done = true
	v[0] = true

	return nil
}

var registerLockDriver sync.Once

func filterTestWriter(t *testing.T) *sql.Conn {
	t.Helper()
	registerLockDriver.Do(func() { sql.Register("nft_filter_lock", lockTestDriver{}) })

	pool, err := sql.Open("nft_filter_lock", "")
	require.NoError(t, err)
	conn, err := pool.Conn(context.Background())
	require.NoError(t, err)
	t.Cleanup(func() { require.NoError(t, conn.Close()); require.NoError(t, pool.Close()) })

	return conn
}

type nftFilterRPC struct {
	queries []map[string]interface{}
	logs    []types.Log
	failure error
}

func (f *nftFilterRPC) BlockNumber(context.Context) (hexutil.Uint64, error) { return 2, nil }
func (f *nftFilterRPC) GetLogs(_ context.Context, q map[string]interface{}) ([]types.Log, error) {
	f.queries = append(f.queries, q)
	return f.logs, f.failure
}

func TestFilterNFTOnlyRPCAndCursor(t *testing.T) {
	for _, mode := range []string{"success", "repository failure", "cancellation", "RPC failure"} {
		t.Run(mode, func(t *testing.T) {
			ctx, cancel := context.WithCancel(context.Background())
			defer cancel()

			first := nftIndexLog(t, "ERC721", ZeroAddress, common.HexToAddress("0x1"), 1, 0, 0)
			second := nftIndexLog(t, "TransferSingle", ZeroAddress, common.HexToAddress("0x1"), 2, 0, 0)
			fixture := &nftFilterRPC{logs: []types.Log{second, first}}
			// No raw block, transaction, bridge or Inbox methods exist on this RPC server.
			server := rpc.NewServer()
			require.NoError(t, server.RegisterName("eth", fixture))

			defer server.Stop()

			client := ethclient.NewClient(rpc.DialInProc(server))
			defer client.Close()

			spy := &nftTransferSpy{}
			failure := errors.New("fixture failed")

			switch mode {
			case "repository failure":
				spy.failure = failure
			case "cancellation":
				spy.cancel = cancel
			case "RPC failure":
				fixture.failure = failure
			}

			cursor := &initialNFTCursorRepository{}
			i := &Indexer{nftCursorRepo: cursor, ethClient: client, nftBalanceRepo: spy, srcChainID: 167, blockBatchSize: 10, writerConn: filterTestWriter(t)}
			err := i.filter(ctx)

			require.Len(t, fixture.queries, 1)
			q := fixture.queries[0]
			require.Equal(t, "0x1", q["fromBlock"])
			require.Equal(t, "0x2", q["toBlock"])
			require.Equal(t, []interface{}{[]interface{}{
				logTransferSigHash.Hex(), transferSingleSignatureHash.Hex(), transferBatchSignatureHash.Hex(),
			}}, q["topics"])
			require.NotContains(t, q, "address")

			if mode == "success" {
				require.NoError(t, err)
				require.EqualValues(t, 2, i.latestIndexedBlockNumber)
				require.Len(t, spy.calls, 2)
				require.Equal(t, nftTransferRef(big.NewInt(167), first, 0), spy.calls[0].ref)
				require.Equal(t, nftTransferRef(big.NewInt(167), second, 0), spy.calls[1].ref)
			} else {
				require.Error(t, err)
				require.Zero(t, i.latestIndexedBlockNumber)

				if mode == "cancellation" {
					require.ErrorIs(t, err, context.Canceled)
				}
			}
		})
	}
}

func TestFilterEmptyBatchDurableRestart(t *testing.T) {
	for _, fail := range []bool{false, true} {
		t.Run(fmt.Sprint(fail), func(t *testing.T) {
			server := rpc.NewServer()
			require.NoError(t, server.RegisterName("eth", &nftFilterRPC{logs: []types.Log{}}))

			defer server.Stop()

			client := ethclient.NewClient(rpc.DialInProc(server))
			defer client.Close()

			cursor := &initialNFTCursorRepository{}
			if fail {
				cursor.saveErr = errors.New("checkpoint failed")
			}

			i := &Indexer{ethClient: client, nftCursorRepo: cursor, nftBalanceRepo: &nftTransferSpy{},
				srcChainID: 167, blockBatchSize: 10, writerConn: filterTestWriter(t)}

			err := i.filter(context.Background())
			if fail {
				require.ErrorContains(t, err, "checkpoint failed")
				require.Zero(t, i.latestIndexedBlockNumber)

				return
			}

			require.NoError(t, err)
			require.Equal(t, []uint64{2}, cursor.saved)
			restart := &Indexer{nftCursorRepo: cursor, srcChainID: 167}
			require.NoError(t, restart.setInitialIndexingBlockByMode(context.Background(), Sync))
			require.EqualValues(t, 3, restart.nextFilterStartBlock())
		})
	}
}
