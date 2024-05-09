package guardianproverheartbeater

import (
	"context"
	"crypto/ecdsa"
	"fmt"
	"math/big"
	"net/url"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/crypto"
	"github.com/ethereum/go-ethereum/log"
	"github.com/go-resty/resty/v2"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/rpc"
)

// healthCheckReq is the request body sent to the health check server when a heartbeat is sent.
type healthCheckReq struct {
	ProverAddress      string `json:"prover"`
	HeartBeatSignature []byte `json:"heartBeatSignature"`
	LatestL1Block      uint64 `json:"latestL1Block"`
	LatestL2Block      uint64 `json:"latestL2Block"`
}

// signedBlockReq is the request body sent to the health check server when a block is signed.
type signedBlockReq struct {
	BlockID   uint64         `json:"blockID"`
	BlockHash string         `json:"blockHash"`
	Signature []byte         `json:"signature"`
	Prover    common.Address `json:"proverAddress"`
}

// startupReq is the request body send to the health check server when the guardian prover starts up.
type startupReq struct {
	ProverAddress   string `json:"prover"`
	GuardianVersion string `json:"guardianVersion"`
	L1NodeVersion   string `json:"l1NodeVersion"`
	L2NodeVersion   string `json:"l2NodeVersion"`
	Revision        string `json:"revision"`
	Signature       []byte `json:"signature"`
}

// GuardianProverHeartBeater is responsible for signing and sending known blocks to the health check server.
type GuardianProverHeartBeater struct {
	privateKey                *ecdsa.PrivateKey
	healthCheckServerEndpoint *url.URL
	rpc                       *rpc.Client
	proverAddress             common.Address
}

// New creates a new GuardianProverBlockSender instance.
func New(
	privateKey *ecdsa.PrivateKey,
	healthCheckServerEndpoint *url.URL,
	rpc *rpc.Client,
	proverAddress common.Address,
) *GuardianProverHeartBeater {
	return &GuardianProverHeartBeater{
		privateKey:                privateKey,
		healthCheckServerEndpoint: healthCheckServerEndpoint,
		rpc:                       rpc,
		proverAddress:             proverAddress,
	}
}

// post sends the given POST request to the health check server.
func (s *GuardianProverHeartBeater) post(ctx context.Context, route string, req interface{}) error {
	resp, err := resty.New().R().
		SetContext(ctx).
		SetHeader("Content-Type", "application/json").
		SetHeader("Accept", "application/json").
		SetBody(req).
		Post(fmt.Sprintf("%v/%v", s.healthCheckServerEndpoint.String(), route))
	if err != nil {
		return err
	}

	if !resp.IsSuccess() {
		return fmt.Errorf(
			"unable to contact health check server endpoint, status code: %v",
			resp.StatusCode(),
		)
	}

	return nil
}

// SignAndSendBlock signs the given block and sends it to the health check server.
func (s *GuardianProverHeartBeater) SignAndSendBlock(ctx context.Context, blockID *big.Int) error {
	signed, header, err := s.signBlock(ctx, blockID)
	if err != nil {
		return nil
	}

	if signed == nil {
		return nil
	}

	if err := s.sendSignedBlockReq(ctx, signed, header.Hash(), blockID); err != nil {
		return err
	}

	return nil
}

// SendStartupMessage sends the startup message to the health check server.
func (s *GuardianProverHeartBeater) SendStartupMessage(
	ctx context.Context,
	revision string,
	version string,
	l1NodeVersion string,
	l2NodeVersion string,
) error {
	if s.healthCheckServerEndpoint == nil {
		log.Warn("No health check server endpoint set, returning early")
		return nil
	}

	sig, err := crypto.Sign(
		crypto.Keccak256Hash(
			s.proverAddress.Bytes(),
			[]byte(revision),
			[]byte(version),
			[]byte(l1NodeVersion),
			[]byte(l2NodeVersion),
		).Bytes(),
		s.privateKey)
	if err != nil {
		return err
	}

	if err := s.post(ctx, "startup", &startupReq{
		Revision:        revision,
		GuardianVersion: version,
		L1NodeVersion:   l1NodeVersion,
		L2NodeVersion:   l2NodeVersion,
		ProverAddress:   s.proverAddress.Hex(),
		Signature:       sig,
	}); err != nil {
		return err
	}

	log.Info(
		"Guardian prover successfully sent the startup message",
		"l1NodeVersion", l1NodeVersion,
		"l2NodeVersion", l2NodeVersion,
	)

	return nil
}

// sendSignedBlockReq is the actual method that sends the signed block to the health check server.
func (s *GuardianProverHeartBeater) sendSignedBlockReq(
	ctx context.Context,
	signed []byte,
	hash common.Hash,
	blockID *big.Int,
) error {
	if s.healthCheckServerEndpoint == nil {
		log.Info("No health check server endpoint set, returning early")
		return nil
	}

	req := &signedBlockReq{
		BlockID:   blockID.Uint64(),
		BlockHash: hash.Hex(),
		Signature: signed,
		Prover:    s.proverAddress,
	}

	if err := s.post(ctx, "signedBlock", req); err != nil {
		return err
	}

	log.Info("Guardian prover successfully signed block", "blockID", blockID.Uint64())

	return nil
}

// signBlock signs the given block and returns the signature and header.
func (s *GuardianProverHeartBeater) signBlock(ctx context.Context, blockID *big.Int) ([]byte, *types.Header, error) {
	log.Info("Guardian prover signing block", "blockID", blockID.Uint64())

	head, err := s.rpc.L2.BlockNumber(ctx)
	if err != nil {
		return nil, nil, err
	}

	for head < blockID.Uint64() {
		log.Info(
			"Guardian prover block signing waiting for chain",
			"latestBlock", head,
			"eventBlockID", blockID.Uint64(),
		)

		if _, err := s.rpc.WaitL2Header(ctx, blockID); err != nil {
			return nil, nil, err
		}

		head, err = s.rpc.L2.BlockNumber(ctx)
		if err != nil {
			return nil, nil, err
		}
	}

	header, err := s.rpc.L2.HeaderByNumber(ctx, blockID)
	if err != nil {
		return nil, nil, err
	}

	log.Info(
		"Guardian prover block signing caught up",
		"latestBlock", head,
		"eventBlockID", blockID.Uint64(),
	)

	signed, err := crypto.Sign(header.Hash().Bytes(), s.privateKey)
	if err != nil {
		return nil, nil, err
	}

	return signed, header, nil
}

// SendHeartbeat sends a heartbeat to the health check server.
func (s *GuardianProverHeartBeater) SendHeartbeat(
	ctx context.Context,
	latestL1Block uint64,
	latestL2Block uint64,
) error {
	sig, err := crypto.Sign(crypto.Keccak256Hash([]byte("HEART_BEAT")).Bytes(), s.privateKey)
	if err != nil {
		return err
	}

	req := &healthCheckReq{
		HeartBeatSignature: sig,
		ProverAddress:      s.proverAddress.Hex(),
		LatestL1Block:      latestL1Block,
		LatestL2Block:      latestL2Block,
	}

	if err := s.post(ctx, "healthCheck", req); err != nil {
		return err
	}

	log.Info("Successfully sent heartbeat", "signature", common.Bytes2Hex(sig))

	return nil
}
