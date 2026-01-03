package anchortxconstructor

import (
	"context"
	"math/big"
	"os"
	"testing"
	"time"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/common/hexutil"
	consensus "github.com/ethereum/go-ethereum/consensus/taiko"
	"github.com/ethereum/go-ethereum/crypto"
	"github.com/stretchr/testify/require"

	pacayaBindings "github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/pacaya"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/rpc"
)

func TestGasLimit(t *testing.T) {
	require.Greater(t, consensus.AnchorGasLimit, uint64(0))
}

func TestAssembleAnchorV3Tx(t *testing.T) {
	client := newTestClient(t)
	l1Head, err := client.L1.HeaderByNumber(context.Background(), nil)
	require.Nil(t, err)

	c, err := New(client)
	require.Nil(t, err)
	head, err := client.L2.HeaderByNumber(context.Background(), nil)
	require.Nil(t, err)
	tx, err := c.AssembleAnchorV3Tx(
		context.Background(),
		l1Head.Number,
		l1Head.Hash(),
		head,
		&pacayaBindings.LibSharedDataBaseFeeConfig{},
		[][32]byte{},
		common.Big1,
		common.Big256,
	)
	require.Nil(t, err)
	require.NotNil(t, tx)
}

func TestAssembleAnchorV4Tx(t *testing.T) {
	client := newTestClient(t)
	l1Head, err := client.L1.HeaderByNumber(context.Background(), nil)
	require.Nil(t, err)

	c, err := New(client)
	require.Nil(t, err)
	head, err := client.L2.HeaderByNumber(context.Background(), nil)
	require.Nil(t, err)
	tx, err := c.AssembleAnchorV4Tx(
		context.Background(),
		head,
		head.Coinbase,
		l1Head.Number,
		l1Head.Hash(),
		l1Head.Root,
		common.Big0,
		new(big.Int).Add(head.Number, common.Big1),
		common.Big256,
	)
	require.Nil(t, err)
	require.NotNil(t, tx)
}

func TestNewAnchorTransactor(t *testing.T) {
	client := newTestClient(t)

	goldenTouchAddress, err := client.PacayaClients.TaikoAnchor.GOLDENTOUCHADDRESS(nil)
	require.Nil(t, err)

	c, err := New(client)
	require.Nil(t, err)

	head, err := client.L2.HeaderByNumber(context.Background(), nil)
	require.Nil(t, err)

	opts, err := c.transactOpts(context.Background(), common.Big1, common.Big256, head.Hash())
	require.Nil(t, err)
	require.True(t, opts.NoSend)
	require.Equal(t, goldenTouchAddress, opts.From)
	require.Equal(t, common.Big256, opts.GasFeeCap)
	require.Equal(t, common.Big0, opts.GasTipCap)
}

func TestCancelCtxTransactOpts(t *testing.T) {
	ctx, cancel := context.WithCancel(context.Background())
	cancel()

	client := newTestClient(t)

	head, err := client.L2.HeaderByNumber(context.Background(), nil)
	require.Nil(t, err)
	c, err := New(client)
	require.Nil(t, err)
	opts, err := c.transactOpts(ctx, common.Big1, common.Big256, head.Hash())
	require.Nil(t, opts)
	require.ErrorContains(t, err, "context canceled")
}

func TestSign(t *testing.T) {
	// Payload 1
	hash := hexutil.MustDecode("0x44943399d1507f3ce7525e9be2f987c3db9136dc759cb7f92f742154196868b9")
	signatureBytes := signatureFromRSV(
		"0x79be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798",
		"0x782a1e70872ecc1a9f740dd445664543f8b7598c94582720bca9a8c48d6a4766",
		1,
	)
	c, err := New(newTestClient(t))
	require.Nil(t, err)
	pubKey, err := crypto.Ecrecover(hash, signatureBytes)
	require.Nil(t, err)
	isValid := crypto.VerifySignature(pubKey, hash, signatureBytes[:64])
	require.True(t, isValid)
	signed, err := c.signTxPayload(hash)
	require.Nil(t, err)
	require.Equal(t, signatureBytes, signed)

	// Payload 2
	hash = hexutil.MustDecode("0x663d210fa6dba171546498489de1ba024b89db49e21662f91bf83cdffe788820")
	signatureBytes = signatureFromRSV(
		"0x79be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798",
		"0x568130fab1a3a9e63261d4278a7e130588beb51f27de7c20d0258d38a85a27ff",
		1,
	)
	pubKey, err = crypto.Ecrecover(hash, signatureBytes)
	require.Nil(t, err)
	isValid = crypto.VerifySignature(pubKey, hash, signatureBytes[:64])
	require.True(t, isValid)
	signed, err = c.signTxPayload(hash)
	require.Nil(t, err)
	require.Equal(t, signatureBytes, signed)
}

func TestSignShortHash(t *testing.T) {
	rand := crypto.Keccak256Hash([]byte(time.Now().UTC().String()))
	hash := rand[:len(rand)-2]
	c, err := New(newTestClient(t))
	require.Nil(t, err)
	_, err = c.signTxPayload(hash)
	require.ErrorContains(t, err, "hash is required to be exactly 32 bytes")
}

func newTestClient(t *testing.T) *rpc.Client {
	client, err := rpc.NewClient(context.Background(), &rpc.ClientConfig{
		L1Endpoint:                  os.Getenv("L1_WS"),
		L2Endpoint:                  os.Getenv("L2_WS"),
		PacayaInboxAddress:          common.HexToAddress(os.Getenv("PACAYA_INBOX")),
		ShastaInboxAddress:          common.HexToAddress(os.Getenv("SHASTA_INBOX")),
		TaikoWrapperAddress:         common.HexToAddress(os.Getenv("TAIKO_WRAPPER")),
		ForcedInclusionStoreAddress: common.HexToAddress(os.Getenv("FORCED_INCLUSION_STORE")),
		ProverSetAddress:            common.HexToAddress(os.Getenv("PROVER_SET")),
		TaikoAnchorAddress:          common.HexToAddress(os.Getenv("TAIKO_ANCHOR")),
		TaikoTokenAddress:           common.HexToAddress(os.Getenv("TAIKO_TOKEN")),
		L2EngineEndpoint:            os.Getenv("L2_AUTH"),
		JwtSecret:                   os.Getenv("JWT_SECRET"),
	})

	require.Nil(t, err)
	require.NotNil(t, client)

	return client
}

// signatureFromRSV creates the signature bytes from r,s,v.
func signatureFromRSV(r, s string, v byte) []byte {
	return append(append(hexutil.MustDecode(r), hexutil.MustDecode(s)...), v)
}
