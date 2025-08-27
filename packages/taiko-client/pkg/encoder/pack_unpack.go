package encoder

import (
	"encoding/binary"
	"math/big"

	"github.com/ethereum/go-ethereum/common"
)

// PackUnpack provides low-level packing/unpacking functions for compact binary encoding
type PackUnpack struct{}

// PackUint8 packs a uint8 value at the specified position
func PackUint8(data []byte, pos int, value uint8) int {
	data[pos] = value
	return pos + 1
}

// UnpackUint8 unpacks a uint8 value from the specified position
func UnpackUint8(data []byte, pos int) (uint8, int) {
	return data[pos], pos + 1
}

// PackUint16 packs a uint16 value at the specified position (big-endian)
func PackUint16(data []byte, pos int, value uint16) int {
	binary.BigEndian.PutUint16(data[pos:], value)
	return pos + 2
}

// UnpackUint16 unpacks a uint16 value from the specified position (big-endian)
func UnpackUint16(data []byte, pos int) (uint16, int) {
	value := binary.BigEndian.Uint16(data[pos:])
	return value, pos + 2
}

// PackUint24 packs a uint24 value at the specified position (big-endian)
func PackUint24(data []byte, pos int, value uint32) int {
	// Store as 3 bytes in big-endian
	data[pos] = byte(value >> 16)
	data[pos+1] = byte(value >> 8)
	data[pos+2] = byte(value)
	return pos + 3
}

// UnpackUint24 unpacks a uint24 value from the specified position (big-endian)
func UnpackUint24(data []byte, pos int) (uint32, int) {
	value := uint32(data[pos])<<16 | uint32(data[pos+1])<<8 | uint32(data[pos+2])
	return value, pos + 3
}

// PackUint32 packs a uint32 value at the specified position (big-endian)
func PackUint32(data []byte, pos int, value uint32) int {
	binary.BigEndian.PutUint32(data[pos:], value)
	return pos + 4
}

// UnpackUint32 unpacks a uint32 value from the specified position (big-endian)
func UnpackUint32(data []byte, pos int) (uint32, int) {
	value := binary.BigEndian.Uint32(data[pos:])
	return value, pos + 4
}

// PackUint48 packs a uint48 value at the specified position (big-endian)
func PackUint48(data []byte, pos int, value uint64) int {
	// Store as 6 bytes in big-endian
	data[pos] = byte(value >> 40)
	data[pos+1] = byte(value >> 32)
	data[pos+2] = byte(value >> 24)
	data[pos+3] = byte(value >> 16)
	data[pos+4] = byte(value >> 8)
	data[pos+5] = byte(value)
	return pos + 6
}

// UnpackUint48 unpacks a uint48 value from the specified position (big-endian)
func UnpackUint48(data []byte, pos int) (uint64, int) {
	value := uint64(data[pos])<<40 | uint64(data[pos+1])<<32 |
		uint64(data[pos+2])<<24 | uint64(data[pos+3])<<16 |
		uint64(data[pos+4])<<8 | uint64(data[pos+5])
	return value, pos + 6
}

// PackUint64 packs a uint64 value at the specified position (big-endian)
func PackUint64(data []byte, pos int, value uint64) int {
	binary.BigEndian.PutUint64(data[pos:], value)
	return pos + 8
}

// UnpackUint64 unpacks a uint64 value from the specified position (big-endian)
func UnpackUint64(data []byte, pos int) (uint64, int) {
	value := binary.BigEndian.Uint64(data[pos:])
	return value, pos + 8
}

// PackBytes32 packs a 32-byte value at the specified position
func PackBytes32(data []byte, pos int, value [32]byte) int {
	copy(data[pos:], value[:])
	return pos + 32
}

// UnpackBytes32 unpacks a 32-byte value from the specified position
func UnpackBytes32(data []byte, pos int) ([32]byte, int) {
	var value [32]byte
	copy(value[:], data[pos:pos+32])
	return value, pos + 32
}

// PackAddress packs an Ethereum address at the specified position
func PackAddress(data []byte, pos int, addr common.Address) int {
	copy(data[pos:], addr.Bytes())
	return pos + 20
}

// UnpackAddress unpacks an Ethereum address from the specified position
func UnpackAddress(data []byte, pos int) (common.Address, int) {
	var addr common.Address
	copy(addr[:], data[pos:pos+20])
	return addr, pos + 20
}

// PackBigInt packs a big.Int value at the specified position with specified byte size
func PackBigInt(data []byte, pos int, value *big.Int, size int) int {
	bytes := value.Bytes()
	if len(bytes) < size {
		// Pad with zeros on the left
		padded := make([]byte, size)
		copy(padded[size-len(bytes):], bytes)
		copy(data[pos:], padded)
	} else {
		// Take the rightmost bytes if value is larger
		copy(data[pos:], bytes[len(bytes)-size:])
	}
	return pos + size
}

// UnpackBigInt unpacks a big.Int value from the specified position with specified byte size
func UnpackBigInt(data []byte, pos int, size int) (*big.Int, int) {
	value := new(big.Int).SetBytes(data[pos : pos+size])
	return value, pos + size
}

// CheckArrayLength ensures array length fits in uint24 (max 16777215)
func CheckArrayLength(length int) bool {
	return length <= 0xFFFFFF // Max uint24
}