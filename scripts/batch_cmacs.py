#!/usr/bin/env python3
import json
import subprocess
import sys

##########################################################################
# BATCH CMAC PROCESSING WITH DFX
##########################################################################

def split_list(lst, batch_size):
    return [lst[i:i + batch_size] for i in range(0, len(lst), batch_size)]

def convert_to_candid(data):
    quoted_strings = [f'"{x}"' for x in data]
    return '(vec {' + ';'.join(quoted_strings) + '})'

def main():
    if len(sys.argv) not in [4, 5]:
        print("Usage: python3 batch_cmacs.py <cmacs_file> <canister_name> <page_path> [--ic]")
        sys.exit(1)

    json_file = sys.argv[1]
    canister_name = sys.argv[2]
    page_path = sys.argv[3]
    
    ic_mode = False
    if len(sys.argv) == 5 and sys.argv[4] == "--ic":
        ic_mode = True
    
    batch_size = 1500  # Max batch size for terminal

    # Read the full JSON file
    with open(json_file, 'r') as f:
        all_cmacs = json.load(f)

    # Split into batches
    batches = split_list(all_cmacs, batch_size)
    total_batches = len(batches)

    print(f"Processing {len(all_cmacs)} CMACs in {total_batches} batches")
    
    ic_flag = "--ic " if ic_mode else ""

    # Process each batch
    for i, batch in enumerate(batches, 1):
        print(f"Processing batch {i}/{total_batches}")
        candid_data = convert_to_candid(batch)
        
        cmd = f'dfx canister call {ic_flag}{canister_name} append_route_cmacs \'("{page_path}", {candid_data})\''
        result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
        
        if result.returncode != 0:
            print(f"Error processing batch {i}: {result.stderr}")
            sys.exit(1)
        
        print(f"Successfully processed batch {i}")

if __name__ == "__main__":
    main()