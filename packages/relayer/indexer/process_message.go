package indexer

import (
	"bytes"
	"context"
	"encoding/hex"

	"github.com/umbracle/ethgo/abi"
	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/crypto"
	"github.com/ethereum/go-ethereum/rlp"
	"github.com/pkg/errors"
	log "github.com/sirupsen/logrus"
	"github.com/taikochain/taiko-mono/packages/relayer"
	"github.com/taikochain/taiko-mono/packages/relayer/contracts"
)

var (
	typ = abi.MustNewType()
	args = abi.Arguments{
		{
			Name: "signalProof",
			Type: relayer.SignalProofABIType,
		},
	}
)

// processMessage prepares and calls `processMessage` on the bridge.
// the proof must be generated from the gethclient's eth_getProof,
// then rlp-encoded and combined as a singular byte slice,
// as the contract expects
func (s *Service) processMessage(
	ctx context.Context,
	event *contracts.BridgeMessageSent,
	crossLayerBridgeAddress string,
) error {
	signal := event.Signal
	message := event.Message
	bridgeAddress := event.Raw.Address
	key := hex.EncodeToString(
		crypto.Keccak256(
			encodePacked(
				message.Sender[:],
				signal[:],
			),
		))
	log.Infof("processing message for signal: %v", common.Hash(signal).Hex())

	auth, err := bind.NewKeyedTransactorWithChainID(s.ecdsaKey, message.DestChainId)
	if err != nil {
		return errors.Wrap(err, "bind.NewKeyedTransactorWithChainID")
	}

	log.Infof("calling eth_getProof")

	// TODO: block should not be nil, but event.Raw.BlockNumber.
	// however, this is throwing a missing trie error with our L1 geth client.
	proof, err := s.gethClient.GetProof(ctx, bridgeAddress, []string{key}, nil)
	if err != nil {
		return errors.Wrap(err, "s.gethClient.GetProof")
	}

	log.Info("rlp encoding account proof")

	rlpEncodedAccountProof, err := rlp.EncodeToBytes(proof.AccountProof)
	if err != nil {
		return errors.Wrap(err, "rlp.EncodeToBytes(proof.AccountProof")
	}

	log.Info("rlp encoding storage proof")
	rlpEncodedStorageProof, err := rlp.EncodeToBytes(proof.StorageProof[0].Proof)
	if err != nil {
		return errors.Wrap(err, "rlp.EncodeToBytes(proof.StorageProof[0].Proof")
	}

	blockheader := relayer.BlockHeader{}

	encodedProof := encodePacked(rlpEncodedAccountProof, rlpEncodedStorageProof

	signalProof := relayer.SignalProof{
		Header: blockheader,
		Proof: 
	}
	
	bridge, err := contracts.NewBridge(common.HexToAddress(crossLayerBridgeAddress), s.crossLayerEthClient)
	if err != nil {
		return errors.Wrap(err, "contracts.NewBridge")
	}

	log.Info("processing message")
	tx, err := bridge.ProcessMessage(auth, message, encodedProof)
	if err != nil {
		return errors.Wrap(err, "bridge.ProcessMessage")
	}

	// TODO: needs to be cross-layer ethclient, not layer we sent the message on.
	ch := relayer.WaitForTx(ctx, s.crossLayerEthClient, tx.Hash())
	// wait for tx until mined
	<-ch

	log.Infof("Mined tx %s", tx.Hash())

	// TODO: update event in DB to be processed, or retriable if it failed
	return nil
}

// encodePacked replicates solidity's `abi.encodePacked`
func encodePacked(input ...[]byte) []byte {
	return bytes.Join(input, nil)
}

func encodeBytesString(v string) []byte {
	decoded, err := hex.DecodeString(v)
	if err != nil {
		panic(err)
	}
	return decoded
}
