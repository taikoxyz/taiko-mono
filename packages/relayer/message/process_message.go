package message

import (
	"context"
	"encoding/hex"

	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/crypto"
	"github.com/pkg/errors"
	log "github.com/sirupsen/logrus"
	"github.com/taikoxyz/taiko-mono/packages/relayer"
	"github.com/taikoxyz/taiko-mono/packages/relayer/contracts/bridge"
)

// Process prepares and calls `processMessage` on the bridge.
// the proof must be generated from the gethclient's eth_getProof via the Prover,
// then rlp-encoded and combined as a singular byte slice,
// then abi encoded into a SignalProof struct as the contract
// expects
func (p *Processor) ProcessMessage(
	ctx context.Context,
	event *bridge.BridgeMessageSent,
	e *relayer.Event,
) error {
	if event.Message.GasLimit == nil || event.Message.GasLimit.Cmp(common.Big0) == 0 {
		return errors.New("only user can process this, gasLimit set to 0")
	}

	if err := p.waitForConfirmations(ctx, event.Raw.TxHash, event.Raw.BlockNumber); err != nil {
		return errors.Wrap(err, "p.waitForConfirmations")
	}

	if err := p.waitHeaderSynced(ctx, event); err != nil {
		return errors.Wrap(err, "p.waitHeaderSynced")
	}

	// get latest synced header since not every header is synced from L1 => L2,
	// and later blocks still have the storage trie proof from previous blocks.
	latestSyncedHeader, err := p.destHeaderSyncer.GetLatestSyncedHeader(&bind.CallOpts{})
	if err != nil {
		return errors.Wrap(err, "taiko.GetSyncedHeader")
	}

	hashed := crypto.Keccak256(
		event.Raw.Address.Bytes(),
		event.MsgHash[:],
	)

	key := hex.EncodeToString(hashed)

	encodedSignalProof, err := p.prover.EncodedSignalProof(ctx, p.rpc, p.srcSignalServiceAddress, key, latestSyncedHeader)
	if err != nil {
		log.Errorf("srcChainID: %v, destChainID: %v, txHash: %v: msgHash: %v, from: %v",
			event.Message.SrcChainId,
			event.Message.DestChainId,
			event.Raw.TxHash.Hex(),
			common.Hash(event.MsgHash).Hex(),
			event.Message.Owner.Hex(),
		)

		return errors.Wrap(err, "p.prover.GetEncodedSignalProof")
	}

	// check if message is received first. if not, it will definitely fail,
	// so we can exit early on this one. there is most likely
	// an issue with the signal generation.
	received, err := p.destBridge.IsMessageReceived(&bind.CallOpts{
		Context: ctx,
	}, event.MsgHash, event.Message.SrcChainId, encodedSignalProof)
	if err != nil {
		return errors.Wrap(err, "p.destBridge.IsMessageReceived")
	}

	// message will fail when we try to process it
	if !received {
		log.Warnf("msgHash %v not received on dest chain", common.Hash(event.MsgHash).Hex())
		return errors.New("message not received")
	}

	tx, err := p.sendProcessMessageCall(ctx, event, encodedSignalProof)
	if err != nil {
		return errors.Wrap(err, "p.sendProcessMessageCall")
	}

	log.Infof("waiting for tx hash %v", hex.EncodeToString(tx.Hash().Bytes()))

	_, err = relayer.WaitReceipt(ctx, p.destEthClient, tx.Hash())
	if err != nil {
		return errors.Wrap(err, "relayer.WaitReceipt")
	}

	log.Infof("Mined tx %s", hex.EncodeToString(tx.Hash().Bytes()))

	messageStatus, err := p.destBridge.GetMessageStatus(&bind.CallOpts{}, event.MsgHash)
	if err != nil {
		return errors.Wrap(err, "p.destBridge.GetMessageStatus")
	}

	log.Infof("updating message status to: %v", relayer.EventStatus(messageStatus).String())

	// update message status
	if err := p.eventRepo.UpdateStatus(ctx, e.ID, relayer.EventStatus(messageStatus)); err != nil {
		return errors.Wrap(err, "s.eventRepo.UpdateStatus")
	}

	return nil
}

func (p *Processor) sendProcessMessageCall(
	ctx context.Context,
	event *bridge.BridgeMessageSent,
	proof []byte,
) (*types.Transaction, error) {
	auth, err := bind.NewKeyedTransactorWithChainID(p.ecdsaKey, event.Message.DestChainId)
	if err != nil {
		return nil, errors.Wrap(err, "bind.NewKeyedTransactorWithChainID")
	}

	auth.Context = ctx

	p.mu.Lock()
	defer p.mu.Unlock()

	err = p.getLatestNonce(ctx, auth)
	if err != nil {
		return nil, errors.New("p.getLatestNonce")
	}

	// profitable, gas, err := p.isProfitable(ctx, event.Message, proof)
	// if err != nil {
	// 	return nil, errors.Wrap(err, "p.isProfitable")
	// }

	// if bool(p.profitableOnly) && !profitable {
	// 	return nil, relayer.ErrUnprofitable
	// }

	// if gas != 0 {
	// 	auth.GasLimit = gas
	// 	log.Infof("gasLimit: %v", gas)
	// }
	auth.GasLimit = 1200000

	// process the message on the destination bridge.
	tx, err := p.destBridge.ProcessMessage(auth, event.Message, proof)
	if err != nil {
		return nil, errors.Wrap(err, "p.destBridge.ProcessMessage")
	}

	p.setLatestNonce(tx.Nonce())

	return tx, nil
}

func (p *Processor) setLatestNonce(nonce uint64) {
	p.destNonce = nonce
}
