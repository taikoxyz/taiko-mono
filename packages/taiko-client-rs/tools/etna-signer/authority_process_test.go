package main

import (
	"bufio"
	"bytes"
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"testing"
	"time"
)

// The child executes the same durable transition phases as authorize, then pauses at the
// selected boundary. The parent uses SIGKILL: no deferred Close or graceful cleanup runs.
func TestAuthorityCrashHelper(t *testing.T) {
	path := os.Getenv("ETNA_AUTHORITY_CRASH_CONFIG")
	if path == "" {
		return
	}
	raw, e := os.ReadFile(path)
	if e != nil {
		t.Fatal(e)
	}
	var c authorityConfig
	if e = json.Unmarshal(raw, &c); e != nil {
		t.Fatal(e)
	}
	a, e := openAuthority(c)
	if e != nil {
		t.Fatal(e)
	}
	chain, r := readyDomain(t, c, 2)
	d := authorityDomain{Generation: 2, Chain: chain, State: filepath.Join(a.config.Root, chain+".json"), Origin: r.RecoveryOrigin}
	stage := os.Getenv("ETNA_AUTHORITY_CRASH_STAGE")
	if stage != "before-intent" {
		if e = armUncertainty(uncertaintyPath(c.LegacyState), "authority transition", d.State); e != nil {
			t.Fatal(e)
		}
		if e = a.recordIntent(d); e != nil {
			t.Fatal(e)
		}
	}
	if stage == "state" || stage == "manifest" || stage == "signature" {
		if e = a.stageDomain(d); e != nil {
			t.Fatal(e)
		}
	}
	if stage == "manifest" || stage == "signature" {
		if e = a.publishDomain(d); e != nil {
			t.Fatal(e)
		}
	}
	if stage == "signature" {
		if e = os.Remove(a.intentPath()); e != nil {
			t.Fatal(e)
		}
		if e = syncDirectory(a.config.Root); e != nil {
			t.Fatal(e)
		}
		a.pending = nil
		if e = finishUncertainty(uncertaintyPath(c.LegacyState)); e != nil {
			t.Fatal(e)
		}
		p, e := a.authorize(chain, r)
		if e != nil {
			t.Fatal(e)
		}
		v := authorityVote(7)
		if e = p.SignVote(chain, v); e != nil {
			t.Fatal(e)
		}
		if e = exclusiveDurable(path+".signature", v.Signature); e != nil {
			t.Fatal(e)
		}
	}
	fmt.Println("durable-boundary")
	for {
		time.Sleep(time.Second)
	}
}
func TestAuthoritySIGKILLTransitionBoundaries(t *testing.T) {
	for _, stage := range []string{"before-intent", "intent", "state", "manifest", "signature"} {
		t.Run(stage, func(t *testing.T) {
			c := authorityFixture(t)
			old, oldReady := readyDomain(t, c, 0)
			a, e := openAuthority(c)
			if e != nil {
				t.Fatal(e)
			}
			p, e := a.authorize(old, oldReady)
			if e != nil {
				t.Fatal(e)
			}
			if e = p.SignVote(old, authorityVote(20)); e != nil {
				t.Fatal(e)
			}
			a.Close()
			before, _ := os.ReadFile(c.LegacyState)
			keyBefore, _ := os.ReadFile(c.Key)
			config := filepath.Join(t.TempDir(), "config.json")
			raw, _ := json.Marshal(c)
			os.WriteFile(config, raw, 0600)
			child := exec.Command(os.Args[0], "-test.run=^TestAuthorityCrashHelper$")
			child.Env = append(os.Environ(), "ETNA_AUTHORITY_CRASH_CONFIG="+config, "ETNA_AUTHORITY_CRASH_STAGE="+stage)
			out, e := child.StdoutPipe()
			if e != nil {
				t.Fatal(e)
			}
			var stderr bytes.Buffer
			child.Stderr = &stderr
			if e = child.Start(); e != nil {
				t.Fatal(e)
			}
			ready := make(chan string, 1)
			go func() { line, _ := bufio.NewReader(out).ReadString('\n'); ready <- line }()
			select {
			case line := <-ready:
				if line != "durable-boundary\n" {
					child.Process.Kill()
					child.Wait()
					t.Fatalf("child failed %q: %s", line, stderr.String())
				}
			case <-time.After(10 * time.Second):
				child.Process.Kill()
				child.Wait()
				t.Fatal("child did not reach boundary")
			}
			if other, e := openAuthority(c); e == nil {
				other.Close()
				child.Process.Kill()
				child.Wait()
				t.Fatal("live child did not own key")
			}
			child.Process.Kill()
			if e = child.Wait(); e == nil {
				t.Fatal("child was not killed")
			}
			if stage == "intent" || stage == "state" || stage == "manifest" {
				if other, err := openAuthority(c); err == nil {
					other.Close()
					t.Fatal("interrupted authority mutation resumed without fence inspection")
				}
				if err := os.Remove(uncertaintyPath(c.LegacyState)); err != nil {
					t.Fatal(err)
				}
			}
			a, e = openAuthority(c)
			if e != nil {
				t.Fatal(e)
			}
			defer a.Close()
			_, e = a.authorize(old, oldReady)
			if stage == "before-intent" {
				if e != nil {
					t.Fatal(e)
				}
			} else if e == nil {
				t.Fatal("crash reopened old generation")
			}
			next, r := readyDomain(t, c, 2)
			p, e = a.authorize(next, r)
			if e != nil {
				t.Fatal(e)
			}
			v := authorityVote(7)
			if e = p.SignVote(next, v); e != nil {
				t.Fatal(e)
			}
			if stage == "signature" {
				previous, e := os.ReadFile(config + ".signature")
				if e != nil || !bytes.Equal(previous, v.Signature) {
					t.Fatal("crash changed same-HRS signature", e)
				}
			}
			after, _ := os.ReadFile(c.LegacyState)
			keyAfter, _ := os.ReadFile(c.Key)
			if !bytes.Equal(before, after) || !bytes.Equal(keyBefore, keyAfter) {
				t.Fatal("crash transition changed original signing files")
			}
		})
	}
}
