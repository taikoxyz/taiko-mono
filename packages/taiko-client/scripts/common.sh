#!/bin/bash
RED='\033[1;31m'
NC='\033[0m' # No Color

PROJECT_ROOT="${PROJECT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
COMPOSE_YML="$PROJECT_ROOT/internal/docker/nodes/docker-compose.yml"

if ! command docker compose version > /dev/null 2>&1; then
    echo "ERROR: 'docker compose' is not available"
    exit 1
fi

docker_compose() {
  docker compose -f "$COMPOSE_YML" "$@"
}

print_error() {
  local msg="$1"
  echo -e "${RED}$msg${NC}"
}

check_env() {
  local name="$1"
  local value="${!name}"

  if [ -z "$value" ]; then
    print_error "$name not set in env"
    exit 1
  fi
}

check_command() {
  if ! command -v "$1" &> /dev/null; then
    print_error "$1 could not be found"
    exit 1
  fi
}

compose_down() {
  local services=("$@")
  echo
  echo "stopping services..."
  docker_compose down -v "${services[@]}"
  echo "done"
}

compose_up() {
  local services=("$@")
  echo
  echo "launching services..."
  docker_compose up --quiet-pull -d --wait "${services[@]}"
  echo "done"
}
