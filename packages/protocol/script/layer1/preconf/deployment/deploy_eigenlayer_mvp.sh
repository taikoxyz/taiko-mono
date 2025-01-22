set -e

: "${PRIVATE_KEY:?Environment variable PRIVATE_KEY is required}"
: "${FORK_URL:?Environment variable FORK_URL is required}"

forge script scripts/deployment/DeployEigenlayerMVP.s.sol:DeployEigenlayerMVP \
  --rpc-url $FORK_URL \
  --broadcast \
  --skip-simulation \
  --private-key $PRIVATE_KEY