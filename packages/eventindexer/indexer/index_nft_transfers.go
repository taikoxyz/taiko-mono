package indexer

import (
	"context"
	"math/big"

	"github.com/ethereum/go-ethereum"
	"github.com/ethereum/go-ethereum/crypto"
	log "github.com/sirupsen/logrus"
	"github.com/taikoxyz/taiko-mono/packages/eventindexer"
)

// indexNftTransfers indexes ERC721s only right now.
func (svc *Service) indexNftTransfers(
	ctx context.Context,
	chainID *big.Int,
	start uint64,
	end uint64,
) error {
	query := ethereum.FilterQuery{
		FromBlock: big.NewInt(int64(start)),
		ToBlock:   big.NewInt(int64(end)),
	}

	logs, err := svc.ethClient.FilterLogs(ctx, query)
	if err != nil {
		return err
	}

	logTransferSignature := []byte("Transfer(address,address,uint256)")
	logTransferSigHash := crypto.Keccak256Hash(logTransferSignature)

	for _, vLog := range logs {
		if vLog.Removed {
			continue
		}

		// malformed event
		if len(vLog.Topics) == 0 {
			continue
		}

		// the first topic is ALWAYS the hash of the event signature.
		// this is how peopel are expected to look up which event is which.
		if vLog.Topics[0].Hex() != logTransferSigHash.Hex() {
			continue
		}

		// erc20 transfer length will be 3, nft will be 4, only way to
		// differentiate them
		if len(vLog.Topics) != 4 {
			continue
		}

		blockNum := int64(vLog.BlockNumber)

		to := vLog.Topics[2].Hex()

		tokenID := vLog.Topics[3].Big().Int64()

		from := vLog.Topics[1].Hex()

		log.Infof(
			"erc721 transfer found. from: %v, to: %v, tokenId: %v, contractAddress: %v",
			from,
			to,
			tokenID,
			vLog.Address.Hex(),
		)

		_, err = svc.eventRepo.Save(ctx, eventindexer.SaveEventOpts{
			Name:    eventindexer.EventNameNFTTransfer,
			Data:    string(vLog.Data),
			ChainID: chainID,
			Event:   eventindexer.EventNameNFTTransfer,
			Address: from,
			To:      &to,
			BlockID: &blockNum,
			TokenID: &tokenID,
		},
		)
		if err != nil {
			return err
		}

		// increment To address's balance

		_, err = svc.nftBalanceRepo.IncreaseBalance(ctx, eventindexer.UpdateNFTBalanceOpts{
			ChainID:         chainID.Int64(),
			Address:         to,
			TokenID:         tokenID,
			ContractAddress: vLog.Address.Hex(),
			ContractType:    "ERC721",
			Amount:          1, // ERC721 is always 1
		})
		if err != nil {
			return err
		}

		// decrement From address's balance
		_, err = svc.nftBalanceRepo.IncreaseBalance(ctx, eventindexer.UpdateNFTBalanceOpts{
			ChainID:         chainID.Int64(),
			Address:         from,
			TokenID:         tokenID,
			ContractAddress: vLog.Address.Hex(),
			ContractType:    "ERC721",
			Amount:          1, // ERC721 is always 1
		})
		if err != nil {
			return err
		}
	}

	return nil
}
