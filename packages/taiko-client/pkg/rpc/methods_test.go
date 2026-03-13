package rpc

import (
	"context"
	"crypto/rand"
	"math/big"
	"testing"

	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/crypto"
	"github.com/ethereum/go-ethereum/params"
	"github.com/stretchr/testify/require"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/encoding"
	pacayaBindings "github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/pacaya"
)

var (
	testAddress = common.HexToAddress("0x98f86166571FE624778203d87A8eD6fd84695B79")
)

func TestNewShastaBaseFeeChainConfig(t *testing.T) {
	chainID := new(big.Int).Set(params.TaikoMainnetNetworkID)
	forkTime := uint64(1234)

	defaultConfig := params.NetworkIDToChainConfigOrDefault(chainID)
	originalChainID := new(big.Int).Set(defaultConfig.ChainID)
	var originalShastaTime *uint64
	if defaultConfig.ShastaTime != nil {
		shastaTime := *defaultConfig.ShastaTime
		originalShastaTime = &shastaTime
	}

	config := newShastaBaseFeeChainConfig(chainID, forkTime)

	require.NotSame(t, defaultConfig, config)
	require.Zero(t, config.ChainID.Cmp(chainID))
	require.NotNil(t, config.ShastaTime)
	require.Equal(t, forkTime, *config.ShastaTime)
	require.Equal(t, defaultConfig.ElasticityMultiplier(), config.ElasticityMultiplier())
	require.Equal(t, defaultConfig.BaseFeeChangeDenominator(), config.BaseFeeChangeDenominator())
	require.Zero(t, defaultConfig.ChainID.Cmp(originalChainID))
	if originalShastaTime == nil {
		require.Nil(t, defaultConfig.ShastaTime)
	} else {
		require.NotNil(t, defaultConfig.ShastaTime)
		require.Equal(t, *originalShastaTime, *defaultConfig.ShastaTime)
	}
}

func TestL2AccountNonce(t *testing.T) {
	client := newTestClientWithTimeout(t)
	header, err := client.L2.HeaderByNumber(context.Background(), nil)
	require.Nil(t, err)

	nonce, err := client.L2AccountNonce(context.Background(), testAddress, header.Hash())

	require.Nil(t, err)
	require.Zero(t, nonce)
}

func TestGetGenesisL1Header(t *testing.T) {
	client := newTestClient(t)

	header, err := client.GetGenesisL1Header(context.Background())

	require.Nil(t, err)
	require.NotZero(t, header.Number.Uint64())
}

func TestLatestL2KnownL1Header(t *testing.T) {
	client := newTestClient(t)

	header, err := client.LatestL2KnownL1Header(context.Background())

	require.Nil(t, err)
	require.NotZero(t, header.Number.Uint64())
}

func TestL2ParentByBlockId(t *testing.T) {
	client := newTestClient(t)

	header, err := client.L2ParentByCurrentBlockID(context.Background(), common.Big1)
	require.Nil(t, err)
	require.Zero(t, header.Number.Uint64())

	_, err = client.L2ParentByCurrentBlockID(context.Background(), common.Big2)
	require.Nil(t, err)
}

func TestL2ExecutionEngineSyncProgress(t *testing.T) {
	client := newTestClient(t)

	progress, err := client.L2ExecutionEngineSyncProgress(context.Background())
	require.Nil(t, err)
	require.NotNil(t, progress)
}

func TestGetProtocolStateVariables(t *testing.T) {
	client := newTestClient(t)
	_, err := client.GetLastVerifiedTransitionPacaya(context.Background())
	require.Nil(t, err)
}

func TestWaitTillL2ExecutionEngineSyncedNewClient(t *testing.T) {
	client := newTestClient(t)
	err := client.WaitTillL2ExecutionEngineSynced(context.Background())
	require.Nil(t, err)
}

func TestGetSyncedL1SnippetFromAnchor(t *testing.T) {
	client := newTestClient(t)

	l1StateRoot := randomHash()
	l1Height := randomHash().Big().Uint64()
	parentGasUsed := uint32(randomHash().Big().Uint64())

	testAddrPrivKey, err := crypto.ToECDSA(common.Hex2Bytes(encoding.GoldenTouchPrivKey))
	require.Nil(t, err)

	opts, err := bind.NewKeyedTransactorWithChainID(testAddrPrivKey, client.L2.ChainID)
	require.Nil(t, err)

	opts.NoSend = true
	opts.GasLimit = 1_000_000

	tx, err := client.PacayaClients.TaikoAnchor.AnchorV3(
		opts,
		l1Height,
		l1StateRoot,
		parentGasUsed,
		pacayaBindings.LibSharedDataBaseFeeConfig{},
		[][32]byte{},
	)
	require.Nil(t, err)

	syncedL1StateRoot,
		syncedL1Height,
		syncedParentGasUsed,
		err := client.GetSyncedL1SnippetFromAnchor(tx)
	require.Nil(t, err)
	require.Equal(t, l1StateRoot, syncedL1StateRoot)
	require.Equal(t, l1Height, syncedL1Height)
	require.Equal(t, parentGasUsed, syncedParentGasUsed)
}

func TestWaitTillL2ExecutionEngineSyncedContextErr(t *testing.T) {
	client := newTestClient(t)
	ctx, cancel := context.WithCancel(context.Background())
	cancel()

	err := client.WaitTillL2ExecutionEngineSynced(ctx)
	require.ErrorContains(t, err, "context canceled")
}

// randomHash generates a random blob of data and returns it as a hash.
func randomHash() common.Hash {
	var hash common.Hash
	if n, err := rand.Read(hash[:]); n != common.HashLength || err != nil {
		panic(err)
	}
	return hash
}
