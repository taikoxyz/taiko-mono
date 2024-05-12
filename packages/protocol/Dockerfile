FROM node:20-slim AS base
ENV PNPM_HOME="/pnpm"
ENV PATH="$PNPM_HOME:$PATH"
RUN corepack enable

FROM ghcr.io/foundry-rs/foundry:latest as source

FROM base AS build
COPY . /usr/src/app
WORKDIR /usr/src/app
RUN apt-get -yq update && \
     apt-get -yqq install ssh git python3 python3-dev curl

RUN --mount=type=cache,id=pnpm,target=/pnpm/store pnpm install

COPY --from=source /usr/local/bin/forge /usr/local/bin/forge
RUN --mount=type=cache,id=pnpm,target=/pnpm/store pnpm compile

CMD sleep infinity
