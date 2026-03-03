#!/bin/bash

RED='\033[1;31m'
NC='\033[0m' # No Color

COMPOSE_YML="internal/docker/nodes/docker-compose.yml"

if docker compose version > /dev/null 2>&1; then
    DOCKER_COMPOSE=(docker compose)
elif command -v docker-compose > /dev/null 2>&1; then
    DOCKER_COMPOSE=(docker-compose)
else
    echo "ERROR: neither 'docker compose' nor 'docker-compose' is available"
    exit 1
fi

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
    exit
  fi
}

compose_down() {
  local services=("$@")
  echo
  echo "stopping services..."
  "${DOCKER_COMPOSE[@]}" -f "$COMPOSE_YML" down -v "${services[@]}"
  echo "done"
}

compose_up() {
  local services=("$@")
  echo
  echo "launching services..."
  "${DOCKER_COMPOSE[@]}" -f "$COMPOSE_YML" up --quiet-pull -d --wait "${services[@]}"
  echo "done"
}
