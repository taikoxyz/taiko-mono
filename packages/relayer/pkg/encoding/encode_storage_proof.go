package encoding

import (
	"github.com/ethereum/go-ethereum/accounts/abi"
	"github.com/pkg/errors"
)

var bytesArrayT, _ = abi.NewType("bytes[]", "", nil)

func EncodeStorageProof(accountProof [][]byte, storageProof [][]byte) ([]byte, error) {
	args := abi.Arguments{
		{
			Type: bytesArrayT,
		},
		{
			Type: bytesArrayT,
		},
	}

	encodedStorageProof, err := args.Pack(accountProof, storageProof)
	if err != nil {
		return nil, errors.Wrap(err, "args.Pack")
	}

	return encodedStorageProof, nil
}
