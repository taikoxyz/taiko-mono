package encoding

import (
	"github.com/ethereum/go-ethereum/accounts/abi"
	"github.com/pkg/errors"
)

func EncodeSignalProof(signalProof SignalProof) ([]byte, error) {
	args := abi.Arguments{
		{
			Type: signalProofT,
		},
	}

	encodedSignalProof, err := args.Pack(signalProof)
	if err != nil {
		return nil, errors.Wrap(err, "args.Pack")
	}

	return encodedSignalProof, nil
}
