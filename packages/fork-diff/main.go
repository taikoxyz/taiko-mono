package main

import (
	"bytes"
	"context"
	"crypto/rand"
	"embed"
	"encoding/hex"
	"errors"
	"flag"
	"fmt"
	t2html "github.com/buildkite/terminal-to-html/v3"
	"github.com/go-git/go-git/v5"
	"github.com/go-git/go-git/v5/plumbing"
	"github.com/go-git/go-git/v5/plumbing/format/diff"
	"github.com/go-git/go-git/v5/plumbing/object"
	"github.com/gomarkdown/markdown"
	"github.com/gomarkdown/markdown/html"
	"github.com/gomarkdown/markdown/parser"
	"gopkg.in/yaml.v3"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"text/template"
)

//go:embed page.gohtml
var page embed.FS

func main() {
	repoPathStr := flag.String("repo", ".", "path to local git repository (fork)")
	upstreamRepoPathStr := flag.String("upstream-repo", "", "path to local git repository (upstream)")
	forkPagePathStr := flag.String("fork", "fork.yaml", "fork page definition")
	outStr := flag.String("out", "index.html", "output")
	flag.Parse()

	// Upstream repo path defaults to the same value as repoPathStr if not set
	if *upstreamRepoPathStr == "" {
		upstreamRepoPathStr = repoPathStr
	}

	must := func(err error, msg string, args ...any) {
		if err != nil {
			_, _ = fmt.Fprintf(os.Stderr, msg, args...)
			_, _ = fmt.Fprintf(os.Stderr, "\nerror: %v", err)
			os.Exit(1)
		}
	}
	pageDefinition, err := readPageYaml(*forkPagePathStr)
	must(err, "failed to read page definition %q", *forkPagePathStr)
	if pageDefinition.Def == nil {
		must(errors.New("no fork definition defined"), "need to root fork definition")
	}

	forkRepo, err := git.PlainOpen(*repoPathStr)
	must(err, "failed to open git repository %q", *repoPathStr)

	baseRepo, err := git.PlainOpen(*upstreamRepoPathStr)
	must(err, "failed to open git repository %q", *upstreamRepoPathStr)

	findCommit := func(rr *RefRepo, repo *git.Repository) *object.Commit {
		if rr.Ref != "" && rr.Hash != "" {
			must(errors.New("hash and ref"), "cannot use both hash and reference")
		}
		if rr.Ref == "" && rr.Hash == "" {
			must(errors.New("no hash and no ref"), "need either hash or reference")
		}
		if rr.Ref != "" {
			ref, err := repo.Reference(plumbing.ReferenceName(rr.Ref), true)
			must(err, "failed to find git ref %q", rr.Ref)

			commit, err := repo.CommitObject(ref.Hash())
			must(err, "failed to open commit %s", ref.Hash())
			return commit
		}
		commit, err := repo.CommitObject(plumbing.NewHash(rr.Hash))
		must(err, "failed to find commit hash %s", rr.Hash)
		return commit
	}

	baseCommit := findCommit(&pageDefinition.Base, baseRepo)
	baseTree, err := baseCommit.Tree()
	must(err, "failed to open base git tree")

	forkCommit := findCommit(&pageDefinition.Fork, forkRepo)
	forkTree, err := forkCommit.Tree()
	must(err, "failed to open fork git tree")

	forkPatch, err := baseTree.PatchContext(context.Background(), forkTree)
	must(err, "failed to compute patch between base and fork")

	baseFiles := map[string]struct{}{}
	forkFiles := map[string]struct{}{}
	patchByName := make(map[string]diff.FilePatch, len(forkPatch.FilePatches()))
	for _, fp := range forkPatch.FilePatches() {
		from, to := fp.Files()
		if to != nil {
			patchByName[to.Path()] = fp
		} else if from != nil {
			patchByName[from.Path()] = fp
		} else {
			continue
		}
		if to != nil {
			forkFiles[to.Path()] = struct{}{}
		}
		if from != nil {
			baseFiles[from.Path()] = struct{}{}
		}
	}
	// remove the patches that are ignored
	ignored := make(map[string]diff.FilePatch)
	for k := range patchByName {
		for _, globPattern := range pageDefinition.Ignore {
			ok, err := filepath.Match(globPattern, k)
			must(err, "failed to check %q against ignore glob pattern %q", k, globPattern)
			if ok {
				ignored[k] = patchByName[k]
				delete(patchByName, k)
			}
		}
	}
	remaining := make(map[string]struct{})
	for k := range patchByName {
		remaining[k] = struct{}{}
	}
	must(pageDefinition.Def.hydrate(patchByName, remaining, 1), "failed to hydrate patch stats")
	if len(remaining) > 0 {
		remainingDef := &ForkDefinition{
			Title: "other changes",
			Level: 2,
		}
		remainingPaths := make([]string, 0, len(remaining))
		for k := range remaining {
			remainingPaths = append(remainingPaths, k)
		}
		sort.Strings(remainingPaths)
		for _, k := range remainingPaths {
			remainingDef.hydratePatch(k, patchByName[k])
		}
		pageDefinition.Def.Sub = append(pageDefinition.Def.Sub, remainingDef)
		pageDefinition.Def.LinesAdded += remainingDef.LinesAdded
		pageDefinition.Def.LinesDeleted += remainingDef.LinesDeleted
	}
	if len(ignored) > 0 {
		ignoredPaths := make([]string, 0, len(ignored))
		for k := range ignored {
			ignoredPaths = append(ignoredPaths, k)
		}
		sort.Strings(ignoredPaths)
		ignoredDef := &ForkDefinition{
			Title: "ignored changes",
			Level: 4,
		}
		for _, k := range ignoredPaths {
			ignoredDef.hydratePatch(k, ignored[k])
		}
		pageDefinition.Ignored = ignoredDef
	}

	templ := template.New("main")
	templ.Funcs(template.FuncMap{
		"renderMarkdown": func(md string) string {
			markdownRenderer := html.NewRenderer(html.RendererOptions{
				Flags:     html.Smartypants | html.SmartypantsFractions | html.SmartypantsDashes | html.SmartypantsLatexDashes,
				Generator: "forkdiff",
			})
			markdownParser := parser.NewWithExtensions(parser.CommonExtensions | parser.OrderedListStart)
			return string(markdown.ToHTML([]byte(md), markdownParser, markdownRenderer))
		},
		"page": func() *Page {
			return pageDefinition
		},
		"existsInBase": func(path string) bool {
			_, ok := baseFiles[path]
			return ok
		},
		"existsInFork": func(path string) bool {
			_, ok := forkFiles[path]
			return ok
		},
		"baseFileURL": func(path string) string {
			return fmt.Sprintf("%s/blob/%s/%s", pageDefinition.Base.URL, baseCommit.Hash, path)
		},
		"forkFileURL": func(path string) string {
			return fmt.Sprintf("%s/blob/%s/%s", pageDefinition.Fork.URL, forkCommit.Hash, path)
		},
		"baseCommitHash": func() string {
			return baseCommit.Hash.String()
		},
		"forkCommitHash": func() string {
			return forkCommit.Hash.String()
		},
		"renderPatch": func(fps *FilePatchStats) (string, error) {
			var out bytes.Buffer
			enc := diff.NewUnifiedEncoder(&out, 3)
			enc.SetSrcPrefix(pageDefinition.Base.Name + "/")
			enc.SetDstPrefix(pageDefinition.Fork.Name + "/")
			enc.SetColor(diff.NewColorConfig())

			err := enc.Encode(FilePatch{filePatch: fps.Patch})
			if err != nil {
				return "", errors.New("")
			}
			return string(t2html.Render(out.Bytes())), nil
		},
		"randomID": func() (string, error) {
			var out [12]byte
			if _, err := rand.Read(out[:]); err != nil {
				return "", err
			}
			return "id-" + hex.EncodeToString(out[:]), nil
		},
	})
	templ, err = templ.ParseFS(page, "*.gohtml")
	must(err, "failed to parse page template")

	f, err := os.OpenFile(*outStr, os.O_WRONLY|os.O_TRUNC|os.O_CREATE, 0o755)
	must(err, "failed to open output file")
	defer f.Close()
	must(templ.ExecuteTemplate(f, "main", pageDefinition), "failed to build page")
}

func readPageYaml(path string) (*Page, error) {
	f, err := os.OpenFile(path, os.O_RDONLY, 0)
	if err != nil {
		return nil, fmt.Errorf("failed to read page YAML file: %w", err)
	}
	defer f.Close()
	dec := yaml.NewDecoder(f)
	dec.KnownFields(true)
	var page Page
	if err := dec.Decode(&page); err != nil {
		return nil, fmt.Errorf("failed to decode page YAML file: %w", err)
	}
	return &page, nil
}

func countOperations(chunks []diff.Chunk, op diff.Operation) (out int) {
	for _, ch := range chunks {
		if ch.Type() == op {
			out += strings.Count(ch.Content(), "\n")
		}
	}
	return
}

type FilePatch struct {
	filePatch diff.FilePatch
}

var _ diff.Patch = FilePatch{}

func (p FilePatch) FilePatches() []diff.FilePatch {
	return []diff.FilePatch{p.filePatch}
}

func (p FilePatch) Message() string {
	return ""
}

type RefRepo struct {
	Name string `yaml:"name"`
	Ref  string `yaml:"ref,omitempty"`
	Hash string `yaml:"hash,omitempty"`
	URL  string `yaml:"url"`
}

type Page struct {
	Title  string          `yaml:"title"`
	Footer string          `yaml:"footer"`
	Base   RefRepo         `yaml:"base"`
	Fork   RefRepo         `yaml:"fork"`
	Def    *ForkDefinition `yaml:"def"`
	Ignore []string        `yaml:"ignore"`

	Ignored *ForkDefinition `yaml:"-"`
}

type FilePatchStats struct {
	Path         string
	LinesAdded   int
	LinesDeleted int
	Binary       bool
	Patch        diff.FilePatch
}

type ForkDefinition struct {
	Title       string            `yaml:"title,omitempty"`
	Description string            `yaml:"description,omitempty"`
	Globs       []string          `yaml:"globs,omitempty"`
	Sub         []*ForkDefinition `yaml:"sub,omitempty"`

	Files        []FilePatchStats `yaml:"-"`
	LinesAdded   int              `yaml:"-"`
	LinesDeleted int              `yaml:"-"`
	Level        int              `yaml:"-"`
}

func (fd *ForkDefinition) hydrate(patchByName map[string]diff.FilePatch, remaining map[string]struct{}, level int) error {
	fd.Level = level
	for i, sub := range fd.Sub {
		if err := sub.hydrate(patchByName, remaining, level+1); err != nil {
			return fmt.Errorf("sub definition %d failed to hydrate: %w", i, err)
		}
		fd.LinesAdded += sub.LinesAdded
		fd.LinesDeleted += sub.LinesDeleted
	}
	for i, globPattern := range fd.Globs {
		for name, p := range patchByName {
			if ok, err := filepath.Match(globPattern, name); err != nil {
				return fmt.Errorf("failed to glob match entry %q against pattern %q", name, globPattern)
			} else if ok {
				if _, ok := remaining[name]; !ok {
					return fmt.Errorf("file %q was matched by glob %d (%q) but is not remaining", name, i, globPattern)
				}
				delete(remaining, name)
				fd.hydratePatch(name, p)
			}
		}
	}
	return nil
}

func (fd *ForkDefinition) hydratePatch(name string, p diff.FilePatch) {
	stat := FilePatchStats{
		Path:         name,
		LinesAdded:   countOperations(p.Chunks(), diff.Add),
		LinesDeleted: countOperations(p.Chunks(), diff.Delete),
		Binary:       p.IsBinary(),
		Patch:        p,
	}
	fd.Files = append(fd.Files, stat)
	fd.LinesAdded += stat.LinesAdded
	fd.LinesDeleted += stat.LinesDeleted
}
