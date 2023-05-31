package relayer

import (
	"context"
	"fmt"
	"math/big"
	"time"

	"github.com/ethereum/go-ethereum"
	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/pkg/errors"
	log "github.com/sirupsen/logrus"
	"github.com/taikoxyz/taiko-mono/packages/relayer/contracts/bridge"
	"github.com/taikoxyz/taiko-mono/packages/relayer/contracts/tokenvault"
)

var (
	ZeroHash    = common.HexToHash("0x0000000000000000000000000000000000000000000000000000000000000000")
	ZeroAddress = common.HexToAddress("0x0000000000000000000000000000000000000000")
)

// IsInSlice determines whether v is in slice s
func IsInSlice[T comparable](v T, s []T) bool {
	for _, e := range s {
		if v == e {
			return true
		}
	}

	return false
}

type confirmer interface {
	TransactionReceipt(ctx context.Context, txHash common.Hash) (*types.Receipt, error)
	BlockNumber(ctx context.Context) (uint64, error)
}

// WaitReceipt keeps waiting until the given transaction has an execution
// receipt to know whether it was reverted or not.
func WaitReceipt(ctx context.Context, confirmer confirmer, txHash common.Hash) (*types.Receipt, error) {
	ticker := time.NewTicker(time.Second)
	defer ticker.Stop()

	log.Infof("waiting for transaction receipt for txHash %v", txHash.Hex())

	for {
		select {
		case <-ctx.Done():
			return nil, ctx.Err()
		case <-ticker.C:
			receipt, err := confirmer.TransactionReceipt(ctx, txHash)
			if err != nil {
				continue
			}

			if receipt.Status != types.ReceiptStatusSuccessful {
				return nil, fmt.Errorf("transaction reverted, hash: %s", txHash)
			}

			log.Infof("transaction receipt found for txHash %v", txHash.Hex())

			return receipt, nil
		}
	}
}

// WaitConfirmations won't return before N blocks confirmations have been seen
// on destination chain.
func WaitConfirmations(ctx context.Context, confirmer confirmer, confirmations uint64, txHash common.Hash) error {
	log.Infof("txHash %v beginning waiting for confirmations", txHash.Hex())

	ticker := time.NewTicker(10 * time.Second)

	defer ticker.Stop()

	for {
		select {
		case <-ctx.Done():
			return ctx.Err()
		case <-ticker.C:
			receipt, err := confirmer.TransactionReceipt(ctx, txHash)
			if err != nil {
				if err == ethereum.NotFound {
					continue
				}

				log.Errorf("txHash: %v encountered error getting receipt: %v", txHash.Hex(), err)

				return err
			}

			latest, err := confirmer.BlockNumber(ctx)
			if err != nil {
				return err
			}

			want := receipt.BlockNumber.Uint64() + confirmations
			log.Infof(
				"txHash: %v waiting for %v confirmations which will happen in block number: %v, latestBlockNumber: %v",
				txHash.Hex(),
				confirmations,
				want,
				latest,
			)

			if latest < receipt.BlockNumber.Uint64()+confirmations {
				continue
			}

			log.Infof("txHash %v received %v confirmations, done", txHash.Hex(), confirmations)

			return nil
		}
	}
}

func DecodeMessageSentData(event *bridge.BridgeMessageSent) (EventType, *CanonicalToken, *big.Int, error) {
	eventType := EventTypeSendETH

	var canonicalToken CanonicalToken

	var amount *big.Int

	if event.Message.Data != nil && common.BytesToHash(event.Message.Data) != ZeroHash {
		tokenVaultMD := bind.MetaData{
			ABI: tokenvault.TokenVaultABI,
		}

		tokenVaultABI, err := tokenVaultMD.GetAbi()
		if err != nil {
			return eventType, nil, big.NewInt(0), errors.Wrap(err, "tokenVaultMD.GetAbi()")
		}

		method, err := tokenVaultABI.MethodById(event.Message.Data[:4])
		if err != nil {
			return eventType, nil, big.NewInt(0), errors.Wrap(err, "tokenVaultABI.MethodById")
		}

		inputsMap := make(map[string]interface{})

		if err := method.Inputs.UnpackIntoMap(inputsMap, event.Message.Data[4:]); err != nil {
			return eventType, nil, big.NewInt(0), errors.Wrap(err, "method.Inputs.UnpackIntoMap")
		}

		if method.Name == "receiveERC20" {
			eventType = EventTypeSendERC20

			canonicalToken = inputsMap["canonicalToken"].(struct {
				// nolint
				ChainId  *big.Int       `json:"chainId"`
				Addr     common.Address `json:"addr"`
				Decimals uint8          `json:"decimals"`
				Symbol   string         `json:"symbol"`
				Name     string         `json:"name"`
			})

			amount = inputsMap["amount"].(*big.Int)
		}
	} else {
		amount = event.Message.DepositValue
	}

	return eventType, &canonicalToken, amount, nil
}

type CanonicalToken struct {
	// nolint
	ChainId  *big.Int       `json:"chainId"`
	Addr     common.Address `json:"addr"`
	Decimals uint8          `json:"decimals"`
	Symbol   string         `json:"symbol"`
	Name     string         `json:"name"`
}

type EthClient interface {
	BlockNumber(ctx context.Context) (uint64, error)
	ChainID(ctx context.Context) (*big.Int, error)
}
