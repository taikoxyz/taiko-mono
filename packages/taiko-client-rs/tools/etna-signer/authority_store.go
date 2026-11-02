package main

import (
	"bytes"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"reflect"
	"strings"
	"syscall"

	"github.com/cometbft/cometbft/crypto"
	cmtjson "github.com/cometbft/cometbft/libs/json"
	"github.com/cometbft/cometbft/libs/protoio"
	"github.com/cometbft/cometbft/privval"
	tm "github.com/cometbft/cometbft/proto/tendermint/types"
)

// Authority metadata uses strict JSON; absence, truncation and ambiguity never mean fresh state.
func readAuthorityJSON(path string, value any) error {
	canonical, err := existingFile(path)
	if err != nil {
		return err
	}
	if canonical != path {
		return errors.New("authority metadata must not be a symlink")
	}
	if err = singleLinkState(path); err != nil {
		return err
	}
	raw, err := os.ReadFile(path)
	if err != nil {
		return err
	}
	if err = uniqueJSON(json.NewDecoder(bytes.NewReader(raw))); err != nil {
		return err
	}
	if err = requiredAuthorityFields(raw, reflect.TypeOf(value).Elem()); err != nil {
		return err
	}
	d := json.NewDecoder(bytes.NewReader(raw))
	d.DisallowUnknownFields()
	if err = d.Decode(value); err != nil {
		return err
	}
	if err = d.Decode(new(any)); err != io.EOF {
		return errors.New("trailing authority data")
	}
	return nil
}

// Every persisted field is mandatory. Only optional nested origin structs may be null.
func requiredAuthorityFields(raw []byte, t reflect.Type) error {
	if bytes.Equal(bytes.TrimSpace(raw), []byte("null")) {
		if t.Kind() == reflect.Pointer && t.Elem().Kind() == reflect.Struct {
			return nil
		}
		return errors.New("null authority field")
	}
	if t.Kind() == reflect.Pointer {
		return requiredAuthorityFields(raw, t.Elem())
	}
	switch t.Kind() {
	case reflect.Struct:
		var fields map[string]json.RawMessage
		if err := json.Unmarshal(raw, &fields); err != nil {
			return err
		}
		for i := 0; i < t.NumField(); i++ {
			field := t.Field(i)
			name := strings.Split(field.Tag.Get("json"), ",")[0]
			value, ok := fields[name]
			if !ok {
				return fmt.Errorf("missing authority field %s", name)
			}
			if err := requiredAuthorityFields(value, field.Type); err != nil {
				return err
			}
		}
	case reflect.Slice:
		var items []json.RawMessage
		if err := json.Unmarshal(raw, &items); err != nil {
			return err
		}
		for _, item := range items {
			if err := requiredAuthorityFields(item, t.Elem()); err != nil {
				return err
			}
		}
	}
	return nil
}
func syncDirectory(path string) error {
	f, e := os.Open(path)
	if e != nil {
		return e
	}
	defer f.Close()
	return f.Sync()
}
func exclusiveDurable(path string, data []byte) error {
	f, e := os.OpenFile(path, os.O_WRONLY|os.O_CREATE|os.O_EXCL, 0600)
	if e != nil {
		return e
	}
	defer f.Close()
	if _, e = f.Write(data); e != nil {
		return e
	}
	if e = f.Sync(); e != nil {
		return e
	}
	return syncDirectory(filepath.Dir(path))
}
func publishAuthority(path string, value any) error {
	data, e := json.Marshal(value)
	if e != nil {
		return e
	}
	f, e := os.CreateTemp(filepath.Dir(path), ".authority-")
	if e != nil {
		return e
	}
	defer os.Remove(f.Name())
	defer f.Close()
	if e = f.Chmod(0600); e != nil {
		return e
	}
	if _, e = f.Write(data); e != nil {
		return e
	}
	if e = f.Sync(); e != nil {
		return e
	}
	if e = f.Close(); e != nil {
		return e
	}
	if e = os.Rename(f.Name(), path); e != nil {
		return e
	}
	return syncDirectory(filepath.Dir(path))
}
func ownerLock(path string) (*os.File, error) {
	f, e := os.OpenFile(path, os.O_CREATE|os.O_RDWR|syscall.O_NOFOLLOW, 0600)
	if e != nil {
		return nil, e
	}
	if e = singleLinkState(path); e == nil {
		e = syscall.Flock(int(f.Fd()), syscall.LOCK_EX|syscall.LOCK_NB)
	}
	if e != nil {
		f.Close()
		return nil, fmt.Errorf("another signer owns signing authority: %w", e)
	}
	return f, nil
}

// validateHRS reads using stock codecs and authenticates persisted canonical bytes with the
// registered public key. Unsigned means exactly the stock zero state, never an arbitrary HRS.
func validateHRS(path, chain string, pub crypto.PubKey) (bool, error) {
	canonical, e := existingFile(path)
	if e != nil {
		return false, e
	}
	if canonical != path {
		return false, errors.New("domain HRS must be canonical")
	}
	if e = singleLinkState(path); e != nil {
		return false, e
	}
	raw, e := os.ReadFile(path)
	if e != nil {
		return false, e
	}
	var fields map[string]json.RawMessage
	if e = json.Unmarshal(raw, &fields); e != nil {
		return false, e
	}
	if e = uniqueJSON(json.NewDecoder(bytes.NewReader(raw))); e != nil {
		return false, e
	}
	for _, key := range []string{"height", "round", "step"} {
		v, ok := fields[key]
		if !ok || bytes.Equal(bytes.TrimSpace(v), []byte("null")) {
			return false, errors.New("missing HRS field")
		}
	}
	for key := range fields {
		switch key {
		case "height", "round", "step", "signature", "signbytes":
		default:
			return false, errors.New("unknown HRS field")
		}
	}
	var s privval.FilePVLastSignState
	if e = cmtjson.Unmarshal(raw, &s); e != nil {
		return false, e
	}
	if s.Height == 0 && s.Round == 0 && s.Step == 0 && len(s.Signature) == 0 && len(s.SignBytes) == 0 {
		return true, nil
	}
	if s.Height <= 0 || s.Round < 0 || len(s.Signature) == 0 || len(s.SignBytes) == 0 || !pub.VerifySignature(s.SignBytes, s.Signature) {
		return false, errors.New("ambiguous or unauthentic HRS")
	}
	var domain string
	var height int64
	var round int64
	switch s.Step {
	case 1:
		var p tm.CanonicalProposal
		if e = protoio.UnmarshalDelimited(s.SignBytes, &p); e != nil {
			return false, e
		}
		if p.Type != tm.ProposalType {
			return false, errors.New("invalid proposal HRS")
		}
		domain, height, round = p.ChainID, p.Height, p.Round
	case 2, 3:
		var v tm.CanonicalVote
		if e = protoio.UnmarshalDelimited(s.SignBytes, &v); e != nil {
			return false, e
		}
		if (s.Step == 2 && v.Type != tm.PrevoteType) || (s.Step == 3 && v.Type != tm.PrecommitType) {
			return false, errors.New("invalid vote HRS")
		}
		domain, height, round = v.ChainID, v.Height, v.Round
	default:
		return false, errors.New("invalid HRS step")
	}
	if domain != chain || height != s.Height || round != int64(s.Round) {
		return false, errors.New("signed HRS domain/height/round mismatch")
	}
	return false, nil
}
