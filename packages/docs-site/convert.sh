#!/bin/bash

# Function to convert markdown links to the desired component structure
convert_markdown_links() {
    local file_path="$1"

    # Use perl to perform the substitution
    perl -pe 's/\[([^\]]+)\]\((https?:\/\/[^\)]+)\)/<NewTabLink href="\2" text="\1"\/>/g' "$file_path" > "${file_path}.tmp"

    # Move the temporary file to the original file
    mv "${file_path}.tmp" "$file_path"

    echo "Conversion completed."
}

# Check if the script received the file path argument
if [ -z "$1" ]; then
    echo "Usage: $0 path_to_file"
    exit 1
fi

convert_markdown_links "$1"
