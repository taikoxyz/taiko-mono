package main

import (
	"encoding/json"
	"fmt"
	"github.com/cometbft/cometbft/crypto/secp256k1eth"
	"github.com/cometbft/cometbft/types"
)

func val(a byte, p int64) *types.Validator {
	key := make([]byte, 32)
	key[31] = a
	v := types.NewValidator(secp256k1eth.PrivKey(key).PubKey(), p)
	v.Address = make([]byte, 20)
	v.Address[19] = a
	return v
}
func out(s *types.ValidatorSet) any {
	xs := make([][3]int64, 0)
	for _, v := range s.Validators {
		xs = append(xs, [3]int64{int64(v.Address[19]), v.VotingPower, v.ProposerPriority})
	}
	return map[string]any{"members": xs, "proposer": s.GetProposer().Address[19]}
}
func main() {
	current := types.NewValidatorSet([]*types.Validator{val(2, 3), val(1, 1)})
	next := current.CopyIncrementProposerPriority(1)
	changed := next.Copy()
	if err := changed.UpdateWithChangeSet([]*types.Validator{val(2, 0), val(3, 2)}); err != nil {
		panic(err)
	}
	changed.IncrementProposerPriority(1)
	result := map[string]any{"genesis_current": out(current), "genesis_next": out(next), "after_change_next": out(changed)}
	found := false
	for x := int64(-6); x <= 6 && !found; x++ {
		for y := int64(-6); y <= 6 && !found; y++ {
			for z := int64(-6); z <= 6 && !found; z++ {
				s := types.NewValidatorSet([]*types.Validator{val(1, 1), val(2, 2), val(3, 3)})
				for _, v := range s.Validators {
					switch v.Address[19] {
					case 1:
						v.ProposerPriority = x
					case 2:
						v.ProposerPriority = y
					case 3:
						v.ProposerPriority = z
					}
				}
				each := s.CopyIncrementProposerPriority(1)
				each.IncrementProposerPriority(1)
				batch := s.CopyIncrementProposerPriority(2)
				a, _ := json.Marshal(out(each))
				b, _ := json.Marshal(out(batch))
				if string(a) != string(b) {
					result["per_height_witness"] = map[string]any{"input": out(s), "each": out(each), "batch": out(batch)}
					found = true
				}
			}
		}
	}
	raw, _ := json.MarshalIndent(result, "", "  ")
	fmt.Println(string(raw))
}
