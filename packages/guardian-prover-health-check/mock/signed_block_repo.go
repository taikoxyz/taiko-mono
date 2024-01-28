package mock

import (
	"errors"

	guardianproverhealthcheck "github.com/taikoxyz/taiko-mono/packages/guardian-prover-health-check"
)

type SignedBlockRepo struct {
	signedBlocks []*guardianproverhealthcheck.SignedBlock
}

func NewSignedBlockRepository() *SignedBlockRepo {
	return &SignedBlockRepo{
		signedBlocks: make([]*guardianproverhealthcheck.SignedBlock, 0),
	}
}

func (r *SignedBlockRepo) Save(opts guardianproverhealthcheck.SaveSignedBlockOpts) error {
	r.signedBlocks = append(r.signedBlocks, &guardianproverhealthcheck.SignedBlock{
		GuardianProverID: opts.GuardianProverID,
		BlockID:          opts.BlockID,
		BlockHash:        opts.BlockHash,
		Signature:        opts.Signature,
		RecoveredAddress: opts.RecoveredAddress,
	},
	)

	return nil
}

func (r *SignedBlockRepo) GetByStartingBlockID(
	opts guardianproverhealthcheck.GetSignedBlocksByStartingBlockIDOpts,
) ([]*guardianproverhealthcheck.SignedBlock, error) {
	sb := make([]*guardianproverhealthcheck.SignedBlock, 0)

	for _, v := range r.signedBlocks {
		if v.BlockID >= opts.StartingBlockID {
			sb = append(sb, v)
		}
	}

	return sb, nil
}

func (r *SignedBlockRepo) GetMostRecentByGuardianProverID(id int) (*guardianproverhealthcheck.SignedBlock, error) {
	var b *guardianproverhealthcheck.SignedBlock

	for k, v := range r.signedBlocks {
		if v.GuardianProverID == uint64(id) {
			if k == 0 {
				b = v
			} else if v.BlockID > b.BlockID {
				b = v
			}
		}
	}

	if b == nil {
		return nil, errors.New("no signed blocks by this guardian prover")
	}

	return b, nil
}
