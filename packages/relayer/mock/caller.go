package mock

import (
	"context"
)

type Caller struct {
}

func (c *Caller) CallContext(ctx context.Context, result interface{}, method string, args ...interface{}) error {
	return nil
}
