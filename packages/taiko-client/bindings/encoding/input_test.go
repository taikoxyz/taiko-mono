package encoding

import (
	"context"
	"math/big"
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

func TestEncodeProverAssignmentPayload(t *testing.T) {
	encoded, err := EncodeProverAssignmentPayload(
		randomHash().Big().Uint64(),
		common.BytesToAddress(randomBytes(20)),
		common.BytesToAddress(randomBytes(20)),
		common.BytesToAddress(randomBytes(20)),
		common.BytesToAddress(randomBytes(20)),
		common.BytesToHash(randomBytes(32)),
		common.BytesToAddress(randomBytes(20)),
		120,
		1024,
		0,
		[]TierFee{{Tier: 0, Fee: common.Big1}},
	)

	require.Nil(t, err)
	require.NotNil(t, encoded)
}

func TestEncodeAssignmentHookInput(t *testing.T) {
	encoded, err := EncodeAssignmentHookInput(&AssignmentHookInput{
		Assignment: &ProverAssignment{
			FeeToken:      common.Address{},
			Expiry:        1,
			MaxBlockId:    1,
			MaxProposedIn: 1,
			MetaHash:      [32]byte{0xff},
			TierFees:      []TierFee{{Tier: 0, Fee: common.Big1}},
			Signature:     []byte{0xff},
		},
		Tip: big.NewInt(1),
	})

	require.Nil(t, err)
	require.NotNil(t, encoded)
}

func TestUnpackTxListBytes(t *testing.T) {
	_, err := UnpackTxListBytes(randomBytes(1024), 0)
	require.NotNil(t, err)

	_, err = UnpackTxListBytes(
		hexutil.MustDecode(
			"0xa0ca2d080000000000000000000000000000000000000000000000000000000000000"+
				"aa8e2b9725cce28787e99447c383d95a9ba83125fe31a9ffa9cbb2c504da86926ab",
		),
		0,
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
		[][]byte{randomBytes(1024)},
		[][]byte{txListBytes},
	)
	require.Nil(t, err)

	b, err := UnpackTxListBytes(tx.Data(), 0)
	require.Nil(t, err)
	require.Equal(t, txListBytes, b)
}
