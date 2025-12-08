# Configuration
DATABASE_URL ?= mysql://urcindexer:password@127.0.0.1:3307/urcindexer
L1_RPC_URL ?= http://127.0.0.1:8545
REGISTRY_ADDRESS ?= 0x0000000000000000000000000000000000000000
L1_START_BLOCK ?= 1
MAX_L1_FORK_DEPTH ?= 2
INDEX_BLOCK_BATCH_SIZE ?= 25
RUST_LOG ?= info
DOCKER_COMPOSE ?= docker compose

.PHONY: db-up db-down db-logs fmt lint check run docker-build docker-run

db-up:
	$(DOCKER_COMPOSE) up -d mysql

db-down:
	$(DOCKER_COMPOSE) down

db-logs:
	$(DOCKER_COMPOSE) logs -f mysql

fmt:
	cargo fmt

lint:
	cargo clippy --all-targets --all-features

check: fmt lint

run:
	DATABASE_URL=$(DATABASE_URL) \
	L1_RPC_URL=$(L1_RPC_URL) \
	REGISTRY_ADDRESS=$(REGISTRY_ADDRESS) \
	L1_START_BLOCK=$(L1_START_BLOCK) \
	MAX_L1_FORK_DEPTH=$(MAX_L1_FORK_DEPTH) \
	INDEX_BLOCK_BATCH_SIZE=$(INDEX_BLOCK_BATCH_SIZE) \
	RUST_LOG=$(RUST_LOG) \
	cargo run --bin urcindexer

docker-build:
	docker build -t urcindexer:latest .

docker-run: docker-build
	docker run --rm \
		--env DATABASE_URL=$(DATABASE_URL) \
		--env L1_RPC_URL=$(L1_RPC_URL) \
		--env REGISTRY_ADDRESS=$(REGISTRY_ADDRESS) \
		--env L1_START_BLOCK=$(L1_START_BLOCK) \
		--env MAX_L1_FORK_DEPTH=$(MAX_L1_FORK_DEPTH) \
		--env INDEX_BLOCK_BATCH_SIZE=$(INDEX_BLOCK_BATCH_SIZE) \
		--env RUST_LOG=$(RUST_LOG) \
		urcindexer:latest
