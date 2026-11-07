package checkpoint

import (
	"bufio"
	"bytes"
	"encoding/binary"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"reflect"
	"strings"

	"golang.org/x/crypto/sha3"
)

// MaxStreamPackageBytes is the explicit disk-spool profile; exceeding it rejects
// the package in full and never truncates the required consensus window.
const MaxStreamPackageBytes int64 = 1 << 40
const maxBlockJSON = 128 << 20
const maxMetadataJSON = 64 << 20

type jsonStream struct{ r *bufio.Reader }

func (s *jsonStream) next() (byte, error) {
	for {
		b, e := s.r.ReadByte()
		if e != nil {
			return 0, e
		}
		if b != ' ' && b != '\n' && b != '\r' && b != '\t' {
			return b, nil
		}
	}
}
func (s *jsonStream) expect(want byte) error {
	b, e := s.next()
	if e != nil {
		return e
	}
	if b != want {
		return fmt.Errorf("expected JSON %q", want)
	}
	return nil
}

// value bounds allocation before asking encoding/json to parse publisher bytes.
func (s *jsonStream) value(limit int) ([]byte, error) {
	first, e := s.next()
	if e != nil {
		return nil, e
	}
	out := []byte{first}
	quoted := first == '"'
	compound := first == '{' || first == '['
	depth := 0
	if compound {
		depth = 1
	}
	escaped := false
	for {
		if len(out) > limit {
			return nil, errors.New("JSON value exceeds resource limit")
		}
		if !compound && !quoted {
			b, e := s.r.Peek(1)
			if e == io.EOF {
				return out, nil
			}
			if e != nil {
				return nil, e
			}
			if bytes.ContainsRune([]byte(",]} \r\n\t"), rune(b[0])) {
				return out, nil
			}
		}
		b, e := s.r.ReadByte()
		if e != nil {
			return nil, e
		}
		out = append(out, b)
		if len(out) > limit {
			return nil, errors.New("JSON value exceeds resource limit")
		}
		if quoted {
			if escaped {
				escaped = false
				continue
			}
			if b == '\\' {
				escaped = true
				continue
			}
			if b == '"' {
				quoted = false
				if !compound {
					return out, nil
				}
			}
			continue
		}
		if b == '"' {
			quoted = true
			continue
		}
		if b == '{' || b == '[' {
			depth++
		}
		if b == '}' || b == ']' {
			depth--
			if depth == 0 {
				return out, nil
			}
		}
	}
}

// uniqueJSON rejects duplicate keys at every nesting level rather than accepting
// encoding/json's last-key-wins behavior at a consensus-data boundary.
func uniqueJSON(raw []byte) error {
	d := json.NewDecoder(bytes.NewReader(raw))
	d.UseNumber()
	var value func(int) error
	value = func(depth int) error {
		if depth > 64 {
			return errors.New("JSON nesting limit exceeded")
		}
		token, e := d.Token()
		if e != nil {
			return e
		}
		switch token {
		case json.Delim('{'):
			seen := map[string]bool{}
			for d.More() {
				name, e := d.Token()
				if e != nil {
					return e
				}
				key, ok := name.(string)
				if !ok || seen[key] {
					return errors.New("duplicate JSON key")
				}
				seen[key] = true
				if e = value(depth + 1); e != nil {
					return e
				}
			}
			end, e := d.Token()
			if e != nil || end != json.Delim('}') {
				return errors.New("invalid JSON object")
			}
		case json.Delim('['):
			for d.More() {
				if e = value(depth + 1); e != nil {
					return e
				}
			}
			end, e := d.Token()
			if e != nil || end != json.Delim(']') {
				return errors.New("invalid JSON array")
			}
		case json.Delim('}'), json.Delim(']'):
			return errors.New("unexpected JSON delimiter")
		}
		return nil
	}
	if e := value(0); e != nil {
		return e
	}
	if _, e := d.Token(); e != io.EOF {
		return errors.New("trailing JSON value")
	}
	return nil
}

// exactSchemaFields prevents encoding/json's case-insensitive struct matching.
// Raw genesis JSON retains its own stock/application schema and original ordering.
func exactSchemaFields(raw []byte, kind reflect.Type) error {
	if kind.Kind() == reflect.Pointer {
		kind = kind.Elem()
	}
	if kind == reflect.TypeOf(json.RawMessage{}) {
		return nil
	}
	switch kind.Kind() {
	case reflect.Struct:
		var object map[string]json.RawMessage
		if e := json.Unmarshal(raw, &object); e != nil {
			return e
		}
		if object == nil {
			return errors.New("expected schema object")
		}
		fields := map[string]reflect.Type{}
		for i := 0; i < kind.NumField(); i++ {
			field := kind.Field(i)
			name := strings.Split(field.Tag.Get("json"), ",")[0]
			if name != "" && name != "-" {
				fields[name] = field.Type
			}
		}
		for name, value := range object {
			field, ok := fields[name]
			if !ok {
				return fmt.Errorf("unknown exact schema field %q", name)
			}
			if e := exactSchemaFields(value, field); e != nil {
				return e
			}
		}
	case reflect.Slice:
		var array []json.RawMessage
		if e := json.Unmarshal(raw, &array); e != nil {
			return e
		}
		for _, value := range array {
			if e := exactSchemaFields(value, kind.Elem()); e != nil {
				return e
			}
		}
	}
	return nil
}
func strictDecode(raw []byte, target any) error {
	if e := uniqueJSON(raw); e != nil {
		return e
	}
	if e := exactSchemaFields(raw, reflect.TypeOf(target)); e != nil {
		return e
	}
	d := json.NewDecoder(bytes.NewReader(raw))
	d.DisallowUnknownFields()
	return d.Decode(target)
}

// VerifyStream spools one bounded block at a time and verifies the complete window.
// Memory is O(maximum block + validator set), disk is O(package); Close removes
// only its own private spool. Outer package field order does not affect
// package_hash; property order inside the original raw genesis is retained.
func VerifyStream(r io.Reader, trust Trust, spoolParent string, limit int64) (out *Verified, err error) {
	if limit <= 0 || limit > MaxStreamPackageBytes {
		return nil, errors.New("invalid stream byte limit")
	}
	for _, hash := range []string{trust.CometHash, trust.ELHash, trust.ValStateHash} {
		if _, err = hashInput(hash); err != nil {
			return nil, err
		}
	}
	dir, err := os.MkdirTemp(spoolParent, "etna-comet-import-")
	if err != nil {
		return nil, err
	}
	keep := false
	defer func() {
		if !keep {
			_ = os.RemoveAll(dir)
		}
	}()
	file, err := os.OpenFile(filepath.Join(dir, "blocks"), os.O_RDWR|os.O_CREATE|os.O_EXCL, 0600)
	if err != nil {
		return nil, err
	}
	defer file.Close()
	limited := &io.LimitedReader{R: r, N: limit + 1}
	stream := jsonStream{r: bufio.NewReaderSize(limited, 64<<10)}
	if err = stream.expect('{'); err != nil {
		return nil, err
	}
	p := &Package{}
	seen := map[string]bool{}
	for {
		keyRaw, e := stream.value(128)
		if e != nil {
			return nil, e
		}
		var key string
		if e = json.Unmarshal(keyRaw, &key); e != nil {
			return nil, e
		}
		if seen[key] {
			return nil, errors.New("duplicate package field")
		}
		seen[key] = true
		if e = stream.expect(':'); e != nil {
			return nil, e
		}
		if key == "blocks" {
			if e = stream.expect('['); e != nil {
				return nil, e
			}
			b, e := stream.next()
			if e != nil {
				return nil, e
			}
			if b != ']' {
				if e = stream.r.UnreadByte(); e != nil {
					return nil, e
				}
				for {
					raw, e := stream.value(maxBlockJSON)
					if e != nil {
						return nil, e
					}
					var block Block
					if e = strictDecode(raw, &block); e != nil {
						return nil, e
					}
					encoded, e := json.Marshal(block)
					if e != nil {
						return nil, e
					}
					if e = binary.Write(file, binary.BigEndian, uint32(len(encoded))); e != nil {
						return nil, e
					}
					if _, e = file.Write(encoded); e != nil {
						return nil, e
					}
					b, e = stream.next()
					if e != nil {
						return nil, e
					}
					if b == ']' {
						break
					}
					if b != ',' {
						return nil, errors.New("invalid block array separator")
					}
				}
			}
		} else {
			raw, e := stream.value(maxMetadataJSON)
			if e != nil {
				return nil, e
			}
			switch key {
			case "schema":
				e = strictDecode(raw, &p.Schema)
			case "genesis":
				if e = uniqueJSON(raw); e == nil {
					p.Genesis = bytes.Clone(raw)
				}
			case "validator_state":
				e = strictDecode(raw, &p.ValidatorState)
			default:
				e = errors.New("unknown package field")
			}
			if e != nil {
				return nil, e
			}
		}
		b, e := stream.next()
		if e != nil {
			return nil, e
		}
		if b == '}' {
			break
		}
		if b != ',' {
			return nil, errors.New("invalid package separator")
		}
	}
	if len(seen) != 4 {
		return nil, errors.New("missing package field")
	}
	if _, e := stream.next(); e != io.EOF {
		return nil, errors.New("trailing package data")
	}
	if limited.N == 0 {
		return nil, errors.New("stream byte limit exceeded")
	}
	if e := file.Sync(); e != nil {
		return nil, e
	}
	source := func(visit func(Block) error) error {
		f, e := os.Open(filepath.Join(dir, "blocks"))
		if e != nil {
			return e
		}
		defer f.Close()
		reader := bufio.NewReaderSize(f, 64<<10)
		for {
			var size uint32
			e = binary.Read(reader, binary.BigEndian, &size)
			if e == io.EOF {
				return nil
			}
			if e != nil {
				return e
			}
			if size > maxBlockJSON {
				return errors.New("corrupt spool length")
			}
			raw := make([]byte, int(size))
			if _, e = io.ReadFull(reader, raw); e != nil {
				return e
			}
			var item Block
			if e = strictDecode(raw, &item); e != nil {
				return e
			}
			if e = visit(item); e != nil {
				return e
			}
		}
	}
	// Match json.Marshal(Package) exactly without ever assembling its block array.
	hash := sha3.NewLegacyKeccak256()
	prefix, e := json.Marshal(struct {
		Schema  uint32          `json:"schema"`
		Genesis json.RawMessage `json:"genesis"`
	}{p.Schema, p.Genesis})
	if e != nil {
		return nil, e
	}
	_, _ = hash.Write(prefix[:len(prefix)-1])
	_, _ = hash.Write([]byte(`,"blocks":[`))
	first := true
	if e = source(func(item Block) error {
		raw, e := json.Marshal(item)
		if e != nil {
			return e
		}
		if !first {
			_, _ = hash.Write([]byte{','})
		}
		first = false
		_, _ = hash.Write(raw)
		return nil
	}); e != nil {
		return nil, e
	}
	suffix, e := json.Marshal(p.ValidatorState)
	if e != nil {
		return nil, e
	}
	_, _ = hash.Write([]byte(`],"validator_state":`))
	_, _ = hash.Write(suffix)
	_, _ = hash.Write([]byte{'}'})
	out, err = verifySource(p, trust, source, hexBytes(hash.Sum(nil)), false)
	if err != nil {
		return nil, err
	}
	out.cleanup = func() error { return os.RemoveAll(dir) }
	keep = true
	return out, nil
}
