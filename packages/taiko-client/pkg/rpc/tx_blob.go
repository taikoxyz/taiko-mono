package rpc

import (
	"errors"

	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/common/hexutil"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/crypto/kzg4844"
	"github.com/holiman/uint256"
)

var (
	errBlobInvalid = errors.New("invalid blob encoding")
)

// TransactBlobTx creates, signs and then sends blob transactions.
func (c *EthClient) TransactBlobTx(
	opts *bind.TransactOpts,
	contract *common.Address,
	input []byte,
	sidecar *types.BlobTxSidecar,
) (*types.Transaction, error) {
	// Sign the transaction and schedule it for execution
	if opts.Signer == nil {
		return nil, errors.New("no signer to authorize the transaction with")
	}
	// Create blob tx
	rawTx, err := c.createBlobTx(opts, contract, input, sidecar)
	if err != nil {
		return nil, err
	}
	signedTx, err := opts.Signer(opts.From, rawTx)
	if err != nil {
		return nil, err
	}
	if opts.NoSend {
		return signedTx, nil
	}
	if err := c.SendTransaction(opts.Context, signedTx); err != nil {
		return nil, err
	}
	return signedTx, nil
}

// createBlobTx creates a blob transaction by given parameters.
func (c *EthClient) createBlobTx(
	opts *bind.TransactOpts,
	contract *common.Address,
	input []byte,
	sidecar *types.BlobTxSidecar,
) (*types.Transaction, error) {
	// Fetch the nonce for the account
	var (
		nonce *hexutil.Uint64
		gas   *hexutil.Uint64
	)
	if opts.Nonce != nil {
		curNonce := hexutil.Uint64(opts.Nonce.Uint64())
		nonce = &curNonce
	}

	if input == nil {
		input = []byte{}
	}

	if contract == nil {
		contract = &common.Address{}
	}

	if opts.GasLimit != 0 {
		gasVal := hexutil.Uint64(opts.GasLimit)
		gas = &gasVal
	}

	rawTx, err := c.FillTransaction(opts.Context, &TransactionArgs{
		From:                 &opts.From,
		To:                   contract,
		Gas:                  gas,
		GasPrice:             (*hexutil.Big)(opts.GasPrice),
		MaxFeePerGas:         (*hexutil.Big)(opts.GasFeeCap),
		MaxPriorityFeePerGas: (*hexutil.Big)(opts.GasTipCap),
		Value:                (*hexutil.Big)(opts.Value),
		Nonce:                nonce,
		Data:                 (*hexutil.Bytes)(&input),
		AccessList:           nil,
		ChainID:              nil,
		BlobFeeCap:           nil,
		BlobHashes:           sidecar.BlobHashes(),
	})
	if err != nil {
		return nil, err
	}

	blobTx := &types.BlobTx{
		ChainID:    uint256.MustFromBig(rawTx.ChainId()),
		Nonce:      rawTx.Nonce(),
		GasTipCap:  uint256.MustFromBig(rawTx.GasTipCap()),
		GasFeeCap:  uint256.MustFromBig(rawTx.GasFeeCap()),
		Gas:        rawTx.Gas(),
		To:         *rawTx.To(),
		Value:      uint256.MustFromBig(rawTx.Value()),
		Data:       rawTx.Data(),
		AccessList: rawTx.AccessList(),
		BlobFeeCap: uint256.MustFromBig(rawTx.BlobGasFeeCap()),
		BlobHashes: sidecar.BlobHashes(),
		Sidecar:    sidecar,
	}

	return types.NewTx(blobTx), nil
}

// MakeSidecar makes a sidecar which only includes one blob with the given data.
func MakeSidecar(data []byte) (*types.BlobTxSidecar, error) {
	sideCar := &types.BlobTxSidecar{Blobs: EncodeBlobs(data)}
	for _, blob := range sideCar.Blobs {
		commitment, err := kzg4844.BlobToCommitment(blob)
		if err != nil {
			return nil, err
		}
		proof, err := kzg4844.ComputeBlobProof(blob, commitment)
		if err != nil {
			return nil, err
		}
		sideCar.Commitments = append(sideCar.Commitments, commitment)
		sideCar.Proofs = append(sideCar.Proofs, proof)
	}
	return sideCar, nil
}

func encode(origin []byte) []byte {
	var res []byte
	for ; len(origin) >= 31; origin = origin[31:] {
		data := [32]byte{}
		copy(data[1:], origin[:31])
		res = append(res, data[:]...)
	}
	if len(origin) > 0 {
		data := make([]byte, len(origin)+1)
		copy(data[1:], origin)
		res = append(res, data...)
	}
	return res
}

// EncodeBlobs encodes bytes into a EIP-4844 blob.
func EncodeBlobs(origin []byte) []kzg4844.Blob {
	data := encode(origin)
	var blobs []kzg4844.Blob
	for ; len(data) >= BlobBytes; data = data[BlobBytes:] {
		blob := kzg4844.Blob{}
		copy(blob[:], data[:BlobBytes])
		blobs = append(blobs, blob)
	}
	if len(data) > 0 {
		blob := kzg4844.Blob{}
		copy(blob[:], data)
		blobs = append(blobs, blob)
	}
	return blobs
}

// DecodeBlob decodes the given blob data.
func DecodeBlob(blob []byte) ([]byte, error) {
	if len(blob) != BlobBytes {
		return nil, errBlobInvalid
	}
	var i = len(blob) - 1
	for ; i >= 0; i-- {
		if blob[i] != 0 {
			break
		}
	}
	blob = blob[:i+1]

	var res []byte
	for ; len(blob) >= 32; blob = blob[32:] {
		data := [31]byte{}
		copy(data[:], blob[1:])
		res = append(res, data[:]...)
	}
	if len(blob) > 0 {
		res = append(res, blob[1:]...)
	}
	return res, nil
}

// DecodeBlobs decodes the given blobs.
func DecodeBlobs(blobs []kzg4844.Blob) ([]byte, error) {
	var res []byte
	for _, blob := range blobs {
		data, err := DecodeBlob(blob[:])
		if err != nil {
			return nil, err
		}
		res = append(res, data...)
	}
	return res, nil
}
