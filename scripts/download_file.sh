#!/bin/bash

# Usage: ./download_file.sh <title> [output_filename] [canister_name] [network]
# Example: ./download_file.sh "Logo" logo_downloaded.png collection local

title=$1
output=${2:-"downloaded_file"}
canister=${3:-collection}
network=${4:-local}

if [ -z "$title" ]; then
    echo "Error: Title is required"
    echo "Usage: $0 <title> [output_filename] [canister_name] [network]"
    exit 1
fi

echo "Downloading file: $title"
echo "Canister: $canister"
echo "Network: $network"
echo ""

# Create Python script for parsing and downloading
cat > /tmp/download_canister_file.py << 'PYTHON_SCRIPT'
import subprocess
import sys
import re
import os

def parse_blob_from_candid(candid_output):
    """Extract binary data from Candid blob format"""
    # Find the blob content between quotes
    match = re.search(r'chunk = blob "([^"]*(?:"[^"]*)*)"', candid_output, re.DOTALL)
    if not match:
        return None

    blob_content = match.group(1)

    # Parse escaped hex bytes
    result = bytearray()
    i = 0
    while i < len(blob_content):
        if blob_content[i] == '\\' and i + 2 < len(blob_content):
            hex_byte = blob_content[i+1:i+3]
            try:
                result.append(int(hex_byte, 16))
                i += 3
            except ValueError:
                i += 1
        else:
            i += 1

    return bytes(result)

def get_file_metadata(canister, network, title):
    """Get file metadata from first chunk"""
    cmd = ['dfx', 'canister', '--network', network, 'call', canister,
           'getFileChunk', f'("{title}", 0)']

    try:
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=30)
        output = result.stdout + result.stderr

        if 'null' in output:
            print(f"✗ File '{title}' not found in canister")
            sys.exit(1)

        # Extract metadata
        total_chunks_match = re.search(r'totalChunks = (\d+)', output)
        content_type_match = re.search(r'contentType = "([^"]*)"', output)
        artist_match = re.search(r'artist = "([^"]*)"', output)

        if not total_chunks_match:
            print("✗ Could not parse metadata")
            sys.exit(1)

        return {
            'total_chunks': int(total_chunks_match.group(1)),
            'content_type': content_type_match.group(1) if content_type_match else 'unknown',
            'artist': artist_match.group(1) if artist_match else 'unknown',
            'first_chunk_output': output
        }
    except subprocess.TimeoutExpired:
        print("✗ Timeout while getting metadata")
        sys.exit(1)
    except Exception as e:
        print(f"✗ Error getting metadata: {e}")
        sys.exit(1)

def download_chunk(canister, network, title, chunk_id):
    """Download a specific chunk"""
    cmd = ['dfx', 'canister', '--network', network, 'call', canister,
           'getFileChunk', f'("{title}", {chunk_id})']

    try:
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=60)
        output = result.stdout + result.stderr

        if result.returncode != 0 or 'null' in output:
            return None

        return parse_blob_from_candid(output)
    except subprocess.TimeoutExpired:
        print(f"✗ Timeout downloading chunk {chunk_id}")
        return None
    except Exception as e:
        print(f"✗ Error downloading chunk {chunk_id}: {e}")
        return None

def main():
    if len(sys.argv) < 5:
        print("Usage: script.py <title> <output> <canister> <network>")
        sys.exit(1)

    title = sys.argv[1]
    output = sys.argv[2]
    canister = sys.argv[3]
    network = sys.argv[4]

    # Get metadata
    print("Getting file metadata...")
    metadata = get_file_metadata(canister, network, title)

    print(f"File found!")
    print(f"  Title: {title}")
    print(f"  Artist: {metadata['artist']}")
    print(f"  Content-Type: {metadata['content_type']}")
    print(f"  Total chunks: {metadata['total_chunks']}")
    print("")

    # Download all chunks
    file_data = bytearray()

    for i in range(metadata['total_chunks']):
        print(f"Downloading chunk {i+1}/{metadata['total_chunks']}...")

        if i == 0:
            # We already have the first chunk from metadata call
            chunk_data = parse_blob_from_candid(metadata['first_chunk_output'])
        else:
            chunk_data = download_chunk(canister, network, title, i)

        if chunk_data is None:
            print(f"✗ Failed to download chunk {i}")
            sys.exit(1)

        file_data.extend(chunk_data)

    print("")
    print("Assembling chunks...")

    # Write to output file
    try:
        with open(output, 'wb') as f:
            f.write(file_data)
    except Exception as e:
        print(f"✗ Failed to write output file: {e}")
        sys.exit(1)

    # Get file size
    file_size = len(file_data)

    print("")
    print("✓ Download completed successfully!")
    print(f"  Output file: {output}")
    print(f"  File size: {file_size} bytes")
    print(f"  Content-Type: {metadata['content_type']}")
    print("")

    # Calculate checksums
    import hashlib

    md5_hash = hashlib.md5(file_data).hexdigest()
    sha256_hash = hashlib.sha256(file_data).hexdigest()

    print("File checksums (for verification):")
    print(f"  MD5:    {md5_hash}")
    print(f"  SHA256: {sha256_hash}")

if __name__ == '__main__':
    main()
PYTHON_SCRIPT

# Run the Python script
python3 /tmp/download_canister_file.py "$title" "$output" "$canister" "$network"
exit_code=$?

# Clean up
rm -f /tmp/download_canister_file.py

exit $exit_code
