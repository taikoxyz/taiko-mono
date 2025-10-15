# Default configuration
DATABASE_URL ?= mysql://root:password@127.0.0.1:3306/blobindexer
BEACON_API ?= http://34.45.250.99:5052
DOCKER_COMPOSE ?= docker compose
WATCH_ADDRESS ?= 0x50A576435E2D9c179124D657d804eb56A10b6999

.PHONY: db-up db-down db-logs fmt lint test migrate run check sqlx-install

db-up:
	$(DOCKER_COMPOSE) up -d mysql

db-down:
	$(DOCKER_COMPOSE) down

db-logs:
	$(DOCKER_COMPOSE) logs -f mysql

fmt:
	cargo fmt

lint:
	cargo clippy --all-targets

check: fmt lint

test:
	DATABASE_URL=$(DATABASE_URL) cargo test

migrate:
	@which sqlx >/dev/null || (echo "sqlx CLI not found. Install with 'cargo install sqlx-cli --no-default-features --features mysql'" && exit 1)
	DATABASE_URL=$(DATABASE_URL) sqlx migrate run

run:
	DATABASE_URL=$(DATABASE_URL) cargo run --bin blobindexer -- \
		--beacon-api $(BEACON_API) \
		--database-url $(DATABASE_URL) \
		--watch-address $(WATCH_ADDRESS)

sqlx-install:
	cargo install sqlx-cli --no-default-features --features mysql
