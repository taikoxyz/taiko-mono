package stress

import (
	"encoding/json"
	"fmt"
	"io"
	"log/slog"
	"os"
	"path"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/common/math"
	"github.com/ethereum/go-ethereum/log"
	proofProducer "github.com/taikoxyz/taiko-mono/packages/taiko-client/prover/proof_producer"
	proofSubmitter "github.com/taikoxyz/taiko-mono/packages/taiko-client/stress/proof_submitter"
)

func (p *Stress) initState(cfg *Config) error {
	stateFilePath := path.Join(cfg.DBPath, stateFileName)
	stateFile, err := os.OpenFile(stateFilePath, os.O_CREATE|os.O_RDWR, 0666)
	if err != nil {
		return err
	}

	byteValue, err := io.ReadAll(stateFile)
	if err != nil {
		return err
	}
	p.state = &state{}
	if len(byteValue) != 0 {
		if err := json.Unmarshal(byteValue, p.state); err != nil {
			return err
		}
	}
	if p.state.LastProvedBlockID == nil {
		p.state.LastProvedBlockID = common.Big0
	}
	p.state.LastProvedBlockID = math.BigMax(p.state.LastProvedBlockID, cfg.StartingBlockID)
	return nil
}

func (p *Stress) saveState(cfg *Config) error {
	stateFilePath := path.Join(cfg.DBPath, stateFileName)
	stateFile, err := os.OpenFile(stateFilePath, os.O_CREATE|os.O_RDWR, 0666)
	if err != nil {
		return err
	}

	byteValue, err := json.Marshal(p.state)
	if err != nil {
		return err
	}

	if _, err := stateFile.Write(byteValue); err != nil {
		return err
	}

	return nil
}

func (p *Stress) initLogger(cfg *Config) error {
	logFilePath := path.Join(cfg.DBPath, logFileName)
	logFile, err := os.OpenFile(logFilePath, os.O_APPEND|os.O_CREATE|os.O_RDWR, 0666)
	if err != nil {
		return err
	}

	p.logger = log.NewLogger(slog.NewJSONHandler(logFile, nil))
	return nil
}

// initProofSubmitter initializes the proof submitters from the given tiers in protocol.
func (p *Stress) initProofSubmitter(
	zkType string,
) error {
	var (
		producer  proofProducer.ProofProducer
		submitter proofSubmitter.Submitter
		err       error
	)
	switch zkType {
	case proofProducer.ZKProofTypeR0:
		producer = &proofProducer.ZKvmProofProducer{
			ZKProofType:         proofProducer.ZKProofTypeR0,
			RaikoHostEndpoint:   p.cfg.RaikoZKVMHostEndpoint,
			JWT:                 p.cfg.RaikoJWT,
			Dummy:               p.cfg.Dummy,
			RaikoRequestTimeout: p.cfg.RaikoRequestTimeout,
		}
	case proofProducer.ZKProofTypeSP1:
		producer = &proofProducer.ZKvmProofProducer{
			ZKProofType:         proofProducer.ZKProofTypeSP1,
			RaikoHostEndpoint:   p.cfg.RaikoZKVMHostEndpoint,
			JWT:                 p.cfg.RaikoJWT,
			Dummy:               p.cfg.Dummy,
			RaikoRequestTimeout: p.cfg.RaikoRequestTimeout,
		}
	default:
		return fmt.Errorf("unsupported tier: %s", zkType)
	}

	if submitter, err = proofSubmitter.NewProofSubmitter(
		p.rpc,
		producer,
		p.proofGenerationCh,
		p.cfg.ProverSetAddress,
		p.cfg.TaikoL2Address,
		p.cfg.Graffiti,
	); err != nil {
		return err
	}

	p.proofSubmitter = submitter
	p.zkType = zkType

	return nil
}
