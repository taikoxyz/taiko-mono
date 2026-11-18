// Differential wire fixtures from unmodified stock CometBFT v0.40.0.
// Run: GOCACHE=/private/tmp/etna-comet-wire-cache go run . > ../comet-wire.json
package main

import (
	"encoding/hex"
	"encoding/json"
	"fmt"
	"time"

	abci "github.com/cometbft/cometbft/abci/types"
	ce "github.com/cometbft/cometbft/crypto/encoding"
	"github.com/cometbft/cometbft/crypto/secp256k1eth"
	"github.com/cometbft/cometbft/types"
)

func hx(b []byte) string { return "0x" + hex.EncodeToString(b) }
func main() {
	var validators []*types.Validator
	var updates []abci.ValidatorUpdate
	var members []map[string]any
	for i, power := range []int64{10, 20, 20} {
		key := make(secp256k1eth.PrivKey, 32)
		key[31] = byte(i + 1)
		pub := key.PubKey()
		native, err := ce.PubKeyToProto(pub)
		if err != nil {
			panic(err)
		}
		validators = append(validators, types.NewValidator(pub, power))
		updates = append(updates, abci.ValidatorUpdate{PubKey: native, Power: power})
		members = append(members, map[string]any{"key": hx(pub.Bytes()), "address": hx(pub.Address()), "power": power})
	}
	params := types.DefaultConsensusParams()
	params.Validator.PubKeyTypes = []string{"secp256k1eth"}
	params.Version.App = 1
	rawParams := params.ToProto()
	req := abci.Request{Value: &abci.Request_InitChain{InitChain: &abci.RequestInitChain{
		Time: time.Unix(1700000000, 0).UTC(), ChainId: "etna-rFfVfgyjbP1zElufI3Hsqar8zT_q-s2n_fB74bWyvP4",
		ConsensusParams: &rawParams, Validators: updates, AppStateBytes: []byte(`{"witness":"0x06"}`), InitialHeight: 1,
	}}}
	reqBytes, err := req.Marshal()
	if err != nil {
		panic(err)
	}
	response := abci.Response{Value: &abci.Response_FinalizeBlock{FinalizeBlock: &abci.ResponseFinalizeBlock{ValidatorUpdates: updates, AppHash: []byte{1, 2, 3}}}}
	respBytes, err := response.Marshal()
	if err != nil {
		panic(err)
	}
	set := types.NewValidatorSet(validators)
	var ordered []string
	for _, member := range set.Validators {
		ordered = append(ordered, hx(member.Address))
	}
	result := map[string]any{"source": "stock CometBFT v0.40.0", "members": members, "validator_order": ordered, "validators_hash": hx(set.Hash()), "init_chain": hx(reqBytes), "finalize_block": hx(respBytes)}
	data, err := json.MarshalIndent(result, "", "  ")
	if err != nil {
		panic(err)
	}
	fmt.Println(string(data))
}
