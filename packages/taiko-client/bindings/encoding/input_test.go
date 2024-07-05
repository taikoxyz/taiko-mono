package encoding

import (
	"context"
	"os"
	"testing"

	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/common/hexutil"
	"github.com/ethereum/go-ethereum/crypto"
	"github.com/ethereum/go-ethereum/ethclient"
	"github.com/stretchr/testify/require"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings"
)

func TestUnpackTxListBytes(t *testing.T) {
	_, err := UnpackTxListBytes(randomBytes(1024))
	require.NotNil(t, err)

	_, err = UnpackTxListBytes(
		hexutil.MustDecode(
			"0xa0ca2d080000000000000000000000000000000000000000000000000000000000000" +
				"aa8e2b9725cce28787e99447c383d95a9ba83125fe31a9ffa9cbb2c504da86926ab",
		),
	)
	require.ErrorContains(t, err, "no method with id")

	cli, err := ethclient.Dial(os.Getenv("L1_NODE_WS_ENDPOINT"))
	require.Nil(t, err)

	chainID, err := cli.ChainID(context.Background())
	require.Nil(t, err)

	taikoL1, err := bindings.NewTaikoL1Client(
		common.HexToAddress(os.Getenv("TAIKO_L1_ADDRESS")),
		cli,
	)
	require.Nil(t, err)

	l1ProposerPrivKey, err := crypto.ToECDSA(common.FromHex(os.Getenv("L1_PROPOSER_PRIVATE_KEY")))
	require.Nil(t, err)

	opts, err := bind.NewKeyedTransactorWithChainID(l1ProposerPrivKey, chainID)
	require.Nil(t, err)

	opts.NoSend = true
	opts.GasLimit = randomHash().Big().Uint64()

	txListBytes := randomBytes(1024)

	tx, err := taikoL1.ProposeBlock(
		opts,
		randomBytes(1024),
		txListBytes,
	)
	require.Nil(t, err)

	b, err := UnpackTxListBytes(tx.Data())
	require.Nil(t, err)
	require.Equal(t, txListBytes, b)
}
