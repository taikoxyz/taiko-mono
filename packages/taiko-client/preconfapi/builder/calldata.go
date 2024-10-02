package builder

import (
	"context"
	"errors"
	"math/big"
	"strings"
	"time"

	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/encoding"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/internal/utils"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/rpc"
)

// CalldataTransactionBuilder is responsible for building a TaikoL1.proposeBlock transaction with txList
// bytes saved in blob.
type CalldataTransactionBuilder struct {
	preconfTaskManagerAddress common.Address
	ethClient                 *rpc.EthClient
	gasLimit                  uint64
}

// NewCalldataTransactionBuilder creates a new CalldataTransactionBuilder instance based on giving configurations.
func NewCalldataTransactionBuilder(
	preconfTaskManagerAddress common.Address,
	ethClient *rpc.EthClient,
	gasLimit uint64,
) *CalldataTransactionBuilder {
	return &CalldataTransactionBuilder{
		preconfTaskManagerAddress,
		ethClient,
		gasLimit,
	}
}

// BuildBlockUnsigned implements the ProposeBlockTransactionBuilder interface to
// return an unsigned transaction, intended for preconfirmations.
func (b *CalldataTransactionBuilder) BuildBlockUnsigned(
	_ context.Context,
	opts BuildBlockUnsignedOpts,
) (*types.Transaction, error) {
	txListBytes, err := signedTransactionsToTxListBytes(opts.SignedTransactions)
	if err != nil {
		return nil, err
	}

	compressedTxListBytes, err := utils.Compress(txListBytes)
	if err != nil {
		return nil, err
	}

	// ABI encode the TaikoL1.proposeBlock parameters.
	encodedParams, err := encoding.EncodeBlockParamsOntake(&encoding.BlockParamsV2{
		Coinbase:      common.HexToAddress(opts.Coinbase),
		AnchorBlockId: uint64(opts.L1StateBlockNumber),
		Timestamp:     opts.Timestamp,
	})
	if err != nil {
		return nil, err
	}

	lookaheadPointer, err := b.getLookaheadBuffer(common.HexToAddress(opts.Coinbase))
	if err != nil {
		return nil, err
	}

	lookaheadSetParams := make([]bindings.IPreconfTaskManagerLookaheadSetParam, 0)
	// can be null/0, we are force pushing lookaheads with netherminds
	// software for now.
	lookaheadSetParam := bindings.IPreconfTaskManagerLookaheadSetParam{
		Timestamp: big.NewInt(0),
		Preconfer: common.HexToAddress(opts.Coinbase),
	}

	lookaheadSetParams = append(lookaheadSetParams, lookaheadSetParam)

	data, err := encoding.PreconfTaskManagerABI.Pack(
		"newBlockProposal",
		encodedParams,
		compressedTxListBytes,
		lookaheadPointer,
		lookaheadSetParams,
	)
	if err != nil {
		return nil, err
	}

	// Create the transaction
	tx := types.NewTransaction(
		0,
		b.preconfTaskManagerAddress,
		nil,
		b.gasLimit,
		big.NewInt(0),
		data,
	)

	return tx, nil
}

func (b *CalldataTransactionBuilder) getLookaheadBuffer(preconferAddress common.Address) (uint64, error) {
	// Create an instance of the contract
	contract, err := bindings.NewPreconfTaskManager(b.preconfTaskManagerAddress, b.ethClient)
	if err != nil {
		return 0, err
	}

	// Get the lookahead buffer
	buffer, err := contract.GetLookaheadBuffer(&bind.CallOpts{
		Context: context.Background(),
	})
	if err != nil {
		return 0, err
	}

	// Get the current timestamp
	currentTimestamp := uint64(time.Now().Unix())

	// Iterate through the buffer to find the correct entry
	lookaheadPointer := ^uint64(0) // Default to max uint64 value to signify not found
	for i, entry := range buffer {
		if strings.EqualFold(entry.Preconfer.Hex(), preconferAddress.Hex()) &&
			currentTimestamp > entry.PrevTimestamp.Uint64() &&
			currentTimestamp <= entry.Timestamp.Uint64() {
			lookaheadPointer = uint64(i)
			break
		}
	}

	if lookaheadPointer == ^uint64(0) {
		return 0, errors.New("lookahead pointer not found")
	}

	return lookaheadPointer, nil
}

// BuildBlockUnsigned implements the ProposeBlockTransactionBuilder interface to
// return an unsigned transaction for a tx with multiple blocks,
// intended for preconfirmations.
func (b *CalldataTransactionBuilder) BuildBlocksUnsigned(
	_ context.Context,
	opts BuildBlocksUnsignedOpts,
) (*types.Transaction, error) {
	encodedParams := make([][]byte, 0)

	txLists := make([][]byte, 0)

	for _, opt := range opts.BlockOpts {
		txListBytes, err := signedTransactionsToTxListBytes(opt.SignedTransactions)
		if err != nil {
			return nil, err
		}

		compressedTxListBytes, err := utils.Compress(txListBytes)
		if err != nil {
			return nil, err
		}

		// ABI encode the TaikoL1.proposeBlock parameters.
		encoded, err := encoding.EncodeBlockParamsOntake(&encoding.BlockParamsV2{
			Coinbase:      common.HexToAddress(opt.Coinbase),
			AnchorBlockId: uint64(opt.L1StateBlockNumber),
			Timestamp:     opt.Timestamp,
		})
		if err != nil {
			return nil, err
		}

		encodedParams = append(encodedParams, encoded)

		txLists = append(txLists, compressedTxListBytes)
	}

	lookaheadPointer, err := b.getLookaheadBuffer(common.HexToAddress(opts.BlockOpts[0].Coinbase))
	if err != nil {
		return nil, err
	}

	lookaheadSetParams := make([]bindings.IPreconfTaskManagerLookaheadSetParam, 0)
	// can be null/0, we are force pushing lookaheads with netherminds
	// software for now.
	lookaheadSetParam := bindings.IPreconfTaskManagerLookaheadSetParam{
		Timestamp: big.NewInt(0),
		Preconfer: common.HexToAddress(opts.BlockOpts[0].Coinbase),
	}

	lookaheadSetParams = append(lookaheadSetParams, lookaheadSetParam)

	data, err := encoding.PreconfTaskManagerABI.Pack(
		"newBlockProposal",
		encodedParams,
		txLists,
		lookaheadPointer,
		lookaheadSetParams,
	)
	if err != nil {
		return nil, err
	}

	// Create the transaction
	tx := types.NewTransaction(
		0,
		b.preconfTaskManagerAddress,
		nil,
		b.gasLimit,
		big.NewInt(0),
		data,
	)

	return tx, nil
}
