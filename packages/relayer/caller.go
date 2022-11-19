package relayer

import "context"

type Caller interface {
	CallContext(ctx context.Context, result interface{}, method string, args ...interface{}) error
}
