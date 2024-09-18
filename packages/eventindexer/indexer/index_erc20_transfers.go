package indexer

import (
	"context"
	"fmt"
	"math/big"
	"strings"

	"log/slog"

	"github.com/ethereum/go-ethereum"
	"github.com/ethereum/go-ethereum/accounts/abi"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/ethclient"
	"github.com/pkg/errors"
	"github.com/taikoxyz/taiko-mono/packages/eventindexer"
	"golang.org/x/sync/errgroup"
)

// nolint: lll
const erc20ABI = `[{"constant":true,"inputs":[],"name":"symbol","outputs":[{"name":"","type":"string"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[],"name":"decimals","outputs":[{"name":"","type":"uint8"}],"payable":false,"stateMutability":"view","type":"function"}]`

// nolint: lll
const transferEventABI = `[{"anonymous":false,"inputs":[{"indexed":true,"name":"from","type":"address"},{"indexed":true,"name":"to","type":"address"},{"indexed":false,"name":"value","type":"uint256"}],"name":"Transfer","type":"event"}]`

// indexERc20Transfers indexes from a given starting block to a given end block and parses all event logs
// to find ERC20 transfer events and update balances
func (i *Indexer) indexERC20Transfers(
	ctx context.Context,
	chainID *big.Int,
	logs []types.Log,
) error {
	wg, ctx := errgroup.WithContext(ctx)

	for _, vLog := range logs {
		l := vLog

		wg.Go(func() error {
			if !i.isERC20Transfer(ctx, l) {
				return nil
			}

			if err := i.saveERC20Transfer(ctx, chainID, l); err != nil {
				return err
			}

			return nil
		})
	}

	if err := wg.Wait(); err != nil {
		return err
	}

	return nil
}

// isERC20Transfer determines whether a given log is a valid ERC20 transfer event
func (i *Indexer) isERC20Transfer(_ context.Context, vLog types.Log) bool {
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
	if len(vLog.Topics) != 3 {
		return false
	}

	return true
}

// saveERC20Transfer updates the user's balances on the from and to of a ERC20 transfer event
func (i *Indexer) saveERC20Transfer(ctx context.Context, chainID *big.Int, vLog types.Log) error {
	from := fmt.Sprintf("0x%v", common.Bytes2Hex(vLog.Topics[1].Bytes()[12:]))

	to := fmt.Sprintf("0x%v", common.Bytes2Hex(vLog.Topics[2].Bytes()[12:]))

	event := struct {
		From  common.Address
		To    common.Address
		Value *big.Int
	}{}

	// Parse the Transfer event ABI
	parsedABI, err := abi.JSON(strings.NewReader(transferEventABI))
	if err != nil {
		return errors.Wrap(err, "abi.JSON(strings.NewReader")
	}

	err = parsedABI.UnpackIntoInterface(&event, "Transfer", vLog.Data)
	if err != nil {
		return errors.Wrap(err, "parsedABI.UnpackIntoInterface")
	}

	amount := event.Value.String()

	slog.Info(
		"erc20 transfer found",
		"from", from,
		"to", to,
		"amount", event.Value.String(),
		"contractAddress", vLog.Address.Hex(),
	)

	var pk int = 0

	i.contractToMetadataMutex.Lock()

	md, ok := i.contractToMetadata[vLog.Address]

	i.contractToMetadataMutex.Unlock()

	if !ok {
		md, err = i.erc20BalanceRepo.FindMetadata(ctx, chainID.Int64(), vLog.Address.Hex())
		if err != nil {
			return errors.Wrap(err, "i.erc20BalanceRepo")
		}
	}

	if md != nil {
		pk = md.ID

		i.contractToMetadataMutex.Lock()

		i.contractToMetadata[vLog.Address] = md

		i.contractToMetadataMutex.Unlock()
	}

	if pk == 0 {
		symbol, err := getERC20Symbol(ctx, i.ethClient, vLog.Address.Hex())
		if err != nil {
			// some erc20 dont have symbol method properly,
			// returns `invalid opcode`.
			if strings.Contains(err.Error(), "invalid opcode") {
				symbol = "ERC20"
			} else {
				return errors.Wrap(err, "getERC20Symbol")
			}
		}

		decimals, err := getERC20Decimals(ctx, i.ethClient, vLog.Address.Hex())
		if err != nil {
			return errors.Wrap(err, "getERC20Decimals")
		}

		pk, err = i.erc20BalanceRepo.CreateMetadata(ctx, chainID.Int64(), vLog.Address.Hex(), symbol, decimals)
		if err != nil {
			return errors.Wrap(err, "i.erc20BalanceRepo.CreateMetadata")
		}
	}

	// increment To address's balance
	// decrement From address's balance
	increaseOpts := eventindexer.UpdateERC20BalanceOpts{
		ERC20MetadataID: int64(pk),
		ChainID:         chainID.Int64(),
		Address:         to,
		ContractAddress: vLog.Address.Hex(),
		Amount:          amount,
	}

	decreaseOpts := eventindexer.UpdateERC20BalanceOpts{}

	// ignore zero address since that is usually the "mint"
	if from != ZeroAddress.Hex() {
		decreaseOpts = eventindexer.UpdateERC20BalanceOpts{
			ERC20MetadataID: int64(pk),
			ChainID:         chainID.Int64(),
			Address:         from,
			ContractAddress: vLog.Address.Hex(),
			Amount:          amount,
		}
	}

	_, _, err = i.erc20BalanceRepo.IncreaseAndDecreaseBalancesInTx(ctx, increaseOpts, decreaseOpts)
	if err != nil {
		return errors.Wrap(err, "i.erc20BalanceRepo.IncreaseAndDecreaseBalancesInTx")
	}

	return nil
}

func getERC20Symbol(ctx context.Context, client *ethclient.Client, contractAddress string) (string, error) {
	// Parse the contract address
	address := common.HexToAddress(contractAddress)

	// Parse the ERC20 contract ABI
	parsedABI, err := abi.JSON(strings.NewReader(erc20ABI))
	if err != nil {
		return "", errors.Wrap(err, "abi.JSON")
	}

	// Prepare the call message
	callData, err := parsedABI.Pack("symbol")
	if err != nil {
		return "", errors.Wrap(err, "parsedABI.Pack")
	}

	msg := ethereum.CallMsg{
		To:   &address,
		Data: callData,
	}

	result, err := client.CallContract(ctx, msg, nil)
	if err != nil {
		return "", errors.Wrap(err, "client.CallContract")
	}

	var symbol string

	err = parsedABI.UnpackIntoInterface(&symbol, "symbol", result)
	if err != nil {
		return "", errors.Wrap(err, "parsedABI.UnpackIntoInterface")
	}

	return symbol, nil
}

func getERC20Decimals(ctx context.Context, client *ethclient.Client, contractAddress string) (uint8, error) {
	// Parse the contract address
	address := common.HexToAddress(contractAddress)

	// Parse the ERC20 contract ABI
	parsedABI, err := abi.JSON(strings.NewReader(erc20ABI))
	if err != nil {
		return 0, err
	}

	// Prepare the call message
	callData, err := parsedABI.Pack("decimals")
	if err != nil {
		return 0, err
	}

	msg := ethereum.CallMsg{
		To:   &address,
		Data: callData,
	}

	result, err := client.CallContract(ctx, msg, nil)
	if err != nil {
		return 0, err
	}

	var decimals uint8

	err = parsedABI.UnpackIntoInterface(&decimals, "decimals", result)
	if err != nil {
		return 0, err
	}

	return decimals, nil
}
