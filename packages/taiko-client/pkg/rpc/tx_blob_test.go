package rpc

import (
	"context"
	"os"
	"testing"
	"time"

	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/crypto"
	"github.com/stretchr/testify/assert"

	"github.com/taikoxyz/taiko-client/internal/utils"
)

func TestBlockTx(t *testing.T) {
	t.SkipNow()
	// Load environment variables.
	utils.LoadEnv()

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	url := os.Getenv("L1_NODE_WS_ENDPOINT")
	l1Client, err := NewEthClient(ctx, url, time.Second*20)
	assert.NoError(t, err)

	priv := os.Getenv("L1_PROPOSER_PRIVATE_KEY")
	sk, err := crypto.ToECDSA(common.FromHex(priv))
	assert.NoError(t, err)

	opts, err := bind.NewKeyedTransactorWithChainID(sk, l1Client.ChainID)
	assert.NoError(t, err)
	opts.Context = ctx
	//opts.NoSend = true

	balance, err := l1Client.BalanceAt(ctx, opts.From, nil)
	assert.NoError(t, err)
	t.Logf("address: %s, balance: %s", opts.From.String(), balance.String())

	data, dErr := os.ReadFile("./tx_blob.go")
	assert.NoError(t, dErr)
	//data := []byte{'s'}
	sideCar, sErr := MakeSidecar(data)
	assert.NoError(t, sErr)

	tx, err := l1Client.TransactBlobTx(opts, nil, nil, sideCar)
	assert.NoError(t, err)

	receipt, err := bind.WaitMined(ctx, l1Client, tx)
	assert.NoError(t, err)
	assert.Equal(t, true, receipt.Status == types.ReceiptStatusSuccessful)

	t.Log("blob hash: ", tx.BlobHashes()[0].String())
	t.Log("block number: ", receipt.BlockNumber.Uint64())
	t.Log("tx hash: ", receipt.TxHash.String())
}

func TestMakeSideCar(t *testing.T) {
	origin, err := os.ReadFile("./tx_blob.go")
	assert.NoError(t, err)

	sideCar, mErr := MakeSidecar(origin)
	assert.NoError(t, mErr)

	origin1, dErr := DecodeBlobs(sideCar.Blobs)
	assert.NoError(t, dErr)
	assert.Equal(t, origin, origin1)
}
