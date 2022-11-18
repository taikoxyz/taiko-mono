package mock

import (
	"context"
	"encoding/json"
	"fmt"

	"github.com/ethereum/go-ethereum/common/hexutil"
)

type Caller struct {
}

func (c *Caller) CallContext(ctx context.Context, result interface{}, method string, args ...interface{}) error {
	if method == "eth_getProof" {
		b := hexutil.MustDecode("0x01")
		return json.Unmarshal(json.RawMessage([]byte(fmt.Sprintf(`{"storageProof": [{"value": "%x"}]}`, b))), result)
	}

	return nil
}
