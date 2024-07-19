package indexer

import (
	"context"
	"fmt"
	"math/big"
	"strings"

	"log/slog"

	"github.com/ethereum/go-ethereum/accounts/abi"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/crypto"
	"github.com/pkg/errors"
	"github.com/taikoxyz/taiko-mono/packages/eventindexer"
	"github.com/taikoxyz/taiko-mono/packages/eventindexer/contracts/erc1155"
	"golang.org/x/sync/errgroup"
)

var (
	logTransferSignature        = []byte("Transfer(address,address,uint256)")
	logTransferSigHash          = crypto.Keccak256Hash(logTransferSignature)
	transferSingleSignature     = []byte("TransferSingle(address,address,address,uint256,uint256)")
	transferSingleSignatureHash = crypto.Keccak256Hash(transferSingleSignature)
	transferBatchSignature      = []byte("TransferBatch(address,address,address,uint256[],uint256[])")
	transferBatchSignatureHash  = crypto.Keccak256Hash(transferBatchSignature)
)

// indexNFTTransfers indexes from a given starting block to a given end block and parses all event logs
// to find ERC721 or ERC1155 transfer events
func (i *Indexer) indexNFTTransfers(
	ctx context.Context,
	chainID *big.Int,
	logs []types.Log,
) error {
	nftWg, ctx := errgroup.WithContext(ctx)

	for _, vLog := range logs {
		l := vLog

		nftWg.Go(func() error {
			if !i.isERC721Transfer(ctx, l) && !i.isERC1155Transfer(ctx, l) {
				return nil
			}

			if err := i.saveNFTTransfer(ctx, chainID, l); err != nil {
				return errors.Wrap(err, "i.saveNFTTransfer")
			}

			return nil
		})
	}

	if err := nftWg.Wait(); err != nil {
		return err
	}

	return nil
}

// isERC1155Transfer determines whether a given log is a valid ERC1155 transfer event
func (i *Indexer) isERC1155Transfer(_ context.Context, vLog types.Log) bool {
	// malformed event
	if len(vLog.Topics) == 0 {
		return false
	}

	// the first topic is ALWAYS the hash of the event signature.
	// this is how people are expected to look up which event is which.
	if vLog.Topics[0].Hex() != transferSingleSignatureHash.Hex() &&
		vLog.Topics[0].Hex() != transferBatchSignatureHash.Hex() {
		return false
	}

	return true
}

// isERC721Transfer determines whether a given log is a valid ERC721 transfer event
func (i *Indexer) isERC721Transfer(ctx context.Context, vLog types.Log) bool {
	// malformed event
	if len(vLog.Topics) == 0 {
		return false
	}

	// the first topic is ALWAYS the hash of the event signature.
	// this is how people are expected to look up which event is which.
	if vLog.Topics[0].Hex() != logTransferSigHash.Hex() {
		return false
	}

	// erc20 transfer length will be 3, nft will be 4, only way to
	// differentiate them
	if len(vLog.Topics) != 4 {
		return false
	}

	return true
}

// saveNFTTransfer parses the event logs and saves either an ERC721 or ERC1155 event, updating
// users balances
func (i *Indexer) saveNFTTransfer(ctx context.Context, chainID *big.Int, vLog types.Log) error {
	if i.isERC721Transfer(ctx, vLog) {
		return i.saveERC721Transfer(ctx, chainID, vLog)
	}

	if i.isERC1155Transfer(ctx, vLog) {
		return i.saveERC1155Transfer(ctx, chainID, vLog)
	}

	return errors.New("nftTransferVlog not ERC721 or ERC1155")
}

// saveERC721Transfer updates the user's balances on the from and to of a ERC721 transfer event
func (i *Indexer) saveERC721Transfer(ctx context.Context, chainID *big.Int, vLog types.Log) error {
	from := fmt.Sprintf("0x%v", common.Bytes2Hex(vLog.Topics[1].Bytes()[12:]))
	to := fmt.Sprintf("0x%v", common.Bytes2Hex(vLog.Topics[2].Bytes()[12:]))
	tokenID := vLog.Topics[3].Big().Int64()

	slog.Info(
		"erc721 transfer found",
		"from", from,
		"to", to,
		"tokenID", tokenID,
		"contractAddress", vLog.Address.Hex(),
	)

	var pk int = 0

	// Check if metadata already exists in db, if not fetch and store
	metadata, err := i.nftMetadataRepo.GetNFTMetadata(ctx, vLog.Address.Hex(), tokenID, chainID.Int64())
	if err != nil {
		return err
	}

	if metadata != nil {
		pk = metadata.ID
	}

	if pk == 0 {
		metadata, err = i.fetchERC721Metadata(ctx, vLog.Address.Hex(), vLog.Topics[3].Big(), chainID)
		if err != nil {
			slog.Warn("error fetching metadata. setting defaults",
				"contractAddress", vLog.Address.Hex(), "error", err.Error())
		}

		if metadata == nil {
			metadata = &eventindexer.NFTMetadata{
				ChainID:         chainID.Int64(),
				ContractAddress: vLog.Address.Hex(),
				TokenID:         tokenID,
				Name:            "invalid_metadata",
			}

			metadata, err = i.nftMetadataRepo.SaveNFTMetadata(ctx, metadata)
			if err != nil {
				return errors.Wrap(err, "i.nftMetadataRepo.SaveNFTMetadata")
			}
		}
		pk = metadata.ID
	}

	// increment To address's balance
	// decrement From address's balance
	increaseOpts := eventindexer.UpdateNFTBalanceOpts{
		ChainID:         chainID.Int64(),
		NftMetadataId:   int64(pk),
		Address:         to,
		TokenID:         tokenID,
		ContractAddress: vLog.Address.Hex(),
		ContractType:    "ERC721",
		Amount:          1, // ERC721 is always 1
	}
	decreaseOpts := eventindexer.UpdateNFTBalanceOpts{}

	// ignore zero address since that is usually the "mint"
	if from != ZeroAddress.Hex() {
		decreaseOpts = eventindexer.UpdateNFTBalanceOpts{
			ChainID:         chainID.Int64(),
			NftMetadataId:   int64(pk),
			Address:         from,
			TokenID:         tokenID,
			ContractAddress: vLog.Address.Hex(),
			ContractType:    "ERC721",
			Amount:          1, // ERC721 is always 1
		}
	}

	_, _, err = i.nftBalanceRepo.IncreaseAndDecreaseBalancesInTx(ctx, increaseOpts, decreaseOpts)
	if err != nil {
		return err
	}

	return nil
}

// saveERC1155Transfer parses and saves either a TransferSingle or TransferBatch event to
// the database and updates the user's balances
func (i *Indexer) saveERC1155Transfer(ctx context.Context, chainID *big.Int, vLog types.Log) error {
	from := fmt.Sprintf("0x%v", common.Bytes2Hex(vLog.Topics[2].Bytes()[12:]))
	to := fmt.Sprintf("0x%v", common.Bytes2Hex(vLog.Topics[3].Bytes()[12:]))

	slog.Info("erc1155 found")

	erc1155ABI, err := abi.JSON(strings.NewReader(erc1155.ABI))
	if err != nil {
		return err
	}

	if vLog.Topics[0].Hex() == transferSingleSignatureHash.Hex() {
		slog.Info("erc1155 transfer single")

		type TransferSingleEvent struct {
			Operator common.Address
			From     common.Address
			To       common.Address
			Id       *big.Int
			Value    *big.Int
		}

		var t TransferSingleEvent

		err = erc1155ABI.UnpackIntoInterface(&t, "TransferSingle", []byte(vLog.Data))
		if err != nil {
			return err
		}

		var pk int = 0

		// Check if metadata already exists in db, if not fetch and store
		metadata, err := i.nftMetadataRepo.GetNFTMetadata(ctx, vLog.Address.Hex(), t.Id.Int64(), chainID.Int64())
		if err != nil {
			return err
		}

		if metadata != nil {
			pk = metadata.ID
		}

		if pk == 0 {
			metadata, err = i.fetchERC1155Metadata(ctx, vLog.Address.Hex(), t.Id, chainID)
			if err != nil {
				slog.Warn("error fetching metadata. setting defaults",
					"contractAddress", vLog.Address.Hex(), "error", err.Error())
			}

			if metadata == nil {
				metadata = &eventindexer.NFTMetadata{
					ChainID:         chainID.Int64(),
					ContractAddress: vLog.Address.Hex(),
					TokenID:         t.Id.Int64(),
					Name:            "invalid_metadata",
				}

				metadata, err = i.nftMetadataRepo.SaveNFTMetadata(ctx, metadata)
				if err != nil {
					return errors.Wrap(err, "i.nftMetadataRepo.SaveNFTMetadata")
				}
			}

			pk = metadata.ID
		}

		increaseOpts := eventindexer.UpdateNFTBalanceOpts{
			ChainID:         chainID.Int64(),
			NftMetadataId:   int64(pk),
			Address:         to,
			TokenID:         t.Id.Int64(),
			ContractAddress: vLog.Address.Hex(),
			ContractType:    "ERC1155",
			Amount:          t.Value.Int64(),
		}
		decreaseOpts := eventindexer.UpdateNFTBalanceOpts{}

		if from != ZeroAddress.Hex() {
			// decrement From address's balance
			decreaseOpts = eventindexer.UpdateNFTBalanceOpts{
				ChainID:         chainID.Int64(),
				NftMetadataId:   int64(pk),
				Address:         from,
				TokenID:         t.Id.Int64(),
				ContractAddress: vLog.Address.Hex(),
				ContractType:    "ERC1155",
				Amount:          t.Value.Int64(),
			}
		}

		_, _, err = i.nftBalanceRepo.IncreaseAndDecreaseBalancesInTx(ctx, increaseOpts, decreaseOpts)
		if err != nil {
			return err
		}
	} else if vLog.Topics[0].Hex() == transferBatchSignatureHash.Hex() {
		type TransferBatchEvent struct {
			Operator common.Address
			From     common.Address
			To       common.Address
			Ids      []*big.Int
			Values   []*big.Int
		}

		var t TransferBatchEvent

		err = erc1155ABI.UnpackIntoInterface(&t, "TransferBatch", []byte(vLog.Data))
		if err != nil {
			return err
		}

		for idx, id := range t.Ids {
			var pk int = 0

			// Check if metadata already exists in db, if not fetch and store
			metadata, err := i.nftMetadataRepo.GetNFTMetadata(ctx, vLog.Address.Hex(), id.Int64(), chainID.Int64())
			if err != nil {
				return err
			}

			if metadata != nil {
				pk = metadata.ID
			}

			if pk == 0 {
				metadata, err = i.fetchERC1155Metadata(ctx, vLog.Address.Hex(), id, chainID)
				if err != nil {
					return err
				}

				if metadata == nil {
					metadata = &eventindexer.NFTMetadata{
						ChainID:         chainID.Int64(),
						ContractAddress: vLog.Address.Hex(),
						TokenID:         id.Int64(),
						Name:            "invalid_metadata",
					}

					metadata, err = i.nftMetadataRepo.SaveNFTMetadata(ctx, metadata)
					if err != nil {
						return errors.Wrap(err, "i.nftMetadataRepo.SaveNFTMetadata")
					}
				}

				pk = metadata.ID
			}

			increaseOpts := eventindexer.UpdateNFTBalanceOpts{
				ChainID:         chainID.Int64(),
				NftMetadataId:   int64(pk),
				Address:         to,
				TokenID:         id.Int64(),
				ContractAddress: vLog.Address.Hex(),
				ContractType:    "ERC1155",
				Amount:          t.Values[idx].Int64(),
			}
			decreaseOpts := eventindexer.UpdateNFTBalanceOpts{}

			if from != ZeroAddress.Hex() {
				// decrement From address's balance
				decreaseOpts = eventindexer.UpdateNFTBalanceOpts{
					ChainID:         chainID.Int64(),
					NftMetadataId:   int64(pk),
					Address:         from,
					TokenID:         id.Int64(),
					ContractAddress: vLog.Address.Hex(),
					ContractType:    "ERC1155",
					Amount:          t.Values[idx].Int64(),
				}
			}

			_, _, err = i.nftBalanceRepo.IncreaseAndDecreaseBalancesInTx(ctx, increaseOpts, decreaseOpts)
			if err != nil {
				return err
			}
		}
	}
	// increment To address's balance

	return nil
}
