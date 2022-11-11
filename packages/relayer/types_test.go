package relayer

import "testing"

func Test_IsInSlice(t *testing.T) {
	if IsInSlice("fake", []string{}) {
		t.Fatal()
	}

	if !IsInSlice("real", []string{"real"}) {
		t.Fatal()
	}
}
