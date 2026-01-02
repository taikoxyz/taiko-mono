package processor

import (
	"context"
	"encoding/json"
	"fmt"
	"log/slog"
	"strings"

	"github.com/ethereum/go-ethereum/accounts/abi"
	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/common"

	"github.com/taikoxyz/taiko-mono/packages/relayer"
	"github.com/taikoxyz/taiko-mono/packages/relayer/bindings/bridge"
	"github.com/taikoxyz/taiko-mono/packages/relayer/pkg/queue"
	shasta "github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/shasta"
)

// processSingle is used to process a single message, when we are
// targeting a specific message via config flag
func (p *Processor) processSingle(ctx context.Context) error {
	slog.Info("processing single", "txHash", common.Hash(*p.targetTxHash).Hex())

	receipt, err := p.srcEthClient.TransactionReceipt(ctx, *p.targetTxHash)
	if err != nil {
		return err
	}

	switch p.eventName {
	case relayer.EventNameMessageSent:
		bridgeAbi, err := abi.JSON(strings.NewReader(bridge.BridgeABI))
		if err != nil {
			return err
		}

		for _, log := range receipt.Logs {
			if len(log.Topics) == 0 {
				continue
			}

			if log.Topics[0] != bridgeAbi.Events["MessageSent"].ID {
				continue
			}

			event, err := p.destBridge.ParseMessageSent(*log)
			if err != nil {
				return err
			}

			msg := queue.QueueMessageSentBody{
				ID:    0,
				Event: event,
			}

			marshalledMsg, err := json.Marshal(msg)
			if err != nil {
				return err
			}

			if _, _, err := p.processMessage(ctx, queue.Message{
				Body: marshalledMsg,
			}); err != nil {
				return err
			}
		}
	case relayer.EventNameBondInstructionCreated:
		inboxABI, err := shasta.ShastaInboxClientMetaData.GetAbi()
		if err != nil {
			return err
		}

		contract := bind.NewBoundContract(common.Address{}, *inboxABI, nil, nil, nil)

		for _, log := range receipt.Logs {
			if len(log.Topics) == 0 {
				continue
			}

			if log.Topics[0] != inboxABI.Events["BondInstructionCreated"].ID {
				continue
			}

			event := new(shasta.ShastaInboxClientBondInstructionCreated)
			if err := contract.UnpackLog(event, "BondInstructionCreated", *log); err != nil {
				return err
			}

			event.Raw = *log

			msg := queue.QueueBondInstructionCreatedBody{
				ID:    0,
				Event: event,
			}

			marshalledMsg, err := json.Marshal(msg)
			if err != nil {
				return err
			}

			if _, _, err := p.processBondInstruction(ctx, queue.Message{
				Body: marshalledMsg,
			}); err != nil {
				return err
			}
		}
	default:
		return fmt.Errorf("unsupported eventName: %s", p.eventName)
	}

	return nil
}
