package sender

import (
	"fmt"
	"math/big"
	"time"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/log"
	"github.com/holiman/uint256"

	"github.com/taikoxyz/taiko-client/internal/utils"
)

// adjustGas adjusts the gas fee cap and gas tip cap of the given transaction with the configured
// growth rate.
func (s *Sender) adjustGas(txData types.TxData) {
	rate := s.GasGrowthRate + 100
	switch baseTx := txData.(type) {
	case *types.DynamicFeeTx:
		gasFeeCap := baseTx.GasFeeCap.Int64()
		gasFeeCap = gasFeeCap / 100 * int64(rate)
		gasFeeCap = utils.Min(gasFeeCap, int64(s.MaxGasFee))
		baseTx.GasFeeCap = big.NewInt(gasFeeCap)

		gasTipCap := baseTx.GasTipCap.Int64()
		gasTipCap = gasTipCap / 100 * int64(rate)
		gasTipCap = utils.Min(gasFeeCap, utils.Min(gasTipCap, int64(s.MaxGasFee)))
		baseTx.GasTipCap = big.NewInt(gasTipCap)
	case *types.BlobTx:
		gasFeeCap := baseTx.GasFeeCap.Uint64()
		gasFeeCap = gasFeeCap / 100 * rate
		gasFeeCap = utils.Min(gasFeeCap, s.MaxGasFee)
		baseTx.GasFeeCap = uint256.NewInt(gasFeeCap)

		gasTipCap := baseTx.GasTipCap.Uint64()
		gasTipCap = gasTipCap / 100 * rate
		gasTipCap = utils.Min(gasFeeCap, utils.Min(gasTipCap, s.MaxGasFee))
		baseTx.GasTipCap = uint256.NewInt(gasTipCap)

		blobFeeCap := baseTx.BlobFeeCap.Uint64()
		blobFeeCap = blobFeeCap / 100 * rate
		blobFeeCap = utils.Min(blobFeeCap, s.MaxBlobFee)
		baseTx.BlobFeeCap = uint256.NewInt(blobFeeCap)
	default:
		log.Warn("Unsupported transaction type when adjust gas fee", "from", s.Opts.From)
	}
}

// SetNonce adjusts the nonce of the given transaction with the current nonce of the sender.
func (s *Sender) SetNonce(txData types.TxData, adjust bool) (err error) {
	var nonce uint64
	if adjust {
		s.nonce, err = s.client.NonceAt(s.ctx, s.Opts.From, nil)
		if err != nil {
			log.Warn("Failed to get the nonce", "from", s.Opts.From, "err", err)
			return err
		}
	}
	nonce = s.nonce

	if !utils.IsNil(txData) {
		switch tx := txData.(type) {
		case *types.DynamicFeeTx:
			tx.Nonce = nonce
		case *types.BlobTx:
			tx.Nonce = nonce
		case *types.LegacyTx:
			tx.Nonce = nonce
		case *types.AccessListTx:
			tx.Nonce = nonce
		default:
			return fmt.Errorf("unsupported transaction type: %v", txData)
		}
	}
	return
}

// updateGasTipGasFee updates the gas tip cap and gas fee cap of the sender with the given chain head info.
func (s *Sender) updateGasTipGasFee(head *types.Header) error {
	// Get the gas tip cap
	gasTipCap, err := s.client.SuggestGasTipCap(s.ctx)
	if err != nil {
		return err
	}

	// Get the gas fee cap
	gasFeeCap := new(big.Int).Add(gasTipCap, new(big.Int).Mul(head.BaseFee, big.NewInt(2)))
	// Check if the gas fee cap is less than the gas tip cap
	if gasFeeCap.Cmp(gasTipCap) < 0 {
		return fmt.Errorf("maxFeePerGas (%v) < maxPriorityFeePerGas (%v)", gasFeeCap, gasTipCap)
	}
	maxGasFee := new(big.Int).SetUint64(s.MaxGasFee)
	if gasFeeCap.Cmp(maxGasFee) > 0 {
		gasFeeCap = new(big.Int).Set(maxGasFee)
		gasTipCap = new(big.Int).Set(maxGasFee)
	}

	s.Opts.GasTipCap = gasTipCap
	s.Opts.GasFeeCap = gasFeeCap

	return nil
}

// buildTxData assembles the transaction data from the given transaction.
func (s *Sender) buildTxData(tx *types.Transaction) (types.TxData, error) {
	switch tx.Type() {
	case types.DynamicFeeTxType:
		return &types.DynamicFeeTx{
			ChainID:    s.client.ChainID,
			To:         tx.To(),
			Nonce:      tx.Nonce(),
			GasFeeCap:  s.Opts.GasFeeCap,
			GasTipCap:  s.Opts.GasTipCap,
			Gas:        tx.Gas(),
			Value:      tx.Value(),
			Data:       tx.Data(),
			AccessList: tx.AccessList(),
		}, nil
	case types.BlobTxType:
		var to common.Address
		if tx.To() != nil {
			to = *tx.To()
		}
		return &types.BlobTx{
			ChainID:    uint256.MustFromBig(s.client.ChainID),
			To:         to,
			Nonce:      tx.Nonce(),
			GasFeeCap:  uint256.MustFromBig(s.Opts.GasFeeCap),
			GasTipCap:  uint256.MustFromBig(s.Opts.GasTipCap),
			Gas:        tx.Gas(),
			Value:      uint256.MustFromBig(tx.Value()),
			Data:       tx.Data(),
			AccessList: tx.AccessList(),
			BlobFeeCap: uint256.MustFromBig(tx.BlobGasFeeCap()),
			BlobHashes: tx.BlobHashes(),
			Sidecar:    tx.BlobTxSidecar(),
		}, nil
	default:
		return nil, fmt.Errorf("unsupported transaction type: %v", tx.Type())
	}
}

// setDefault sets the default value if the given value is 0.
func setDefault[T uint64 | time.Duration](src, dest T) T {
	if src == 0 {
		return dest
	}
	return src
}

// setConfigWithDefaultValues sets the config with default values if the given config is nil.
func setConfigWithDefaultValues(config *Config) *Config {
	if config == nil {
		return DefaultConfig
	}
	return &Config{
		ConfirmationDepth: setDefault(config.ConfirmationDepth, DefaultConfig.ConfirmationDepth),
		MaxRetrys:         setDefault(config.MaxRetrys, DefaultConfig.MaxRetrys),
		MaxWaitingTime:    setDefault(config.MaxWaitingTime, DefaultConfig.MaxWaitingTime),
		GasLimit:          setDefault(config.GasLimit, DefaultConfig.GasLimit),
		GasGrowthRate:     setDefault(config.GasGrowthRate, DefaultConfig.GasGrowthRate),
		MaxGasFee:         setDefault(config.MaxGasFee, DefaultConfig.MaxGasFee),
		MaxBlobFee:        setDefault(config.MaxBlobFee, DefaultConfig.MaxBlobFee),
	}
}
