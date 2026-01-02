package processor

import (
	"context"
	"encoding/json"
	"math/big"
	"testing"

	ethereum "github.com/ethereum/go-ethereum"
	"github.com/ethereum/go-ethereum/accounts/abi"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/stretchr/testify/assert"
	"github.com/taikoxyz/taiko-mono/packages/relayer/pkg/queue"
	shasta "github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/shasta"
)

type contractCallerStub struct {
	returnData []byte
	calls      int
}

func (s *contractCallerStub) CallContract(
	ctx context.Context,
	call ethereum.CallMsg,
	blockNumber *big.Int,
) ([]byte, error) {
	s.calls++
	return s.returnData, nil
}

func (s *contractCallerStub) CodeAt(
	ctx context.Context,
	contract common.Address,
	blockNumber *big.Int,
) ([]byte, error) {
	return []byte{0x1}, nil
}

func newBondInstructionEvent() *shasta.ShastaInboxClientBondInstructionCreated {
	return &shasta.ShastaInboxClientBondInstructionCreated{
		ProposalId: big.NewInt(1),
		BondInstruction: shasta.LibBondsBondInstruction{
			ProposalId: big.NewInt(1),
			BondType:   1,
			Payer:      common.HexToAddress("0x1111111111111111111111111111111111111111"),
			Payee:      common.HexToAddress("0x2222222222222222222222222222222222222222"),
		},
		Raw: types.Log{
			Address:     common.HexToAddress("0x3333333333333333333333333333333333333333"),
			Topics:      []common.Hash{common.HexToHash("0x01")},
			Data:        []byte{0x1},
			TxHash:      common.HexToHash("0x01"),
			BlockNumber: 1,
		},
	}
}

func TestProcessBondInstruction_ConfigErrorDoesNotRequeue(t *testing.T) {
	p := newTestProcessor(false)

	body := queue.QueueBondInstructionCreatedBody{
		Event: newBondInstructionEvent(),
	}

	marshaled, err := json.Marshal(body)
	assert.NoError(t, err)

	msg := queue.Message{Body: marshaled}

	shouldRequeue, _, err := p.processBondInstruction(context.Background(), msg)
	assert.ErrorContains(t, err, "bond manager not configured")
	assert.False(t, shouldRequeue)
}

func TestResolveBondInstructionSignal_UsesSignal(t *testing.T) {
	expected := common.HexToHash("0x0102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f20")
	msgBody := &queue.QueueBondInstructionCreatedBody{Signal: expected.Hex()}

	signal, signalHex, err := (&Processor{}).resolveBondInstructionSignal(context.Background(), msgBody)

	assert.NoError(t, err)
	assert.Equal(t, expected, common.Hash(signal))
	assert.Equal(t, expected.Hex(), signalHex)
}

func TestResolveBondInstructionSignal_CallsInbox(t *testing.T) {
	expected := [32]byte{0x42}
	byte32Type, err := abi.NewType("bytes32", "", nil)
	assert.NoError(t, err)

	returnData, err := abi.Arguments{{Type: byte32Type}}.Pack(expected)
	assert.NoError(t, err)

	caller := &contractCallerStub{returnData: returnData}
	p := &Processor{srcContractCaller: caller}

	signal, signalHex, err := p.resolveBondInstructionSignal(context.Background(), &queue.QueueBondInstructionCreatedBody{
		Event: newBondInstructionEvent(),
	})

	assert.NoError(t, err)
	assert.Equal(t, expected, signal)
	assert.Equal(t, common.Hash(expected).Hex(), signalHex)
	assert.Equal(t, 1, caller.calls)
}
