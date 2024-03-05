package guardianproversender

import (
	"bytes"
	"context"
	"crypto/ecdsa"
	"encoding/json"
	"fmt"
	"math/big"
	"net/http"
	"net/url"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/crypto"
	"github.com/ethereum/go-ethereum/ethdb"
	"github.com/ethereum/go-ethereum/log"

	"github.com/taikoxyz/taiko-client/pkg/rpc"
	"github.com/taikoxyz/taiko-client/prover/db"
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

// GuardianProverBlockSender is responsible for signing and sending known blocks to the health check server.
type GuardianProverBlockSender struct {
	privateKey                *ecdsa.PrivateKey
	healthCheckServerEndpoint *url.URL
	db                        ethdb.KeyValueStore
	rpc                       *rpc.Client
	proverAddress             common.Address
}

// New creates a new GuardianProverBlockSender instance.
func New(
	privateKey *ecdsa.PrivateKey,
	healthCheckServerEndpoint *url.URL,
	db ethdb.KeyValueStore,
	rpc *rpc.Client,
	proverAddress common.Address,
) *GuardianProverBlockSender {
	return &GuardianProverBlockSender{
		privateKey:                privateKey,
		healthCheckServerEndpoint: healthCheckServerEndpoint,
		db:                        db,
		rpc:                       rpc,
		proverAddress:             proverAddress,
	}
}

// post sends the given POST request to the health check server.
func (s *GuardianProverBlockSender) post(ctx context.Context, route string, req interface{}) error {
	body, err := json.Marshal(req)
	if err != nil {
		return err
	}

	resp, err := http.Post(
		fmt.Sprintf("%v/%v", s.healthCheckServerEndpoint.String(), route),
		"application/json",
		bytes.NewBuffer(body),
	)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf(
			"unable to contact health check server endpoint, status code: %v", resp.StatusCode,
		)
	}

	return nil
}

// SignAndSendBlock signs the given block and sends it to the health check server.
func (s *GuardianProverBlockSender) SignAndSendBlock(ctx context.Context, blockID *big.Int) error {
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

	return s.db.Put(
		db.BuildBlockKey(header.Time, header.Number.Uint64()),
		db.BuildBlockValue(header.Hash().Bytes(),
			signed,
			blockID,
		),
	)
}

func (s *GuardianProverBlockSender) SendStartup(
	ctx context.Context,
	revision string,
	version string,
	l1NodeVersion string,
	l2NodeVersion string,
) error {
	if s.healthCheckServerEndpoint == nil {
		log.Info("No health check server endpoint set, returning early")
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

	req := &startupReq{
		Revision:        revision,
		GuardianVersion: version,
		L1NodeVersion:   l1NodeVersion,
		L2NodeVersion:   l2NodeVersion,
		ProverAddress:   s.proverAddress.Hex(),
		Signature:       sig,
	}

	if err := s.post(ctx, "startup", req); err != nil {
		return err
	}

	log.Info("Guardian prover successfully sent startup",
		"revision", revision,
		"version", version,
	)

	return nil
}

// sendSignedBlockReq is the actual method that sends the signed block to the health check server.
func (s *GuardianProverBlockSender) sendSignedBlockReq(
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

// sign signs the given block and returns the signature and header.
func (s *GuardianProverBlockSender) signBlock(ctx context.Context, blockID *big.Int) ([]byte, *types.Header, error) {
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

		if _, err := s.rpc.WaitL1Origin(ctx, blockID); err != nil {
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

	exists, err := s.db.Has(db.BuildBlockKey(header.Time, header.Number.Uint64()))
	if err != nil {
		return nil, nil, err
	}

	if exists {
		log.Info("Guardian prover already signed block", "blockID", blockID.Uint64())
		return nil, nil, nil
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

// Close closes the underlying database.
func (s *GuardianProverBlockSender) Close() error {
	return s.db.Close()
}

// SendHeartbeat sends a heartbeat to the health check server.
func (s *GuardianProverBlockSender) SendHeartbeat(
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
