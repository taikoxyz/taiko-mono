package utils

import (
	"crypto/rand"
	"fmt"
	"math/big"
	"os"
	"strings"

	"github.com/ethereum/go-ethereum/common/math"
	"github.com/ethereum/go-ethereum/log"
	"github.com/joho/godotenv"
	"github.com/modern-go/reflect2"
	"golang.org/x/exp/constraints"
)

func LoadEnv() {
	// load test environment variables.
	currentPath, err := os.Getwd()
	if err != nil {
		log.Debug("get current path failed", "err", err)
	}
	path := strings.Split(currentPath, "/taiko-client")
	if len(path) == 0 {
		log.Debug("not a taiko-client repo")
	}
	err = godotenv.Load(fmt.Sprintf("%s/taiko-client/integration_test/.env", path[0]))
	if err != nil {
		log.Debug("failed to load test env", "current path", currentPath, "err", err)
	}
}

func RandUint64(max *big.Int) uint64 {
	if max == nil {
		max = new(big.Int)
		max.SetUint64(math.MaxUint64)
	}
	num, _ := rand.Int(rand.Reader, max)

	return num.Uint64()
}

func RandUint32(max *big.Int) uint32 {
	if max == nil {
		max = new(big.Int)
		max.SetUint64(math.MaxUint32)
	}
	num, _ := rand.Int(rand.Reader, max)
	return uint32(num.Uint64())
}

// IsNil checks if the interface is empty.
func IsNil(i interface{}) bool {
	return reflect2.IsNil(i)
}

// Min return the minimum value of two integers.
func Min[T constraints.Integer](a, b T) T {
	if a < b {
		return a
	}
	return b
}

// Max return the maximum value of two integers.
func Max[T constraints.Integer](a, b T) T {
	if a > b {
		return a
	}
	return b
}
