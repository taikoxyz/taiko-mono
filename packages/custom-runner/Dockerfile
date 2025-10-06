FROM ghcr.io/actions/actions-runner:latest

RUN sudo apt update && \
  sudo apt -y install gh && \
  sudo apt clean && \
  sudo rm -rf /var/lib/apt/lists/*
