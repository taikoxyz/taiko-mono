# custom-runner

Custom self-hosted GitHub Actions runner with `gh` CLI baked in.

Workflow only triggers manually, when triggered will pull latest version of `actions/actions-runner` and bake `gh` in before pushing to `us-docker.pkg.dev/evmchain/images/custom-runner:latest`.

# Build locally and push

cd packages/custom-runner
docker build -t ${DOCKER_USER}/${DOCKER_REPO}:latest .
docker push ${DOCKER_USER}/${DOCKER_REPO}:latest

# Build locally and push (multi-arch)

cd packages/custom-runner
docker buildx build --platform linux/amd64,linux/arm64 --tag ${DOCKER_USER}/${DOCKER_REPO}:latest --push .
