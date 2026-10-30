package rpc

import (
	"context"
	"encoding/json"
	"fmt"
	"math/big"
	"testing"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/ethclient"
	gethrpc "github.com/ethereum/go-ethereum/rpc"
	"github.com/stretchr/testify/require"
)

func TestEthClientGlamsterdamHeaderHash(t *testing.T) {
	hash := common.HexToHash("0x0123456789abcdef")
	one := uint64(1)
	header := types.Header{
		Number: big.NewInt(1), Difficulty: big.NewInt(0),
		GasLimit: 60000000, Time: 1791500000, BaseFee: big.NewInt(1000000000),
		WithdrawalsHash: &hash, BlobGasUsed: &one, ExcessBlobGas: &one,
		ParentBeaconRoot: &hash, RequestsHash: &hash, SlotNumber: &one,
	}
	encoded, err := json.Marshal(header)
	require.NoError(t, err)
	var fields map[string]json.RawMessage
	require.NoError(t, json.Unmarshal(encoded, &fields))

	bal := common.HexToHash("0xaabbccddeeff00112233445566778899")
	// Independently computed from all 23 canonical RLP fields, including BAL and slot.
	want := common.HexToHash("0xa0b985526c11666e3da8990ac0c07ab5ad84cab8fdabddf37a5e295235ce3245")
	fields["blockAccessListHash"], err = json.Marshal(bal)
	require.NoError(t, err)
	fields["hash"], err = json.Marshal(want)
	require.NoError(t, err)
	encoded, err = json.Marshal(fields)
	require.NoError(t, err)

	server := gethrpc.NewServer()
	t.Cleanup(server.Stop)
	require.NoError(t, server.RegisterName("eth", &glamsterdamHeaderRPC{header: encoded, hash: want}))
	transport := gethrpc.DialInProc(server)
	t.Cleanup(transport.Close)
	client := &EthClient{
		Client: transport, ethClient: &ethClient{ethclient.NewClient(transport)},
		timeout: DefaultRpcTimeout,
	}

	// Anchor and reorg callers rely on Header.Hash() matching the L1 RPC block hash.
	t.Run("HeaderByNumber", func(t *testing.T) {
		got, err := client.HeaderByNumber(context.Background(), big.NewInt(1))
		require.NoError(t, err)
		require.NotNil(t, got)
		require.Equal(t, want, got.Hash())
	})
	t.Run("HeaderByHash", func(t *testing.T) {
		got, err := client.HeaderByHash(context.Background(), want)
		require.NoError(t, err)
		require.NotNil(t, got)
		require.Equal(t, want, got.Hash())
	})
	t.Run("BatchHeadersByNumbers", func(t *testing.T) {
		got, err := client.BatchHeadersByNumbers(context.Background(), []*big.Int{big.NewInt(1)})
		require.NoError(t, err)
		require.Len(t, got, 1)
		require.NotNil(t, got[0])
		require.Equal(t, want, got[0].Hash())
	})
}

type glamsterdamHeaderRPC struct {
	header json.RawMessage
	hash   common.Hash
}

func (s *glamsterdamHeaderRPC) GetBlockByNumber(number string, full bool) (json.RawMessage, error) {
	if number != "0x1" || full {
		return nil, fmt.Errorf("unexpected block request: number %s, full %t", number, full)
	}
	return s.header, nil
}

func (s *glamsterdamHeaderRPC) GetBlockByHash(hash common.Hash, full bool) (json.RawMessage, error) {
	if hash != s.hash || full {
		return nil, fmt.Errorf("unexpected block request: hash %s, full %t", hash, full)
	}
	return s.header, nil
}
