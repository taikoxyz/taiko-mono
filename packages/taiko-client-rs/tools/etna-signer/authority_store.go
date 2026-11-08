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
