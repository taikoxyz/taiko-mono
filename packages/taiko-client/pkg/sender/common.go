package sender

import (
	"fmt"
	"math/big"

	"github.com/creasty/defaults"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/log"
	"github.com/holiman/uint256"

	"github.com/taikoxyz/taiko-client/internal/utils"
)

// AdjustGasFee adjusts the gas fee cap and gas tip cap of the given transaction with the configured
// growth rate.
func (s *Sender) AdjustGasFee(txData types.TxData) {
	rate := s.GasGrowthRate
	switch baseTx := txData.(type) {
	case *types.DynamicFeeTx:
		gasFeeCap := baseTx.GasFeeCap.Int64()
		gasFeeCap += gasFeeCap * int64(rate) / 100
		baseTx.GasFeeCap = big.NewInt(utils.Min(gasFeeCap, int64(s.MaxGasFee)))

		gasTipCap := baseTx.GasTipCap.Int64()
		gasTipCap += gasTipCap * int64(rate) / 100
		gasTipCap = utils.Min(gasFeeCap, utils.Min(gasTipCap, int64(s.MaxGasFee)))
		baseTx.GasTipCap = big.NewInt(gasTipCap)
	case *types.BlobTx:
		gasFeeCap := baseTx.GasFeeCap.Uint64()
		gasFeeCap += gasFeeCap * rate / 100
		baseTx.GasFeeCap = uint256.NewInt(utils.Min(gasFeeCap, s.MaxGasFee))

		gasTipCap := baseTx.GasTipCap.Uint64()
		gasTipCap += gasTipCap * rate / 100
		gasTipCap = utils.Min(gasFeeCap, utils.Min(gasTipCap, s.MaxGasFee))
		baseTx.GasTipCap = uint256.NewInt(gasTipCap)
	default:
		log.Warn("Unsupported transaction type when adjust gasFeeCap and gasTipCap", "from", s.opts.From)
	}
}

// AdjustBlobGasFee adjusts the gas fee cap and gas tip cap of the given transaction with the configured.
func (s *Sender) AdjustBlobGasFee(txData types.TxData) {
	rate := s.GasGrowthRate + 100
	switch baseTx := txData.(type) {
	case *types.BlobTx:
		blobFeeCap := baseTx.BlobFeeCap.Uint64()
		// Use Max check is to catch is situation: +1 is necessary, if blobFeeCap can't increase.
		blobFeeCap = utils.Max(blobFeeCap*rate/100, blobFeeCap+1)
		blobFeeCap = utils.Min(blobFeeCap, s.MaxBlobFee)
		baseTx.BlobFeeCap = uint256.NewInt(blobFeeCap)
	default:
		log.Warn("Unsupported transaction type when adjust blobGasFeeCap", "from", s.opts.From)
	}
}

// SetNonce adjusts the nonce of the given transaction with the current nonce of the sender.
func (s *Sender) SetNonce(txData types.TxData, adjust bool) (err error) {
	var nonce uint64
	if adjust {
		s.nonce, err = s.client.NonceAt(s.ctx, s.opts.From, nil)
		if err != nil {
			log.Warn("Failed to get the nonce", "from", s.opts.From, "err", err)
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

	s.opts.GasTipCap = gasTipCap
	s.opts.GasFeeCap = gasFeeCap

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
			GasFeeCap:  s.opts.GasFeeCap,
			GasTipCap:  s.opts.GasTipCap,
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
			GasFeeCap:  uint256.MustFromBig(s.opts.GasFeeCap),
			GasTipCap:  uint256.MustFromBig(s.opts.GasTipCap),
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

// setConfigWithDefaultValues sets the config with default values if the given config is nil.
func setConfigWithDefaultValues(config *Config) *Config {
	if config == nil {
		config = new(Config)
	}
	_ = defaults.Set(config)
	return config
}
