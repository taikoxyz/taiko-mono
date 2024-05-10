package rpc

import (
	"errors"
	"math/big"

	"github.com/ethereum-optimism/optimism/op-service/eth"
	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/common/hexutil"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/crypto/kzg4844"
	"github.com/ethereum/go-ethereum/params"
	"github.com/holiman/uint256"
)

var (
	ErrBlobInvalid = errors.New("invalid blob encoding")
)

// TransactBlobTx creates, signs and then sends blob transactions.
func (c *EthClient) TransactBlobTx(
	opts *bind.TransactOpts,
	contract common.Address,
	input []byte,
	sidecar *types.BlobTxSidecar,
) (*types.Transaction, error) {
	// Sign the transaction and schedule it for execution
	if opts.Signer == nil {
		return nil, errors.New("no signer to authorize the transaction with")
	}
	// Create blob tx
	blobTx, err := c.CreateBlobTx(opts, contract, input, sidecar)
	if err != nil {
		return nil, err
	}
	signedTx, err := opts.Signer(opts.From, types.NewTx(blobTx))
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

// CreateBlobTx creates a blob transaction by given parameters.
func (c *EthClient) CreateBlobTx(
	opts *bind.TransactOpts,
	contract common.Address,
	input []byte,
	sidecar *types.BlobTxSidecar,
) (*types.BlobTx, error) {
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

	if opts.GasLimit != 0 {
		gasVal := hexutil.Uint64(opts.GasLimit)
		gas = &gasVal
	}

	rawTx, err := c.FillTransaction(opts.Context, &TransactionArgs{
		From:                 &opts.From,
		To:                   &contract,
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

	blobFeeCap := rawTx.BlobGasFeeCap()
	if blobFeeCap == nil || blobFeeCap.Uint64() < params.BlobTxMinBlobGasprice {
		blobFeeCap = new(big.Int).SetUint64(uint64(params.BlobTxMinBlobGasprice))
	}

	return &types.BlobTx{
		ChainID:    uint256.MustFromBig(rawTx.ChainId()),
		Nonce:      rawTx.Nonce(),
		GasTipCap:  uint256.MustFromBig(rawTx.GasTipCap()),
		GasFeeCap:  uint256.MustFromBig(rawTx.GasFeeCap()),
		Gas:        rawTx.Gas(),
		To:         *rawTx.To(),
		Value:      uint256.MustFromBig(rawTx.Value()),
		Data:       rawTx.Data(),
		AccessList: rawTx.AccessList(),
		BlobFeeCap: uint256.MustFromBig(blobFeeCap),
		BlobHashes: sidecar.BlobHashes(),
		Sidecar:    sidecar,
	}, nil
}

// MakeSidecar makes a sidecar which only includes one blob with the given data.
func MakeSidecar(data []byte) (*types.BlobTxSidecar, error) {
	var blob eth.Blob
	if err := blob.FromData(data); err != nil {
		return nil, err
	}

	sideCar := &types.BlobTxSidecar{Blobs: []kzg4844.Blob{*blob.KZGBlob()}}
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
