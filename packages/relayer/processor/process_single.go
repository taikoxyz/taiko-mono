package processor

import (
	"context"
	"encoding/json"
	"strings"

	"github.com/ethereum/go-ethereum/accounts/abi"
	"github.com/taikoxyz/taiko-mono/packages/relayer/bindings/bridge"
	"github.com/taikoxyz/taiko-mono/packages/relayer/pkg/queue"
)

func (p *Processor) processSingle(ctx context.Context) error {
	bridgeAbi, err := abi.JSON(strings.NewReader(bridge.BridgeABI))
	if err != nil {
		return err
	}

	receipt, err := p.srcEthClient.TransactionReceipt(ctx, *p.targetTxHash)
	if err != nil {
		return err
	}

	for _, log := range receipt.Logs {
		topic := log.Topics[0]

		if topic == bridgeAbi.Events["MessageSent"].ID {
			s := &bridge.BridgeMessageSent{}
			err = bridgeAbi.UnpackIntoInterface(s, "MessageSent", log.Data)

			if err != nil {
				return err
			}

			s.MsgHash = log.Topics[1]
			s.Raw.TxHash = *p.targetTxHash
			s.Raw.BlockNumber = receipt.BlockNumber.Uint64()
			s.Raw.Address = log.Address
			s.Raw.Topics = log.Topics

			msg := queue.QueueMessageBody{
				ID:    0,
				Event: s,
			}

			marshalledMsg, err := json.Marshal(msg)
			if err != nil {
				return err
			}

			if err := p.processMessage(ctx, queue.Message{
				Body: marshalledMsg,
			}); err != nil {
				return err
			}
		}
	}

	return nil
}
