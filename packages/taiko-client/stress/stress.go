package stress

import (
	"context"
	"math/big"
	"sync"
	"time"

	"github.com/cenkalti/backoff/v4"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/common/hexutil"
	"github.com/ethereum/go-ethereum/log"
	"github.com/urfave/cli/v2"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/encoding"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/metadata"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/rpc"
	handler "github.com/taikoxyz/taiko-mono/packages/taiko-client/prover/event_handler"
	proofProducer "github.com/taikoxyz/taiko-mono/packages/taiko-client/prover/proof_producer"
	proofSubmitter "github.com/taikoxyz/taiko-mono/packages/taiko-client/stress/proof_submitter"
)

const stateFileName = "state.json"
const logFileName = "stress.log"

//go:generate go run github.com/fjl/gencodec -type state -field-override stateMarshaling -out gen_ed.go
type state struct {
	LastProvedBlockID *big.Int `json:"lastProvedBlockID"`
}

type stateMarshaling struct {
	LastProvedBlockID *hexutil.Big
}

// Stress keeps trying to prove newly proposed blocks.
type Stress struct {
	// Configurations
	cfg     *Config
	backoff backoff.BackOffContext

	// Clients
	rpc *rpc.Client

	// Contract configurations
	protocolConfig *bindings.TaikoDataConfig

	// States
	state *state

	// stress logger
	logger log.Logger

	// Proof submitters
	proofSubmitter proofSubmitter.Submitter
	zkType         string

	// Proof related channels
	proofSubmissionCh chan *proofProducer.ProofRequestBody
	proofGenerationCh chan *proofSubmitter.Proof

	ctx context.Context
	wg  sync.WaitGroup
}

// InitFromCli initializes the given prover instance based on the command line flags.
func (p *Stress) InitFromCli(ctx context.Context, c *cli.Context) error {
	cfg, err := NewConfigFromCliContext(c)
	if err != nil {
		return err
	}

	return InitFromConfig(ctx, p, cfg)
}

// InitFromConfig initializes the prover instance based on the given configurations.
func InitFromConfig(
	ctx context.Context,
	p *Stress, cfg *Config,
) (err error) {
	p.cfg = cfg
	p.ctx = ctx
	// Initialize state which will be shared by event handlers.
	p.backoff = backoff.WithContext(
		backoff.WithMaxRetries(
			backoff.NewConstantBackOff(p.cfg.BackOffRetryInterval),
			p.cfg.BackOffMaxRetries,
		),
		p.ctx,
	)

	l1Endpoint := cfg.L1WsEndpoint
	if l1Endpoint == "" {
		l1Endpoint = cfg.L1HttpEndpoint
	}

	l2Endpoint := cfg.L2WsEndpoint
	if l2Endpoint == "" {
		l2Endpoint = cfg.L2HttpEndpoint
	}

	// Clients
	if p.rpc, err = rpc.NewClient(p.ctx, &rpc.ClientConfig{
		L1Endpoint:                    l1Endpoint,
		L2Endpoint:                    l2Endpoint,
		TaikoL1Address:                cfg.TaikoL1Address,
		TaikoL2Address:                cfg.TaikoL2Address,
		TaikoTokenAddress:             rpc.ZeroAddress,
		ProverSetAddress:              cfg.ProverSetAddress,
		GuardianProverMinorityAddress: rpc.ZeroAddress,
		GuardianProverMajorityAddress: rpc.ZeroAddress,
		Timeout:                       cfg.RPCTimeout,
	}); err != nil {
		return err
	}

	// Configs
	p.protocolConfig = encoding.GetProtocolConfig(p.rpc.L2.ChainID.Uint64())
	log.Info("Protocol configs", "configs", p.protocolConfig)

	chBufferSize := p.protocolConfig.BlockMaxProposals
	p.proofGenerationCh = make(chan *proofSubmitter.Proof, chBufferSize)
	p.proofSubmissionCh = make(chan *proofProducer.ProofRequestBody, p.cfg.Capacity)

	if err := p.initState(cfg); err != nil {
		return err
	}

	if err := p.initLogger(cfg); err != nil {
		return err
	}

	// Proof submitter
	if err := p.initProofSubmitter(cfg); err != nil {
		return err
	}

	return nil
}

// Start starts the main loop of the L2 block prover.
func (p *Stress) Start() error {
	go p.eventLoop()
	go p.trigger()
	return nil
}

// eventLoop starts the main loop of Taiko prover.
func (p *Stress) eventLoop() {
	p.wg.Add(1)
	defer p.wg.Done()

	for {
		select {
		case <-p.ctx.Done():
			return
		case proofWithHeader := <-p.proofGenerationCh:
			p.withRetry(func() error { return p.submitProofOp(proofWithHeader) })
		case req := <-p.proofSubmissionCh:
			p.withRetry(func() error { return p.requestProofOp(req.Meta) })
		}
	}
}

func (p *Stress) trigger() {
	p.wg.Add(1)
	defer p.wg.Done()
	var lastBlockTime uint64
	lastProvedBlockID := p.state.LastProvedBlockID
	for {
		if lastProvedBlockID.Cmp(p.cfg.EndingBlockID) > 0 {
			log.Info("All blocks have been proved")
			return
		}
		if err := backoff.Retry(func() error {
			// get l1 info
			l1Origin, err := p.rpc.L2.L1OriginByID(p.ctx, lastProvedBlockID)
			if err != nil {
				log.Error("Get L1Origin failed", "error", err)
				return err
			}
			// get metadata
			meta, err := handler.GetMetadataFromBlockID(p.ctx, p.rpc, l1Origin.BlockID, l1Origin.L1BlockHeight)
			if err != nil {
				log.Error("Get Metadata failed", "error", err, "l1BlockID", l1Origin.BlockID, "l1Height", l1Origin.L1BlockHeight)
				return err
			}
			if lastBlockTime != 0 && lastBlockTime < meta.GetTimestamp() {
				time.Sleep(time.Duration(meta.GetTimestamp()-lastBlockTime) * time.Second)
			}
			lastBlockTime = meta.GetTimestamp()
			p.proofSubmissionCh <- &proofProducer.ProofRequestBody{Meta: meta}
			return nil
		}, p.backoff); err != nil {
			log.Error("Operation failed", "error", err)
			continue
		}
		lastProvedBlockID.Add(lastProvedBlockID, common.Big1)
		p.state.LastProvedBlockID = lastProvedBlockID
		if err := p.saveState(p.cfg); err != nil {
			log.Error("Save state failed", "error", err)
		}
	}
}

// Close closes the prover instance.
func (p *Stress) Close(_ context.Context) {
	p.wg.Wait()
}

// requestProofOp requests a new proof generation operation.
func (p *Stress) requestProofOp(meta metadata.TaikoBlockMetaData) error {
	if err := p.proofSubmitter.RequestProof(p.ctx, meta); err != nil {
		log.Error("Request new proof error", "blockID", meta.GetBlockID(), "minTier", meta.GetMinTier(), "error", err)
		return err
	}

	return nil
}

// submitProofOp performs a proof submission operation.
func (p *Stress) submitProofOp(proof *proofSubmitter.Proof) error {
	p.logger.Info("zkvm proof",
		"zkType", p.zkType,
		"blockID", proof.BlockID,
		"cost", proof.EndAt.Sub(proof.BeginAt).String(),
		"isTimeout", proof.Timeout,
	)
	return nil
}

// Name returns the application name.
func (p *Stress) Name() string {
	return "stress"
}

// withRetry retries the given function with prover backoff policy.
func (p *Stress) withRetry(f func() error) {
	p.wg.Add(1)
	go func() {
		defer p.wg.Done()
		if err := backoff.Retry(f, p.backoff); err != nil {
			log.Error("Operation failed", "error", err)
		}
	}()
}
