#!/bin/bash

RED='\033[1;31m'
NC='\033[0m' # No Color

COMPOSE="docker compose -f internal/docker/nodes/docker-compose.yml"

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
  if ! command -v "$1" &>/dev/null; then
    print_error "$1 could not be found"
    exit
  fi
}

compose_down() {
  local services=("$@")
  echo
  echo "stopping services..."
  $COMPOSE down "${services[@]}" #--remove-orphans
  echo "done"
}

compose_up() {
  local services=("$@")
  echo
  echo "launching services..."
  $COMPOSE up --quiet-pull "${services[@]}" -d --wait --build
  echo "done"
}
