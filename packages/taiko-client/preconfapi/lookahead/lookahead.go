package lookahead

import (
	"context"
	"crypto/ecdsa"
	"errors"
	"fmt"
	"math/big"
	"strings"
	"time"

	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/rpc"
)

type Lookahead struct {
	preconfTaskManagerAddress common.Address
	preconfTaskManager        *bindings.PreconfTaskManager
	ethClient                 *rpc.EthClient
	beaconClient              *rpc.BeaconClient
	genesisTime               uint64
	genesisSlot               uint64
	secondsPerSlot            uint64
	slotsPerEpoch             uint64
	privateKey                *ecdsa.PrivateKey
}

func NewLookahead(
	preconfTaskManagerAddress common.Address,
	ethClient *rpc.EthClient,
	beaconClient *rpc.BeaconClient,
	genesisTime uint64,
	genesisSlot uint64,
	secondsPerSlot uint64,
	slotsPerEpoch uint64,
	privateKey *ecdsa.PrivateKey,
) (*Lookahead, error) {
	// Create an instance of the contract
	preconfTaskManager, err := bindings.NewPreconfTaskManager(preconfTaskManagerAddress, ethClient)
	if err != nil {
		return nil, err
	}

	return &Lookahead{
		preconfTaskManagerAddress,
		preconfTaskManager,
		ethClient,
		beaconClient,
		genesisTime,
		genesisSlot,
		secondsPerSlot,
		slotsPerEpoch,
		privateKey,
	}, nil
}

func (l *Lookahead) ForcePushLookahead(ctx context.Context) error {
	auth, err := bind.NewKeyedTransactorWithChainID(l.privateKey, l.ethClient.ChainID)
	if err != nil {
		return err
	}

	// Set the context if needed
	auth.Context = ctx

	params, err := l.GetLookaheadSetParams(ctx)
	if err != nil {
		return err
	}

	tx, err := l.preconfTaskManager.ForcePushLookahead(auth, params)
	if err != nil {
		return err
	}

	_, err = l.waitReceipt(ctx, tx.Hash())

	return err
}
func (l *Lookahead) GetLookaheadSetParams(ctx context.Context) ([]bindings.IPreconfTaskManagerLookaheadSetParam, error) {
	nextEpoch, err := l.getNextEpoch()
	if err != nil {
		return nil, err
	}

	duties, err := l.beaconClient.GetProposerDuties(ctx, nextEpoch)
	if err != nil {
		return nil, err
	}

	validatorPubKeys := [32][]byte{}

	for i, d := range duties {
		validatorPubKeys[i] = common.Hex2Bytes(d.Pubkey)
	}

	epochBeginTimestamp := l.startOfSlot(nextEpoch)

	return l.preconfTaskManager.GetLookaheadParamsForEpoch(&bind.CallOpts{
		Context: ctx,
	},
		epochBeginTimestamp,
		validatorPubKeys,
	)
}

func (l *Lookahead) startOfSlot(nextEpoch *big.Int) *big.Int {
	slot := (nextEpoch.Uint64() * l.slotsPerEpoch) - l.genesisSlot

	unadjustedSlotDuration := slot * l.secondsPerSlot

	return new(big.Int).Add(new(big.Int).SetUint64(l.genesisTime), new(big.Int).SetUint64(unadjustedSlotDuration))
}

func (l *Lookahead) IsLookaheadRequired() (bool, error) {
	nextEpoch, err := l.getNextEpoch()
	if err != nil {
		return false, err
	}

	return l.preconfTaskManager.IsLookaheadRequired(&bind.CallOpts{}, nextEpoch)
}

func (l *Lookahead) GetLookaheadBuffer(preconferAddress common.Address) (uint64, error) {
	// Get the lookahead buffer
	buffer, err := l.preconfTaskManager.GetLookaheadBuffer(&bind.CallOpts{
		Context: context.Background(),
	})
	if err != nil {
		return 0, err
	}

	// Get the current timestamp
	currentTimestamp := uint64(time.Now().Unix())

	// Iterate through the buffer to find the correct entry
	lookaheadPointer := ^uint64(0) // Default to max uint64 value to signify not found
	for i, entry := range buffer {
		if strings.EqualFold(entry.Preconfer.Hex(), preconferAddress.Hex()) &&
			currentTimestamp > entry.PrevTimestamp.Uint64() &&
			currentTimestamp <= entry.Timestamp.Uint64() {
			lookaheadPointer = uint64(i)
			break
		}
	}

	if lookaheadPointer == ^uint64(0) {
		return 0, errors.New("lookahead pointer not found")
	}

	return lookaheadPointer, nil
}

func (l *Lookahead) getNextEpoch() (*big.Int, error) {
	currentSlot, err := l.getCurrentSlot()
	if err != nil {
		return big.NewInt(0), err
	}

	return new(big.Int).SetUint64((currentSlot / l.slotsPerEpoch) + 1), nil
}

func (l *Lookahead) getCurrentSlot() (uint64, error) {
	currentTimestamp := uint64(time.Now().Unix())
	return l.timeToSlot(currentTimestamp)
}

// timeToSlot returns the slots of the given timestamp.
func (l *Lookahead) timeToSlot(timestamp uint64) (uint64, error) {
	if timestamp < l.genesisTime {
		return 0, fmt.Errorf("provided timestamp (%v) precedes genesis time (%v)", timestamp, l.genesisTime)
	}
	return (timestamp - l.genesisTime) / l.secondsPerSlot, nil
}

func (l *Lookahead) waitReceipt(ctx context.Context, txHash common.Hash) (*types.Receipt, error) {
	ticker := time.NewTicker(time.Second)
	defer ticker.Stop()

	for {
		select {
		case <-ctx.Done():
			return nil, ctx.Err()
		case <-ticker.C:
			receipt, err := l.ethClient.TransactionReceipt(ctx, txHash)
			if err != nil {
				continue
			}

			if receipt.Status != types.ReceiptStatusSuccessful {
				return nil, fmt.Errorf("transaction reverted, hash: %s", txHash)
			}

			return receipt, nil
		}
	}
}
