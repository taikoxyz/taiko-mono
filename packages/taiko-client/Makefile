GIT_COMMIT := $(shell git rev-parse HEAD)
GIT_DATE := $(shell git show -s --format='%ct')

LD_FLAGS_ARGS +=-X github.com/taikoxyz/taiko-mono/packages/taiko-client/version.GitCommit=$(GIT_COMMIT)
LD_FLAGS_ARGS +=-X github.com/taikoxyz/taiko-mono/packages/taiko-client/version.GitDate=$(GIT_DATE)

LD_FLAGS := -ldflags "$(LD_FLAGS_ARGS)"

build:
	@GO111MODULE=on CGO_CFLAGS="-O -D__BLST_PORTABLE__" CGO_CFLAGS_ALLOW="-O -D__BLST_PORTABLE__" go build -v $(LD_FLAGS) -o bin/taiko-client cmd/main.go

clean:
	@rm -rf bin/*

lint:
	@go install golang.org/x/tools/cmd/goimports@latest \
	&& go install github.com/golangci/golangci-lint/cmd/golangci-lint@v1.56.2 \
	&& goimports -local "github.com/taikoxyz/taiko-mono/packages/taiko-client" -w ./ \
	&& golangci-lint run

test:
	PACKAGE=${PACKAGE} \
	RUN_TESTS=true \
		./integration_test/entrypoint.sh

dev_net:
	COMPILE_PROTOCOL=${COMPILE_PROTOCOL} \
		./integration_test/entrypoint.sh

gen_bindings:
	TAIKO_GETH_DIR=${TAIKO_GETH_DIR} \
		./scripts/gen_bindings.sh

.PHONY: build \
				clean \
				lint \
				test \
				dev_net \
				gen_bindings
