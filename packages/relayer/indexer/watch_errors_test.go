package indexer

import (
	"errors"
	"testing"
)

func Test_watchErrors(t *testing.T) {
	svc := newTestService()

	go svc.watchErrors()

	err := errors.New("err")

	svc.errChan <- err
}
