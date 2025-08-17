#!/bin/bash

# Read the Foundry version from .foundry-version file
FOUNDRY_VERSION=$(cat .foundry-version)

echo "Installing Foundry version: $FOUNDRY_VERSION"

# Install foundryup if not already installed
if ! command -v foundryup &> /dev/null; then
    echo "Installing foundryup..."
    curl -L https://foundry.paradigm.xyz | bash
    source ~/.bashrc || source ~/.zshrc
fi

# Install the specific Foundry version
foundryup --version $FOUNDRY_VERSION

echo "Foundry installation complete. Version installed:"
forge --version