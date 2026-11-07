# Test-only runtime for the governance_recovery LinuxRuntime scenarios. script/build_recovery_runtime.sh
# stages the host-built client, Go helpers, stock Comet and runtime scripts under rootfs/ and passes the
# host's own distribution (ID:VERSION_ID from os-release) as BASE_IMAGE, so the host-built glibc client
# runs unchanged. tests/runtime_build_test.py RecoveryImage keeps the staged files, tools, user, WORKDIR,
# ENV and ENTRYPOINT equal to the production Dockerfile's runtime stages.
ARG ALETHIA_RETH_IMAGE
ARG BASE_IMAGE

FROM ${ALETHIA_RETH_IMAGE} AS execution-runtime

FROM ${BASE_IMAGE}

RUN apt-get update && \
  apt-get install -y jq curl python3 libstdc++6 && \
  rm -rf /var/lib/apt/lists/* && \
  groupadd --gid 10001 etna-comet && \
  useradd --uid 10001 --gid 10001 --no-create-home etna-comet

WORKDIR /app

COPY --from=execution-runtime /app/alethia-reth ./alethia-reth
COPY rootfs/ /
# /app/etna-el-import is deliberately absent: no recovery-image consumer imports, and the
# production-image job covers the importer. ETNA_EL_IMPORT_BIN therefore dangles by design.
ENV ETNA_SIGNER_BIN=/app/etna-signer ETNA_EL_IMPORT_BIN=/app/etna-el-import ETNA_EL_BIN=/app/alethia-reth ETNA_COMET_UID=10001 ETNA_COMET_GID=10001
# Turn a host/base ABI mismatch into a build error instead of a scenario failure.
RUN ./taiko-client --help > /dev/null && cometbft version
ENTRYPOINT ["./taiko-client"]
