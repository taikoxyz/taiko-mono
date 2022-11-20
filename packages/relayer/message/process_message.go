package message

import (
	"context"
	"encoding/hex"
	"math/big"
	"time"

	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/crypto"
	"github.com/pkg/errors"
	log "github.com/sirupsen/logrus"
	"github.com/taikoxyz/taiko-mono/packages/relayer"
	"github.com/taikoxyz/taiko-mono/packages/relayer/contracts"
)

// Process prepares and calls `processMessage` on the bridge.
// the proof must be generated from the gethclient's eth_getProof via the Prover,
// then rlp-encoded and combined as a singular byte slice,
// then abi encoded into a SignalProof struct as the contract
// expects
func (p *Processor) ProcessMessage(
	ctx context.Context,
	event *contracts.BridgeMessageSent,
	e *relayer.Event,
) error {
	log.Infof("processing message for signal: %v", common.Hash(event.Signal).Hex())

	// TODO: if relayer can not process, save this to DB with status Unprocessable
	if event.Message.GasLimit == nil || event.Message.GasLimit.Cmp(common.Big0) == 0 {
		return errors.New("only user can process this, gasLimit set to 0")
	}

	if err := p.waitForConfirmations(ctx, event.Raw.TxHash, event.Raw.BlockNumber); err != nil {
		return errors.Wrap(err, "p.waitForConfirmations")
	}

	// get latest synced header since not every header is synced from L1 => L2,
	// and later blocks still have the storage trie proof from previous blocks.
	latestSyncedHeader, err := p.destHeaderSyncer.GetLatestSyncedHeader(&bind.CallOpts{})
	if err != nil {
		return errors.Wrap(err, "taiko.GetSyncedHeader")
	}

	// if header hasnt been synced, we are unable to process this message
	if common.BytesToHash(latestSyncedHeader[:]).Hex() == relayer.ZeroHash.Hex() {
		log.Infof("header not synced, bailing")
		return nil
	}

	hashed := crypto.Keccak256(
		event.Raw.Address.Bytes(), // L1 bridge address
		event.Signal[:],
	)

	key := hex.EncodeToString(hashed)

	encodedSignalProof, err := p.prover.EncodedSignalProof(ctx, p.rpc, event.Raw.Address, key, latestSyncedHeader)
	if err != nil {
		return errors.Wrap(err, "p.prover.GetEncodedSignalProof")
	}

	// check if message is received first. if not, it will definitely fail,
	// so we can exit early on this one. there is most likely
	// an issue with the signal generation.
	received, err := p.destBridge.IsMessageReceived(&bind.CallOpts{
		Context: ctx,
	}, event.Signal, event.Message.SrcChainId, encodedSignalProof)
	if err != nil {
		return errors.Wrap(err, "p.destBridge.IsMessageReceived")
	}

	// message will fail when we try to process is
	// TODO: update status in db
	if !received {
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

	messageStatus, err := p.destBridge.GetMessageStatus(&bind.CallOpts{}, event.Signal)
	if err != nil {
		return errors.Wrap(err, "p.destBridge.GetMessageStatus")
	}

	log.Infof("updating message status to: %v", relayer.EventStatus(messageStatus).String())

	// update message status
	if err := p.eventRepo.UpdateStatus(e.ID, relayer.EventStatus(messageStatus)); err != nil {
		return errors.Wrap(err, "s.eventRepo.UpdateStatus")
	}

	return nil
}

func (p *Processor) sendProcessMessageCall(
	ctx context.Context,
	event *contracts.BridgeMessageSent,
	proof []byte,
) (*types.Transaction, error) {
	auth, err := bind.NewKeyedTransactorWithChainID(p.ecdsaKey, event.Message.DestChainId)
	if err != nil {
		return nil, errors.Wrap(err, "bind.NewKeyedTransactorWithChainID")
	}

	auth.Context = ctx

	// uncomment to skip `eth_estimateGas`
	auth.GasLimit = 2000000
	auth.GasPrice = new(big.Int).SetUint64(500000000)

	p.mu.Lock()
	defer p.mu.Unlock()

	err = p.getLatestNonce(ctx, auth)
	if err != nil {
		return nil, errors.New("p.getLatestNonce")
	}
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

func (p *Processor) getLatestNonce(ctx context.Context, auth *bind.TransactOpts) error {
	pendingNonce, err := p.destEthClient.PendingNonceAt(ctx, p.relayerAddr)
	if err != nil {
		return err
	}

	if pendingNonce > p.destNonce {
		p.setLatestNonce(pendingNonce)
	}

	auth.Nonce = big.NewInt(int64(p.destNonce))

	return nil
}

func (p *Processor) waitForConfirmations(ctx context.Context, txHash common.Hash, blockNumber uint64) error {
	// TODO: make timeout a config var
	ctx, cancelFunc := context.WithTimeout(ctx, 2*time.Minute)

	defer cancelFunc()

	if err := relayer.WaitConfirmations(
		ctx,
		p.srcEthClient,
		p.confirmations,
		txHash,
	); err != nil {
		return errors.Wrap(err, "relayer.WaitConfirmations")
	}

	return nil
}
