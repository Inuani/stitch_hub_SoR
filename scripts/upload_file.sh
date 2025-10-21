#!/bin/bash

# Usage: ./upload_file.sh <file_path> [title] [artist] [canister_name] [network]
# Example: ./upload_file.sh logo.png "Logo" "Artist Name" collection local

file=$1
title=${2:-$(basename "$file")}
artist=${3:-"Unknown"}
canister=${4:-collection}
network=${5:-local}

if [ -z "$file" ]; then
    echo "Error: File path is required"
    echo "Usage: $0 <file_path> [title] [artist] [canister_name] [network]"
    exit 1
fi

if [ ! -f "$file" ]; then
    echo "Error: File '$file' not found"
    exit 1
fi

contentType=$(file --mime-type -b "$file")
chunk_size=36000

echo "Uploading file: $file"
echo "Title: $title"
echo "Artist: $artist"
echo "Content-Type: $contentType"
echo "Canister: $canister"
echo "Network: $network"
echo ""

byteArray=( $(od -An -v -tuC "$file") )
total_chunks=$(( (${#byteArray[@]} + chunk_size - 1) / chunk_size ))

i=0
chunk=1
while [ $i -lt ${#byteArray[@]} ]
do
   echo "Uploading chunk $chunk of $total_chunks"
   payload="vec {"
   for byte in "${byteArray[@]:$i:$chunk_size}"
   do
       payload+="$byte;"
   done
   payload+="}"
   dfx canister --network "$network" call "$canister" upload "$payload"
   i=$((i + chunk_size))
   chunk=$((chunk + 1))
done

echo ""
echo "Finalizing upload..."
dfx canister --network "$network" call "$canister" uploadFinalize "(\"$title\", \"$artist\", \"$contentType\")"

if [ $? -eq 0 ]; then
    echo ""
    echo "✓ Upload completed successfully!"
else
    echo ""
    echo "✗ Upload finalization failed"
    exit 1
fi
