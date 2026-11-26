#!/usr/bin/env bash

set -euo pipefail

if [[ "$#" -ne 2 ]]; then
    echo "Usage: $0 filename.csv output_folder" >&2
    exit 1
fi

csv_file="$1"
download_dir="$2"
max_attempts="${MS2QUERY_DOWNLOAD_MAX_ATTEMPTS:-5}"
retry_delay_seconds="${MS2QUERY_DOWNLOAD_RETRY_DELAY_SECONDS:-10}"

if ! [[ "$max_attempts" =~ ^[1-9][0-9]*$ ]]; then
    echo "MS2QUERY_DOWNLOAD_MAX_ATTEMPTS must be a positive integer" >&2
    exit 1
fi

if ! [[ "$retry_delay_seconds" =~ ^[0-9]+$ ]]; then
    echo "MS2QUERY_DOWNLOAD_RETRY_DELAY_SECONDS must be a non-negative integer" >&2
    exit 1
fi

mkdir -p "$download_dir"

# Read the header and rows through one file descriptor so streamed manifests also work.
exec 3< "$csv_file"
if ! IFS= read -r header <&3; then
    echo "Model manifest is empty: $csv_file" >&2
    exit 1
fi

header="${header%$'\r'}"
if [[ "$header" != "url,md5,size" ]]; then
    echo "Invalid model manifest header in $csv_file; expected url,md5,size" >&2
    exit 1
fi

while IFS=',' read -r url expected_md5 expected_size; do
    url="${url%$'\r'}"
    expected_md5="${expected_md5%$'\r'}"
    expected_size="${expected_size%$'\r'}"

    [[ -z "$url" ]] && continue

    if ! [[ "$expected_md5" =~ ^[0-9a-fA-F]{32}$ ]]; then
        echo "Invalid MD5 checksum for $url" >&2
        exit 1
    fi

    if ! [[ "$expected_size" =~ ^[1-9][0-9]*$ ]]; then
        echo "Invalid expected size for $url" >&2
        exit 1
    fi

    filename="${url##*/}"
    filename="${filename%%\?*}"
    final_file="$download_dir/$filename"
    temporary_file="$download_dir/.${filename}.part"
    verified=false

    for ((attempt = 1; attempt <= max_attempts; attempt++)); do
        # A previous interrupted attempt may have left a partial file.
        rm -f "$temporary_file"

        if wget --timeout=60 --tries=1 --output-document "$temporary_file" "$url"; then
            actual_md5="$(md5sum "$temporary_file" | cut -d' ' -f1)"
            actual_size="$(wc -c < "$temporary_file" | tr -d '[:space:]')"

            if [[ "$actual_md5" == "${expected_md5,,}" && "$actual_size" == "$expected_size" ]]; then
                mv "$temporary_file" "$final_file"
                verified=true
                break
            fi

            echo "Downloaded file failed verification: $filename (attempt $attempt/$max_attempts)" >&2
        else
            echo "Download failed: $url (attempt $attempt/$max_attempts)" >&2
        fi

        if ((attempt < max_attempts)); then
            sleep "$retry_delay_seconds"
        fi
    done

    rm -f "$temporary_file"

    if [[ "$verified" != true ]]; then
        echo "Failed to download and verify $filename after $max_attempts attempts" >&2
        exit 1
    fi
done <&3
exec 3<&-
