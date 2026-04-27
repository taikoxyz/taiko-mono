//go:build live
// +build live

package proposer

import (
	"context"
	"math/big"
	"os"
	"testing"

	"github.com/ethereum-optimism/optimism/op-service/txmgr"
	txmetrics "github.com/ethereum-optimism/optimism/op-service/txmgr/metrics"
	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/crypto"
	"github.com/ethereum/go-ethereum/ethclient"
	"github.com/ethereum/go-ethereum/log"
	"github.com/ethereum/go-ethereum/params"
	"github.com/stretchr/testify/require"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/manifest"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/shasta"
	builder "github.com/taikoxyz/taiko-mono/packages/taiko-client/proposer/transaction_builder"
)

const (
	defaultL1Endpoint  = "https://l1rpc.hoodi.taiko.xyz/"
	defaultL2Endpoint  = "https://rpc.masaya.taiko.xyz/"
	defaultInboxAddr   = "0x3477f9e8A890C2286C5E62150ad6593EeF4590b9"
	defaultChainID     = 167011
	liveTestEnvEnabled = "RUN_LIVE_TEST"
)

func TestSaveForcedInclusionLive(t *testing.T) {
	if os.Getenv(liveTestEnvEnabled) != "1" {
		t.Skip("set RUN_LIVE_TEST=1 to execute this live test")
	}

	require := require.New(t)

	l1Endpoint := envOrDefault("L1_ENDPOINT", defaultL1Endpoint)
	l2Endpoint := envOrDefault("L2_ENDPOINT", defaultL2Endpoint)
	inboxAddress := common.HexToAddress(envOrDefault("INBOX_ADDRESS", defaultInboxAddr))
	privateKeyHex := os.Getenv("SENDER_PRIVATE_KEY")
	if privateKeyHex == "" {
		t.Fatalf("missing SENDER_PRIVATE_KEY (sender private key hex)")
	}

	privateKey, err := crypto.ToECDSA(common.FromHex(privateKeyHex))
	require.NoError(err)

	ctx := context.Background()

	l1Client, err := ethclient.DialContext(ctx, l1Endpoint)
	require.NoError(err)
	l2Client, err := ethclient.DialContext(ctx, l2Endpoint)
	require.NoError(err)

	if err := ctx.Err(); err != nil {
		t.Fatalf("context canceled before nonce fetch: %v", err)
	}

	fromAddr := crypto.PubkeyToAddress(privateKey.PublicKey)

	nonce, err := selectNonce(
		ctx,
		fromAddr,
		l2Client.PendingNonceAt,
		func(ctx context.Context, addr common.Address) (uint64, error) {
			return l2Client.NonceAt(ctx, addr, nil)
		},
	)
	require.NoError(err)

	chainID := big.NewInt(defaultChainID)
	to := common.HexToAddress("0x4200000000000000000000000000000000000006")
	unsigned := types.NewTx(&types.DynamicFeeTx{
		ChainID:   chainID,
		Nonce:     nonce,
		GasTipCap: big.NewInt(params.GWei),
		GasFeeCap: new(big.Int).Mul(big.NewInt(2), big.NewInt(params.GWei)),
		Gas:       210000,
		To:        &to,
		Value:     big.NewInt(0),
		Data:      []byte{0xaa, 0xbb, 0xcc},
	})
	signed, err := types.SignTx(unsigned, types.LatestSignerForChainID(chainID), privateKey)
	require.NoError(err)
	err = l2Client.SendTransaction(context.Background(), signed)
	require.NoError(err)

	derivationSourceManifest := &manifest.DerivationSourceManifest{}
	derivationSourceManifest.Blocks = append(derivationSourceManifest.Blocks, &manifest.BlockManifest{
		Timestamp:         123,
		Coinbase:          inboxAddress,
		AnchorBlockNumber: 456,
		GasLimit:          210000,
		Transactions:      types.Transactions{signed},
	})
	sourceManifestBytes, err := builder.EncodeSourceManifest(derivationSourceManifest)
	require.NoError(err)
	blobs, err := builder.SplitToBlobs(sourceManifestBytes)
	require.NoError(err)
	require.NotEmpty(blobs)

	blobRef := shasta.LibBlobsBlobReference{
		BlobStartIndex: 0,
		NumBlobs:       uint16(len(blobs)),
		Offset:         big.NewInt(0),
	}

	abi, err := shasta.ShastaInboxClientMetaData.GetAbi()
	require.NoError(err)
	txData, err := abi.Pack("saveForcedInclusion", blobRef)
	require.NoError(err)

	inbox, err := shasta.NewShastaInboxClient(inboxAddress, l1Client)
	require.NoError(err)

	feeInGwei, err := inbox.GetCurrentForcedInclusionFee(&bind.CallOpts{Context: ctx})
	require.NoError(err)
	require.NotZero(feeInGwei)

	callValue := new(big.Int).Mul(new(big.Int).SetUint64(feeInGwei), big.NewInt(params.GWei))

	cfg := txmgr.CLIConfig{
		L1RPCURL:                  l1Endpoint,
		PrivateKey:                common.Bytes2Hex(crypto.FromECDSA(privateKey)),
		NumConfirmations:          1,
		SafeAbortNonceTooLowCount: txmgr.DefaultBatcherFlagValues.SafeAbortNonceTooLowCount,
		FeeLimitMultiplier:        txmgr.DefaultBatcherFlagValues.FeeLimitMultiplier,
		FeeLimitThresholdGwei:     txmgr.DefaultBatcherFlagValues.FeeLimitThresholdGwei,
		MinBaseFeeGwei:            txmgr.DefaultBatcherFlagValues.MinBaseFeeGwei,
		MinTipCapGwei:             txmgr.DefaultBatcherFlagValues.MinTipCapGwei,
		ResubmissionTimeout:       txmgr.DefaultBatcherFlagValues.ResubmissionTimeout,
		ReceiptQueryInterval:      txmgr.DefaultBatcherFlagValues.ReceiptQueryInterval,
		NetworkTimeout:            txmgr.DefaultBatcherFlagValues.NetworkTimeout,
		TxSendTimeout:             txmgr.DefaultBatcherFlagValues.TxSendTimeout,
		TxNotInMempoolTimeout:     txmgr.DefaultBatcherFlagValues.TxNotInMempoolTimeout,
	}

	txMgr, err := txmgr.NewSimpleTxManager("forced_inclusion_live_test", log.Root(), &txmetrics.NoopTxMetrics{}, cfg)
	require.NoError(err)
	defer txMgr.Close()

	receipt, err := txMgr.Send(ctx, txmgr.TxCandidate{
		To:     &inboxAddress,
		TxData: txData,
		Blobs:  blobs,
		Value:  callValue,
	})
	require.NoError(err)
	require.NotNil(receipt)
	require.Equal(uint64(types.ReceiptStatusSuccessful), receipt.Status)
}

func envOrDefault(key, fallback string) string {
	if val := os.Getenv(key); val != "" {
		return val
	}
	return fallback
}
