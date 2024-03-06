package transaction

import (
	"context"
	"crypto/ecdsa"
	"math/big"
	"sync"

	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/crypto"
	"github.com/ethereum/go-ethereum/log"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/encoding"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/rpc"
)

// TxBuilder will build a transaction with the given nonce.
type TxBuilder func(nonce *big.Int) (*types.Transaction, error)

// ProveBlockTxBuilder is responsible for building ProveBlock transactions.
type ProveBlockTxBuilder struct {
	rpc              *rpc.Client
	proverPrivateKey *ecdsa.PrivateKey
	proverAddress    common.Address
	gasLimit         *big.Int
	gasTipCap        *big.Int
	gasTipMultiplier *big.Int
	mutex            *sync.Mutex
}

// NewProveBlockTxBuilder creates a new ProveBlockTxBuilder instance.
func NewProveBlockTxBuilder(
	rpc *rpc.Client,
	proverPrivateKey *ecdsa.PrivateKey,
	gasLimit *big.Int,
	gasTipCap *big.Int,
	gasTipMultiplier *big.Int,
) *ProveBlockTxBuilder {
	return &ProveBlockTxBuilder{
		rpc:              rpc,
		proverPrivateKey: proverPrivateKey,
		proverAddress:    crypto.PubkeyToAddress(proverPrivateKey.PublicKey),
		gasLimit:         gasLimit,
		gasTipCap:        gasTipCap,
		gasTipMultiplier: gasTipMultiplier,
		mutex:            new(sync.Mutex),
	}
}

// Build creates a new TaikoL1.ProveBlock transaction with the given nonce.
func (a *ProveBlockTxBuilder) Build(
	ctx context.Context,
	blockID *big.Int,
	meta *bindings.TaikoDataBlockMetadata,
	transition *bindings.TaikoDataTransition,
	tierProof *bindings.TaikoDataTierProof,
	guardian bool,
) TxBuilder {
	return func(nonce *big.Int) (*types.Transaction, error) {
		a.mutex.Lock()
		defer a.mutex.Unlock()

		txOpts, err := getProveBlocksTxOpts(ctx, a.rpc.L1, a.rpc.L1.ChainID, a.proverPrivateKey)
		if err != nil {
			return nil, err
		}

		if a.gasLimit != nil {
			txOpts.GasLimit = a.gasLimit.Uint64()
		}

		if nonce != nil {
			txOpts.Nonce = nonce

			if txOpts, err = rpc.IncreaseGasTipCap(
				ctx,
				a.rpc,
				txOpts,
				a.proverAddress,
				a.gasTipMultiplier,
				a.gasTipCap,
			); err != nil {
				return nil, err
			}
		}

		log.Info(
			"Build proof submission transaction",
			"blockID", blockID,
			"gasLimit", txOpts.GasLimit,
			"nonce", txOpts.Nonce,
			"gasTipCap", txOpts.GasTipCap,
			"gasFeeCap", txOpts.GasFeeCap,
			"guardian", guardian,
		)

		if !guardian {
			input, err := encoding.EncodeProveBlockInput(meta, transition, tierProof)
			if err != nil {
				return nil, err
			}
			return a.rpc.TaikoL1.ProveBlock(txOpts, blockID.Uint64(), input)
		}

		return a.rpc.GuardianProver.Approve(txOpts, *meta, *transition, *tierProof)
	}
}

// getProveBlocksTxOpts creates a bind.TransactOpts instance using the given private key.
// Used for creating TaikoL1.proveBlock and TaikoL1.proveBlockInvalid transactions.
func getProveBlocksTxOpts(
	ctx context.Context,
	cli *rpc.EthClient,
	chainID *big.Int,
	proverPrivKey *ecdsa.PrivateKey,
) (*bind.TransactOpts, error) {
	opts, err := bind.NewKeyedTransactorWithChainID(proverPrivKey, chainID)
	if err != nil {
		return nil, err
	}
	gasTipCap, err := cli.SuggestGasTipCap(ctx)
	if err != nil {
		if rpc.IsMaxPriorityFeePerGasNotFoundError(err) {
			gasTipCap = rpc.FallbackGasTipCap
		} else {
			return nil, err
		}
	}

	opts.GasTipCap = gasTipCap

	return opts, nil
}
