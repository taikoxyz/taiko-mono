#!/bin/bash

# Location of the .env file
env_file="./.env"

# Config paths
bridgesPath="config/configuredBridges.json"
chainsPath="config/configuredChains.json"
tokensPath="config/configuredCustomToken.json"
relayerPath="config/configuredRelayer.json"

# Create a backup of the existing .env file
cp $env_file "${env_file}.bak"

# List of JSON config files
json_files=(
  $bridgesPath
  $chainsPath
  $tokensPath
  $relayerPath
)

# Loop through each JSON file
for json_file in "${json_files[@]}"; do
  # Check if the file exists
  if [[ -f "$json_file" ]]; then
    echo "Exporting $json_file to .env file..."

    # Read and encode the file content
    base64_content=$(base64 -w 0 "$json_file")

    # Create env variable key from filename
    filename=$(basename "$json_file" .json) # removing the .json extension

    # Conditionally trim whitespace, chain names might contain spaces, so we exclude that file
    if [[ "$filename" != "configuredChains" ]]; then
      base64_content=$(base64 -w 0 "$json_file" | tr -d '[:space:]')
    else
      base64_content=$(base64 -w 0 "$json_file")
    fi

    env_key=$(echo "$filename" | sed 's/\([a-z0-9]\)\([A-Z]\)/\1_\2/g' | tr '[:lower:]' '[:upper:]')

    # Try to find and replace the line; if it fails, append to the file
    if sed -i.bak "s/^export $env_key=.*/export $env_key='$base64_content'/" $env_file || echo -e "\nexport $env_key='$base64_content'" >> $env_file; then
      echo "Successfully updated $env_key"
    else
      echo "Failed to update $env_key"
    fi
  else
    echo "Warning: File $json_file does not exist."
  fi
done
echo "Done."