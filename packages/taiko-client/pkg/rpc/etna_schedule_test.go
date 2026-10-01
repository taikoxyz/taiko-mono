package rpc

import (
	"context"
	"encoding/json"
	"math"
	"math/big"
	"testing"
	"time"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/params"
	"github.com/stretchr/testify/require"
)

// scheduleHeader returns an L2 header with the given number, timestamp and parentBeaconBlockRoot.
func scheduleHeader(number, timestamp uint64, root *common.Hash) *types.Header {
	return &types.Header{
		Number:           new(big.Int).SetUint64(number),
		Time:             timestamp,
		Difficulty:       common.Big0,
		ParentBeaconRoot: root,
	}
}

func TestCheckEtnaSchedule_GenesisPasses(t *testing.T) {
	// With Etna from genesis, the genesis block still commits no L1 anchor block hash.
	pinDevnetForkTimes(t, 0, 0)

	zero := common.Hash{}
	require.NoError(t, CheckEtnaSchedule(params.TaikoInternalNetworkID, scheduleHeader(0, 0, nil)))
	require.NoError(t, CheckEtnaSchedule(params.TaikoInternalNetworkID, scheduleHeader(0, 0, &zero)))
}

func TestCheckEtnaSchedule_PreUnzenNilRoot(t *testing.T) {
	pinDevnetForkTimes(t, 100, 200)

	require.NoError(t, CheckEtnaSchedule(params.TaikoInternalNetworkID, scheduleHeader(5, 99, nil)))
}

func TestCheckEtnaSchedule_UnzenZeroRoot(t *testing.T) {
	pinDevnetForkTimes(t, 100, 200)

	zero := common.Hash{}
	require.NoError(t, CheckEtnaSchedule(params.TaikoInternalNetworkID, scheduleHeader(5, 199, &zero)))
}

func TestCheckEtnaSchedule_EtnaAnchorRoot(t *testing.T) {
	pinDevnetForkTimes(t, 100, 200)

	root := common.HexToHash("0xaa")
	require.NoError(t, CheckEtnaSchedule(params.TaikoInternalNetworkID, scheduleHeader(5, 200, &root)))
}

func TestCheckEtnaSchedule_PublicNetworksStayPreEtna(t *testing.T) {
	zero := common.Hash{}
	for _, chainID := range []*big.Int{params.TaikoMainnetNetworkID, params.TaikoHoodiNetworkID} {
		require.NoError(t, CheckEtnaSchedule(chainID, scheduleHeader(5, math.MaxUint64-1, nil)))
		require.NoError(t, CheckEtnaSchedule(chainID, scheduleHeader(5, math.MaxUint64-1, &zero)))
	}
}

func TestCheckEtnaSchedule_ScheduleExpectsEtna(t *testing.T) {
	// The client activates Etna at 200, while the execution engine built a pre-Etna block after it.
	pinDevnetForkTimes(t, 100, 200)

	zero := common.Hash{}
	for _, root := range []*common.Hash{nil, &zero} {
		err := CheckEtnaSchedule(params.TaikoInternalNetworkID, scheduleHeader(5, 250, root))
		require.ErrorContains(t, err, "L2 head block 5 (timestamp 250, parentBeaconBlockRoot ")
		require.ErrorContains(t, err, "is a pre-Etna block, but the client's fork schedule expects Etna")
		require.ErrorContains(t, err, "set --taiko.devnet-etna-time to the execution engine's Etna time")
	}
}

func TestCheckEtnaSchedule_ScheduleExpectsPreEtna(t *testing.T) {
	// The execution engine built an Etna block, while the client never activates Etna.
	pinDevnetForkTimes(t, 100, math.MaxUint64)

	root := common.HexToHash("0xaa")
	err := CheckEtnaSchedule(params.TaikoInternalNetworkID, scheduleHeader(5, 250, &root))
	require.ErrorContains(t, err, "L2 head block 5 (timestamp 250, parentBeaconBlockRoot "+root.Hex()+")")
	require.ErrorContains(t, err, "is an Etna block, but the client's fork schedule expects Unzen")
	require.ErrorContains(t, err, "set --taiko.devnet-etna-time to the execution engine's Etna time")
}

func TestCheckEtnaSchedule_NilHeader(t *testing.T) {
	require.Error(t, CheckEtnaSchedule(params.TaikoInternalNetworkID, nil))
}

func TestClientCheckEtnaSchedule_ChecksLatestL2Head(t *testing.T) {
	pinDevnetForkTimes(t, 0, 100)

	zero := common.Hash{}
	head, err := json.Marshal(scheduleHeader(5, 150, &zero))
	require.NoError(t, err)
	url, calls := newFakeRPCServer(t, map[string]string{
		"eth_chainId":          `"0x28c59"`, // 167001, the internal devnet
		"eth_getBlockByNumber": string(head),
	})
	l2, err := NewEthClient(context.Background(), url, time.Second)
	require.NoError(t, err)

	err = (&Client{L2: l2}).CheckEtnaSchedule(context.Background())
	require.ErrorContains(t, err, "L2 head block 5 (timestamp 150, parentBeaconBlockRoot "+zero.Hex()+")")

	recorded := calls()
	require.Len(t, recorded, 2)
	require.Equal(t, "eth_getBlockByNumber", recorded[1].Method)
	require.JSONEq(t, `"latest"`, string(recorded[1].Params[0]))
}
