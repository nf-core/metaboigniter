#!/bin/bash

# Check if correct number of arguments are provided
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 filename.csv output_folder"
    exit 1
fi

# File containing URLs
CSV_FILE="$1"

# Directory where files will be downloaded
DOWNLOAD_DIR="$2"

# Create the directory if it doesn't exist
mkdir -p "$DOWNLOAD_DIR"

# Skip the first line (header) and read each subsequent line from the CSV file
tail -n +2 "$CSV_FILE" | while IFS= read -r url
do
    # Download the file using wget or curl
    wget -P "$DOWNLOAD_DIR" "$url" || curl -o "${DOWNLOAD_DIR}/$(basename $url)" "$url"
done
