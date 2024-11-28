.DEFAULT_TARGET: help

SOLIDITY_VERSION=0.8.17
TEST_TREE_MARKDOWN=TEST_TREE.md
SOURCE_FILES=$(shell find test -type f -name '*.t.yaml')
TREE_FILES = $(SOURCE_FILES:.t.yaml=.tree)
TARGET_TEST_FILES = $(SOURCE_FILES:.tree=.t.sol)
MAKE_TEST_TREE=deno run ./script/make-test-tree.ts
MAKEFILE=Makefile

.PHONY: help
help:
	@echo "Available targets:"
	@grep -E '^[a-zA-Z0-9_-]+:.*?## .*$$' $(MAKEFILE) \
	   | sed -n 's/^\(.*\): \(.*\)##\(.*\)/- make \1  \3/p'

all: sync markdown ##      Builds all tree files and updates the test tree markdown

sync: $(TREE_FILES) ##     Scaffold or sync tree files into solidity tests
	@for file in $^; do \
		if [ ! -f $${file%.tree}.t.sol ]; then \
			echo "[Scaffold]   $${file%.tree}.t.sol" ; \
			bulloak scaffold -s $(SOLIDITY_VERSION) --vm-skip -w $$file ; \
		else \
			echo "[Sync file]  $${file%.tree}.t.sol" ; \
			bulloak check --fix $$file ; \
		fi \
	done

check: $(TREE_FILES) ##    Checks if solidity files are out of sync
	bulloak check $^

markdown: $(TEST_TREE_MARKDOWN) ## Generates a markdown file with the test definitions rendered as a tree

# Internal targets

# Generate a markdown file with the test trees
$(TEST_TREE_MARKDOWN): $(TREE_FILES)
	@echo "[Markdown]   TEST_TREE.md"
	@echo "# Test tree definitions" > $@
	@echo "" >> $@
	@echo "Below is the graphical definition of the contract tests implemented on [the test folder](./test)" >> $@
	@echo "" >> $@

	@for file in $^; do \
		echo "\`\`\`" >> $@ ; \
		cat $$file >> $@ ; \
		echo "\`\`\`" >> $@ ; \
		echo "" >> $@ ; \
	done

# Internal dependencies and transformations

$(TREE_FILES): $(SOURCE_FILES)

%.tree: %.t.yaml
	@for file in $^; do \
	  echo "[Convert]    $$file -> $${file%.t.yaml}.tree" ; \
		cat $$file | $(MAKE_TEST_TREE) > $${file%.t.yaml}.tree ; \
	done

# Global

.PHONY: init
init: ##     Check the dependencies and prompt to install if needed
	@which deno > /dev/null && echo "Deno is available" || echo "Install Deno:  curl -fsSL https://deno.land/install.sh | sh"
	@which bulloak > /dev/null && echo "bulloak is available" || echo "Install bulloak:  cargo install bulloak"

.PHONY: clean
clean: ##    Clean the intermediary tree files
	rm -f $(TREE_FILES)
	rm -f $(TEST_TREE_MARKDOWN)