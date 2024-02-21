package encoding

import (
	"github.com/davecgh/go-spew/spew"
	"github.com/ethereum/go-ethereum/accounts/abi"
	"github.com/pkg/errors"
)

func EncodeHopProofs(hopProofs []HopProof) ([]byte, error) {
	spew.Dump(hopProofs)
	args := abi.Arguments{
		{
			Type: hopProofsT,
		},
	}

	encodedHopProofs, err := args.Pack(hopProofs)
	if err != nil {
		return nil, errors.Wrap(err, "args.Pack")
	}

	return encodedHopProofs, nil
}
