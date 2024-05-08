package rpc

import (
	"context"
	"math/big"
	"os"
	"strconv"
	"testing"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/crypto"
	"github.com/ethereum/go-ethereum/params"
	"github.com/stretchr/testify/require"
)

func TestSetHead(t *testing.T) {
	require.Nil(t, SetHead(context.Background(), newTestClient(t).L2, common.Big0))
}

func TestStringToBytes32(t *testing.T) {
	require.Equal(t, [32]byte{}, StringToBytes32(""))
	require.Equal(t, [32]byte{0x61, 0x62, 0x63}, StringToBytes32("abc"))
}

func TestL1ContentFrom(t *testing.T) {
	client := newTestClient(t)
	l2Head, err := client.L2.HeaderByNumber(context.Background(), nil)
	require.Nil(t, err)

	baseFeeInfo, err := client.TaikoL2.GetBasefee(nil, 0, uint32(l2Head.GasUsed))
	require.Nil(t, err)

	testAddrPrivKey, err := crypto.ToECDSA(common.FromHex(os.Getenv("L1_PROPOSER_PRIVATE_KEY")))
	require.Nil(t, err)

	testAddr := crypto.PubkeyToAddress(testAddrPrivKey.PublicKey)

	nonce, err := client.L2.PendingNonceAt(context.Background(), testAddr)
	require.Nil(t, err)

	tx := types.NewTransaction(
		nonce,
		testAddr,
		common.Big1,
		100000,
		new(big.Int).SetUint64(uint64(10*params.GWei)+baseFeeInfo.Basefee.Uint64()),
		[]byte{},
	)
	signedTx, err := types.SignTx(tx, types.LatestSignerForChainID(client.L2.ChainID), testAddrPrivKey)
	require.Nil(t, err)
	require.Nil(t, client.L2.SendTransaction(context.Background(), signedTx))

	content, err := ContentFrom(context.Background(), client.L2, testAddr)
	require.Nil(t, err)

	require.NotZero(t, len(content["pending"]))
	require.Equal(t, signedTx.Nonce(), content["pending"][strconv.Itoa(int(signedTx.Nonce()))].Nonce())
}
