package bindings

import (
	"github.com/ethereum/go-ethereum/common"
)

var (
	// Account address and private key of golden touch account, defined in protocol's LibAnchorSignature.
	// ref: https://github.com/taikoxyz/taiko-mono/blob/main/packages/protocol/contracts/libs/LibAnchorSignature.sol
	GoldenTouchAddress = common.HexToAddress("0x0000777735367b36bC9B61C50022d9D0700dB4Ec")
	GoldenTouchPrivKey = "0x92954368afd3caa1f3ce3ead0069c1af414054aefe1ef9aeacc1bf426222ce38"
)
