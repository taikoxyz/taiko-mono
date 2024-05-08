package signer

import (
	"testing"

	"github.com/btcsuite/btcd/btcec/v2"
	"github.com/decred/dcrd/dcrec/secp256k1/v4"
	"github.com/ethereum/go-ethereum/common/hexutil"
	"github.com/stretchr/testify/require"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/internal/testutils"
)

func TestSignWithK(t *testing.T) {
	var priv btcec.PrivateKey
	overflow := priv.Key.SetByteSlice(
		hexutil.MustDecode("0x92954368afd3caa1f3ce3ead0069c1af414054aefe1ef9aeacc1bf426222ce38"),
	)
	require.False(t, overflow || priv.Key.IsZero())

	signer := FixedKSigner{privKey: &priv.Key}

	// K = 2, test case 1
	payload := hexutil.MustDecode("0x44943399d1507f3ce7525e9be2f987c3db9136dc759cb7f92f742154196868b9")
	expected := testutils.SignatureFromRSV(
		"0xc6047f9441ed7d6d3045406e95c07cd85c778e4b8cef3ca7abac09b95c709ee5",
		"0x38940d69b21d5b088beb706e9ebabe6422307e12863997a44239774467e240d5",
		1,
	)

	signed, ok := signer.SignWithK(new(secp256k1.ModNScalar).SetInt(2))(payload)
	require.True(t, ok)
	require.Equal(t, expected, signed)

	// K = 2, test case 2
	payload = hexutil.MustDecode("0x663d210fa6dba171546498489de1ba024b89db49e21662f91bf83cdffe788820")
	expected = testutils.SignatureFromRSV(
		"0xc6047f9441ed7d6d3045406e95c07cd85c778e4b8cef3ca7abac09b95c709ee5",
		"0x5840695138a83611aa9dac67beb95aba7323429787a78df993f1c5c7f2c0ef7f",
		0,
	)

	signed, ok = signer.SignWithK(new(secp256k1.ModNScalar).SetInt(2))(payload)
	require.True(t, ok)
	require.Equal(t, expected, signed)
}
