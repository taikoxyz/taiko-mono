package server

import (
	"context"
	"math/big"
	"net/http"
	"time"

	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/crypto"
	"github.com/ethereum/go-ethereum/log"
	"github.com/labstack/echo/v4"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/encoding"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/internal/utils"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/rpc"
)

const (
	rpcTimeout = 1 * time.Minute
)

// @title Taiko Prover Server API
// @version 1.0
// @termsOfService http://swagger.io/terms/

// @contact.name API Support
// @contact.url https://community.taiko.xyz/
// @contact.email info@taiko.xyz

// @license.name MIT
// @license.url https://github.com/taikoxyz/taiko-mono/packages/taiko-client/blob/main/LICENSE.md

// CreateAssignmentRequestBody represents a request body when handling assignment creation request.
type CreateAssignmentRequestBody struct {
	Proposer common.Address     `json:"proposer"`
	FeeToken common.Address     `json:"feeToken"`
	TierFees []encoding.TierFee `json:"tierFees"`
	Expiry   uint64             `json:"expiry"`
	BlobHash common.Hash        `json:"blobHash"`
}

// Status represents the current prover server status.
type Status struct {
	MinOptimisticTierFee uint64 `json:"minOptimisticTierFee"`
	MinSgxTierFee        uint64 `json:"minSgxTierFee"`
	MinSgxAndZkVMTierFee uint64 `json:"minSgxAndZkVMTierFee"`
	MaxExpiry            uint64 `json:"maxExpiry"`
	Prover               string `json:"prover"`
}

// GetStatus handles a query to the current prover server status.
//
//	@Summary		Get current prover server status
//	@ID			   	get-status
//	@Accept			json
//	@Produce		json
//	@Success		200	{object} Status
//	@Router			/status [get]
func (s *ProverServer) GetStatus(c echo.Context) error {
	return c.JSON(http.StatusOK, &Status{
		MinOptimisticTierFee: s.minOptimisticTierFee.Uint64(),
		MinSgxTierFee:        s.minSgxTierFee.Uint64(),
		MinSgxAndZkVMTierFee: s.minSgxAndZkVMTierFee.Uint64(),
		MaxExpiry:            uint64(s.maxExpiry.Seconds()),
		Prover:               s.proverAddress.Hex(),
	})
}

// ProposeBlockResponse represents the JSON response which will be returned by
// the ProposeBlock request handler.
type ProposeBlockResponse struct {
	SignedPayload []byte         `json:"signedPayload"`
	Prover        common.Address `json:"prover"`
	MaxBlockID    uint64         `json:"maxBlockID"`
	MaxProposedIn uint64         `json:"maxProposedIn"`
}

// CreateAssignment handles a block proof assignment request, decides if this prover wants to
// handle this block, and if so, returns a signed payload the proposer
// can submit onchain.
//
//	@Summary		Try to accept a block proof assignment
//	@Param          body	body	server.CreateAssignmentRequestBody   true    "assignment request body"
//	@Accept			json
//	@Produce		json
//	@Success		200		{object} ProposeBlockResponse
//	@Failure		422		{string} string	"empty blob hash"
//	@Failure		422		{string} string	"only receive ETH"
//	@Failure		422		{string} string	"insufficient prover balance"
//	@Failure		422		{string} string	"proof fee too low"
//	@Failure		422		{string} string "expiry too long"
//	@Failure		422		{string} string "prover does not have capacity"
//	@Router			/assignment [post]
func (s *ProverServer) CreateAssignment(c echo.Context) error {
	req := new(CreateAssignmentRequestBody)
	if err := c.Bind(req); err != nil {
		return c.JSON(http.StatusUnprocessableEntity, err)
	}

	log.Info(
		"Proof assignment request body",
		"feeToken", req.FeeToken,
		"expiry", req.Expiry,
		"tierFees", req.TierFees,
		"blobHash", req.BlobHash,
		"currentUsedCapacity", len(s.proofSubmissionCh),
	)

	// If the prover set address is set, use it as the prover address.
	prover := s.proverAddress
	if s.proverSetAddress != rpc.ZeroAddress {
		prover = s.proverSetAddress
	}

	// 1. Check if the request body is valid.
	if req.BlobHash == (common.Hash{}) {
		log.Warn("Empty blob hash", "prover", s.proverAddress)
		return echo.NewHTTPError(http.StatusUnprocessableEntity, "empty blob hash")
	}
	if req.FeeToken != (common.Address{}) {
		log.Warn("Only receive ETH", "prover", s.proverAddress)
		return echo.NewHTTPError(http.StatusUnprocessableEntity, "only receive ETH")
	}

	// 2. Check if the prover has the required minimum on-chain ETH and Taiko token balance.
	ok, err := s.checkMinEthAndToken(c.Request().Context(), prover)
	if err != nil {
		log.Error("Failed to check prover's ETH and Taiko token balance", "error", err)
		return echo.NewHTTPError(http.StatusInternalServerError, err)
	}

	if !ok {
		log.Error("Insufficient prover balance", "prover", s.proverAddress)
		return echo.NewHTTPError(http.StatusUnprocessableEntity, "insufficient prover balance")
	}

	// 3. Check if the prover's token balance is enough to cover the bonds.
	if ok, err = rpc.CheckProverBalance(
		c.Request().Context(),
		s.rpc,
		prover,
		s.assignmentHookAddress,
		s.livenessBond,
	); err != nil {
		log.Error("Failed to check prover's token balance", "error", err)
		return echo.NewHTTPError(http.StatusInternalServerError, err)
	}
	if !ok {
		log.Warn(
			"Insufficient prover token balance, please get more tokens or wait for verification of the blocks you proved",
			"prover", s.proverAddress,
		)
		return echo.NewHTTPError(http.StatusUnprocessableEntity, "insufficient prover balance")
	}

	// 4. Check if the proof fee meets prover's minimum requirement for each tier.
	for _, tier := range req.TierFees {
		if tier.Tier == encoding.TierGuardianMajorityID {
			continue
		}

		if tier.Tier == encoding.TierGuardianMinorityID {
			continue
		}

		var minTierFee *big.Int
		switch tier.Tier {
		case encoding.TierOptimisticID:
			minTierFee = s.minOptimisticTierFee
		case encoding.TierSgxID:
			minTierFee = s.minSgxTierFee
		case encoding.TierSgxAndZkVMID:
			minTierFee = s.minSgxAndZkVMTierFee
		default:
			log.Warn("Unknown tier", "tier", tier.Tier, "fee", tier.Fee, "proposerIP", c.RealIP())
			return echo.NewHTTPError(http.StatusUnprocessableEntity, "unknown tier")
		}

		if tier.Fee.Cmp(minTierFee) < 0 {
			log.Warn(
				"Proof fee too low",
				"tier", tier.Tier,
				"fee", tier.Fee,
				"minTierFee", minTierFee,
				"proposerIP", c.RealIP(),
			)
			return echo.NewHTTPError(http.StatusUnprocessableEntity, "proof fee too low")
		}
	}

	// 5. Check if the expiry is too long.
	if req.Expiry > uint64(time.Now().Add(s.maxExpiry).Unix()) {
		log.Warn(
			"Expiry too long",
			"requestExpiry", req.Expiry,
			"srvMaxExpiry", s.maxExpiry,
			"proposerIP", c.RealIP(),
		)
		return echo.NewHTTPError(http.StatusUnprocessableEntity, "expiry too long")
	}

	// 6. Check if the prover has any capacity now.
	if s.proofSubmissionCh != nil && len(s.proofSubmissionCh) == cap(s.proofSubmissionCh) {
		log.Warn("Prover does not have capacity", "capacity", cap(s.proofSubmissionCh))
		return echo.NewHTTPError(http.StatusUnprocessableEntity, "prover does not have capacity")
	}

	// 7. Encode and sign the prover assignment payload.
	l1Head, err := s.rpc.L1.BlockNumber(c.Request().Context())
	if err != nil {
		log.Error("Failed to get L1 block head", "error", err)
		return echo.NewHTTPError(http.StatusUnprocessableEntity, err)
	}

	encoded, err := encoding.EncodeProverAssignmentPayload(
		s.protocolConfigs.ChainId,
		s.taikoL1Address,
		s.assignmentHookAddress,
		req.Proposer,
		prover,
		req.BlobHash,
		req.FeeToken,
		req.Expiry,
		l1Head+s.maxSlippage,
		s.maxProposedIn,
		req.TierFees,
	)
	if err != nil {
		log.Error("Failed to encode proverAssignment payload data", "error", err)
		return echo.NewHTTPError(http.StatusUnprocessableEntity, err)
	}

	signed, err := crypto.Sign(crypto.Keccak256Hash(encoded).Bytes(), s.proverPrivateKey)
	if err != nil {
		return echo.NewHTTPError(http.StatusInternalServerError, err)
	}

	// 8. Return the signed payload.
	return c.JSON(http.StatusOK, &ProposeBlockResponse{
		SignedPayload: signed,
		Prover:        prover,
		MaxBlockID:    l1Head + s.maxSlippage,
		MaxProposedIn: s.maxProposedIn,
	})
}

// checkMinEthAndToken checks if the prover has the required minimum on-chain Taiko token balance.
func (s *ProverServer) checkMinEthAndToken(ctx context.Context, proverAddress common.Address) (bool, error) {
	ctx, cancel := context.WithTimeout(ctx, rpcTimeout)
	defer cancel()

	// 1. Check prover's ETH balance, if it's using proverSet.
	if proverAddress == s.proverAddress {
		ethBalance, err := s.rpc.L1.BalanceAt(ctx, proverAddress, nil)
		if err != nil {
			return false, err
		}

		log.Info(
			"Prover's ETH balance",
			"balance", utils.WeiToEther(ethBalance),
			"address", proverAddress,
		)

		if ethBalance.Cmp(s.minEthBalance) <= 0 {
			log.Warn(
				"Prover does not have required minimum on-chain ETH balance",
				"providedProver", proverAddress,
				"ethBalance", utils.WeiToEther(ethBalance),
				"minEthBalance", utils.WeiToEther(s.minEthBalance),
			)
			return false, nil
		}
	}

	// 2. Check prover's Taiko token balance.
	balance, err := s.rpc.TaikoToken.BalanceOf(&bind.CallOpts{Context: ctx}, proverAddress)
	if err != nil {
		return false, err
	}

	log.Info(
		"Prover's Taiko token balance",
		"balance", utils.WeiToEther(balance),
		"address", proverAddress,
	)

	if balance.Cmp(s.minTaikoTokenBalance) <= 0 {
		log.Warn(
			"Prover does not have required on-chain Taiko token balance",
			"providedProver", proverAddress,
			"taikoTokenBalance", utils.WeiToEther(balance),
			"minTaikoTokenBalance", utils.WeiToEther(s.minTaikoTokenBalance),
		)
		return false, nil
	}

	return true, nil
}
