package message

import (
	"context"
	"encoding/hex"
	"fmt"

	"github.com/ethereum/go-ethereum"
	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/ethclient"
	solsha3 "github.com/miguelmota/go-solidity-sha3"
	"github.com/pkg/errors"
	log "github.com/sirupsen/logrus"
	"github.com/taikochain/taiko-mono/packages/relayer"
	"github.com/taikochain/taiko-mono/packages/relayer/contracts"
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
	// TODO: if relayer can not process, save this to DB with status Unprocessable so
	// when we reiterate over blocks, we do not attempt to reprocess given it
	// will definitely fail.
	if event.Message.GasLimit == nil || event.Message.GasLimit.Cmp(common.Big0) == 0 {
		return errors.New("only user can process this, gasLimit set to 0")
	}

	// get latest synced header since not every header is synced from L1 => L2,
	// and later blocks still have the storage trie proof from previous blocks.
	latestSyncedHeader, err := p.destHeaderSyncer.GetLatestSyncedHeader(&bind.CallOpts{})
	if err != nil {
		return errors.Wrap(err, "taiko.GetSyncedHeader")
	}

	// if header hasnt been synced, we are unable to process this message
	if common.BytesToHash(latestSyncedHeader[:]).String() == common.HexToHash("0x0000000000000000000000000000000000000000000000000000000000000000").String() {
		log.Infof("header not synced, bailing")
		return nil
	}

	hashed := solsha3.SoliditySHA3(
		solsha3.Address(event.Raw.Address), // L1 bridge address
		solsha3.Bytes32(event.Signal),
	)

	key := hex.EncodeToString(hashed)

	log.Infof("processing message for signal: %v, key: %v", common.Hash(event.Signal).Hex(), key)

	auth, err := bind.NewKeyedTransactorWithChainID(p.ecdsaKey, event.Message.DestChainId)
	if err != nil {
		return errors.Wrap(err, "bind.NewKeyedTransactorWithChainID")
	}
	auth.Context = ctx

	// uncomment to skip `eth_estimateGas`
	// auth.GasLimit = 2000000
	// auth.GasPrice = new(big.Int).SetUint64(500000000)

	log.Infof("getting proof")
	encodedSignalProof, err := p.prover.EncodedSignalProof(ctx, p.rpc, event.Raw.Address, key, latestSyncedHeader)
	if err != nil {
		return errors.Wrap(err, "s.getEncodedSignalProof")
	}

	// check if message is received first. if not, it will definitely fail,
	// so we can exit early on this one. there is most likely
	// an issue with the signal generation.
	received, err := p.destBridge.IsMessageReceived(&bind.CallOpts{
		Context: ctx,
	}, event.Signal, event.Message.SrcChainId, encodedSignalProof)
	if err != nil {
		return errors.Wrap(err, "p.destBridge.IsSignalReceived")
	}

	log.Infof("isMessageReceived: %v", received)

	// message will fail when we try to process is
	// TODO: update status in db
	if !received {
		return errors.New("message not received")
	}

	// process the message on the destination bridge.
	tx, err := p.destBridge.ProcessMessage(auth, event.Message, encodedSignalProof)
	if err != nil {
		return errors.Wrap(err, "p.destBridge.ProcessMessage")
	}

	log.Infof("waiting for tx hash %v", hex.EncodeToString(tx.Hash().Bytes()))

	// TODO: needs to be cross-layer ethclient, not layer we sent the message on.
	ch := relayer.WaitForTx(ctx, p.destEthClient, tx.Hash())
	// wait for tx until mined
	<-ch

	log.Infof("Mined tx %s", hex.EncodeToString(tx.Hash().Bytes()))
	messageStatus, err := p.destBridge.GetMessageStatus(&bind.CallOpts{}, event.Signal)
	if err != nil {
		return errors.Wrap(err, "p.destBridge.GetMessageStatus")
	}

	r, err := getFailingMessage(*p.destEthClient, tx.Hash())
	if err != nil {
		return errors.Wrap(err, "GetFailingMessage")
	}

	if r != "" {
		log.Infof("tx failed, reason: %s", r)
		return errors.New(fmt.Sprintf("transaction failed, reason: %v", r))
	}

	// update message status
	if err := p.eventRepo.UpdateStatus(e.ID, relayer.EventStatus(messageStatus)); err != nil {
		return errors.Wrap(err, "s.eventRepo.UpdateStatus")
	}
	return nil
}

func getFailingMessage(client ethclient.Client, hash common.Hash) (string, error) {
	tx, _, err := client.TransactionByHash(context.Background(), hash)
	if err != nil {
		return "", err
	}

	from, err := types.Sender(types.NewEIP155Signer(tx.ChainId()), tx)
	if err != nil {
		return "", err
	}

	msg := ethereum.CallMsg{
		From:     from,
		To:       tx.To(),
		GasPrice: tx.GasPrice(),
		Value:    tx.Value(),
		Data:     tx.Data(),
	}

	res, err := client.CallContract(context.Background(), msg, nil)
	if err != nil {
		return "", err
	}

	return string(res), nil
}
