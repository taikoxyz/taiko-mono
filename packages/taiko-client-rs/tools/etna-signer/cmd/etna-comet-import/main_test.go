package main

import (
	"bytes"
	"errors"
	"testing"
)

func TestMissingTrustedInputs(t *testing.T) {
	if err := run([]string{"verify"}); err == nil {
		t.Fatal("missing trusted inputs accepted")
	}
}

func TestOrdinaryFailureHasNoAuthenticationReceipt(t *testing.T) {
	var stdout, stderr bytes.Buffer
	if code := writeFailure(&stdout, &stderr, errors.New("acquisition failed")); code != 1 || stdout.Len() != 0 || stderr.String() != "acquisition failed\n" {
		t.Fatalf("ordinary failure was misclassified: code/output %d %q %q", code, stdout.String(), stderr.String())
	}
}
