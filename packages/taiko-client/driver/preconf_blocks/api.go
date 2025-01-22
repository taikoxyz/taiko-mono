package preconfblocks

import (
	"errors"
	"net/http"

	"github.com/ethereum/go-ethereum/beacon/engine"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/crypto"
	"github.com/ethereum/go-ethereum/log"
	"github.com/ethereum/go-ethereum/rlp"
	"github.com/labstack/echo/v4"

	pacayaBindings "github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/pacaya"
)

// ValidateSignature validates the signature of the request body.
func (b *BuildPreconfBlockRequestBody) ValidateSignature() (bool, error) {
	payload, err := rlp.EncodeToBytes(b)
	if err != nil {
		return false, err
	}

	pubKey, err := crypto.SigToPub(crypto.Keccak256(payload), common.FromHex(b.Signature))
	if err != nil {
		return false, err
	}

	return crypto.PubkeyToAddress(*pubKey).Hex() == b.ExecutableData.FeeRecipient.Hex(), nil
}

// BuildPreconfBlockRequestBody represents a request body when handling
// soft blocks creation requests.
type BuildPreconfBlockRequestBody struct {
	// @param ExecutableData engine.ExecutableData the data necessary to execute an EL payload.
	ExecutableData *engine.ExecutableData `json:"executableData"`
	// @param signature string Signature of this executable data payload.
	Signature string `json:"signature" rlp:"-"`

	// @param anchorBlockID uint64 `_anchorBlockId` parameter of the `anchorV3` transaction in the preconf block
	AnchorBlockID uint64 `json:"anchorBlockID"`
	// @param anchorStateRoot string `_anchorStateRoot` parameter of the `anchorV3` transaction in the preconf block
	AnchorStateRoot common.Hash                                `json:"anchorStateRoot"`
	AnchorInput     [32]byte                                   `json:"anchorInput"`
	SignalSlots     [][32]byte                                 `json:"signalSlots"`
	BaseFeeConfig   *pacayaBindings.LibSharedDataBaseFeeConfig `json:"baseFeeConfig"`
}

// BuildPreconfBlockResponseBody represents a response body when handling preconf
// blocks creation requests.
type BuildPreconfBlockResponseBody struct {
	// @param blockHeader types.Header of the soft block
	BlockHeader *types.Header `json:"blockHeader"`
}

// BuildSoftBlock handles a preconfirmation block creation request,
// if the preconfirmation block creation body in request are valid, it will insert the correspoinding the
// preconfirmation block to the backend L2 execution engine and return a success response.
//
//	@Description	Insert a preconfirmation block to the L2 execution engine.
//	@Param  	body body BuildPreconfBlockRequestBody true "preconf block creation request body"
//	@Accept	  json
//	@Produce	json
//	@Success	200		{object} BuildPreconfBlockResponseBody
//	@Router		/preconfBlocks [post]
func (s *PreconfBlockAPIServer) BuildPreconfBlock(c echo.Context) error {
	// Parse the request body.
	reqBody := new(BuildPreconfBlockRequestBody)
	if err := c.Bind(reqBody); err != nil {
		return s.returnError(c, http.StatusUnprocessableEntity, err)
	}
	if reqBody.ExecutableData == nil {
		return s.returnError(c, http.StatusBadRequest, errors.New("executable data is required"))
	}

	log.Info(
		"New preconfirmation block building request",
		"blockID", reqBody.ExecutableData.Number,
		"signature", reqBody.Signature,
		"timestamp", reqBody.ExecutableData.Timestamp,
		"coinbase", reqBody.ExecutableData.FeeRecipient.Hex(),
		"anchorBlockID", reqBody.AnchorBlockID,
		"anchorStateRoot", reqBody.AnchorStateRoot,
		"anchorInput", common.Bytes2Hex(reqBody.AnchorInput[:]),
		"signalSlots", len(reqBody.SignalSlots),
	)

	// Request body validation.
	if reqBody.AnchorBlockID == 0 {
		return s.returnError(c, http.StatusBadRequest, errors.New("non-zero anchorBlockID is required"))
	}
	if reqBody.AnchorStateRoot == (common.Hash{}) {
		return s.returnError(c, http.StatusBadRequest, errors.New("empty anchorStateRoot"))
	}
	if reqBody.ExecutableData.Timestamp == 0 {
		return s.returnError(c, http.StatusBadRequest, errors.New("non-zero timestamp is required"))
	}
	if reqBody.ExecutableData.FeeRecipient == (common.Address{}) {
		return s.returnError(c, http.StatusBadRequest, errors.New("empty L2 fee recipient"))
	}
	if len(reqBody.ExecutableData.Transactions) != 1 {
		return s.returnError(c, http.StatusBadRequest, errors.New("only one transaction list is allowed"))
	}

	// If the `--preconfBlock.signatureCheck` flag is enabled, validate the signature.
	if s.checkSig {
		ok, err := reqBody.ValidateSignature()
		if err != nil {
			return c.JSON(http.StatusInternalServerError, map[string]string{"error": err.Error()})
		}
		if !ok {
			log.Warn(
				"Invalid signature",
				"signature", reqBody.Signature,
				"coinbase", reqBody.ExecutableData.FeeRecipient.Hex(),
			)
			return s.returnError(c, http.StatusBadRequest, errors.New("invalid signature"))
		}
	}

	// Check if the L2 execution engine is syncing from L1.
	progress, err := s.rpc.L2ExecutionEngineSyncProgress(c.Request().Context())
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": err.Error()})
	}
	if progress.IsSyncing() {
		return s.returnError(c, http.StatusBadRequest, errors.New("L2 execution engine is syncing"))
	}

	// Insert the preconf block.
	header, err := s.chainSyncer.InsertPreconfBlockFromTransactionsBatch(
		c.Request().Context(),
		reqBody.ExecutableData,
		reqBody.AnchorBlockID,
		reqBody.AnchorStateRoot,
		reqBody.AnchorInput,
		reqBody.SignalSlots,
		reqBody.BaseFeeConfig,
	)
	if err != nil {
		return s.returnError(c, http.StatusInternalServerError, err)
	}

	return c.JSON(http.StatusOK, BuildPreconfBlockResponseBody{BlockHeader: header})
}

// HealthCheck is the endpoints for probes.
//
//	@Summary		Get current server health status
//	@ID			   	health-check
//	@Accept			json
//	@Produce		json
//	@Success		200	{object} string
//	@Router			/healthz [get]
func (s *PreconfBlockAPIServer) HealthCheck(c echo.Context) error {
	return c.NoContent(http.StatusOK)
}

// returnError is a helper function to return an error response.
func (s *PreconfBlockAPIServer) returnError(c echo.Context, statusCode int, err error) error {
	return c.JSON(statusCode, map[string]string{"error": err.Error()})
}
