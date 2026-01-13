CARGO ?= cargo
CLIPPY_FLAGS ?= --all-targets --all-features -D warnings
TEST_FLAGS ?=
BUILD_FLAGS ?=

.PHONY: fmt fmt-check lint test build check clean

fmt:
	$(CARGO) fmt

fmt-check:
	$(CARGO) fmt -- --check

lint:
	$(CARGO) clippy $(CLIPPY_FLAGS)

test:
	$(CARGO) test $(TEST_FLAGS)

build:
	$(CARGO) build $(BUILD_FLAGS)

check: fmt-check lint test

clean:
	$(CARGO) clean
