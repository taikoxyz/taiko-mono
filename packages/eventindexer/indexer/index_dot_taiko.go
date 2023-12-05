package indexer

import (
	"context"
	"math/big"
	"strings"
	"time"

	"github.com/ethereum/go-ethereum/accounts/abi"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/crypto"
	"github.com/labstack/gommon/log"
	"github.com/pkg/errors"
	"github.com/taikoxyz/taiko-mono/packages/eventindexer"
)

var (
	contractAbi = `[{
		"type": "event",
		"name": "NewOwner",
		"inputs": [
		  {
			"type": "bytes32",
			"name": "node",
			"indexed": true
		  },
		  {
			"type": "bytes32",
			"name": "label",
			"indexed": true
		  },
		  {
			"type": "address",
			"name": "owner",
			"indexed": false
		  }
		],
		"anonymous": false
	  }]`
	newOwnerSignature           = []byte("NewOwner(bytes32,bytes32,address)")
	nameRegisteredSignatureHash = crypto.Keccak256Hash(newOwnerSignature)
)

// indexDotTaiko indexes from a given starting block to a given end block and parses all event logs
// to find NameRegistered events
func (indxr *Indexer) indexDotTaiko(
	ctx context.Context,
	chainID *big.Int,
	logs []types.Log,
) error {
	for _, vLog := range logs {
		// malformed event
		if len(vLog.Topics) == 0 {
			continue
		}

		if vLog.Topics[0].Hex() != nameRegisteredSignatureHash.Hex() {
			continue
		}

		log.Info("name registered event found")

		if err := indxr.saveDotTaiko(ctx, chainID, vLog); err != nil {
			return err
		}
	}

	return nil
}

// saveNFTTrasnfer parses the event logs and saves either an ERC721 or ERC1155 event, updating
// users balances
func (indxr *Indexer) saveDotTaiko(ctx context.Context, chainID *big.Int, vLog types.Log) error {
	eventABI, err := abi.JSON(strings.NewReader(contractAbi))
	if err != nil {
		return err
	}

	output, err := eventABI.Unpack("NewOwner", vLog.Data)
	if err != nil {
		return err
	}

	block, err := indxr.ethClient.BlockByNumber(ctx, new(big.Int).SetUint64(vLog.BlockNumber))
	if err != nil {
		return errors.Wrap(err, "indxr.ethClient.BlockByNumber")
	}

	from := output[0].(common.Address)

	log.Info("name registered", "owner", from.Hex())

	_, err = indxr.eventRepo.Save(ctx, eventindexer.SaveEventOpts{
		Name:         eventindexer.EventNameNameRegistered,
		Data:         "{}",
		ChainID:      chainID,
		Event:        eventindexer.EventNameNameRegistered,
		Address:      from.Hex(),
		TransactedAt: time.Unix(int64(block.Time()), 0),
	})
	if err != nil {
		return errors.Wrap(err, "indxr.eventRepo.Save")
	}

	eventindexer.NameRegisteredEventsProcessed.Inc()

	return nil
}
