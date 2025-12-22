package processor

import (
	"context"
	"encoding/json"
	"log/slog"

	"github.com/ethereum-optimism/optimism/op-service/txmgr"
	"github.com/ethereum/go-ethereum"
	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/pkg/errors"
	"github.com/taikoxyz/taiko-mono/packages/relayer"
	"github.com/taikoxyz/taiko-mono/packages/relayer/pkg/queue"
	shasta "github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/shasta"
)

const bondInstructionGasLimitOverheadPercent = 10

func (p *Processor) processBondInstruction(
	ctx context.Context,
	msg queue.Message,
) (bool, uint64, error) {
	msgBody := &queue.QueueBondInstructionCreatedBody{}
	if err := json.Unmarshal(msg.Body, msgBody); err != nil {
		return false, 0, errors.Wrap(err, "json.Unmarshal")
	}

	if msgBody.Event == nil {
		slog.Warn("empty bond instruction event")
		return false, 0, errors.New("empty bond instruction event")
	}

	if p.bondManager == nil || p.cfg.DestBondManagerAddress == relayer.ZeroAddress {
		return false, msgBody.TimesRetried, errors.New("bond manager not configured")
	}

	signal, signalHex, err := p.resolveBondInstructionSignal(ctx, msgBody)
	if err != nil {
		return false, msgBody.TimesRetried, err
	}

	signalHash := common.Hash(signal)

	checkSignal := func(hash common.Hash) error {
		p.processingSignalMu.Lock()
		defer p.processingSignalMu.Unlock()

		if _, ok := p.processingSignals[hash]; ok {
			slog.Warn("already processing signal", "signal", hash.Hex())
			return errAlreadyProcessing
		}

		p.processingSignals[hash] = true

		return nil
	}

	if err := checkSignal(signalHash); err != nil {
		return false, msgBody.TimesRetried, err
	}

	defer func(hash common.Hash) {
		p.processingSignalMu.Lock()
		defer p.processingSignalMu.Unlock()
		delete(p.processingSignals, hash)
	}(signalHash)

	if msgBody.TimesRetried >= p.maxMessageRetries {
		slog.Warn("max retries reached", "timesRetried", msgBody.TimesRetried)

		if msg.Internal != nil {
			if err := p.eventRepo.UpdateStatus(ctx, msgBody.ID, relayer.EventStatusFailed); err != nil {
				return false, msgBody.TimesRetried, err
			}
		}

		return false, msgBody.TimesRetried, errUnprocessable
	}

	if err := p.waitForConfirmations(ctx, msgBody.Event.Raw.TxHash); err != nil {
		return false, msgBody.TimesRetried, err
	}

	processed, err := p.bondManager.ProcessedSignals(&bind.CallOpts{Context: ctx}, signal)
	if err != nil {
		return false, msgBody.TimesRetried, err
	}

	if processed {
		slog.Info("bond instruction already processed", "signal", signalHex)

		if msg.Internal != nil {
			if err := p.eventRepo.UpdateStatus(ctx, msgBody.ID, relayer.EventStatusDone); err != nil {
				return false, msgBody.TimesRetried, err
			}
		}

		return false, msgBody.TimesRetried, errUnprocessable
	}

	proof, err := p.generateEncodedSignalProofForSignal(
		ctx,
		p.srcChainId.Uint64(),
		msgBody.Event.Raw.Address,
		signal,
		msgBody.Event.Raw.BlockNumber,
	)
	if err != nil {
		return false, msgBody.TimesRetried, err
	}

	bondManagerABI, err := shasta.BondManagerMetaData.GetAbi()
	if err != nil {
		return false, msgBody.TimesRetried, err
	}

	data, err := bondManagerABI.Pack("processBondInstruction", msgBody.Event.BondInstruction, proof)
	if err != nil {
		return false, msgBody.TimesRetried, err
	}

	gasUsed, err := p.destEthClient.EstimateGas(ctx, ethereum.CallMsg{
		From: p.relayerAddr,
		To:   &p.cfg.DestBondManagerAddress,
		Data: data,
	})
	if err != nil {
		return false, msgBody.TimesRetried, err
	}

	gasLimit := gasUsed + (gasUsed*bondInstructionGasLimitOverheadPercent)/100

	candidate := txmgr.TxCandidate{
		TxData:   data,
		To:       &p.cfg.DestBondManagerAddress,
		GasLimit: gasLimit,
	}

	receipt, err := p.txmgr.Send(ctx, candidate)
	if err != nil {
		slog.Warn("failed to send processBondInstruction transaction", "error", err.Error())
		return false, msgBody.TimesRetried, err
	}

	slog.Info("mined bond instruction tx",
		"txHash", receipt.TxHash.Hex(),
		"signal", signalHex,
		"srcTxHash", msgBody.Event.Raw.TxHash.Hex(),
	)

	if receipt.Status != types.ReceiptStatusSuccessful {
		slog.Warn("bond instruction transaction reverted", "txHash", receipt.TxHash.Hex(), "signal", signalHex)
		return false, msgBody.TimesRetried, errTxReverted
	}

	if msg.Internal != nil {
		if err := p.eventRepo.UpdateStatus(ctx, msgBody.ID, relayer.EventStatusDone); err != nil {
			return false, msgBody.TimesRetried, err
		}
	}

	return false, msgBody.TimesRetried, nil
}

func (p *Processor) resolveBondInstructionSignal(
	ctx context.Context,
	msgBody *queue.QueueBondInstructionCreatedBody,
) ([32]byte, string, error) {
	if msgBody.Signal != "" {
		hash := common.HexToHash(msgBody.Signal)
		return [32]byte(hash), hash.Hex(), nil
	}

	if p.srcContractCaller == nil {
		return [32]byte{}, "", errors.New("src contract caller not configured")
	}

	inbox, err := shasta.NewShastaInboxClientCaller(msgBody.Event.Raw.Address, p.srcContractCaller)
	if err != nil {
		return [32]byte{}, "", err
	}

	signal, err := inbox.HashBondInstruction(&bind.CallOpts{Context: ctx}, msgBody.Event.BondInstruction)
	if err != nil {
		return [32]byte{}, "", err
	}

	return signal, common.Hash(signal).Hex(), nil
}
