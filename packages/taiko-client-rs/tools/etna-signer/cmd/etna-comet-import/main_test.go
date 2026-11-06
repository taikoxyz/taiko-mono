package main

import "testing"

func TestMissingTrustedInputs(t *testing.T) {
	if err := run([]string{"verify"}); err == nil {
		t.Fatal("missing trusted inputs accepted")
	}
}
